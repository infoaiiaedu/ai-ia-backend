from ninja import Schema
from typing import List, Optional

class SubjectSchema(Schema):
    id: int
    name: str

class GradeSchema(Schema):
    id: int
    level: str

class TopicSchema(Schema):
    id: int
    name: str
    subject: SubjectSchema
    grade: Optional[GradeSchema] = None
    image: Optional[dict] = None
    video: Optional[dict] = None
    description: Optional[str] = None

