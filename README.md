# AI-IA Backend

Info for DevOps Engineer

Overview
- Django + Gunicorn, Postgres, Redis. Containerized via Docker Compose.
- Compose variants in deployment/docker/ for different setups (dev, subdomain, backend-only).
- Host Nginx typically proxies api/admin subdomains to the backend nginx service.

Prerequisites
- Docker and Docker Compose installed
- Configure environment (DB creds, secrets, allowed hosts)

Run with Docker Compose (production-like, subdomain proxy)
```bash
# from repo root
cd deployment/docker
# exposes backend nginx on host 8080/8443 by default
docker compose -f docker-compose.subdomain.yml up -d

# view logs
docker compose -f docker-compose.subdomain.yml logs -f

# health check nginx inside stack
curl -i http://127.0.0.1:8080/
```

Host Nginx example (api/admin)
```
upstream aiia_backend {
    server 127.0.0.1:8080;
    keepalive 32;
}
server {
    listen 80;
    server_name api.your-domain.com;
    location / { proxy_pass http://aiia_backend; }
}
server {
    listen 80;
    server_name admin.your-domain.com;
    location / { proxy_pass http://aiia_backend; }
}
```

Run locally (development compose)
```bash
# from repo root
cd deployment/docker
# maps Django directly to 5000 for faster iteration
docker compose -f docker-compose.dev.yml up -d
# app: http://127.0.0.1:5000/
```

Run without Docker (local Python)
```bash
cd code
pip install -r requirements.txt
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver 0.0.0.0:5000
```

Access Points
- API Base: http://localhost:5000/api/
- Admin Panel: http://localhost:5000/admin/
- API Docs (if enabled): http://localhost:5000/api/docs/

Development commands
```bash
# In code/
python manage.py makemigrations
python manage.py migrate
python manage.py test
```

Key directories
- code/ — Django project and apps
- deployment/docker/ — compose files and nginx configs
- storage/ — static/media/certbot data persisted via volumes

Production notes
- Migrations and collectstatic run on container start (see compose command).
- Ensure ALLOWED_HOSTS, database credentials, and secure settings are configured for production.
- For HTTPS, terminate TLS at host Nginx or mount certificates into the nginx service.

<!-- Test GHCR auto-deployment for backend Sat Dec 13 16:24:04 UTC 2025 -->
