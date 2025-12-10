#!/bin/bash

# Django Subdomain Deployment Script
# Serves API docs on api.eduaiia.com and admin on admin.eduaiia.com

echo "🚀 Starting Django subdomain deployment..."

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p ./storage/db/pgdata ./config ./storage/certbot/conf ./storage/certbot/www

# Create configuration if it doesn't exist
if [ ! -f "./config/project.toml" ]; then
    echo "⚙️ Creating configuration for subdomains..."
    cat > ./config/project.toml << 'EOF'
[project]
SECRET_KEY = "django-insecure-change-this-in-production"
DEBUG = false
ALLOWED_HOSTS = ["localhost", "127.0.0.1", "api.eduaiia.com", "admin.eduaiia.com", "eduaiia.com"]
CSRF_TRUSTED_ORIGINS = ["http://api.eduaiia.com", "https://api.eduaiia.com", "http://admin.eduaiia.com", "https://admin.eduaiia.com"]
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
    echo "✅ Configuration created with subdomain support"
    echo "⚠️  Please update SECRET_KEY in production!"
fi

echo ""
echo "🌐 This will deploy Django backend on:"
echo "   - API Docs: http://api.eduaiia.com:8080/api/docs/ (via nginx on port 8080)"
echo "   - Admin: http://admin.eduaiia.com:8080/admin/ (via nginx on port 8080)"
echo "   - Direct backend: http://localhost:5000 (bypassing nginx)"
echo ""
echo "📝 DNS Setup Required:"
echo "   Add these A records to your DNS:"
echo "   api.eduaiia.com → YOUR_SERVER_IP"
echo "   admin.eduaiia.com → YOUR_SERVER_IP"
echo ""

read -p "Continue with deployment? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 1
fi

echo "🐳 Starting Django backend services..."
docker-compose -f docker-compose.subdomain.yml up -d

echo ""
echo "⏳ Waiting for services to start..."
sleep 10

echo ""
echo "📊 Checking container status..."
docker-compose -f docker-compose.subdomain.yml ps

echo ""
echo "🔍 Health checks..."

# Check if backend is responding
if curl -s http://localhost:5000/ > /dev/null 2>&1; then
    echo "✅ Django backend is responding on port 5000"
else
    echo "❌ Django backend is not responding on port 5000"
fi

# Check nginx
if curl -s http://localhost:8080/ > /dev/null 2>&1; then
    echo "✅ Nginx is responding on port 8080"
else
    echo "❌ Nginx is not responding on port 8080"
fi

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🌐 Access your Django backend:"
echo "   - API Docs: http://api.eduaiia.com:8080/api/docs/"
echo "   - Admin: http://admin.eduaiia.com:8080/admin/"
echo "   - Direct backend: http://localhost:5000"
echo ""
echo "🔧 Next steps:"
echo "1. Set up DNS A records for api.eduaiia.com and admin.eduaiia.com"
echo "2. Configure your main nginx (PM2) to proxy subdomain requests:"
echo ""
echo "   # Add to your main nginx config:"
echo "   server {"
echo "       listen 80;"
echo "       server_name api.eduaiia.com;"
echo "       location / {"
echo "           proxy_pass http://localhost:8080;"
echo "           proxy_set_header Host \$host;"
echo "           proxy_set_header X-Real-IP \$remote_addr;"
echo "           proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;"
echo "           proxy_set_header X-Forwarded-Proto \$scheme;"
echo "       }"
echo "   }"
echo ""
echo "   server {"
echo "       listen 80;"
echo "       server_name admin.eduaiia.com;"
echo "       location / {"
echo "           proxy_pass http://localhost:8080;"
echo "           proxy_set_header Host \$host;"
echo "           proxy_set_header X-Real-IP \$remote_addr;"
echo "           proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;"
echo "           proxy_set_header X-Forwarded-Proto \$scheme;"
echo "       }"
echo "   }"
echo ""
echo "📝 Useful commands:"
echo "  - View logs: docker-compose -f docker-compose.subdomain.yml logs -f app"
echo "  - Stop: docker-compose -f docker-compose.subdomain.yml down"
echo "  - Restart: docker-compose -f docker-compose.subdomain.yml restart"
echo ""
echo "🎉 Django subdomain deployment completed!"