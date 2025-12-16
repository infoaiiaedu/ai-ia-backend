from ninja import Schema, Form
from typing import Optional

class RegisterSchema(Schema):
    name: str
    mobile_phone: str
    password: str


class TokenSchema(Schema):
    access_token: str
    refresh_token: str
    

class ChildRegisterSchema(Schema):
    name: str
    grade: int
    nickname: Optional[str] = None
    logo_id: Optional[int] = None

class ChildLoginSchema(Schema):
    mobile_phone: str  # parent's phone
    child_name: str
    otp_code: str

class OTPResponseSchema(Schema):
    message: str