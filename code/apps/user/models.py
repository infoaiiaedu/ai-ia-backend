import random
import jwt
from datetime import datetime, timedelta

from django.db import models
from django.utils import timezone
from django.conf import settings
from django.contrib.auth.models import AbstractUser
import requests

# ---------------------------
# Textbelt API configuration
# ---------------------------
TEXTBELT_API_KEY = "8d23cd12853a8fd96975cfb53c079e0c8382006cNnPSkVmmeXusbIVdEZTQw0uF5"
TEXTBELT_API_URL = "https://textbelt.com/text"

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
    mobile_phone = models.CharField(max_length=20, unique=True, verbose_name="მობილურის ნომერი")
    created = models.DateTimeField(default=timezone.now, verbose_name="შეიქმნა")
    is_active = models.BooleanField(default=False, verbose_name="აქტიური")
    is_verified = models.BooleanField(default=False, verbose_name="ვერიფიცირებული")

    otp_code = models.CharField(max_length=6, blank=True, null=True)
    otp_expiry = models.DateTimeField(blank=True, null=True)

    REQUIRED_FIELDS = ["mobile_phone", "name"]

    # ---------------------------
    # JWT Token Generation
    # ---------------------------
    def generate_tokens(self) -> dict:
        access_payload = {
            "account_id": self.id,
            "account_type": "Parent",
            "exp": datetime.utcnow() + timedelta(minutes=60),
            "iat": datetime.utcnow(),
        }
        refresh_payload = {
            "account_id": self.id,
            "account_type": "Parent",
            "exp": datetime.utcnow() + timedelta(days=14),
            "iat": datetime.utcnow(),
        }

        access_token = jwt.encode(access_payload, settings.SECRET_KEY, algorithm="HS256")
        refresh_token = jwt.encode(refresh_payload, settings.SECRET_KEY, algorithm="HS256")

        ParentRefreshToken.objects.create(
            parent=self,
            token=refresh_token,
            expires_at=datetime.utcnow() + timedelta(days=14)
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

    def send_otp_sms(self) -> dict:
        if not self.otp_code or self.otp_expiry < timezone.now():
            self.generate_otp()

        payload = {
            "phone": self.mobile_phone,
            "message": f"Your OTP is {self.otp_code}",
            "key": TEXTBELT_API_KEY,
        }
        response = requests.post(TEXTBELT_API_URL, data=payload)
        return response.json()

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


# ---------------------------
# Child Model
# ---------------------------
class Child(models.Model):
    parent = models.ForeignKey(Parent, on_delete=models.CASCADE, related_name='children', verbose_name="მშობელი")
    name = models.CharField(max_length=100, verbose_name="სახელი და გვარი")
    grade = models.PositiveIntegerField("კლასი")

    access_code = models.CharField(max_length=10, unique=True, blank=True, null=True)

    # ---------------------------
    # Generate permanent random access code
    # ---------------------------
    def generate_access_code(self):
        if not self.access_code:
            self.access_code = f"{random.randint(100000, 999999)}"
            self.save(update_fields=["access_code"])
        return self.access_code

    # ---------------------------
    # JWT Token Generation
    # ---------------------------
    def generate_tokens(self) -> dict:
        access_payload = {
            "account_id": self.id,
            "account_type": "Child",
            "exp": datetime.utcnow() + timedelta(minutes=60),
            "iat": datetime.utcnow(),
        }
        refresh_payload = {
            "account_id": self.id,
            "account_type": "Child",
            "exp": datetime.utcnow() + timedelta(days=14),
            "iat": datetime.utcnow(),
        }

        access_token = jwt.encode(access_payload, settings.SECRET_KEY, algorithm="HS256")
        refresh_token = jwt.encode(refresh_payload, settings.SECRET_KEY, algorithm="HS256")

        ChildRefreshToken.objects.create(
            child=self,
            token=refresh_token,
            expires_at=datetime.utcnow() + timedelta(days=14)
        )

        return {"access_token": access_token, "refresh_token": refresh_token}

    def __str__(self):
        return f"{self.name} ({self.parent.name}-ის შვილი)"

    class Meta:
        verbose_name = "ბავშვი"
        verbose_name_plural = "ბავშვები"


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
