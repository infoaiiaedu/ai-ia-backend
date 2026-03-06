import random
import jwt
from datetime import datetime, timedelta

from django.db import models
from django.utils import timezone
from django.conf import settings
from django.core.mail import send_mail
from django.contrib.auth.models import AbstractUser
from twilio.rest import Client
from apps.core.models import Subject

# ---------------------------
# Twilio configuration
# ---------------------------
TWILIO_ACCOUNT_SID = "ACf1749d275eaab4b9ead992b2a058edfb"
TWILIO_AUTH_TOKEN = "718b274bebf4966cfe8d13d3a1e4d6b1"
TWILIO_PHONE_NUMBER = "+13167105763"  # Your Twilio virtual number

twilio_client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)

# ---------------------------
# User Model
# ---------------------------
class User(AbstractUser):
    def __str__(self):
        return self.username

# ---------------------------
# Parent Model
# ---------------------------
class Parent(models.Model):
    name = models.CharField(max_length=100, verbose_name="სახელი და გვარი")
    email = models.EmailField(unique=True, null=True, blank=True, verbose_name="ელ-ფოსტა")
    mobile_phone = models.CharField(max_length=20, unique=True, null=True, blank=True, verbose_name="მობილურის ნომერი")
    created = models.DateTimeField(default=timezone.now, verbose_name="შეიქმნა")
    is_active = models.BooleanField(default=False, verbose_name="აქტიური")
    is_verified = models.BooleanField(default=False, verbose_name="ვერიფიცირებული")

    otp_code = models.CharField(max_length=6, blank=True, null=True)
    otp_expiry = models.DateTimeField(blank=True, null=True)

    REQUIRED_FIELDS = ["name"]

    # ---------------------------
    # JWT Token Generation
    # ---------------------------
    def generate_tokens(self) -> dict:
        access_payload = {
            "account_id": self.id,
            "account_type": "Parent",
            "exp": datetime.utcnow() + timedelta(days=365),
            "iat": datetime.utcnow(),
        }
        refresh_payload = {
            "account_id": self.id,
            "account_type": "Parent",
            "exp": datetime.utcnow() + timedelta(days=365),
            "iat": datetime.utcnow(),
        }

        access_token = jwt.encode(access_payload, settings.SECRET_KEY, algorithm="HS256")
        refresh_token = jwt.encode(refresh_payload, settings.SECRET_KEY, algorithm="HS256")

        ParentRefreshToken.objects.create(
            parent=self,
            token=refresh_token,
            expires_at=datetime.utcnow() + timedelta(days=365)
        )

        return {"access_token": access_token, "refresh_token": refresh_token}

    # ---------------------------
    # OTP Methods
    # ---------------------------
    def generate_otp(self) -> str:
        code = f"{random.randint(100000, 999999)}"
        self.otp_code = code
        self.otp_expiry = timezone.now() + timedelta(minutes=5)
        self.save(update_fields=["otp_code", "otp_expiry"])
        return code

    def send_otp_sms(self):
        if not self.mobile_phone:
            return {"success": False, "error": "Mobile phone not set"}
        if not self.otp_code or self.otp_expiry < timezone.now():
            self.generate_otp()

        try:
            message = twilio_client.messages.create(
                body=f"თქვენი კოდია {self.otp_code}",
                from_=TWILIO_PHONE_NUMBER,
                to=self.mobile_phone
            )
            return {"success": True, "sid": message.sid}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def send_otp_email(self):
        if not self.email:
            return {"success": False, "error": "Email not set"}
        if not self.otp_code or self.otp_expiry < timezone.now():
            self.generate_otp()

        from_email = getattr(settings, "DEFAULT_FROM_EMAIL", None) or "no-reply@localhost"
        try:
            send_mail(
                subject="თქვენი ერთჯერადი კოდი",
                message=f"თქვენი კოდია {self.otp_code}",
                from_email=from_email,
                recipient_list=[self.email],
                fail_silently=False,
            )
            return {"success": True}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def verify_otp(self, code: str) -> bool:
        if self.otp_code == code and self.otp_expiry and self.otp_expiry >= timezone.now():
            self.otp_code = None
            self.otp_expiry = None
            self.save(update_fields=["otp_code", "otp_expiry"])
            return True
        return False

    def __str__(self):
        return self.name

    class Meta:
        verbose_name = "მშობელი"
        verbose_name_plural = "მშობლები"

class Logo(models.Model):
    name = models.CharField(max_length=100, verbose_name="ლოგოს სახელი")
    image = models.ImageField(upload_to='logos/', verbose_name="ლოგოს სურათი")

    def __str__(self):
        return self.name
    
    class Meta:
        verbose_name = "ლოგო"
        verbose_name_plural = "ლოგოები"

# ---------------------------
# Child Model
# ---------------------------
class Child(models.Model):
    GENDER_CHOICES = (
        ('male', 'ბიჭი'),
        ('female', 'გოგო'),
    )

    parent = models.ForeignKey(Parent, on_delete=models.CASCADE, related_name='children', verbose_name="მშობელი")
    name = models.CharField(max_length=100, verbose_name="სახელი და გვარი")
    grade = models.PositiveIntegerField("კლასი")
    subject = models.ForeignKey(
        Subject,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="children",
        verbose_name="საგანი",
    )
    nickname = models.CharField(max_length=100, null=True, blank=True, verbose_name="ნიქნეიმი")
    logo = models.ForeignKey(Logo, on_delete=models.SET_NULL, null=True, blank=True, verbose_name="ლოგო")
    date_of_birth = models.DateField(null=True, blank=True, verbose_name="დაბადების თარიღი")
    created = models.DateTimeField(default=timezone.now, verbose_name="შეიქმნა")
    sex = models.CharField(choices=GENDER_CHOICES, null=True, blank=True, verbose_name="სქესი")

    access_code = models.CharField(max_length=10, unique=True, blank=True, null=True)

    def generate_access_code(self):
        if not self.access_code:
            self.access_code = f"{random.randint(100000, 999999)}"
            self.save(update_fields=["access_code"])
        return self.access_code

    def generate_tokens(self) -> dict:
        access_payload = {
            "account_id": self.id,
            "account_type": "Child",
            "exp": datetime.utcnow() + timedelta(days=365),
            "iat": datetime.utcnow(),
        }
        refresh_payload = {
            "account_id": self.id,
            "account_type": "Child",
            "exp": datetime.utcnow() + timedelta(days=365),
            "iat": datetime.utcnow(),
        }

        access_token = jwt.encode(access_payload, settings.SECRET_KEY, algorithm="HS256")
        refresh_token = jwt.encode(refresh_payload, settings.SECRET_KEY, algorithm="HS256")

        ChildRefreshToken.objects.create(
            child=self,
            token=refresh_token,
            expires_at=datetime.utcnow() + timedelta(days=365)
        )

        return {"access_token": access_token, "refresh_token": refresh_token}

    def __str__(self):
        return f"{self.name} ({self.parent.name}-ის შვილი)"

    class Meta:
        verbose_name = "ბავშვი"
        verbose_name_plural = "ბავშვები"


class DiagnosticSession(models.Model):
    child = models.ForeignKey(Child, on_delete=models.CASCADE, related_name="diagnostic_sessions")
    subject = models.ForeignKey(Subject, on_delete=models.CASCADE, related_name="diagnostic_sessions")
    topics = models.JSONField(default=list)
    low_index = models.IntegerField(default=0)
    high_index = models.IntegerField(default=0)
    current_index = models.IntegerField(default=0)
    current_topic_id = models.IntegerField(null=True, blank=True)
    current_question_id = models.IntegerField(null=True, blank=True)
    asked_question_ids = models.JSONField(default=list)
    topic_stats = models.JSONField(default=dict)
    topic_outcomes = models.JSONField(default=dict)
    total_answered = models.PositiveSmallIntegerField(default=0)
    max_questions = models.PositiveSmallIntegerField(default=12)
    is_complete = models.BooleanField(default=False)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"DiagnosticSession(child_id={self.child_id}, subject_id={self.subject_id})"


# ---------------------------
# Refresh Token Models
# ---------------------------
class ParentRefreshToken(models.Model):
    parent = models.ForeignKey(Parent, on_delete=models.CASCADE, related_name="refresh_tokens")
    token = models.CharField(max_length=255, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()

    def is_expired(self):
        return timezone.now() >= self.expires_at

    def __str__(self):
        return f"ParentRefreshToken(parent_id={self.parent_id}, token={self.token})"


class ChildRefreshToken(models.Model):
    child = models.ForeignKey(Child, on_delete=models.CASCADE, related_name="refresh_tokens")
    token = models.CharField(max_length=255, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()

    def is_expired(self):
        return timezone.now() >= self.expires_at

    def __str__(self):
        return f"ChildRefreshToken(child_id={self.child_id}, token={self.token})"
