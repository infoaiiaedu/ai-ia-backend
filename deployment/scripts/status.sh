#!/bin/bash

# Django Docker Status Check Script

echo "🐳 Docker Container Status"
echo "=========================="

# Check if docker-compose.yml services are running
if docker-compose ps | grep -q "main_app"; then
    echo "📊 Full Stack Status:"
    docker-compose ps
    echo ""
    echo "📝 Recent App Logs:"
    docker-compose logs --tail=10 app
elif docker-compose -f docker-compose.backend-only.yml ps | grep -q "main_app" 2>/dev/null; then
    echo "📊 Backend Only Status:"
    docker-compose -f docker-compose.backend-only.yml ps
    echo ""
    echo "📝 Recent App Logs:"
    docker-compose -f docker-compose.backend-only.yml logs --tail=10 app
else
    echo "❌ No Django containers found running"
    echo "💡 Run './deploy.sh' to start the application"
fi

echo ""
echo "🔍 Health Check:"
if curl -s http://localhost:5000/ > /dev/null 2>&1; then
    echo "✅ Django app is responding on port 5000"
else
    echo "❌ Django app is not responding on port 5000"
fi

if curl -s http://localhost/ > /dev/null 2>&1; then
    echo "✅ Nginx is responding on port 80"
else
    echo "ℹ️  No response on port 80 (normal if using backend-only mode)"
fi