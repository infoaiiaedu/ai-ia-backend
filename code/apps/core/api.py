# apps/core/router.py
from ninja import Router
from typing import List
from django.shortcuts import get_object_or_404

from apps.user.utils import decode_jwt_token
from ninja.security import HttpBearer
from .models import Subject, Grade, Topic
from .schema import (
    SubjectSchema,
    GradeSchema,
)

router = Router()

class AuthBearer(HttpBearer):
    def authenticate(self, request, token):
        account, state = decode_jwt_token(token)

        if not state:
            return None

        return account

@router.get("/subjects/", response=List[SubjectSchema], auth=AuthBearer())
def list_subjects(request):
    subjects = Subject.objects.filter(is_active=True)
    
    return subjects

@router.get("/subjects/{subject_id}/", response=SubjectSchema, auth=AuthBearer())
def get_subject(request, subject_id: int):
    return get_object_or_404(Subject, id=subject_id)

@router.delete("/subjects/{subject_id}/", response={"success": bool}, auth=AuthBearer())
def delete_subject(request, subject_id: int):
    subject = get_object_or_404(Subject, id=subject_id)
    subject.delete()
    return {"success": True}

@router.get("/grades/", response=List[GradeSchema], auth=AuthBearer())
def list_grades(request):
    return Grade.objects.all()

