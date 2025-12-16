from ninja import Router, Form
from ninja.errors import HttpError
from ninja.security import HttpBearer
from apps.user.models import Parent, Child, Logo
from .schema import TokenSchema, ChildRegisterSchema, OTPResponseSchema
from .utils import decode_jwt_token
from django.shortcuts import get_object_or_404

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
# Parent Registration (sends OTP via Twilio)
# ---------------------------
@router.post("/parent/register/", response=OTPResponseSchema)
def parent_register(
    request,
    name: str = Form(...),
    mobile_phone: str = Form(...),
):
    if Parent.objects.filter(mobile_phone=mobile_phone).exists():
        raise HttpError(400, "Parent with this mobile phone already exists")

    parent = Parent.objects.create(name=name, mobile_phone=mobile_phone)

    parent.generate_otp()               # Generate OTP
    result = parent.send_otp_sms()      # Send via Twilio

    if not result.get("success"):
        raise HttpError(500, f"Failed to send SMS: {result.get('error')}")

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


@router.post("/child/register/", response=OTPResponseSchema, auth=AuthBearer())
def child_register(request, data: ChildRegisterSchema):
    parent: Parent = request.auth

    logo = None
    if data.logo_id:
        logo = get_object_or_404(Logo, id=data.logo_id)

    child = Child.objects.create(
        parent=parent,
        name=data.name,
        grade=data.grade,
        nickname=data.nickname,
        logo=logo,
    )

    access_code = child.generate_access_code()

    return {
        "message": f"Child {child.name} registered.",
        "access_code": access_code,
    }

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
