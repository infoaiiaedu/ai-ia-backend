from typing import List, Optional

from django.db import models
from django.utils import timezone
from ninja.security import HttpBearer
from apps.core.models import Subject, Topic, Question
from apps.user.models import Child, DiagnosticSession, XPEvent
from .utils import decode_jwt_token, decode_child_jwt_token


class AuthBearer(HttpBearer):
    def authenticate(self, request, token):
        account, valid = decode_jwt_token(token)
        if not valid:
            return None
        return account


class ChildAuthBearer(HttpBearer):
    def authenticate(self, request, token):
        account, valid = decode_child_jwt_token(token)
        if not valid:
            return None
        return account

STREAK_BONUS_MAP = {
    7: 50,
    14: 120,
    21: 200,
    28: 300,
}


def _award_xp(child: Child, amount: int, source: str, subject: Optional[Subject] = None):
    if amount <= 0:
        return
    XPEvent.objects.create(child=child, subject=subject, amount=amount, source=source)
    Child.objects.filter(id=child.id).update(xp_total=models.F("xp_total") + amount)


def _update_streak(child: Child):
    today = timezone.localdate()
    if child.last_active_date == today:
        return

    yesterday = today - timezone.timedelta(days=1)
    if child.last_active_date == yesterday:
        child.streak_count += 1
    else:
        child.streak_count = 1

    child.last_active_date = today
    child.save(update_fields=["streak_count", "last_active_date"])

    bonus = STREAK_BONUS_MAP.get(child.streak_count)
    if bonus:
        _award_xp(child, bonus, f"streak_{child.streak_count}", child.subject)


def _build_profile_progress(child: Child) -> dict:
    completed_sessions = list(
        DiagnosticSession.objects.filter(child=child, is_complete=True).only("topic_outcomes")
    )
    tests_completed = len(completed_sessions)
    tests_attempted = DiagnosticSession.objects.filter(child=child).count()

    tests_passed = 0
    for session in completed_sessions:
        outcomes = session.topic_outcomes or {}
        known = sum(1 for status in outcomes.values() if status == "known")
        weak = sum(1 for status in outcomes.values() if status == "weak")
        if (known + weak) > 0 and known >= weak:
            tests_passed += 1

    tests_failed = tests_completed - tests_passed
    quizzes_completed = 0
    quizzes_passed = 0
    quizzes_failed = 0
    total_attempts = quizzes_completed + tests_attempted

    return {
        "quizzes_completed": quizzes_completed,
        "quizzes_passed": quizzes_passed,
        "quizzes_failed": quizzes_failed,
        "tests_completed": tests_completed,
        "tests_passed": tests_passed,
        "tests_failed": tests_failed,
        "total_attempts": total_attempts,
    }


def _build_weekly_activity(child: Child) -> List[bool]:
    today = timezone.localdate()
    start_of_week = today - timezone.timedelta(days=today.weekday())
    end_of_week = start_of_week + timezone.timedelta(days=6)

    event_dates = XPEvent.objects.filter(
        child=child,
        created_at__date__range=(start_of_week, end_of_week),
    ).values_list("created_at", flat=True)
    active_dates = {timezone.localdate(dt) for dt in event_dates}

    if child.last_active_date and start_of_week <= child.last_active_date <= end_of_week:
        active_dates.add(child.last_active_date)

    return [
        (start_of_week + timezone.timedelta(days=offset)) in active_dates
        for offset in range(7)
    ]


def _topics_with_questions(subject: Subject) -> List[int]:
    return list(
        Topic.objects.filter(subject=subject, quizzes__questions__isnull=False)
        .distinct()
        .order_by("order", "id")
        .values_list("id", flat=True)
    )


def _pick_question(topic_id: int, asked_ids: List[int], level: Optional[int] = None) -> Optional[Question]:
    qs = (
        Question.objects.filter(quiz__topics=topic_id)
        .exclude(id__in=asked_ids)
        .distinct()
        .prefetch_related("answers")
    )
    if level:
        qs = qs.filter(level=level)
    question = qs.order_by("order", "id").first()
    if question is None and level is not None:
        question = (
            Question.objects.filter(quiz__topics=topic_id)
            .exclude(id__in=asked_ids)
            .distinct()
            .prefetch_related("answers")
            .order_by("order", "id")
            .first()
        )
    return question


def _serialize_diagnostic_question(question: Question, topic_id: int, topic_name: Optional[str]):
    answers = []
    if question.question_type == Question.MCQ:
        answers = [
            {"id": answer.id, "text": answer.text}
            for answer in question.answers.all().order_by("order")
        ]

    return {
        "id": question.id,
        "text": question.text,
        "question_type": question.question_type,
        "answers": answers,
        "topic_id": topic_id,
        "topic_name": topic_name,
    }


def _build_topic_status(session: DiagnosticSession):
    topic_map = Topic.objects.in_bulk(session.topics)
    topics = []
    weak_topics = []
    for topic_id in session.topics:
        topic = topic_map.get(topic_id)
        status = session.topic_outcomes.get(str(topic_id), "unknown")
        item = {"id": topic_id, "name": topic.name if topic else "", "status": status}
        topics.append(item)
        if status == "weak":
            weak_topics.append(item)

    return topics, weak_topics


def _diagnostic_response(
    session: DiagnosticSession,
    question: Optional[Question] = None,
    topic_id: Optional[int] = None,
):
    expires_at = session.created_at + timezone.timedelta(minutes=session.max_minutes)
    remaining_seconds = max(0, int((expires_at - timezone.now()).total_seconds()))
    payload = {
        "session_id": session.id,
        "is_complete": session.is_complete,
        "total_answered": session.total_answered,
        "max_questions": session.max_questions,
        "max_minutes": session.max_minutes,
        "time_remaining_seconds": remaining_seconds if not session.is_complete else 0,
        "question": None,
        "boundary_topic": None,
        "weak_topics": [],
        "topics": [],
    }

    if question is not None and topic_id is not None:
        topic_name = Topic.objects.filter(id=topic_id).values_list("name", flat=True).first()
        payload["question"] = _serialize_diagnostic_question(question, topic_id, topic_name)

    if session.is_complete:
        topics, weak_topics = _build_topic_status(session)
        payload["topics"] = topics
        payload["weak_topics"] = weak_topics
        if session.boundary_topic_id:
            boundary_topic = Topic.objects.filter(id=session.boundary_topic_id).first()
            if boundary_topic:
                payload["boundary_topic"] = {
                    "id": boundary_topic.id,
                    "name": boundary_topic.name,
                    "status": "weak",
                }

    return payload
