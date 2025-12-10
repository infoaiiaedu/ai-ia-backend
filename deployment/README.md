# Django Backend Deployment

This directory contains all the deployment configurations and scripts for the Django backend.

## 📁 Structure

```
deployment/
├── scripts/           # Deployment and management scripts
│   ├── deploy-subdomain.sh    # Main subdomain deployment script
│   ├── deploy.sh             # General deployment script
│   ├── setup-ssl.sh          # SSL certificate setup
│   └── status.sh             # Container status checker
├── docker/           # Docker Compose configurations
│   ├── docker-compose.yml           # Original full stack
│   ├── docker-compose.subdomain.yml # Subdomain-specific setup
│   └── docker-compose.backend-only.yml # Backend only
├── configs/          # Nginx and server configurations
│   ├── nginx-proxy-config.conf      # Main nginx proxy config
│   └── eduaiia-updated.conf         # Complete eduaiia.com config
├── examples/         # Configuration templates
│   └── .env.example             # Environment variables template
└── README.md         # This file
```

## 🚀 Quick Start

1. **Deploy Django backend on subdomains:**
   ```bash
   chmod +x deployment/scripts/deploy-subdomain.sh
   ./deployment/scripts/deploy-subdomain.sh
   ```

2. **Set up SSL certificates:**
   ```bash
   chmod +x deployment/scripts/setup-ssl.sh
   ./deployment/scripts/setup-ssl.sh
   ```

3. **Check deployment status:**
   ```bash
   ./deployment/scripts/status.sh
   ```

## 🌐 Live URLs

- **Frontend**: https://eduaiia.com (PM2/Next.js)
- **API Docs**: https://api.eduaiia.com/api/docs/
- **Admin Panel**: https://admin.eduaiia.com/admin/

## 🔧 Configuration

### Environment Variables
Copy and customize the environment template:
```bash
cp deployment/examples/.env.example .env
# Edit .env with your specific values
```

### Nginx Setup
The main nginx configuration needs to include subdomain routing. Use:
```bash
sudo cp deployment/configs/eduaiia-updated.conf /etc/nginx/sites-available/eduaiia.com
sudo nginx -t && sudo nginx -s reload
```

## 📊 Architecture

```
Internet → Cloudflare → Server Nginx → {
  ├── eduaiia.com → PM2 Frontend (port 3000)
  ├── api.eduaiia.com → Docker Nginx (port 8080) → Django (port 5000)
  └── admin.eduaiia.com → Docker Nginx (port 8080) → Django (port 5000)
}
```

## 🐳 Docker Services

- **django_backend**: Django application with Gunicorn
- **django_psql**: PostgreSQL database
- **django_redis**: Redis cache
- **django_nginx**: Nginx reverse proxy

## 👤 Default Admin

- **Username**: admin
- **Password**: AiiaAdmin#1
- **URL**: https://admin.eduaiia.com/admin/