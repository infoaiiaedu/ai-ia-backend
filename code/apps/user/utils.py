import jwt
from main.settings import JWT_SECRET_KEY, JWT_ALGORITHM
from datetime import datetime, timedelta
from apps.user.models import Parent

from datetime import timedelta


def encode_jwt_token(user):
    payload = {
        "account_id": user.id,
        "exp": datetime.utcnow() + timedelta(minutes=30),
        "iat": datetime.utcnow(),
    }
    token = jwt.encode(payload, JWT_SECRET_KEY, algorithm="HS256")
    return token


def decode_jwt_token(token):
    try:
        decoded_payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=["HS256"])
        account = Parent.objects.get(id=decoded_payload["account_id"])
        return account, True
    except jwt.ExpiredSignatureError:
        return None, False
    except (jwt.InvalidTokenError, Parent.DoesNotExist):
        return None, False
    
    
