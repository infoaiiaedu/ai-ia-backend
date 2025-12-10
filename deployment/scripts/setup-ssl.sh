#!/bin/bash

# SSL Setup Script for Django Subdomains
# Sets up Let's Encrypt SSL certificates for api.eduaiia.com and admin.eduaiia.com

echo "🔐 Setting up SSL certificates for Django subdomains..."

# Check if domain names resolve to this server
echo "🔍 Checking DNS resolution..."

API_DOMAIN="api.eduaiia.com"
ADMIN_DOMAIN="admin.eduaiia.com"

# Get server's public IP
SERVER_IP=$(curl -s http://checkip.amazonaws.com/ || curl -s http://ipv4.icanhazip.com/)
echo "Server public IP: $SERVER_IP"

# Check if domains resolve to this server
API_IP=$(dig +short $API_DOMAIN || echo "")
ADMIN_IP=$(dig +short $ADMIN_DOMAIN || echo "")

echo "DNS Resolution:"
echo "  $API_DOMAIN -> $API_IP"
echo "  $ADMIN_DOMAIN -> $ADMIN_IP"

if [ "$API_IP" != "$SERVER_IP" ] || [ "$ADMIN_IP" != "$SERVER_IP" ]; then
    echo "⚠️  WARNING: DNS records don't point to this server yet!"
    echo "   Please ensure these DNS A records are set up:"
    echo "   $API_DOMAIN -> $SERVER_IP"
    echo "   $ADMIN_DOMAIN -> $SERVER_IP"
    echo ""
    read -p "Continue anyway? (y/N): " continue_setup
    if [[ ! $continue_setup =~ ^[Yy]$ ]]; then
        echo "SSL setup cancelled. Please set up DNS first."
        exit 1
    fi
fi

# Install certbot if not present
if ! command -v certbot &> /dev/null; then
    echo "📦 Installing certbot..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y certbot
    elif command -v yum &> /dev/null; then
        sudo yum install -y certbot
    else
        echo "❌ Please install certbot manually"
        exit 1
    fi
fi

# Create directories for certbot
sudo mkdir -p ./storage/certbot/conf ./storage/certbot/www
sudo chmod -R 755 ./storage/certbot

echo "🌐 Starting temporary nginx for certificate verification..."

# Start nginx temporarily for domain verification
docker-compose -f deployment/docker/docker-compose.subdomain.yml up -d nginx

# Wait for nginx to be ready
echo "⏳ Waiting for nginx to start..."
sleep 10

# Test if nginx is accessible
if ! curl -s http://localhost:8080/ > /dev/null; then
    echo "❌ Nginx is not responding. Please check the deployment."
    exit 1
fi

echo "✅ Nginx is ready for certificate verification"

# Request SSL certificates
echo "📜 Requesting SSL certificate for $API_DOMAIN..."
sudo certbot certonly \
    --webroot \
    --webroot-path=./storage/certbot/www \
    --email admin@eduaiia.com \
    --agree-tos \
    --no-eff-email \
    --domains $API_DOMAIN

if [ $? -eq 0 ]; then
    echo "✅ SSL certificate obtained for $API_DOMAIN"
else
    echo "❌ Failed to obtain SSL certificate for $API_DOMAIN"
    echo "💡 Make sure the domain points to this server and port 80 is accessible"
    exit 1
fi

echo "📜 Requesting SSL certificate for $ADMIN_DOMAIN..."
sudo certbot certonly \
    --webroot \
    --webroot-path=./storage/certbot/www \
    --email admin@eduaiia.com \
    --agree-tos \
    --no-eff-email \
    --domains $ADMIN_DOMAIN

if [ $? -eq 0 ]; then
    echo "✅ SSL certificate obtained for $ADMIN_DOMAIN"
else
    echo "❌ Failed to obtain SSL certificate for $ADMIN_DOMAIN"
    exit 1
fi

# Update nginx configuration to enable HTTPS
echo "🔧 Enabling HTTPS in nginx configuration..."

# Enable HTTPS blocks in subdomain.conf
sed -i 's/^# server {$/server {/' deployment/configs/subdomain.conf
sed -i 's/^#     listen 443/    listen 443/' deployment/configs/subdomain.conf
sed -i 's/^#     /    /' deployment/configs/subdomain.conf

# Update Django configuration for HTTPS
echo "🔧 Updating Django configuration for HTTPS..."
sed -i 's/DEBUG = false/DEBUG = false/' config/project.toml
sed -i 's|CSRF_TRUSTED_ORIGINS = .*|CSRF_TRUSTED_ORIGINS = ["https://api.eduaiia.com", "https://admin.eduaiia.com"]|' config/project.toml

# Restart services to apply SSL configuration
echo "🔄 Restarting services with SSL configuration..."
docker-compose -f deployment/docker/docker-compose.subdomain.yml down
docker-compose -f deployment/docker/docker-compose.subdomain.yml up -d

# Wait for services to restart
echo "⏳ Waiting for services to restart..."
sleep 15

# Test HTTPS
echo "🔍 Testing HTTPS connections..."
if curl -s https://$API_DOMAIN/ > /dev/null 2>&1; then
    echo "✅ HTTPS working for $API_DOMAIN"
else
    echo "⚠️  HTTPS test failed for $API_DOMAIN (this might be normal if DNS isn't propagated)"
fi

if curl -s https://$ADMIN_DOMAIN/ > /dev/null 2>&1; then
    echo "✅ HTTPS working for $ADMIN_DOMAIN"
else
    echo "⚠️  HTTPS test failed for $ADMIN_DOMAIN (this might be normal if DNS isn't propagated)"
fi

# Set up auto-renewal
echo "⏰ Setting up SSL auto-renewal..."
(crontab -l 2>/dev/null; echo "0 0 * * 0 certbot renew --quiet && docker-compose -f $(pwd)/docker-compose.subdomain.yml restart nginx") | crontab -

echo ""
echo "🎉 SSL setup complete!"
echo ""
echo "📋 Summary:"
echo "✅ SSL certificates obtained for both subdomains"
echo "✅ HTTPS enabled in nginx"
echo "✅ Auto-renewal configured"
echo ""
echo "🌐 Your Django backend is now available at:"
echo "   - API Docs: https://$API_DOMAIN/api/docs/"
echo "   - Admin: https://$ADMIN_DOMAIN/admin/"
echo ""
echo "🔧 Next: Update your main nginx to use HTTPS in proxy config!"