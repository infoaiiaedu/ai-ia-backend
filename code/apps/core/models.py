from django.db import models
from django.utils import timezone

class Subject(models.Model):
    name = models.CharField(max_length=100, verbose_name="საგნის სახელი")
    price = models.DecimalField(max_digits=10, decimal_places=2, default=0, verbose_name="ფასი")
    
    topic = models.ManyToManyField('Topic', related_name='subjects', blank=True, verbose_name="თემები")
    is_active = models.BooleanField(default=True, verbose_name="აქტიური")

    def __str__(self):
        return self.name
    
    class Meta:
        verbose_name = "საგანი"
        verbose_name_plural = "საგნები"
    
class Grade(models.Model):
    level = models.CharField(max_length=50, verbose_name="კლასი")

    def __str__(self):
        return self.level
    
    class Meta:
        verbose_name = "კლასი"
        verbose_name_plural = "კლასები"
        
class Topic(models.Model):
    name = models.CharField(max_length=100, verbose_name="თემის სახელი")
    grade = models.ForeignKey(Grade, on_delete=models.CASCADE, related_name='topics', null=True, blank=True, verbose_name="კლასი")
    
    image = models.JSONField(
        null=True, blank=True, editable=True, verbose_name="სურათი"
    )

    video = models.JSONField(
        null=True, blank=True, editable=True, verbose_name="ვიდეო"
    )
    description = models.TextField(blank=True, null=True, verbose_name="აღწერა")
    
    created_at = models.DateTimeField(default=timezone.now, verbose_name="შექმნის თარიღი")
    update_at = models.DateTimeField(default=timezone.now, verbose_name="განახლების თარიღი")
    
    def __str__(self):
        return f"{self.name}"
    
    class Meta:
        verbose_name = "თემა"
        verbose_name_plural = "თემები"