# AI-IA Backend

Django REST API backend for the AI-IA educational platform.

## 🚀 Run Locally (Development)

### Quick Setup
```bash
git clone https://github.com/infoaiiaedu/ai-ia-backend.git
cd ai-ia-backend
```

### Option 1: Docker (Recommended)
```bash
# Start development environment
docker-compose -f deployment/docker/docker-compose.dev.yml up -d

# View logs
docker-compose -f deployment/docker/docker-compose.dev.yml logs -f app

# Stop when done
docker-compose -f deployment/docker/docker-compose.dev.yml down
```

### Option 2: Local Python
```bash
cd code
pip install -r requirements.txt
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver 0.0.0.0:5000
```

## 🌐 Access Points

- **API Documentation**: http://localhost:5000/api/docs/
- **Admin Panel**: http://localhost:5000/admin/
- **API Base**: http://localhost:5000/api/

## 🔧 Development

```bash
# Make changes in code/ directory
# Create migrations
python manage.py makemigrations

# Apply migrations  
python manage.py migrate

# Run tests
python manage.py test
```

## 📁 Key Directories

- `code/` - Django application
- `code/apps/` - Django apps (core, user, payments)
- `code/api/` - API endpoints
- `deployment/` - Docker and deployment configs

## 🌐 Production URLs

- **API**: https://api.eduaiia.com/api/docs/
- **Admin**: https://admin.eduaiia.com/admin/