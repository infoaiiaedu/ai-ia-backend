# apps/core/router.py
from ninja import Router
from typing import List, Optional
from django.shortcuts import get_object_or_404
from django.db.models import Count


# Authentication temporarily commented out
# from apps.user.utils import decode_jwt_token
# from ninja.security import HttpBearer

from .models import Subject, Grade, Topic, Quiz, Question, Answer
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
    AnswerSubmission,
    QuizSubmission,
    AnswerResult,
    QuizSubmissionResult,
)

router = Router()


@router.get("/subjects/", response=List[SubjectSchema])
def list_subjects(request, grade_id: Optional[int] = None):
    subjects = Subject.objects.filter(is_active=True)
    if grade_id is not None:
        subjects = subjects.filter(grade_id=grade_id)
    subjects = subjects.annotate(
        topics_count=Count('topics', distinct=True),
        quizzes_count=Count('quizzes', distinct=True)
    )
    return subjects.distinct()


@router.get("/subjects/{subject_id}/", response=SubjectSchema)
def get_subject(request, subject_id: int):
    return get_object_or_404(
        Subject.objects.annotate(
            topics_count=Count('topics', distinct=True),
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
def get_topics(request, topic_id: Optional[int] = None, grade_id: Optional[int] = None, subject_id: Optional[int] = None):
    """Get topics with optional filtering by topic_id, grade_id, or subject_id"""
    topics = Topic.objects.select_related('subject')
    
    if topic_id is not None:
        topics = topics.filter(id=topic_id)
    
    if grade_id is not None:
        topics = topics.filter(subject__grade_id=grade_id)
    
    if subject_id is not None:
        topics = topics.filter(subject_id=subject_id)
    
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


@router.post("/quizzes/submit/", response=QuizSubmissionResult)
def submit_quiz(request, payload: QuizSubmission):
    quiz = get_object_or_404(Quiz, id=payload.quiz_id)
    results = []
    total_xp = 0
    correct_count = 0
    
    for submission in payload.answers:
        question = get_object_or_404(Question, id=submission.question_id, quiz=quiz)
        is_correct = False
        xp = 0
        
        if question.question_type == Question.MCQ:
            # For multiple choice - check answer_id
            if submission.answer_id:
                answer = get_object_or_404(Answer, id=submission.answer_id, question=question)
                is_correct = answer.is_correct
        else:
            # For open question - check text match (case-insensitive)
            if submission.text and question.correct_text_answer:
                is_correct = submission.text.lower().strip() == question.correct_text_answer.lower().strip()
        
        if is_correct:
            xp = question.xp
            correct_count += 1
            total_xp += xp
        
        results.append({
            'question_id': question.id,
            'is_correct': is_correct,
            'explanation': question.explanation,
            'xp': xp,
        })
    
    return {
        'total_xp': total_xp,
        'correct_count': correct_count,
        'total_count': len(payload.answers),
        'answers': results,
    }


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


