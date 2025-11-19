import base64
import hmac
from secrets import token_urlsafe, token_bytes
from hashlib import pbkdf2_hmac


PASSWORD_ITERATIONS = 180000

PASSWORD_PEPPER = b"f\xe7\xe6\\'y\x80\xd0g\xa5f\xcc\xf4\x88i\xc2"


def generate_pepper():
    return token_bytes(16)


def generate_salt():
    return token_urlsafe(16)


def make_password_hash(
    raw_password, salt=None, pepper=None, iterations=PASSWORD_ITERATIONS
):
    password = raw_password.encode()

    if pepper is not None:
        password += pepper

    if salt is None:
        salt = generate_salt()

    password_hash = pbkdf2_hmac("sha256", password, salt.encode(), iterations)

    return "$".join(
        [
            "pbkdf2_sha256",
            str(iterations),
            salt,
            base64.b64encode(password_hash).decode(),
        ]
    )


def check_password_hash(raw_password, password_hash, pepper=None):
    try:
        _, iterations, salt, _ = password_hash.split("$")
        iterations = int(iterations)
    except Exception:
        return False

    encoded_password = make_password_hash(raw_password, salt, pepper, iterations)

    return hmac.compare_digest(password_hash, encoded_password)


regex_validations = [
    # Minimum eight characters, at least one letter and one number:
    r"^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$",
    # Minimum eight characters, at least one letter,
    # one number and one special character:
    r"^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$",
    # Minimum eight characters, at least one uppercase letter,
    # one lowercase letter and one number:
    r"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d]{8,}$",
    # Minimum eight characters, at least one uppercase letter,
    # one lowercase letter, one number and one special character:
    r"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$",
]

PASSWORD_REGEX = r"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\_\W\d@$!%*#?&]{8,}$"
