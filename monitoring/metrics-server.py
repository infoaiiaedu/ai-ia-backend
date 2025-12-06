#!/usr/bin/env python3
"""
Simple HTTP server for monitoring metrics API
Serves JSON metrics for the monitoring dashboard
Usage: python3 monitoring/metrics-server.py
"""

import json
import subprocess
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

class MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/api/metrics':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            try:
                metrics = self.get_metrics()
                self.wfile.write(json.dumps(metrics).encode())
            except Exception as e:
                error_response = {'error': str(e)}
                self.wfile.write(json.dumps(error_response).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def get_metrics(self):
        """Collect system and service metrics"""
        metrics = {}
        
        # Deployment status
        try:
            import json
            import os
            from pathlib import Path
            
            # Try to read deployment status files
            deploy_status = {}
            for env in ['production', 'staging']:
                status_file = Path(f'/home/ubuntu/{env}/ai-ia-backend/.deployments/last_{env}.json')
                if status_file.exists():
                    with open(status_file, 'r') as f:
                        deploy_status[env] = json.load(f)
                else:
                    deploy_status[env] = {
                        'status': 'unknown',
                        'timestamp': None,
                        'message': 'No deployment recorded'
                    }
            metrics['deployments'] = deploy_status
        except Exception as e:
            metrics['deployments'] = {'error': str(e)}
        
        # System metrics
        try:
            result = subprocess.run(['top', '-bn1'], capture_output=True, text=True, timeout=5)
            cpu_line = [l for l in result.stdout.split('\n') if 'Cpu(s)' in l]
            if cpu_line:
                cpu_usage = cpu_line[0].split()[1].replace('%us', '')
                metrics['cpu_usage'] = float(cpu_usage)
        except:
            metrics['cpu_usage'] = 0
        
        try:
            result = subprocess.run(['free', '-m'], capture_output=True, text=True, timeout=5)
            for line in result.stdout.split('\n'):
                if line.startswith('Mem:'):
                    parts = line.split()
                    metrics['memory_total'] = int(parts[1])
                    metrics['memory_used'] = int(parts[2])
                    break
        except:
            metrics['memory_total'] = 512
            metrics['memory_used'] = 0
        
        try:
            result = subprocess.run(['df', '-BG', '/'], capture_output=True, text=True, timeout=5)
            for line in result.stdout.split('\n'):
                if '/dev/' in line:
                    parts = line.split()
                    metrics['disk_total'] = int(parts[1].replace('G', ''))
                    metrics['disk_used'] = int(parts[2].replace('G', ''))
                    break
        except:
            metrics['disk_total'] = 20
            metrics['disk_used'] = 0
        
        try:
            result = subprocess.run(['uptime'], capture_output=True, text=True, timeout=5)
            load_avg = result.stdout.split('load average:')[1].strip() if 'load average:' in result.stdout else 'N/A'
            metrics['load_avg'] = load_avg
        except:
            metrics['load_avg'] = 'N/A'
        
        # Docker service status
        services = []
        containers = [
            ('aiia_postgresql', 'PostgreSQL'),
            ('aiia_pgbouncer', 'PgBouncer'),
            ('aiia_redis', 'Redis'),
            ('aiia_django_prod', 'Django Prod'),
            ('aiia_django_staging', 'Django Staging'),
            ('aiia_nginx', 'Nginx')
        ]
        
        try:
            result = subprocess.run(['docker', 'ps', '--format', '{{.Names}}'], 
                                  capture_output=True, text=True, timeout=5)
            running_containers = result.stdout.split('\n')
            
            for container, name in containers:
                status = 'ok' if container in running_containers else 'error'
                services.append({'name': name, 'status': status})
        except:
            pass
        
        metrics['services'] = services
        
        # Database metrics
        try:
            result = subprocess.run(['docker', 'exec', 'aiia_postgresql', 'psql', '-U', 'aiia', 
                                    '-d', 'aiia_prod', '-c', 
                                    "SELECT pg_size_pretty(pg_database_size('aiia_prod'))", '-t'],
                                  capture_output=True, text=True, timeout=5)
            metrics['db_prod_size'] = result.stdout.strip() if result.returncode == 0 else 'N/A'
        except:
            metrics['db_prod_size'] = 'N/A'
        
        metrics['db_status'] = 'ok' if 'aiia_postgresql' in [s['name'] for s in services if s['status'] == 'ok'] else 'error'
        metrics['pgbouncer_status'] = 'ok' if 'PgBouncer' in [s['name'] for s in services if s['status'] == 'ok'] else 'error'
        metrics['redis_status'] = 'ok' if 'Redis' in [s['name'] for s in services if s['status'] == 'ok'] else 'error'
        metrics['redis_memory'] = 'N/A'  # Would need docker exec to get
        
        # Recent logs
        logs = []
        try:
            result = subprocess.run(['docker', 'logs', 'aiia_django_prod', '--tail', '25'],
                                  capture_output=True, text=True, timeout=5)
            logs.extend(result.stdout.split('\n')[-25:])
        except:
            pass
        
        metrics['logs'] = [l for l in logs if l.strip()]
        
        # Deployment status (read from JSON files)
        deployments = {}
        try:
            import json
            from pathlib import Path
            
            # Check both production and staging deployment status
            for env in ['production', 'staging']:
                # Try multiple possible paths
                possible_paths = [
                    Path(f'/home/ubuntu/{env}/ai-ia-backend/.deployments/last_{env}.json'),
                    Path(f'/home/ubuntu/main/ai-ia-backend/.deployments/last_{env}.json') if env == 'production' else Path(f'/home/ubuntu/staging/ai-ia-backend/.deployments/last_{env}.json'),
                ]
                
                for status_file in possible_paths:
                    if status_file.exists():
                        try:
                            with open(status_file, 'r') as f:
                                deployments[env] = json.load(f)
                            break
                        except:
                            pass
                
                if env not in deployments:
                    deployments[env] = {
                        'status': 'unknown',
                        'timestamp': None,
                        'message': 'No deployment recorded'
                    }
        except Exception as e:
            deployments = {'error': str(e)}
        
        metrics['deployments'] = deployments
        
        return metrics
    
    def log_message(self, format, *args):
        # Suppress default logging
        pass

def run(port=9100):
    server_address = ('', port)
    httpd = HTTPServer(server_address, MetricsHandler)
    print(f'Metrics server running on port {port}')
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print('\nShutting down metrics server')
        httpd.shutdown()

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 9100
    run(port)

