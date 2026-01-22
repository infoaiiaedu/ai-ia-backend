from ninja import Schema
from typing import List, Optional
from datetime import datetime


class SubjectSchema(Schema):
    id: int
    name: str


class GradeSchema(Schema):
    id: int
    level: str


class TopicSchema(Schema):
    id: int
    name: str
    grade: Optional[GradeSchema] = None
    image: Optional[dict] = None
    video: Optional[dict] = None
    description: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class AnswerSchema(Schema):
    id: int
    text: str
    is_correct: bool


class AnswerIn(Schema):
    text: str
    is_correct: Optional[bool] = False


class QuestionSchema(Schema):
    id: int
    text: str
    question_type: str
    xp: int
    correct_text_answer: Optional[str] = None
    explanation: Optional[str] = None
    answers: List[AnswerSchema] = []


class QuestionIn(Schema):
    text: str
    question_type: str
    xp: Optional[int] = 10
    correct_text_answer: Optional[str] = None
    explanation: Optional[str] = None


class QuizSchema(Schema):
    id: int
    title: str
    description: Optional[str] = None
    level: int
    is_active: bool
    created_at: datetime
    updated_at: datetime
    questions: List[QuestionSchema] = []


class QuizIn(Schema):
    title: str
    description: Optional[str] = None
    level: int
    is_active: Optional[bool] = True


class PublicAnswerSchema(Schema):
        id: int
        text: str


class PublicQuestionSchema(Schema):
        id: int
        text: str
        question_type: str
        xp: int
        explanation: Optional[str] = None
        answers: List[PublicAnswerSchema] = []


class PublicQuizSchema(Schema):
        id: int
        title: str
        description: Optional[str] = None
        level: int
        is_active: bool
        created_at: datetime
        updated_at: datetime
        questions: List[PublicQuestionSchema] = []

