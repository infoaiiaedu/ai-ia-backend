from django.db import models

from django.contrib.auth.models import AbstractUser

class User(AbstractUser):
    pass

    def __str__(self):
        return self.username

class Parent(models.Model):
    name = models.CharField(max_length=100)
    mobile_phone = models.CharField(max_length=20, unique=True)
    password = models.CharField(max_length=128)
    
    def __str__(self):
        return f"{self.name} {self.surname}"


class Child(models.Model):
    parent = models.ForeignKey(Parent, on_delete=models.CASCADE, related_name='children')
    name = models.CharField(max_length=100)
    grade = models.PositiveIntegerField("კლასი")

    def __str__(self):
        return f"{self.name} (Child of {self.parent.name})"
