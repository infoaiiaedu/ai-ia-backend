from ninja import Router, Form
from ninja.errors import HttpError
from ninja.security import HttpBearer
from django.core.exceptions import ValidationError
from django.utils import timezone
from apps.user.models import Parent, Child
from .schema import TokenSchema, ChildRegisterSchema, OTPResponseSchema
from .utils import decode_jwt_token
import random

router = Router()


# ---------------------------
# AuthBearer for JWT
# ---------------------------
class AuthBearer(HttpBearer):
    def authenticate(self, request, token):
        account, valid = decode_jwt_token(token)
        if not valid:
            return None
        return account


# ---------------------------
# Parent Registration (sends OTP)
# ---------------------------
@router.post("/parent/register/", response=OTPResponseSchema)
def parent_register(
    request,
    name: str = Form(...),
    mobile_phone: str = Form(...),
):
    # Check if parent already exists
    if Parent.objects.filter(mobile_phone=mobile_phone).exists():
        raise HttpError(400, "Parent with this mobile phone already exists")

    # Create parent
    parent = Parent.objects.create(name=name, mobile_phone=mobile_phone)
    parent.generate_otp()        # generate OTP
    parent.send_otp_sms()        # send OTP via Textbelt

    return {"message": "Parent created. Check your mobile for OTP."}


# ---------------------------
# Parent Verify OTP and Login
# ---------------------------
@router.post("/parent/verify_otp/", response=TokenSchema)
def parent_verify_otp(
    request,
    mobile_phone: str = Form(...),
    otp_code: str = Form(...),
):
    try:
        parent = Parent.objects.get(mobile_phone=mobile_phone)
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


# ---------------------------
# Child Registration (by Parent)
# ---------------------------
@router.post("/child/register/", response=OTPResponseSchema, auth=AuthBearer())
def child_register(request, data: ChildRegisterSchema):
    parent: Parent = request.auth

    # Create child
    child = Child.objects.create(
        parent=parent,
        name=data.name,
        grade=data.grade
    )

    # Generate permanent access code
    access_code = child.generate_access_code()

    return {
        "message": f"Child {child.name} registered.",
        "access_code": access_code
    }


# ---------------------------
# Child Login (with permanent access_code)
# ---------------------------
@router.post("/child/login/", response=TokenSchema)
def child_login(request, access_code: str = Form(...)):
    try:
        child = Child.objects.get(access_code=access_code)
    except Child.DoesNotExist:
        raise HttpError(400, "Invalid access code")

    tokens = child.generate_tokens()
    return {
        "access_token": tokens["access_token"],
        "refresh_token": tokens["refresh_token"],
        "message": f"Child {child.name} logged in successfully."
    }
