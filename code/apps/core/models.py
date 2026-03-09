from django.db import models
from django.core.validators import MinValueValidator
from django.utils import timezone

class Subject(models.Model):
    name = models.CharField(max_length=100, verbose_name="საგნის სახელი")
    short_description = models.TextField(
        blank=True,
        null=True,
        verbose_name="მოკლე აღწერა",
    )
    price = models.DecimalField(max_digits=10, decimal_places=2, default=0, verbose_name="ფასი")
    icon = models.JSONField(
        null=True, blank=True, editable=True, verbose_name="აიქონი"
    )

    cover_image = models.JSONField(
        null=True, blank=True, editable=True, verbose_name="ქავერის ფოტო"
    )
    
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
    subject = models.ForeignKey(Subject, on_delete=models.CASCADE, related_name='topics', null=True, blank=True, verbose_name="საგანი")
    grade = models.ForeignKey(
        "Grade",
        on_delete=models.CASCADE,
        related_name="topics",
        null=True,
        blank=True,
        verbose_name="კლასი",
    )
    
    image = models.JSONField(
        null=True, blank=True, editable=True, verbose_name="სურათი"
    )

    video = models.JSONField(
        null=True, blank=True, editable=True, verbose_name="ვიდეო"
    )
    description = models.TextField(blank=True, null=True, verbose_name="აღწერა")
    
    created_at = models.DateTimeField(default=timezone.now, verbose_name="შექმნის თარიღი")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="განახლების თარიღი")
    
    order = models.SmallIntegerField(
        default=0,
        validators=[MinValueValidator(0)],
        verbose_name="მიმდევრობა",
    )
    
    def __str__(self):
        return f"{self.name}"
    
    class Meta:
        verbose_name = "თემა"
        verbose_name_plural = "თემები"
        ordering = ['order']


class Quiz(models.Model):
    title = models.CharField(max_length=255, verbose_name="ქვიზის სახელი")
    description = models.TextField(blank=True, null=True, verbose_name="აღწერა")
    
    subject = models.ForeignKey(
        Subject, 
        on_delete=models.CASCADE, 
        related_name='quizzes', 
        null=True, 
        blank=True, 
        verbose_name="საგანი"
    )
    topics = models.ManyToManyField(
        Topic, 
        related_name='quizzes', 
        blank=True, 
        verbose_name="თემები"
    )
    grade = models.ForeignKey(
        Grade, 
        on_delete=models.CASCADE, 
        related_name='quizzes', 
        null=True, 
        blank=True, 
        verbose_name="კლასი"
    )
    
    is_active = models.BooleanField(default=True, verbose_name="აქტიური")
    created_at = models.DateTimeField(default=timezone.now, verbose_name="შექმნის თარიღი")

    # def clean(self):
    #     from django.core.exceptions import ValidationError
    #     # For existing MCQ questions, ensure at least one answer exists
    #     if self.question_type == self.MCQ:
    #         if self.pk and self.answers.count() == 0:
    #             raise ValidationError('Multiple choice questions require at least one answer.')

    #     # Open questions should have a correct text answer
    #     if self.question_type == self.OPEN and not self.correct_text_answer:
    #         raise ValidationError('Open questions require a correct text answer.')
    updated_at = models.DateTimeField(auto_now=True, verbose_name="განახლების თარიღი")

    def __str__(self):
        return self.title

    class Meta:
        verbose_name = "ქვიზი"
        verbose_name_plural = "ქვიზები"
        ordering = ['-created_at']


class Question(models.Model):
    MCQ = "mcq"
    OPEN = "open"
    QUESTION_TYPES = ((MCQ, "Multiple Choice"), (OPEN, "Open Question"))

    quiz = models.ForeignKey(Quiz, related_name="questions", on_delete=models.CASCADE, verbose_name="ქვიზი")
    text = models.TextField(verbose_name="კითხვის ტექსტი")
    question_type = models.CharField(max_length=10, choices=QUESTION_TYPES, verbose_name="კითხვის ტიპი")
    level = models.PositiveSmallIntegerField(default=1, verbose_name="დონე")
    order = models.PositiveSmallIntegerField(default=0, verbose_name="მიმდევრობა")
    
    xp = models.PositiveIntegerField(default=10, verbose_name="XP per question")
    correct_text_answer = models.TextField(blank=True, null=True, verbose_name="სწორი პასუხი (ღია კითხვებისთვის)")
    explanation = models.TextField(blank=True, null=True, verbose_name="ახსნა")
    
    created_at = models.DateTimeField(default=timezone.now, verbose_name="შექმნის თარიღი")

    def __str__(self):
        return f"{self.text[:50]} ({self.get_question_type_display()})"

    class Meta:
        ordering = ['order']
        verbose_name = "კითხვა"
        verbose_name_plural = "კითხვები"


class Answer(models.Model):
    question = models.ForeignKey(Question, related_name="answers", on_delete=models.CASCADE, verbose_name="კითხვა")
    text = models.CharField(max_length=255, verbose_name="პასუხი")
    is_correct = models.BooleanField(default=False, verbose_name="სწორია?")  # only used for MCQs
    order = models.PositiveSmallIntegerField(default=0, verbose_name="მიმდევრობა")

    def __str__(self):
        return self.text

    class Meta:
        verbose_name = "პასუხი"
        verbose_name_plural = "პასუხები"
        ordering = ['order']
        unique_together = (('question', 'order'),)