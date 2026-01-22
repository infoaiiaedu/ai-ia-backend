# apps/core/router.py
from ninja import Router
from typing import List, Optional
from django.shortcuts import get_object_or_404
from django.db.models import Count


# Authentication temporarily commented out
# from apps.user.utils import decode_jwt_token
# from ninja.security import HttpBearer

from .models import Subject, Grade, Topic, Quiz
from .schema import (
    SubjectSchema,
    GradeSchema,
    TopicSchema,
    PublicQuizSchema,
    PublicQuestionSchema,
    PublicAnswerSchema,
    QuizSchema,
    QuestionSchema,
    AnswerSchema,
)

router = Router()


@router.get("/subjects/", response=List[SubjectSchema])
def list_subjects(request):
    subjects = Subject.objects.filter(is_active=True).annotate(
        topics_count=Count('topic', distinct=True),
        quizzes_count=Count('quizzes', distinct=True)
    )
    return subjects


@router.get("/subjects/{subject_id}/", response=SubjectSchema)
def get_subject(request, subject_id: int):
    return get_object_or_404(
        Subject.objects.annotate(
            topics_count=Count('topic', distinct=True),
            quizzes_count=Count('quizzes', distinct=True)
        ),
        id=subject_id
    )


@router.get("/grades/", response=List[GradeSchema])
def list_grades(request):
    return Grade.objects.annotate(
        quizzes_count=Count('quizzes', distinct=True)
    )


@router.get("/topics/", response=List[TopicSchema])
def get_topics(request, topic_id: Optional[int] = None, grade_id: Optional[int] = None):
    """Get topics with optional filtering by topic_id or grade_id"""
    topics = Topic.objects.select_related('grade')
    
    if topic_id is not None:
        topics = topics.filter(id=topic_id)
    
    if grade_id is not None:
        topics = topics.filter(grade__id=grade_id)
    
    return list(topics.order_by('-created_at'))

def _serialize_quiz(quiz: Quiz):
    questions = []
    for q in quiz.questions.all().order_by('order'):
        answers = [
            {
                'id': a.id,
                'text': a.text,
                'is_correct': a.is_correct,
                'order': a.order,
            }
            for a in q.answers.all().order_by('order')
        ]
        questions.append({
            'id': q.id,
            'text': q.text,
            'question_type': q.question_type,
            'order': q.order,
            'xp': q.xp,
            'correct_text_answer': q.correct_text_answer,
            'explanation': q.explanation,
            'answers': answers,
        })

    return {
        'id': quiz.id,
        'title': quiz.title,
        'description': quiz.description,
        'level': quiz.level,
        'is_active': quiz.is_active,
        'created_at': quiz.created_at,
        'updated_at': quiz.updated_at,
        'questions': questions,
    }


@router.get("/quizzes/", response=List[PublicQuizSchema])
def list_quizzes(request):
    qs = Quiz.objects.filter(is_active=True).prefetch_related('questions__answers').order_by('-created_at')
    # serialize without exposing correct answers
    result = []
    for q in qs:
        questions = []
        for qq in q.questions.all().order_by('order'):
            answers = [
                {
                    'id': a.id,
                    'text': a.text,
                    'order': a.order,
                }
                for a in qq.answers.all().order_by('order')
            ]
            questions.append({
                'id': qq.id,
                'text': qq.text,
                'question_type': qq.question_type,
                'order': qq.order,
                'xp': qq.xp,
                'explanation': qq.explanation,
                'answers': answers,
            })
        result.append({
            'id': q.id,
            'title': q.title,
            'description': q.description,
            'level': q.level,
            'is_active': q.is_active,
            'created_at': q.created_at,
            'updated_at': q.updated_at,
            'questions': questions,
        })
    return result


@router.get("/quizzes/{quiz_id}/", response=PublicQuizSchema)
def get_quiz(request, quiz_id: int):
    quiz = get_object_or_404(Quiz.objects.prefetch_related('questions__answers'), id=quiz_id)
    questions = []
    for q in quiz.questions.all().order_by('order'):
        answers = [
            {
                'id': a.id,
                'text': a.text,
                'order': a.order,
            }
            for a in q.answers.all().order_by('order')
        ]
        questions.append({
            'id': q.id,
            'text': q.text,
            'question_type': q.question_type,
            'order': q.order,
            'xp': q.xp,
            'explanation': q.explanation,
            'answers': answers,
        })

    return {
        'id': quiz.id,
        'title': quiz.title,
        'description': quiz.description,
        'level': quiz.level,
        'is_active': quiz.is_active,
        'created_at': quiz.created_at,
        'updated_at': quiz.updated_at,
        'questions': questions,
    }


