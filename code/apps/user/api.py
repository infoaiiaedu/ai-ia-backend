import random

from ninja import Router, Form
from typing import List, Optional
from datetime import date
from django.db import models
from django.utils import timezone
from ninja.errors import HttpError
from ninja.security import HttpBearer
from apps.user.models import Parent, Child, Logo, DiagnosticSession, XPEvent
from apps.core.models import Subject, Topic, Question, Answer
from .schema import TokenSchema, ChildRegisterSchema, OTPResponseSchema, AvatarSchema, ChildLoginSchema
from .schema import ParentChildSchema, DiagnosticAnswerSchema, DiagnosticResponseSchema
from .schema import LeaderboardEntrySchema, LeaderboardResponseSchema
from .schema import ChildProfileSchema
from .utils import decode_jwt_token, decode_child_jwt_token
from django.shortcuts import get_object_or_404

router = Router(tags=["User"])


# ---------------------------
# AuthBearer for JWT
# ---------------------------
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


# ---------------------------
# Parent Registration (sends OTP via Twilio)
# ---------------------------
@router.post("/parent/register/", response=OTPResponseSchema)
def parent_register(
    request,
    name: str = Form(...),
    contact: str = Form(...),
):
    clean_name = name.strip()
    contact_value = contact.strip()

    if not clean_name:
        raise HttpError(400, "Name is required")
    if not contact_value:
        raise HttpError(400, "Email or phone is required")

    is_email = "@" in contact_value
    if is_email:
        if Parent.objects.filter(email__iexact=contact_value).exists():
            raise HttpError(400, "Parent with this email already exists")
        parent = Parent.objects.create(name=clean_name, email=contact_value.lower())
        parent.generate_otp()
        result = parent.send_otp_email()
    else:
        if Parent.objects.filter(mobile_phone=contact_value).exists():
            raise HttpError(400, "Parent with this mobile phone already exists")
        parent = Parent.objects.create(name=clean_name, mobile_phone=contact_value)
        parent.generate_otp()
        result = parent.send_otp_sms()

    if not result.get("success"):
        raise HttpError(500, f"Failed to send OTP: {result.get('error')}")

    return {"message": "Parent created. Check your email or phone for OTP."}


# ---------------------------
# Parent Login (sends OTP)
# ---------------------------
@router.post("/parent/login/", response=OTPResponseSchema)
def parent_login(
    request,
    email: str = Form(...),
):
    email_value = email.strip()
    if not email_value:
        raise HttpError(400, "Email is required")

    try:
        parent = Parent.objects.get(email__iexact=email_value)
    except Parent.DoesNotExist:
        raise HttpError(400, "Parent not found")

    parent.generate_otp()
    result = parent.send_otp_email()

    if not result.get("success"):
        raise HttpError(500, f"Failed to send OTP: {result.get('error')}")

    return {"message": "OTP sent. Check your email."}


# ---------------------------
# Parent Verify OTP and Login
# ---------------------------
@router.post("/parent/verify_otp/", response=TokenSchema)
def parent_verify_otp(
    request,
    contact: str = Form(...),
    otp_code: str = Form(...),
):
    try:
        contact_value = contact.strip()
        if "@" in contact_value:
            parent = Parent.objects.get(email__iexact=contact_value)
        else:
            parent = Parent.objects.get(mobile_phone=contact_value)
    except Parent.DoesNotExist:
        raise HttpError(400, "Parent not found")

    if parent.verify_otp(otp_code):
        parent.is_verified = True
        parent.save(update_fields=["is_verified"])
        tokens = parent.generate_tokens()
        return {
            "access_token": tokens["access_token"],
            "refresh_token": tokens["refresh_token"],
            "message": "Parent verified and logged in successfully."
        }

    raise HttpError(400, "Invalid or expired OTP")


@router.post("/child/register/", response=OTPResponseSchema, auth=AuthBearer())
def child_register(request, data: ChildRegisterSchema):
    parent: Parent = request.auth

    first = data.first_name.strip()
    last = data.last_name.strip()
    if not first or not last:
        raise HttpError(400, "Student first and last name are required")

    gender_value = data.gender.strip().lower()
    gender_map = {"boy": "male", "girl": "female", "male": "male", "female": "female"}
    if gender_value not in gender_map:
        raise HttpError(400, "Gender must be boy or girl")
    gender = gender_map[gender_value]

    subject = get_object_or_404(Subject, id=data.subject_id)

    child = Child.objects.create(
        parent=parent,
        name=f"{first} {last}".strip(),
        grade=data.grade,
        subject=subject,
        date_of_birth=data.date_of_birth,
        sex=gender,
    )

    access_code = child.generate_access_code()

    return {
        "message": f"Child {child.name} registered.",
        "access_code": access_code,
    }

@router.post("/child/login/", response=TokenSchema)
def child_login(request, data: ChildLoginSchema = Form(...)):
    try:
        clean_code = data.access_code.strip()
        if not clean_code:
            raise HttpError(400, "Access code is required")
        child = Child.objects.get(access_code=clean_code)
    except Child.DoesNotExist:
        raise HttpError(400, "Invalid access code")

    update_fields = []
    if data.nickname is not None:
        clean_nickname = data.nickname.strip()
        child.nickname = clean_nickname or None
        update_fields.append("nickname")

    if data.avatar_id is not None:
        logo = get_object_or_404(Logo, id=data.avatar_id)
        child.logo = logo
        update_fields.append("logo")

    if update_fields:
        child.save(update_fields=update_fields)

    _update_streak(child)

    tokens = child.generate_tokens()
    return {
        "access_token": tokens["access_token"],
        "refresh_token": tokens["refresh_token"],
        "message": f"Child {child.name} logged in successfully."
    }


@router.get("/avatars/", response=List[AvatarSchema])
def avatars_list(request):
    logos = Logo.objects.all().order_by("id")
    return [
        {
            "id": logo.id,
            "name": logo.name,
            "image": logo.image.url if logo.image else "",
        }
        for logo in logos
    ]

@router.get("/parent/children/", response=List[ParentChildSchema], auth=AuthBearer())
def parent_children(request):
    parent: Parent = request.auth
    children = Child.objects.filter(parent=parent).select_related("subject")
    today = date.today()

    result = []
    for child in children:
        parts = child.name.split()
        first_name = parts[0] if parts else ""
        last_name = " ".join(parts[1:]) if len(parts) > 1 else ""
        age = None
        if child.date_of_birth:
            age = today.year - child.date_of_birth.year
            if (today.month, today.day) < (child.date_of_birth.month, child.date_of_birth.day):
                age -= 1

        subject = None
        if child.subject:
            subject = {"id": child.subject.id, "name": child.subject.name}

        result.append(
            {
                "first_name": first_name,
                "last_name": last_name,
                "grade": child.grade,
                "age": age,
                "subject": subject,
                "access_code": child.access_code,
            }
        )

    return result


@router.get("/child/profile/", response=ChildProfileSchema, auth=ChildAuthBearer())
def child_profile(request):
    child: Child = request.auth

    item_bought = None
    if child.subject:
        item_bought = {"id": child.subject.id, "name": child.subject.name}

    avatar = None
    if child.logo:
        image_url = child.logo.image.url if child.logo.image else ""
        avatar = {"id": child.logo.id, "name": child.logo.name, "image": image_url}

    progress = _build_profile_progress(child)

    return {
        "child_id": child.id,
        "full_name": child.name,
        "child_class": child.grade,
        "item_bought": item_bought,
        "nickname": child.nickname,
        "avatar": avatar,
        "streak_days": child.streak_count,
        "xp_count": child.xp_total,
        "progress": progress,
    }


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


@router.post("/child/diagnostic/start/", response=DiagnosticResponseSchema, auth=ChildAuthBearer())
def diagnostic_start(
    request,
    max_questions: Optional[int] = Form(None),
    max_minutes: Optional[int] = Form(None),
):
    child: Child = request.auth
    _update_streak(child)
    if not child.subject:
        raise HttpError(400, "Child has no subject")

    topics = _topics_with_questions(child.subject)
    if not topics:
        raise HttpError(400, "No diagnostic topics available")

    session = DiagnosticSession.objects.filter(
        child=child, subject=child.subject, is_complete=False
    ).order_by("-created_at").first()

    if session is not None:
        expires_at = session.created_at + timezone.timedelta(minutes=session.max_minutes)
        if timezone.now() >= expires_at:
            session.is_complete = True
            session.completed_at = timezone.now()
            session.save(update_fields=["is_complete", "completed_at"])

    if session is None or session.is_complete:
        max_q = max_questions if max_questions and max_questions > 0 else 22
        max_m = max_minutes if max_minutes and max_minutes > 0 else 12
        if max_q > 22:
            max_q = 22
        if max_m > 12:
            max_m = 12
        eligible_topic_ids = list(
            Topic.objects.filter(id__in=topics, quizzes__questions__level=2)
            .distinct()
            .values_list("id", flat=True)
        )
        start_topic_id = random.choice(eligible_topic_ids or topics)
        start_index = topics.index(start_topic_id) if start_topic_id in topics else (len(topics) - 1) // 2
        session = DiagnosticSession.objects.create(
            child=child,
            subject=child.subject,
            topics=topics,
            low_index=0,
            high_index=len(topics) - 1,
            current_index=start_index,
            current_level=2,
            max_questions=max_q,
            max_minutes=max_m,
        )
    elif session.current_level not in (1, 2, 3):
        session.current_level = 2
        session.save(update_fields=["current_level"])

    if session.current_question_id and session.total_answered < len(session.asked_question_ids):
        question = Question.objects.prefetch_related("answers").get(id=session.current_question_id)
        topic_id = session.current_topic_id or session.topics[session.current_index]
        return _diagnostic_response(session, question, topic_id)

    topic_id = session.topics[session.current_index]
    question = _pick_question(topic_id, session.asked_question_ids, session.current_level)
    if not question:
        session.is_complete = True
        session.completed_at = timezone.now()
        session.save(update_fields=["is_complete", "completed_at"])
        return _diagnostic_response(session)

    session.current_topic_id = topic_id
    session.current_question_id = question.id
    if question.id not in session.asked_question_ids:
        session.asked_question_ids.append(question.id)
    session.save(update_fields=["current_topic_id", "current_question_id", "asked_question_ids"])

    return _diagnostic_response(session, question, topic_id)


@router.post("/child/diagnostic/answer/", response=DiagnosticResponseSchema, auth=ChildAuthBearer())
def diagnostic_answer(request, data: DiagnosticAnswerSchema = Form(...)):
    child: Child = request.auth
    _update_streak(child)
    session = get_object_or_404(DiagnosticSession, id=data.session_id, child=child)
    if session.is_complete:
        return _diagnostic_response(session)

    expires_at = session.created_at + timezone.timedelta(minutes=session.max_minutes)
    if timezone.now() >= expires_at:
        session.is_complete = True
        session.completed_at = timezone.now()
        session.current_question_id = None
        session.current_topic_id = None
        session.save(update_fields=[
            "is_complete",
            "completed_at",
            "current_question_id",
            "current_topic_id",
        ])
        return _diagnostic_response(session)

    if session.current_question_id != data.question_id:
        raise HttpError(400, "Question does not match current session")

    question = Question.objects.prefetch_related("answers").get(id=data.question_id)
    topic_id = session.current_topic_id
    if topic_id is None:
        raise HttpError(400, "No active topic for this session")

    is_correct = False
    if question.question_type == Question.MCQ:
        if data.answer_id:
            answer = Answer.objects.filter(id=data.answer_id, question=question).first()
            is_correct = bool(answer and answer.is_correct)
    else:
        if data.text and question.correct_text_answer:
            is_correct = data.text.strip().lower() == question.correct_text_answer.strip().lower()

    if is_correct:
        _award_xp(child, question.xp or 0, "diagnostic_correct", question.quiz.subject or child.subject)

    stats_key = str(topic_id)
    stats = session.topic_stats.get(stats_key, {"asked": 0, "correct": 0})
    stats["asked"] += 1
    if is_correct:
        stats["correct"] += 1
    session.topic_stats[stats_key] = stats
    session.total_answered += 1

    if not is_correct and stats["asked"] < 2 and session.total_answered < session.max_questions:
        next_question = _pick_question(topic_id, session.asked_question_ids, session.current_level)
        if next_question:
            session.current_topic_id = topic_id
            session.current_question_id = next_question.id
            if next_question.id not in session.asked_question_ids:
                session.asked_question_ids.append(next_question.id)
            session.save(update_fields=[
                "current_topic_id",
                "current_question_id",
                "asked_question_ids",
                "topic_stats",
                "total_answered",
            ])
            return _diagnostic_response(session, next_question, topic_id)

    outcome = "known" if stats["correct"] > 0 else "weak"
    session.topic_outcomes[stats_key] = outcome
    if outcome == "known":
        session.current_level = min(3, session.current_level + 1)
    else:
        session.current_level = max(1, session.current_level - 1)
    if outcome == "weak":
        if session.boundary_topic_id is None:
            session.boundary_topic_id = topic_id
        else:
            current_index = session.current_index
            try:
                boundary_index = session.topics.index(session.boundary_topic_id)
            except ValueError:
                boundary_index = current_index
            if current_index < boundary_index:
                session.boundary_topic_id = topic_id
    if outcome == "known":
        session.low_index = session.current_index + 1
    else:
        session.high_index = session.current_index - 1

    if session.total_answered >= session.max_questions or session.low_index > session.high_index:
        session.is_complete = True
        session.completed_at = timezone.now()
        session.current_question_id = None
        session.current_topic_id = None
        session.save(update_fields=[
            "is_complete",
            "completed_at",
            "current_question_id",
            "current_topic_id",
            "topic_outcomes",
            "topic_stats",
            "total_answered",
            "low_index",
            "high_index",
            "boundary_topic_id",
            "current_level",
        ])
        return _diagnostic_response(session)

    session.current_index = (session.low_index + session.high_index) // 2
    next_topic_id = session.topics[session.current_index]
    next_question = _pick_question(next_topic_id, session.asked_question_ids, session.current_level)
    if not next_question:
        session.is_complete = True
        session.completed_at = timezone.now()
        session.current_question_id = None
        session.current_topic_id = None
        session.save(update_fields=[
            "is_complete",
            "completed_at",
            "current_question_id",
            "current_topic_id",
            "topic_outcomes",
            "topic_stats",
            "total_answered",
            "low_index",
            "high_index",
            "current_index",
            "current_level",
        ])
        return _diagnostic_response(session)

    session.current_topic_id = next_topic_id
    session.current_question_id = next_question.id
    if next_question.id not in session.asked_question_ids:
        session.asked_question_ids.append(next_question.id)
    session.save(update_fields=[
        "current_topic_id",
        "current_question_id",
        "asked_question_ids",
        "topic_outcomes",
        "topic_stats",
        "total_answered",
        "low_index",
        "high_index",
        "current_index",
        "boundary_topic_id",
        "current_level",
    ])

    return _diagnostic_response(session, next_question, next_topic_id)


@router.get("/leaderboard/{int:subject_id}/", response=LeaderboardResponseSchema, auth=ChildAuthBearer())
def leaderboard(request, subject_id: int, period: str = "weekly"):
    child: Child = request.auth
    subject = get_object_or_404(Subject, id=subject_id)

    now = timezone.now()
    period_key = period.lower()
    if period_key == "monthly":
        since = now - timezone.timedelta(days=30)
    elif period_key == "yearly":
        since = now - timezone.timedelta(days=365)
    else:
        period_key = "weekly"
        since = now - timezone.timedelta(days=7)

    qs = (
        XPEvent.objects.filter(subject=subject, created_at__gte=since)
        .values("child_id", "child__name", "child__nickname", "child__logo__image")
        .annotate(xp=models.Sum("amount"))
        .order_by("-xp", "child_id")
    )

    entries = []
    me_rank = None
    for idx, row in enumerate(qs, start=1):
        if row["child_id"] == child.id:
            me_rank = idx
        entries.append(
            {
                "rank": idx,
                "child_id": row["child_id"],
                "name": row["child__name"],
                "nickname": row["child__nickname"],
                "avatar": row["child__logo__image"] or None,
                "xp": int(row["xp"] or 0),
            }
        )

    return {
        "subject_id": subject.id,
        "period": period_key,
        "entries": entries,
        "me_rank": me_rank,
    }
