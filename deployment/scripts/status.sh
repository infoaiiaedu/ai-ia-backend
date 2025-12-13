#!/bin/bash

# Django Backend Status Checker
# Checks the status of all Django backend services

echo "📊 Django Backend Status Check"
echo "=============================="
echo ""

# Change to deployment directory
cd "$(dirname "$0")/../docker" || exit 1

# Check if running
if docker-compose -f docker-compose.subdomain.yml ps | grep -q "django" 2>/dev/null; then
    echo "✅ Backend services are running"
    echo ""
    echo "📦 Container Status:"
    docker-compose -f docker-compose.subdomain.yml ps
    echo ""
    
    # Check Django backend health
    echo "🔍 Health Checks:"
    if curl -s http://localhost:8080/ > /dev/null 2>&1; then
        echo "✅ Backend nginx responding on port 8080"
    else
        echo "❌ Backend nginx not responding on port 8080"
    fi
    
    if docker exec django_backend curl -s http://localhost:5000/ > /dev/null 2>&1; then
        echo "✅ Django app responding internally"
    else
        echo "❌ Django app not responding"
    fi
    
    echo ""
    echo "📝 Recent Logs (last 10 lines):"
    docker-compose -f docker-compose.subdomain.yml logs --tail=10 app
    
else
    echo "❌ Backend services are not running"
    echo ""
    echo "To start services, run:"
    echo "  cd deployment/docker"
    echo "  docker-compose -f docker-compose.subdomain.yml up -d"
fi

echo ""
echo "💡 Useful commands:"
echo "  View logs: docker-compose -f deployment/docker/docker-compose.subdomain.yml logs -f app"
echo "  Restart: docker-compose -f deployment/docker/docker-compose.subdomain.yml restart"
echo "  Stop: docker-compose -f deployment/docker/docker-compose.subdomain.yml down"
