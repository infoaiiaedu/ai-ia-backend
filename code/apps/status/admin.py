from django.contrib import admin
from .models import Deployment, HealthCheck


@admin.register(Deployment)
class DeploymentAdmin(admin.ModelAdmin):
    list_display = [
        "commit_sha_short",
        "deployed_at",
        "status",
        "duration_seconds",
        "deployed_by",
    ]
    list_filter = ["status", "deployed_at"]
    search_fields = ["commit_sha", "deployed_by", "commit_message"]
    readonly_fields = ["deployed_at"]

    def commit_sha_short(self, obj):
        return obj.commit_sha[:7]

    commit_sha_short.short_description = "Commit"


@admin.register(HealthCheck)
class HealthCheckAdmin(admin.ModelAdmin):
    list_display = ["service", "status", "response_time_ms", "checked_at"]
    list_filter = ["service", "status", "checked_at"]
    readonly_fields = ["checked_at"]

    def has_add_permission(self, request):
        return False
