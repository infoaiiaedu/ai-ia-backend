from ninja import Schema
from typing import List, Optional
from datetime import datetime

class GradeSchema(Schema):
    id: int
    level: str
    quizzes_count: int = 0

class SubjectSchema(Schema):
    id: int
    name: str
    short_description: Optional[str] = None
    icon: Optional[dict] = None
    cover_image: Optional[dict] = None
    grade: Optional[GradeSchema] = None
    topics_count: int = 0
    quizzes_count: int = 0


class ParentSubjectSchema(Schema):
    id: int
    name: str
    grade: Optional[GradeSchema] = None
    short_description: Optional[str] = None
    cover_image: Optional[dict] = None
    topics: List[str] = []


class TopicSchema(Schema):
    id: int
    name: str
    subject: Optional[SubjectSchema] = None
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
    level: int
    xp: int
    correct_text_answer: Optional[str] = None
    explanation: Optional[str] = None
    answers: List[AnswerSchema] = []


class QuestionIn(Schema):
    text: str
    question_type: str
    level: int
    xp: Optional[int] = 10
    correct_text_answer: Optional[str] = None
    explanation: Optional[str] = None


class QuizSchema(Schema):
    id: int
    title: str
    description: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime
    topics: List[TopicSchema] = []
    questions: List[QuestionSchema] = []


class QuizIn(Schema):
    title: str
    description: Optional[str] = None
    is_active: Optional[bool] = True


class PublicAnswerSchema(Schema):
        id: int
        text: str


class PublicQuestionSchema(Schema):
    id: int
    text: str
    question_type: str
    level: int
    xp: int
    explanation: Optional[str] = None
    answers: List[PublicAnswerSchema] = []


class PublicQuizSchema(Schema):
    id: int
    title: str
    description: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime
    topics: List[TopicSchema] = []
    questions: List[PublicQuestionSchema] = []


class AnswerSubmission(Schema):
    """User's answer submission - can be answer_id or text"""
    question_id: int
    answer_id: Optional[int] = None  # For MCQ
    text: Optional[str] = None  # For open questions


class QuizSubmission(Schema):
    """Submit multiple answers for a quiz"""
    quiz_id: int
    answers: List[AnswerSubmission]


class AnswerResult(Schema):
    """Result of a single answer validation"""
    question_id: int
    is_correct: bool
    explanation: Optional[str] = None
    xp: int = 0  # XP earned if correct


class QuizSubmissionResult(Schema):
    """Result of quiz submission"""
    total_xp: int
    correct_count: int
    total_count: int
    answers: List[AnswerResult]
    questions: List[PublicQuestionSchema] = []

