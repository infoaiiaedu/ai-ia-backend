from typing import List, Optional

from django.utils import timezone
from ninja import Router
from ninja.errors import HttpError

from apps.core.models import Topic
from apps.core.schema import StudentContextSchema, TopicProfileSchema, ActivitySnapshotSchema
from apps.user.api_utils import ChildAuthBearer
from apps.user.models import Child, DiagnosticSession, XPEvent

router = Router(tags=["AI"])


def _build_topic_profiles(topic_ids: List[int]) -> List[TopicProfileSchema]:
    if not topic_ids:
        return []
    topic_map = Topic.objects.in_bulk(topic_ids)
    profiles = []
    for topic_id in topic_ids:
        topic = topic_map.get(topic_id)
        if topic:
            profiles.append({"id": topic.id, "name": topic.name})
    return profiles


def _build_activity_snapshot(child: Child) -> ActivitySnapshotSchema:
    today = timezone.localdate()
    start_date = today - timezone.timedelta(days=6)

    event_dates = XPEvent.objects.filter(
        child=child,
        created_at__date__range=(start_date, today),
    ).values_list("created_at", flat=True)

    active_dates = {timezone.localdate(dt) for dt in event_dates}
    if child.last_active_date and start_date <= child.last_active_date <= today:
        active_dates.add(child.last_active_date)

    days_active_7d = len(active_dates)

    if days_active_7d >= 5:
        consistency_band = "high"
    elif days_active_7d >= 2:
        consistency_band = "medium"
    else:
        consistency_band = "low"

    tests_completed_30d = DiagnosticSession.objects.filter(
        child=child,
        is_complete=True,
        completed_at__date__gte=today - timezone.timedelta(days=30),
    ).count()

    return {
        "days_active_7d": days_active_7d,
        "study_minutes_7d": 0,
        "tests_completed_30d": tests_completed_30d,
        "avg_accuracy": 0.0,
        "consistency_band": consistency_band,
    }


def _support_level(weak_count: int, strong_count: int) -> str:
    total = weak_count + strong_count
    if total == 0:
        return "medium"
    ratio = weak_count / total
    if ratio >= 0.6:
        return "high"
    if ratio >= 0.3:
        return "medium"
    return "low"


@router.get("/student-context/", response=StudentContextSchema, auth=ChildAuthBearer())
def get_student_context(request):
    child: Child = request.auth
    if child.subject_id is None:
        raise HttpError(400, "Child subject is not set")

    session = (
        DiagnosticSession.objects.filter(
            child=child,
            subject_id=child.subject_id,
            is_complete=True,
        )
        .order_by("-completed_at", "-created_at")
        .first()
    )

    boundary_topic: Optional[TopicProfileSchema] = None
    weak_topics: List[TopicProfileSchema] = []
    strong_topics: List[TopicProfileSchema] = []

    avg_accuracy = 0.0
    if session and session.topic_outcomes:
        outcomes = session.topic_outcomes
        weak_ids = [int(topic_id) for topic_id, status in outcomes.items() if status == "weak"]
        strong_ids = [int(topic_id) for topic_id, status in outcomes.items() if status == "known"]

        weak_topics = _build_topic_profiles(weak_ids)
        strong_topics = _build_topic_profiles(strong_ids)

        total = len(weak_ids) + len(strong_ids)
        if total:
            avg_accuracy = round((len(strong_ids) / total) * 100, 2)

        if session.boundary_topic_id:
            boundary = Topic.objects.filter(id=session.boundary_topic_id).first()
            if boundary:
                boundary_topic = {"id": boundary.id, "name": boundary.name}

    activity = _build_activity_snapshot(child)
    activity["avg_accuracy"] = avg_accuracy

    return {
        "boundary_topic": boundary_topic,
        "weak_topics": weak_topics,
        "strong_topics": strong_topics,
        "prerequisite_gaps": [],
        "support_level": _support_level(len(weak_topics), len(strong_topics)),
        "activity": activity,
    }
