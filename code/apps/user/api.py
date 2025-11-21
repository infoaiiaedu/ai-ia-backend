from ninja import Router, Form
from ninja.errors import HttpError
from apps.user.models import (
    Parent,
    Child,
)
from .utils import encode_jwt_token, decode_jwt_token
from ninja.security import HttpBearer
from .schema import TokenSchema, ChildRegisterSchema, OTPResponseSchema
from django.core.exceptions import ValidationError
import random
from datetime import datetime, timedelta
from django.utils import timezone


router = Router()

class AuthBearer(HttpBearer):
    def authenticate(self, request, token):
        account, state = decode_jwt_token(token)

        if not state:
            return None

        return account


@router.post("/parent/register/")
def register(
    request,
    name: str = Form(...),
    mobile_phone: str = Form(...),
    password1: str = Form(...),
    password2: str = Form(...),
):
    if password1 != password2:
        raise ValidationError("Passwords do not match")

    account = Parent(name=name, mobile_phone=mobile_phone)
    account.set_password(password1)
    account.save()
    
    return {
        "message": "User created. Please check your messages to activate your account."
    }
    
@router.post("/parent/login/", response=TokenSchema)
def login(request, mobile_phone: str = Form(...), password: str = Form(...)):
    try:
        parent = Parent.objects.get(mobile_phone=mobile_phone)
    except Parent.DoesNotExist:
        raise HttpError(400, "Invalid mobile phone or password")

    if not parent.check_password(password):
        raise HttpError(400, "Invalid mobile phone or password")

    if not parent.is_verified:
        raise HttpError(400, "Account not verified. Activate your account first.")

    tokens = parent.generate_tokens()

    return {
        "access_token": tokens["access_token"],
        "refresh_token": tokens["refresh_token"],
    }


@router.post("/child/register/", response=OTPResponseSchema, auth=AuthBearer())
def child_register(request, data: ChildRegisterSchema):
    parent: Parent = request.auth

    child = Child.objects.create(
        parent=parent,
        name=data.name,
        grade=data.grade
    )

    otp_code = f"{random.randint(100000, 999999)}"

    child.otp_code = otp_code
    child.save(update_fields=["otp_code"])

    return {
        "message": f"Child {child.name} registered. Use OTP to login.",
        "otp_code": otp_code
    }

@router.post("/child/login/", response=TokenSchema)
def child_login(request, otp_code: str = Form(...)):
    try:
        child = Child.objects.get(otp_code=otp_code)
    except Child.DoesNotExist:
        raise HttpError(400, "Invalid OTP code")

    if not child.verify_otp(otp_code):
        raise HttpError(400, "Invalid OTP code")

    tokens = child.generate_tokens()

    return {
        "access_token": tokens["access_token"],
        "refresh_token": tokens["refresh_token"],
        "message": f"Child {child.name} logged in successfully."
    }
