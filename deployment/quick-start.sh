#!/bin/bash

# Quick Start Script for Django Backend Deployment
# This script provides easy access to all deployment commands

echo "🚀 Django Backend Deployment Manager"
echo "===================================="
echo ""
echo "Choose an option:"
echo "1) Deploy Django backend on subdomains"
echo "2) Check deployment status"
echo "3) Set up SSL certificates"
echo "4) View container logs"
echo "5) Stop deployment"
echo "6) Restart deployment"
echo ""
read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        echo "🚀 Starting subdomain deployment..."
        ./deployment/scripts/deploy-subdomain.sh
        ;;
    2)
        echo "📊 Checking deployment status..."
        ./deployment/scripts/status.sh
        ;;
    3)
        echo "🔐 Setting up SSL certificates..."
        ./deployment/scripts/setup-ssl.sh
        ;;
    4)
        echo "📝 Showing container logs..."
        docker-compose -f deployment/docker/docker-compose.subdomain.yml logs -f app
        ;;
    5)
        echo "🛑 Stopping deployment..."
        docker-compose -f deployment/docker/docker-compose.subdomain.yml down
        echo "✅ Deployment stopped"
        ;;
    6)
        echo "🔄 Restarting deployment..."
        docker-compose -f deployment/docker/docker-compose.subdomain.yml restart
        echo "✅ Deployment restarted"
        ;;
    *)
        echo "❌ Invalid choice. Exiting."
        exit 1
        ;;
esac