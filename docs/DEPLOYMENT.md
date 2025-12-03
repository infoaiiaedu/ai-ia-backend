# Deployment Secrets & Configuration Guide

## GitHub Secrets Setup

Add the following secrets to your GitHub repository settings at:
`https://github.com/infoaiiaedu/ai-ia-backend/settings/secrets/actions`

### Required Secrets

```
DEPLOY_HOST              Production server IP/hostname
DEPLOY_USER              SSH user (typically: ubuntu)
DEPLOY_KEY               SSH private key (PEM format)
```

### Optional Secrets

```
SLACK_WEBHOOK            Slack webhook for deployment notifications
DOCKER_REGISTRY_TOKEN    GitHub Container Registry token
```

## Server Setup Checklist

### 1. Initial Server Setup

```bash
# 1. Update system
sudo apt-get update && sudo apt-get upgrade -y

# 2. Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# 3. Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 4. Verify installation
docker --version
docker-compose --version

# 5. Configure swap (critical for 512MB system)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
# Make permanent: add to /etc/fstab
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# 6. Set resource limits
sudo sysctl -w vm.swappiness=10
sudo sysctl -w vm.overcommit_memory=1
# Save: echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
```

### 2. Directory Structure

```bash
# Create deployment directories
sudo mkdir -p /home/ubuntu/main/ai-ia-backend
sudo mkdir -p /home/ubuntu/staging/ai-ia-backend
sudo mkdir -p /home/ubuntu/main/ai-ia-backend/logs
sudo mkdir -p /home/ubuntu/main/ai-ia-backend/backups
sudo mkdir -p /home/ubuntu/main/ai-ia-backend/storage_prod
sudo mkdir -p /home/ubuntu/staging/ai-ia-backend/logs
sudo mkdir -p /home/ubuntu/staging/ai-ia-backend/backups
sudo mkdir -p /home/ubuntu/staging/ai-ia-backend/storage_staging

# Set permissions
sudo chown -R ubuntu:ubuntu /home/ubuntu/main
sudo chown -R ubuntu:ubuntu /home/ubuntu/staging
chmod 755 /home/ubuntu/main/ai-ia-backend
chmod 755 /home/ubuntu/staging/ai-ia-backend
```

### 3. SSL Certificate Setup

```bash
# Install Certbot
sudo apt-get install -y certbot python3-certbot-nginx

# Create certificates for each domain
sudo certbot certonly --standalone \
  -d eduaiia.com \
  -d www.eduaiia.com \
  -d staging.eduaiia.com \
  -d devstatus.eduaiia.com

# Copy to Docker volume (assuming they're accessible)
sudo cp /etc/letsencrypt/live/*/fullchain.pem /home/ubuntu/main/ai-ia-backend/docker/nginx/ssl/
sudo cp /etc/letsencrypt/live/*/privkey.pem /home/ubuntu/main/ai-ia-backend/docker/nginx/ssl/

# Auto-renewal cron
# Add to crontab: 0 3 * * * certbot renew --quiet
```

### 4. SSH Key Configuration

```bash
# Create SSH key pair for deployments (on your local machine)
ssh-keygen -t ed25519 -C "ai-ia-github-actions" -f ~/.ssh/ai-ia_deploy_key -N ""

# Add public key to authorized_keys on server
cat ~/.ssh/ai-ia_deploy_key.pub | ssh ubuntu@your.server.ip "cat >> ~/.ssh/authorized_keys"

# Copy private key to GitHub Secrets (encode as base64 if needed)
cat ~/.ssh/ai-ia_deploy_key
# Copy the output and paste into DEPLOY_KEY secret

# Test SSH access
ssh -i ~/.ssh/ai-ia_deploy_key ubuntu@your.server.ip
```

## Environment Configuration

### Production (.env)

Copy `config/prod.env.example` to `.env` and fill in:

```bash
# CRITICAL - Change these!
SECRET_KEY=<generate-with: python -c "import secrets; print(secrets.token_urlsafe(50))">
DB_PASSWORD=<generate-strong-password>

# Your actual domains
ALLOWED_HOSTS=eduaiia.com,www.eduaiia.com
CSRF_TRUSTED_ORIGINS=https://eduaiia.com,https://www.eduaiia.com

# Email configuration
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=<app-specific-password>

# Payment integration (if applicable)
BOG_CLIENT_ID=<your-bog-client-id>
BOG_CLIENT_SECRET=<your-bog-client-secret>
BOG_MERCHANT_ID=<your-merchant-id>
BOG_TERMINAL_ID=<your-terminal-id>
USE_BOG_MOCK=false

# Monitoring
GRAFANA_PASSWORD=<secure-password>
```

### Staging (.env.staging)

Similar to production but:
- Different SECRET_KEY
- staging.eduaiia.com domain
- USE_BOG_MOCK=true (for testing)

### Local Development (.env.local)

Copy `config/dev.env.example` and use development credentials.

## Initial Deployment Steps

### 1. First Time Setup

```bash
# SSH to production server
ssh ubuntu@your.server.ip

# Clone repository
cd /home/ubuntu/main/ai-ia-backend
git clone https://github.com/infoaiiaedu/ai-ia-backend.git .

# Copy environment files
cp config/prod.env.example .env
# Edit .env with production values
nano .env
```

### 2. Database Initialization

```bash
# Build images
docker-compose build

# Start services
docker-compose up -d postgresql redis

# Wait for PostgreSQL to be ready
sleep 10

# Create databases
docker-compose up -d pgbouncer

# Create superuser (you can do this after Django starts)
docker-compose run --rm django_prod python manage.py createsuperuser
```

### 3. Start Services

```bash
# Start all services
docker-compose up -d

# Verify all services are running
docker-compose ps

# Check logs
docker-compose logs -f

# Run health checks
curl http://localhost:8000/health/
curl http://localhost:8001/health/
curl http://localhost/health
```

### 4. Create Cron Jobs

```bash
# Edit crontab
crontab -e

# Add these lines:

# Backup production database daily at 2 AM
0 2 * * * cd /home/ubuntu/main/ai-ia-backend && bash scripts/backup.sh production >> logs/backup_cron.log 2>&1

# Backup staging database daily at 2:30 AM
30 2 * * * cd /home/ubuntu/staging/ai-ia-backend && bash scripts/backup.sh staging >> logs/backup_cron.log 2>&1

# Monitor system resources daily at 6 AM
0 6 * * * cd /home/ubuntu/main/ai-ia-backend && bash scripts/monitor.sh >> logs/monitor_cron.log 2>&1

# Certificate renewal (Let's Encrypt)
0 3 * * * certbot renew --quiet
```

## Continuous Deployment with GitHub Actions

### 1. Add Secrets to GitHub

Go to: `Settings → Secrets and variables → Actions`

Create these secrets:

```
DEPLOY_HOST:      your.server.ip
DEPLOY_USER:      ubuntu
DEPLOY_KEY:       [paste your SSH private key]
SLACK_WEBHOOK:    [optional - your Slack webhook URL]
```

### 2. Deployment Branches

```
main branch       →  Production deployment
staging branch    →  Staging deployment
```

### 3. Making a Production Deployment

```bash
# 1. Create feature branch
git checkout -b feature/your-feature

# 2. Make changes and test locally
make test

# 3. Push to staging first
git push origin feature/your-feature
git push origin staging --force  # Cherry-pick commits or merge to staging

# 4. Wait for staging deployment (watch GitHub Actions)
# 5. Test on https://staging.eduaiia.com

# 6. Create pull request to main
# 7. Get approval and merge

# 8. Automatically deploys to production
# 9. Monitor deployment in GitHub Actions
# 10. Verify at https://eduaiia.com
```

## Secret Rotation

### Rotating Database Password

```bash
# 1. Generate new password
NEW_PASS=$(openssl rand -base64 32)

# 2. Update PostgreSQL user
docker exec aiia_postgresql psql -U aiia -c "ALTER USER aiia WITH PASSWORD '$NEW_PASS';"

# 3. Update environment file
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$NEW_PASS/" .env

# 4. Restart services
docker-compose down
docker-compose up -d

# 5. Verify connection works
docker exec aiia_pgbouncer psql -U aiia -d aiia_prod -c "SELECT 1"
```

### Rotating Django Secret Key

```bash
# 1. Generate new key
NEW_SECRET=$(python -c "import secrets; print(secrets.token_urlsafe(50))")

# 2. Update .env
sed -i "s/SECRET_KEY=.*/SECRET_KEY=$NEW_SECRET/" .env

# 3. Restart Django
docker-compose restart django_prod django_staging

# 4. Verify
curl http://localhost:8000/admin/
```

### Rotating SSH Deployment Key

```bash
# 1. On your local machine, generate new key
ssh-keygen -t ed25519 -C "ai-ia-github-actions-new" -f ~/.ssh/ai-ia_deploy_key_new

# 2. Add new public key to server
ssh ubuntu@your.server.ip "echo '$(cat ~/.ssh/ai-ia_deploy_key_new.pub)' >> ~/.ssh/authorized_keys"

# 3. Update GitHub Secret with new private key
# Go to Settings → Secrets → Update DEPLOY_KEY

# 4. Test new key
ssh -i ~/.ssh/ai-ia_deploy_key_new ubuntu@your.server.ip

# 5. Remove old key from server
ssh ubuntu@your.server.ip "ssh-keygen -R your.server.ip"
```

## Emergency Procedures

### Emergency Rollback

```bash
# 1. If deployment fails, manually rollback
cd /home/ubuntu/main/ai-ia-backend

# 2. Stop current services
docker-compose down

# 3. Restore database from backup
BACKUP_FILE=$(ls -t backups/db_prod_*/database.dump | head -1)
docker exec aiia_postgresql pg_restore -U aiia -d aiia_prod -F custom "$BACKUP_FILE"

# 4. Revert code to previous commit
git reset --hard HEAD~1

# 5. Rebuild and start
docker-compose build
docker-compose up -d

# 6. Verify
curl http://localhost:8000/health/
```

### Emergency Database Restore

```bash
# 1. Find backup
ls -lh backups/db_prod_*/

# 2. Stop application
docker-compose down

# 3. Connect to PostgreSQL directly
docker-compose up -d postgresql

# 4. Restore database
docker exec aiia_postgresql pg_restore -U aiia -d aiia_prod -F custom /path/to/backup.dump

# 5. Verify
docker exec aiia_postgresql psql -U aiia -d aiia_prod -c "SELECT COUNT(*) FROM django_content_type;"

# 6. Start services
docker-compose up -d
```

### Emergency Stop All Services

```bash
# If system is under DDoS or attack
docker-compose down
sudo systemctl stop docker
sudo iptables -I INPUT 1 -p tcp --dport 80 -j DROP
sudo iptables -I INPUT 1 -p tcp --dport 443 -j DROP
```

## Monitoring & Alerts Setup

### Slack Notifications

The GitHub Actions workflows automatically notify Slack on success/failure.

Add webhook URL to GitHub Secrets:
```
SLACK_WEBHOOK=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

### Email Notifications

Configure Django email settings in `.env`:

```
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_HOST_USER=your-gmail@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
```

Then add email alerts to Django views as needed.

## Documentation Links

- Server Setup: README.md
- Architecture: ARCHITECTURE.md
- Make Commands: Run `make help`
- Docker Compose: `docker-compose --help`

## Contact & Support

- **GitHub Issues:** Report bugs
- **Deployment**: Watch GitHub Actions tab
- **Server SSH**: `ssh ubuntu@your.server.ip`
- **Logs**: `tail -f /home/ubuntu/main/ai-ia-backend/logs/*`

---

**Last Updated:** 2024
**Security Level:** Production
**Access:** Team only
