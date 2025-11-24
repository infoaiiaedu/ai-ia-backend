from django.contrib import admin
from .models import Order, Subscription

@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ("bog_id", "external_id", "status", "created_at", "updated_at")
    search_fields = ("bog_id", "external_id")
    list_filter = ("status", "created_at")
    ordering = ("-created_at",)
    autocomplete_fields = ["user", "subject"]
    
@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    list_display = ("user", "subject", "order", "start_date", "end_date", "active")
    search_fields = ("user__username", "subject__name")
    list_filter = ("active", "start_date", "end_date")
    ordering = ("-start_date",)
    autocomplete_fields = ["user", "subject", "order"]