#!/bin/bash

# Django Docker Deployment Script
# This script helps deploy the Django project alongside your existing PM2 frontend

echo "🚀 Starting Django deployment..."

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p ./storage/db/pgdata ./config

# Create basic configuration if it doesn't exist
if [ ! -f "./config/project.toml" ]; then
    echo "⚙️ Creating basic configuration..."
    cat > ./config/project.toml << 'EOF'
[project]
SECRET_KEY = "django-insecure-change-this-in-production-$(openssl rand -hex 32)"
DEBUG = false
ALLOWED_HOSTS = ["localhost", "127.0.0.1", "your-domain.com"]
CSRF_TRUSTED_ORIGINS = ["http://localhost", "https://your-domain.com"]
REDIS_URI = "redis://redis:6379/0"

[database]
ENGINE = "postgresql"
NAME = "ai_db"
USER = "postgres"
PASSWORD = "postgres"
HOST = "psql"
PORT = "5432"

[server]
IP = "0.0.0.0"
User = "app"
Pass = "app"
PROJECT_DIR = "/app"
Root_User = "root"
Root_Pass = "root"
EOF
    echo "✅ Configuration created at ./config/project.toml"
    echo "⚠️  Please update the configuration with your actual domain and secret key!"
fi

# Ask user which deployment option they prefer
echo ""
echo "Choose deployment option:"
echo "1) Full stack with Nginx (uses ports 80/443)"
echo "2) Backend only (uses port 5000, recommended if PM2 frontend uses 80/443)"
read -p "Enter choice (1 or 2): " choice

case $choice in
    1)
        echo "🐳 Starting full stack with Nginx..."
        docker-compose up -d
        echo ""
        echo "✅ Deployment complete!"
        echo "🌐 Your Django app should be available at:"
        echo "   - http://localhost (HTTP)"
        echo "   - https://localhost (HTTPS, if SSL configured)"
        ;;
    2)
        echo "🐳 Starting backend services only..."
        docker-compose -f deployment/docker/docker-compose.backend-only.yml up -d
        echo ""
        echo "✅ Deployment complete!"
        echo "🌐 Your Django app should be available at:"
        echo "   - http://localhost:5000"
        echo ""
        echo "💡 You can proxy this through your existing PM2/Nginx setup"
        ;;
    *)
        echo "❌ Invalid choice. Exiting."
        exit 1
        ;;
esac

echo ""
echo "📊 Checking container status..."
if [ $choice -eq 1 ]; then
    docker-compose ps
else
    docker-compose -f deployment/docker/docker-compose.backend-only.yml ps
fi

echo ""
echo "📝 Useful commands:"
echo "  - View logs: docker-compose logs -f app"
echo "  - Stop services: docker-compose down"
echo "  - Restart: docker-compose restart app"
echo "  - Shell access: docker-compose exec app sh"
echo ""
echo "🎉 Django deployment completed successfully!"