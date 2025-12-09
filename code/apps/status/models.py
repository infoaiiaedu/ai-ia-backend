from django.db import models
from django.utils import timezone


class Deployment(models.Model):
    """Track deployment history"""
    
    commit_sha = models.CharField(max_length=40, db_index=True)
    deployed_at = models.DateTimeField(default=timezone.now, db_index=True)
    deployed_by = models.CharField(max_length=100)
    status = models.CharField(
        max_length=20,
        choices=[
            ('success', 'Success'),
            ('failed', 'Failed'),
            ('in_progress', 'In Progress'),
            ('rolled_back', 'Rolled Back'),
        ],
        default='in_progress'
    )
    duration_seconds = models.IntegerField(null=True, blank=True)
    commit_message = models.TextField(blank=True)
    error_message = models.TextField(blank=True)
    
    class Meta:
        ordering = ['-deployed_at']
        indexes = [
            models.Index(fields=['-deployed_at', 'status']),
        ]
    
    def __str__(self):
        return f"{self.commit_sha[:7]} - {self.status} at {self.deployed_at}"


class HealthCheck(models.Model):
    """Store health check results"""
    
    checked_at = models.DateTimeField(default=timezone.now, db_index=True)
    service = models.CharField(max_length=50)  # django, postgres, redis, nginx
    status = models.CharField(
        max_length=20,
        choices=[
            ('healthy', 'Healthy'),
            ('unhealthy', 'Unhealthy'),
            ('degraded', 'Degraded'),
        ]
    )
    response_time_ms = models.IntegerField(null=True)
    error_message = models.TextField(blank=True)
    metadata = models.JSONField(default=dict, blank=True)
    
    class Meta:
        ordering = ['-checked_at']
        indexes = [
            models.Index(fields=['-checked_at', 'service']),
        ]
    
    def __str__(self):
        return f"{self.service} - {self.status} at {self.checked_at}"
