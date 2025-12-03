"""
Health check view for production monitoring
Add this to your Django urls.py:
from apps.core.views import health_check

urlpatterns = [
    ...
    path('health/', health_check, name='health_check'),
]
"""

import json
from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from django.db import connection
from django.core.cache import cache
import logging

logger = logging.getLogger(__name__)


@require_http_methods(["GET"])
def health_check(request):
    """
    Health check endpoint for load balancers and monitoring systems
    Returns 200 OK if application is healthy
    Returns 503 Service Unavailable if critical services are down
    """
    
    status = {
        'status': 'ok',
        'services': {},
        'timestamp': None
    }
    
    http_status = 200
    
    # Check database connectivity
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            status['services']['database'] = 'ok'
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        status['services']['database'] = f'error: {str(e)}'
        http_status = 503
    
    # Check Redis/cache connectivity
    try:
        cache_key = 'health_check_test'
        cache.set(cache_key, 'ok', 1)
        cache_value = cache.get(cache_key)
        if cache_value == 'ok':
            status['services']['cache'] = 'ok'
        else:
            raise Exception("Cache read/write failed")
    except Exception as e:
        logger.error(f"Cache health check failed: {e}")
        status['services']['cache'] = f'error: {str(e)}'
        http_status = 503
    
    # Overall status
    if http_status != 200:
        status['status'] = 'degraded'
    
    return JsonResponse(
        status,
        status=http_status,
        content_type='application/json',
        headers={
            'X-Health-Check': 'true',
            'Cache-Control': 'no-cache, no-store, must-revalidate'
        }
    )
