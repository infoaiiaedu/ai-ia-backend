from django.db import models
from main import settings
from datetime import timedelta
from django.utils import timezone

class Order(models.Model):
    user = models.ForeignKey("user.Parent", on_delete=models.CASCADE, null=True, blank=True, verbose_name="მომხმარებელი")
    external_id = models.CharField(max_length=100, unique=True, default="DUMMY_EXTERNAL_ID", verbose_name="გარე ID")
    bog_id = models.CharField(max_length=100, default="DUMMY_BOG_ID", verbose_name="BOG ID")
    parent_order_id = models.CharField(max_length=100, null=True, blank=True, verbose_name="მშობელი შეკვეთის ID")
    total_amount = models.FloatField(verbose_name="თანხა")
    status = models.CharField(
        max_length=50,
        choices=[("PENDING", "Pending"), ("SUCCESS", "Success"), ("FAILED", "Failed")],
        default="PENDING", verbose_name="სტატუსი"
    )
    redirect_url = models.URLField(default="", verbose_name="გადამისამართების URL")
    subject = models.ForeignKey("core.Subject", on_delete=models.SET_NULL, null=True, blank=True, verbose_name="საგანი") 
    
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="შექმნის თარიღი")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="განახლების თარიღი")
    
    class Meta:
        db_table = "payments_order"
        ordering = ["-created_at"] 
        verbose_name = "გადახდა"
        verbose_name_plural = "გადახდები"


class Subscription(models.Model):
    user = models.ForeignKey("user.Parent", on_delete=models.CASCADE, null=True, blank=True, verbose_name="მომხმარებელი")
    subject = models.ForeignKey("core.Subject", on_delete=models.CASCADE, verbose_name="საგანი")
    order = models.ForeignKey("Order", on_delete=models.CASCADE, verbose_name="გადახდა")
    start_date = models.DateTimeField(auto_now_add=True, verbose_name="დაწყების თარიღი")
    end_date = models.DateTimeField(verbose_name="დასრულების თარიღი")
    active = models.BooleanField(default=True, verbose_name="აქტიური")

    def save(self, *args, **kwargs):
        if not self.end_date:
            self.end_date = timezone.now() + timedelta(days=30)
        super().save(*args, **kwargs)
        
    class Meta:
        db_table = "payments_subscription"
        ordering = ["-start_date"]
        verbose_name = "აბონიმენტი"
        verbose_name_plural = "აბონიმენტები"