from ninja import Schema, Form

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

class ChildLoginSchema(Schema):
    mobile_phone: str  # parent's phone
    child_name: str
    otp_code: str

class OTPResponseSchema(Schema):
    message: str
    otp_code: str = None 