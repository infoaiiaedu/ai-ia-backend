from django.db import models

class Subject(models.Model):
    name = models.CharField(max_length=100)

    def __str__(self):
        return self.name
    
    class Meta:
        verbose_name = "საგანი"
        verbose_name_plural = "საგნები"
    
class Grade(models.Model):
    level = models.CharField(max_length=50)

    def __str__(self):
        return self.level
    
    class Meta:
        verbose_name = "კლასი"
        verbose_name_plural = "კლასები"
        
class Topic(models.Model):
    subject = models.ForeignKey(Subject, on_delete=models.CASCADE, related_name='topics')
    name = models.CharField(max_length=100)
    grade = models.ForeignKey(Grade, on_delete=models.CASCADE, related_name='topics', null=True, blank=True)
    
    image = models.JSONField(
        null=True, blank=True, editable=True, verbose_name="სურათი"
    )

    video = models.JSONField(
        null=True, blank=True, editable=True, verbose_name="ვიდეო"
    )
    description = models.TextField(blank=True, null=True)

    def __str__(self):
        return f"{self.subject.name} - {self.name}"
    
    class Meta:
        verbose_name = "თემა"
        verbose_name_plural = "თემები"