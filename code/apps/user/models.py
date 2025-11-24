from django.db import models
from django.utils import timezone
from datetime import datetime, timedelta
from django.contrib.auth.models import AbstractUser
from django.conf import settings
from django.contrib.contenttypes.models import ContentType
from django.contrib.contenttypes.fields import GenericForeignKey
import jwt
import random

from .password import check_password_hash, make_password_hash


class User(AbstractUser):
    def __str__(self):
        return self.username



class Parent(models.Model):
    name = models.CharField(max_length=100, verbose_name="სახელი და გვარი")
    mobile_phone = models.CharField(max_length=20, unique=True, verbose_name="მობილურის ნომერი")
    password = models.CharField(max_length=128, verbose_name="პაროლი")

    created = models.DateTimeField(default=timezone.now, verbose_name="შეიქმნა")
    is_active = models.BooleanField(default=False, verbose_name="აქტიური")
    is_verified = models.BooleanField(default=False, verbose_name="ვერიფიცირებული")

    REQUIRED_FIELDS = ["mobile_phone", "name"]

    def set_password(self, password: str):
        self.password = make_password_hash(password)

    def check_password(self, password: str) -> bool:
        return check_password_hash(password, self.password) if self.password else False

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

        # Save refresh token in separate model
        ParentRefreshToken.objects.create(
            parent=self,
            token=refresh_token,
            expires_at=datetime.utcnow() + timedelta(days=14)
        )

        return {"access_token": access_token, "refresh_token": refresh_token}

    def __str__(self):
        return self.name

    class Meta:
        verbose_name = "მშობელი"
        verbose_name_plural = "მშობლები"


class Child(models.Model):
    parent = models.ForeignKey(Parent, on_delete=models.CASCADE, related_name='children', verbose_name="მშობელი")
    name = models.CharField(max_length=100, verbose_name="სახელი და გვარი")
    grade = models.PositiveIntegerField("კლასი")
    otp_code = models.CharField(max_length=6, blank=True, null=True)
    otp_expiry = models.DateTimeField(blank=True, null=True)

    def generate_otp(self) -> str:
        code = f"{random.randint(100000, 999999)}"
        self.otp_code = code
        self.otp_expiry = timezone.now() + timedelta(minutes=5)
        self.save(update_fields=["otp_code", "otp_expiry"])
        return code

    def verify_otp(self, code: str) -> bool:
        if self.otp_code == code:
            self.otp_code = None  # clear OTP after use
            self.save(update_fields=["otp_code"])
            return True
        return False


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

        # Save refresh token in separate model
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

class ParentRefreshToken(models.Model):
    parent = models.ForeignKey("user.Parent", on_delete=models.CASCADE, related_name="refresh_tokens")
    token = models.CharField(max_length=255, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()

    def is_expired(self):
        return timezone.now() >= self.expires_at

    def __str__(self):
        return f"ParentRefreshToken(parent_id={self.parent_id}, token={self.token})"
    
class ChildRefreshToken(models.Model):
    child = models.ForeignKey("user.Child", on_delete=models.CASCADE, related_name="refresh_tokens")
    token = models.CharField(max_length=255, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()

    def is_expired(self):
        return timezone.now() >= self.expires_at

    def __str__(self):
        return f"ChildRefreshToken(child_id={self.child_id}, token={self.token})"