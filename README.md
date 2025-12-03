# AI-IA Backend Deployment Guide

Production-ready DevOps infrastructure for Django applications with strict resource constraints (512MB RAM, 2 vCPU).

## Table of Contents

- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Local Development](#local-development)
- [Deployment](#deployment)
- [Monitoring](#monitoring)
- [Backup & Recovery](#backup--recovery)
- [Troubleshooting](#troubleshooting)
- [Resource Optimization](#resource-optimization)

## Quick Start

### Prerequisites

- Docker & Docker Compose 3.9+
- Git with SSH key setup
- 512MB minimum RAM on server
- 20GB disk space

### Local Development (5 minutes)

#### Windows
```cmd
# 1. Clone the repository
git clone git@github.com:infoaiiaedu/ai-ia-backend.git
cd ai-ia-backend

# 2. Start development environment (uses port 9000)
dev.bat start

# 3. Create superuser
docker-compose -f docker-compose.local.yml exec django python manage.py createsuperuser

# 4. Access the application
# Django: http://localhost:9000
# Admin: http://localhost:9000/admin
```

#### Mac/Linux
```bash
# 1. Clone the repository
git clone git@github.com:infoaiiaedu/ai-ia-backend.git
cd ai-ia-backend

# 2. Setup environment
make setup

# 3. Start development environment
make dev

# 4. Run migrations
make migrate

# 5. Create superuser
make superuser

# 6. Access the application
# Django: http://localhost:8000
# Admin: http://localhost:8000/admin
```

**Note**: Windows uses alternate ports (9000, 9080) due to Docker port binding limitations - see [Windows Port Binding Fix](#windows-port-binding-fix)

**Note**: Windows uses alternate ports (9000, 9080) due to Docker port binding limitations - see [Windows Port Binding Fix](#windows-port-binding-fix)

### Production Deployment

```bash
# 1. Configure environment variables
cp config/prod.env.example .env
# Edit .env with production credentials

# 2. Deploy to production (via GitHub Actions on main branch push)
git push origin main

# 3. Monitor deployment
make healthcheck
```

## Architecture

### Single-Stack Resource-Optimized Design

```
┌─────────────────────────────────────────────────────────────┐
│                      Production Server                       │
│                  512MB RAM | 2 vCPU | 20GB Disk             │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Nginx Reverse Proxy (50MB)              │   │
│  │  ┌──────────────┐         ┌──────────────────┐      │   │
│  │  │  eduaiia.com │         │ staging.*.com    │      │   │
│  │  │ www.*.com    │         │ devstatus.*.com  │      │   │
│  │  └──────────────┘         └──────────────────┘      │   │
│  └──────────────────────────────────────────────────────┘   │
│                           ▼                                   │
│  ┌────────────────────────────────────────────────────────┐  │
│  │        Django Applications (Separate Environments)     │  │
│  │                                                        │  │
│  │  Production (150MB)      │   Staging (100MB)          │  │
│  │  ├─ 2 workers           │   ├─ 1 worker             │  │
│  │  ├─ 2 threads           │   ├─ 2 threads            │  │
│  │  ├─ Port 8000           │   ├─ Port 8001            │  │
│  │  └─ aiia_prod DB        │   └─ aiia_staging DB      │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │          Shared Data Layer (200MB Total)              │  │
│  │                                                        │  │
│  │  PostgreSQL (200MB)    │  Redis (50MB)               │  │
│  │  ├─ Shared Instance    │  ├─ Caching                │  │
│  │  ├─ Max 50 conn        │  ├─ Sessions               │  │
│  │  ├─ 128MB buffers      │  ├─ Real-time data         │  │
│  │  └─ PgBouncer (30MB)   │  └─ 50MB max memory        │  │
│  │     Connection pooling │                             │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Container Strategy** | Single docker-compose + environment overrides | Reduces overhead, simpler management |
| **Database** | Shared PostgreSQL with separate databases | Saves ~50MB vs separate instances |
| **Connection Pooling** | PgBouncer (30MB) | Essential for 512MB RAM, reduces connection overhead |
| **Redis** | Single instance, 2 databases (prod/staging) | Lightweight, 50MB max |
| **Static Files** | Nginx serving from volumes | No Django overhead, 30day caching |
| **Process Management** | Docker restart policies + systemd | Automatic recovery, simple monitoring |
| **Backups** | Keep only latest backup | Storage constraint, encrypt on remote push |

### Port Allocation

```
Host    | Service          | Internal | Purpose
--------|------------------|----------|------------------
80      | Nginx HTTP       | -        | Redirect to HTTPS
443     | Nginx HTTPS      | -        | Main reverse proxy
6432    | PgBouncer        | 6432     | Connection pooling
5432    | PostgreSQL       | 5432     | Database (internal only)
6379    | Redis            | 6379     | Cache (internal only)
8000    | Django Prod      | 8000     | Production app (internal)
8001    | Django Staging   | 8001     | Staging app (internal)
```

## Local Development

### Commands

```bash
# Start/stop development
make dev           # Start environment
make dev-down      # Stop environment
make dev-logs      # View logs
make dev-shell     # Django shell
make dev-bash      # Container bash

# Database
make migrate       # Run migrations
make makemigrations # Create migrations
make superuser     # Create admin user
make test          # Run tests
make test-fast     # Run tests with failfast

# Code quality
make lint          # Run flake8
make format        # Format with black
make check         # Django system checks

# Docker
make build-dev     # Build development image
make ps            # Show containers
make images        # List images
make prune         # Clean unused resources
```

### Database Credentials (Development)

```
PostgreSQL:
  Host:     postgresql
  Port:     5432
  Database: aiia_dev
  User:     aiia_dev
  Password: dev_password_123

Redis:
  Host:     redis
  Port:     6379
  Database: 0
```

### Troubleshooting Development

```bash
# Container won't start?
docker-compose -f docker-compose.local.yml logs django

# Permission denied?
sudo chown -R $USER:$USER storage_dev

# Reset everything
make clean
make setup
make dev

# Port already in use?
lsof -i :8000  # Check what's using port 8000
```

## Deployment

### GitHub Actions CI/CD Pipeline

Two separate workflows for simultaneous deployments:

#### Production Workflow (on `main` push)

1. **Test Phase**
   - Run Django checks
   - Run database migrations
   - Run test suite
   - Collect static files

2. **Build Phase**
   - Build Docker image from `docker/Dockerfile.prod`
   - Push to GitHub Container Registry

3. **Deploy Phase**
   - SSH to production server
   - Pull latest code from `main` branch
   - Backup production database
   - Build and start `django_prod` container
   - Run migrations
   - Collect static files
   - Restart Nginx
   - Health checks (30 attempts, 2s interval)

#### Staging Workflow (on `staging` push)

Identical to production but:
- Uses `docker/Dockerfile.staging` (1 worker vs 2)
- Deploys to `/home/ubuntu/staging/ai-ia-backend`
- Uses `aiia_staging` database
- Connects to `staging.eduaiia.com`

### Manual Deployment

```bash
# 1. SSH to server
ssh ubuntu@your.server.ip

# 2. Navigate to deployment directory
cd /home/ubuntu/main/ai-ia-backend  # for production
cd /home/ubuntu/staging/ai-ia-backend  # for staging

# 3. Run deployment script
bash scripts/deploy.sh production  # or staging

# 4. Monitor deployment
tail -f logs/deploy_production_*.log
```

### Deployment Checklist

- [ ] All tests passing
- [ ] Database backup created
- [ ] Code changes reviewed
- [ ] Environment variables configured
- [ ] SSL certificates valid
- [ ] Monitoring alerts configured
- [ ] Deployment started
- [ ] Health checks passing
- [ ] Error logs reviewed

## Monitoring

### Health Checks

```bash
# Quick health check
make healthcheck

# Comprehensive monitoring
make monitor

# View specific service logs
make prod-logs
make staging-logs
docker logs aiia_nginx -f
docker logs aiia_postgresql -f
docker logs aiia_redis -f
```

### Key Metrics to Monitor

1. **Resource Usage** (512MB total)
   - PostgreSQL: 200MB
   - Redis: 50MB
   - Nginx: 50MB
   - Django Prod: 150MB
   - Django Staging: 100MB
   - System: 62MB (reserve)

2. **Application Health**
   - Django health endpoint: `/health/`
   - Nginx health endpoint: `/health`
   - Database connection count
   - Redis memory usage

3. **Performance**
   - Request latency (goal: <200ms p95)
   - Error rate (goal: <0.1%)
   - Active connections
   - Database query time

### Monitoring Dashboard

Access monitoring at `https://devstatus.eduaiia.com` (with basic auth):

- System metrics (CPU, memory, disk)
- Service status (all containers)
- Last deployment info
- Uptime statistics
- Error rate
- Recent logs

## Backup & Recovery

### Automatic Backups

Backups run:
- Before each deployment (via deploy script)
- Daily via cron: `0 2 * * * /home/ubuntu/main/ai-ia-backend/scripts/backup.sh production`

### Manual Backup

```bash
# Backup production
make db-backup

# Backup staging
make db-backup-staging

# Restore from backup
make db-restore BACKUP_PATH=backups/db_prod_20240101_120000/database.dump
```

### Backup Contents

Each backup includes:
- `database.dump` - PostgreSQL dump (pg_restore format)
- `media.tar.gz` - User uploads (optional)
- `config.tar.gz` - Application configuration
- `MANIFEST.txt` - Metadata and restoration commands

### Backup Storage Policy

- **Local:** Keep only latest 3 backups
- **Remote:** Push encrypted backups to S3 (optional)
- **Retention:** 30 days minimum

### Recovery Procedure

```bash
# 1. Locate backup
ls backups/db_prod_*/database.dump

# 2. Stop application
docker-compose down

# 3. Restore database
docker exec aiia_postgresql pg_restore -U aiia -d aiia_prod -F custom backups/db_prod_20240101_120000/database.dump

# 4. Restore media (if needed)
tar -xzf backups/db_prod_20240101_120000/media.tar.gz

# 5. Restart services
docker-compose up -d

# 6. Verify
make healthcheck
```

## Troubleshooting

### Containers Won't Start

```bash
# Check logs
docker-compose logs django_prod
docker-compose logs postgresql
docker-compose logs nginx

# Check resource limits
docker stats

# Check disk space
df -h /var/lib/docker

# Solution: Free disk space, increase swap
sudo swapoff -a
sudo dd if=/dev/zero of=/swapfile bs=1G count=2
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### High Memory Usage

```bash
# Check memory pressure
free -h
docker stats

# Identify memory hog
docker top aiia_postgresql
docker top aiia_django_prod

# Solutions:
# 1. Increase PostgreSQL work_mem
# 2. Reduce gunicorn workers
# 3. Enable memory swapping (last resort)
# 4. Upgrade server resources
```

### Database Connection Errors

```bash
# Check PgBouncer status
docker exec aiia_pgbouncer psql -U aiia -c "SHOW POOLS"

# Check actual PostgreSQL
docker exec aiia_postgresql psql -U aiia -d aiia_prod -c "SELECT count(*) FROM pg_stat_activity"

# Restart connection pooler
docker-compose restart pgbouncer
```

### Slow Queries

```bash
# Enable query logging (temporarily)
docker exec aiia_postgresql psql -U aiia -d aiia_prod -c "SET log_min_duration_statement = 1000"

# View slow queries
docker logs aiia_postgresql | grep "duration:"

# Analyze slow query
docker exec aiia_postgresql psql -U aiia -d aiia_prod
# In psql: EXPLAIN ANALYZE SELECT ...
```

### SSL Certificate Issues

```bash
# Check certificate expiration
openssl x509 -in /etc/letsencrypt/live/eduaiia.com/cert.pem -text -noout | grep -A2 "Validity"

# Manual renewal
docker exec aiia_nginx certbot renew --dry-run

# Full renewal
docker exec aiia_nginx certbot renew --force-renewal
```

## Resource Optimization

### Why This Design Works in 512MB

1. **Connection Pooling** (PgBouncer)
   - Reduces PostgreSQL connection overhead by ~90%
   - Shared across production + staging
   - Saves ~50MB vs separate instances

2. **Multi-threaded Workers**
   - Gunicorn gthread model vs multiprocessing
   - Threads share memory (lower overhead per worker)
   - 2 prod workers + 1 staging worker = ~250MB total vs 400MB+

3. **Shared Cache Layer**
   - Single Redis instance (50MB max) vs separate instances
   - Sessions + cache in same database
   - LRU eviction prevents memory exhaustion

4. **Minimal Nginx**
   - Alpine-based (50MB vs 150MB for full image)
   - Serves static files directly (no Django overhead)
   - Effective caching headers (reduces origin requests)

5. **Lean PostgreSQL Config**
   - shared_buffers: 128MB (vs typical 256MB+)
   - work_mem: 2.6MB (aggressive but sufficient)
   - Autovacuum tuned for low memory
   - Fewer concurrent connections (50 vs 300)

### Performance Targets

- **Latency:** <200ms p95 for /admin
- **Throughput:** 100 concurrent users
- **Memory:** Stable at 480MB under normal load
- **CPU:** <40% average, <80% peak
- **Error Rate:** <0.1%
- **Uptime:** 99.99%

### Capacity Planning

To scale beyond 512MB:

1. **Add more RAM** (recommended if >200 concurrent users)
   - Increase PostgreSQL shared_buffers to 256MB
   - Increase gunicorn workers to 4
   - Add Redis cluster

2. **Split services** (if >500 concurrent users)
   - Separate PostgreSQL server
   - Separate Redis server
   - Multiple Django instances behind load balancer

3. **Use CDN** (for static content)
   - Move media/static to Cloudflare/S3
   - Reduces Nginx load
   - Better geographic distribution

## Security Hardening

### SSL/TLS

- Let's Encrypt auto-renewal via Certbot
- Automatic rotation at 30 days before expiration
- TLS 1.2 + 1.3 only
- Strong cipher suites

### Application Security

- CSRF protection via Django middleware
- X-Frame-Options: SAMEORIGIN
- X-Content-Type-Options: nosniff
- Content-Security-Policy configured
- Rate limiting (200 req/s general, 500 req/s API)

### Infrastructure Security

- Non-root container users
- Read-only volumes where possible
- Network isolation (aiia_network)
- SSH key-based deployment only
- No default passwords

### Monitoring & Alerts

- Failed deployment notifications (Slack)
- Resource threshold alerts (>80% CPU, >400MB RAM)
- Error rate monitoring
- Uptime tracking

## Support & Documentation

- **Issues:** Create issue in GitHub
- **Deployments:** Monitor in GitHub Actions
- **Logs:** `docker-compose logs -f`
- **Performance:** Run `make monitor`

## License

Internal use only

## Contributing

1. Create feature branch: `git checkout -b feature/your-feature`
2. Make changes and test locally: `make test`
3. Push to staging: `git push origin staging`
4. Test on staging environment
5. Create pull request to `main`
6. After review, merge and push: `git push origin main`
7. Monitor production deployment

## Deployment Timeline

```
Commit → GitHub Actions (15 min)
  ├─ Tests (5 min)
  ├─ Build (5 min)
  ├─ Deploy (3 min)
  └─ Health checks (2 min)
  
Total: ~15 minutes end-to-end
```

---

**Last Updated:** 2024
**Status:** Production Ready
**Uptime Target:** 99.99%
**Support:** DevOps Team