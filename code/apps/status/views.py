import os
import subprocess
import psutil
import time
from datetime import datetime, timedelta
from pathlib import Path

from django.shortcuts import render
from django.http import JsonResponse
from django.views.decorators.cache import cache_page
from django.db import connection
from django.core.cache import cache
from django.conf import settings

from django.db.models import Avg
from .models import Deployment, HealthCheck


def dashboard(request):
    """Main monitoring dashboard"""
    
    context = {
        'system_metrics': get_system_metrics(),
        'services_status': get_services_status(),
        'recent_deployments': get_recent_deployments(),
        'error_logs': get_recent_error_logs(),
        'uptime_stats': get_uptime_stats(),
    }
    
    return render(request, 'status/dashboard.html', context)


def health_check(request):
    """
    Comprehensive health check endpoint for load balancers and monitoring.
    Returns 200 if all services are healthy, 503 otherwise.
    """
    
    # Check if app is ready first
    if hasattr(settings, 'is_app_ready') and not settings.is_app_ready():
        return JsonResponse({
            'status': 'initializing',
            'message': 'Application is starting up',
            'timestamp': datetime.utcnow().isoformat(),
        }, status=503)
    
    health_status = {
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'checks': {}
    }
    
    is_healthy = True
    
    # Database connectivity check
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            result = cursor.fetchone()
            if result and result[0] == 1:
                health_status['checks']['database'] = 'ok'
            else:
                health_status['checks']['database'] = 'error: unexpected result'
                is_healthy = False
    except Exception as e:
        health_status['checks']['database'] = f'error: {str(e)}'
        is_healthy = False
    
    # Cache connectivity check (Redis)
    try:
        test_key = f'health_check_{int(time.time())}'
        cache.set(test_key, 'ok', 10)
        cache_value = cache.get(test_key)
        if cache_value == 'ok':
            health_status['checks']['cache'] = 'ok'
            cache.delete(test_key)
        else:
            health_status['checks']['cache'] = 'error: cache read failed'
            is_healthy = False
    except Exception as e:
        health_status['checks']['cache'] = f'error: {str(e)}'
        is_healthy = False
    
    # Static files check
    try:
        static_root = getattr(settings, 'STATIC_ROOT', None)
        if static_root and Path(static_root).exists():
            health_status['checks']['static_files'] = 'ok'
        else:
            health_status['checks']['static_files'] = 'warning: static root not found'
            # Non-critical, don't mark as unhealthy
    except Exception as e:
        health_status['checks']['static_files'] = f'warning: {str(e)}'
    
    # Media files check
    try:
        media_root = getattr(settings, 'MEDIA_ROOT', None)
        if media_root and Path(media_root).exists():
            health_status['checks']['media_files'] = 'ok'
        else:
            health_status['checks']['media_files'] = 'warning: media root not found'
            # Non-critical, don't mark as unhealthy
    except Exception as e:
        health_status['checks']['media_files'] = f'warning: {str(e)}'
    
    # Set overall status
    health_status['status'] = 'healthy' if is_healthy else 'unhealthy'
    
    # Return appropriate status code
    status_code = 200 if is_healthy else 503
    
    return JsonResponse(health_status, status=status_code)


@cache_page(10)
def metrics_api(request):
    """API endpoint for metrics (cached for 10 seconds)"""
    
    return JsonResponse({
        'system': get_system_metrics(),
        'services': get_services_status(),
        'timestamp': datetime.utcnow().isoformat(),
    })


def get_system_metrics():
    """Get system resource metrics"""
    
    try:
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        return {
            'cpu': {
                'percent': round(cpu_percent, 1),
                'count': psutil.cpu_count(),
            },
            'memory': {
                'total_mb': round(memory.total / 1024 / 1024, 1),
                'used_mb': round(memory.used / 1024 / 1024, 1),
                'available_mb': round(memory.available / 1024 / 1024, 1),
                'percent': round(memory.percent, 1),
            },
            'disk': {
                'total_gb': round(disk.total / 1024 / 1024 / 1024, 1),
                'used_gb': round(disk.used / 1024 / 1024 / 1024, 1),
                'free_gb': round(disk.free / 1024 / 1024 / 1024, 1),
                'percent': round(disk.percent, 1),
            },
            'load_average': os.getloadavg() if hasattr(os, 'getloadavg') else [0, 0, 0],
        }
    except Exception as e:
        return {'error': str(e)}


def get_services_status():
    """Check status of all services"""
    
    services = {}
    
    # Django
    services['django'] = {
        'status': 'healthy',
        'uptime': get_process_uptime('gunicorn'),
    }
    
    # PostgreSQL
    try:
        start = time.time()
        with connection.cursor() as cursor:
            cursor.execute("SELECT version()")
            version = cursor.fetchone()[0]
        response_time = int((time.time() - start) * 1000)
        
        services['postgres'] = {
            'status': 'healthy',
            'response_time_ms': response_time,
            'version': version.split(',')[0],
        }
    except Exception as e:
        services['postgres'] = {
            'status': 'unhealthy',
            'error': str(e),
        }
    
    # Redis
    try:
        start = time.time()
        cache.set('health_check_redis', '1', 10)
        cache.get('health_check_redis')
        response_time = int((time.time() - start) * 1000)
        
        services['redis'] = {
            'status': 'healthy',
            'response_time_ms': response_time,
        }
    except Exception as e:
        services['redis'] = {
            'status': 'unhealthy',
            'error': str(e),
        }
    
    # Nginx (check if running)
    try:
        result = subprocess.run(
            ['pgrep', '-x', 'nginx'],
            capture_output=True,
            timeout=5
        )
        services['nginx'] = {
            'status': 'healthy' if result.returncode == 0 else 'unhealthy',
        }
    except Exception:
        services['nginx'] = {
            'status': 'unknown',
        }
    
    return services


def get_recent_deployments(limit=5):
    """Get recent deployment history"""
    
    deployments = Deployment.objects.all()[:limit]
    
    return [{
        'commit': d.commit_sha[:7],
        'time': d.deployed_at,
        'status': d.status,
        'duration': d.duration_seconds,
        'by': d.deployed_by,
        'message': d.commit_message[:100] if d.commit_message else '',
    } for d in deployments]


def get_recent_error_logs(lines=50):
    """Get recent error logs from Django log file"""
    
    try:
        log_file = Path(settings.BASE_DIR) / 'logs' / 'django.log'
        
        if not log_file.exists():
            return []
        
        with open(log_file, 'r') as f:
            # Get last N lines
            all_lines = f.readlines()
            recent_lines = all_lines[-lines:] if len(all_lines) > lines else all_lines
            
            # Filter for errors
            error_lines = [
                line.strip() for line in recent_lines
                if 'ERROR' in line or 'CRITICAL' in line or 'Exception' in line
            ]
            
            return error_lines[-20:]  # Return last 20 errors
    
    except Exception as e:
        return [f'Error reading logs: {str(e)}']


def get_uptime_stats():
    """Calculate uptime statistics"""
    
    now = datetime.now()
    
    # Last 24 hours health checks
    yesterday = now - timedelta(days=1)
    health_checks = HealthCheck.objects.filter(
        checked_at__gte=yesterday,
        service='django'
    )
    
    total_checks = health_checks.count()
    healthy_checks = health_checks.filter(status='healthy').count()
    
    uptime_percent = (healthy_checks / total_checks * 100) if total_checks > 0 else 100
    
    # Average response time
    avg_response_time = health_checks.filter(
        response_time_ms__isnull=False
    ).aggregate(
        avg=models.Avg('response_time_ms')
    )['avg'] or 0
    
    return {
        'uptime_24h_percent': round(uptime_percent, 2),
        'total_checks_24h': total_checks,
        'avg_response_time_ms': round(avg_response_time, 0),
        'last_check': health_checks.first().checked_at if health_checks.exists() else None,
    }


def get_process_uptime(process_name):
    """Get process uptime in seconds"""
    
    try:
        for proc in psutil.process_iter(['name', 'create_time']):
            if process_name in proc.info['name']:
                create_time = proc.info['create_time']
                uptime_seconds = int(time.time() - create_time)
                
                # Format uptime
                days = uptime_seconds // 86400
                hours = (uptime_seconds % 86400) // 3600
                minutes = (uptime_seconds % 3600) // 60
                
                if days > 0:
                    return f"{days}d {hours}h"
                elif hours > 0:
                    return f"{hours}h {minutes}m"
                else:
                    return f"{minutes}m"
        
        return "Unknown"
    
    except Exception:
        return "Unknown"
