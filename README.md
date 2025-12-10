# AI-IA Backend

Django REST API backend for the AI-IA educational platform.

## 🚀 Quick Start for Developers

### Prerequisites
- Python 3.11+
- Docker & Docker Compose
- Git

### 1. Clone and Setup
```bash
git clone https://github.com/infoaiiaedu/ai-ia-backend.git
cd ai-ia-backend

# Copy environment template
cp deployment/examples/.env.example .env
# Edit .env with your local settings
```

### 2. Run Locally (Development)

**Option A: Docker (Recommended)**
```bash
# Start all services (Django + PostgreSQL + Redis)
docker-compose -f deployment/docker/docker-compose.subdomain.yml up -d

# View logs
docker-compose -f deployment/docker/docker-compose.subdomain.yml logs -f app

# Stop services
docker-compose -f deployment/docker/docker-compose.subdomain.yml down
```

**Option B: Local Python**
```bash
# Install dependencies
cd code
pip install -r requirements.txt

# Setup database (you'll need PostgreSQL running)
python manage.py migrate
python manage.py createsuperuser

# Run development server
python manage.py runserver 0.0.0.0:5000
```

### 3. Access Your Local Backend

- **API Documentation**: http://localhost:5000/api/docs/
- **Admin Panel**: http://localhost:5000/admin/
- **API Base URL**: http://localhost:5000/api/

### 4. Development Workflow

```bash
# Make your changes in code/
# Test your changes
python manage.py test

# Create migrations
python manage.py makemigrations

# Apply migrations
python manage.py migrate

# Commit and push
git add .
git commit -m "feat: your feature description"
git push origin main
```

## 📁 Project Structure

```
├── code/                    # Django application
│   ├── main/               # Main Django settings
│   ├── apps/               # Django apps
│   │   ├── core/          # Core functionality
│   │   ├── user/          # User management
│   │   └── payments/      # Payment system
│   ├── api/               # API endpoints
│   └── manage.py          # Django management
├── deployment/            # Deployment configurations
│   ├── scripts/          # Deployment scripts
│   ├── docker/           # Docker Compose files
│   └── configs/          # Server configurations
└── docker/               # Docker configurations
```

## 🔧 Key Technologies

- **Django 4.2**: Web framework
- **Django Ninja**: API framework (automatic OpenAPI/Swagger)
- **PostgreSQL**: Primary database
- **Redis**: Caching and sessions
- **Gunicorn**: WSGI server for production
- **Docker**: Containerization

## 📚 API Documentation

The API uses Django Ninja which automatically generates interactive documentation:

- **Local**: http://localhost:5000/api/docs/
- **Production**: https://api.eduaiia.com/api/docs/

## 🗄️ Database

### Models Overview
- **User**: Custom user model with extended fields
- **Core**: Educational content (subjects, topics, grades)
- **Payments**: Subscription and payment handling

### Migrations
```bash
# Create new migration
python manage.py makemigrations app_name

# Apply migrations
python manage.py migrate

# Check migration status
python manage.py showmigrations
```

## 🧪 Testing

```bash
# Run all tests
python manage.py test

# Run specific app tests
python manage.py test apps.core

# Run with coverage
coverage run --source='.' manage.py test
coverage report
```

## 🔐 Authentication

The API uses JWT authentication. To test protected endpoints:

1. Create superuser: `python manage.py createsuperuser`
2. Login via admin panel: http://localhost:5000/admin/
3. Use session authentication for testing

## 🌐 Production Deployment

This project is configured for production deployment with subdomains:

- **Frontend**: https://eduaiia.com (PM2/Next.js)
- **API**: https://api.eduaiia.com/api/docs/
- **Admin**: https://admin.eduaiia.com/admin/

See `deployment/README.md` for deployment instructions.

## 🤝 Contributing

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Make your changes in the `code/` directory
3. Test your changes locally
4. Commit with clear message: `git commit -m "feat: add user profile endpoint"`
5. Push and create pull request

## 📞 Support

- **Repository**: https://github.com/infoaiiaedu/ai-ia-backend
- **Issues**: Use GitHub issues for bug reports
- **Documentation**: Check `deployment/README.md` for deployment details

## 📄 License

Private repository - All rights reserved.