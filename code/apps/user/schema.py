from ninja import Schema, Form
from typing import Optional, List
from datetime import date
from pydantic import field_validator

class RegisterSchema(Schema):
    name: str
    mobile_phone: str
    password: str


class TokenSchema(Schema):
    access_token: str
    refresh_token: str
    

class ChildRegisterSchema(Schema):
    first_name: str
    last_name: str
    gender: str
    date_of_birth: date
    grade: int
    subject_id: int

class ChildLoginSchema(Schema):
    access_code: str
    nickname: Optional[str] = None
    avatar_id: Optional[int] = None

    @field_validator("nickname", mode="before")
    @classmethod
    def _empty_nickname_to_none(cls, value):
        if value == "":
            return None
        return value

    @field_validator("avatar_id", mode="before")
    @classmethod
    def _empty_avatar_to_none(cls, value):
        if value == "" or value is None:
            return None
        return value


class AvatarSchema(Schema):
    id: int
    name: str
    image: str


class SubjectMiniSchema(Schema):
    id: int
    name: str


class ParentChildSchema(Schema):
    first_name: str
    last_name: str
    grade: int
    age: Optional[int] = None
    subject: Optional[SubjectMiniSchema] = None
    access_code: Optional[str] = None


class DiagnosticAnswerOptionSchema(Schema):
    id: int
    text: str


class DiagnosticQuestionSchema(Schema):
    id: int
    text: str
    question_type: str
    answers: List[DiagnosticAnswerOptionSchema] = []
    topic_id: int
    topic_name: Optional[str] = None


class DiagnosticTopicStatusSchema(Schema):
    id: int
    name: str
    status: str


class DiagnosticAnswerSchema(Schema):
    session_id: int
    question_id: int
    answer_id: Optional[int] = None
    text: Optional[str] = None


class DiagnosticResponseSchema(Schema):
    session_id: int
    is_complete: bool
    total_answered: int
    max_questions: int
    max_minutes: int
    time_remaining_seconds: Optional[int] = None
    question: Optional[DiagnosticQuestionSchema] = None
    boundary_topic: Optional[DiagnosticTopicStatusSchema] = None
    weak_topics: List[DiagnosticTopicStatusSchema] = []
    topics: List[DiagnosticTopicStatusSchema] = []

class OTPResponseSchema(Schema):
    message: str
    access_code: Optional[str] = None


class LeaderboardEntrySchema(Schema):
    rank: int
    child_id: int
    name: str
    nickname: Optional[str] = None
    avatar: Optional[str] = None
    xp: int


class LeaderboardResponseSchema(Schema):
    subject_id: int
    period: str
    entries: List[LeaderboardEntrySchema]
    me_rank: Optional[int] = None