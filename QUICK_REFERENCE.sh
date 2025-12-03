#!/usr/bin/env bash
# AI-IA Backend Quick Reference Card
# Print this for your desk: chmod +x and run directly

cat << 'EOF'

╔══════════════════════════════════════════════════════════════════════════════╗
║                      AI-IA BACKEND QUICK REFERENCE                          ║
║                                                                              ║
║  Production-Ready Django Deployment | 512MB RAM | 2 vCPU | 99.99% Uptime   ║
╚══════════════════════════════════════════════════════════════════════════════╝

┌─ LOCAL DEVELOPMENT ─────────────────────────────────────────────────────────┐
│                                                                              │
│  make help              Show all available commands                         │
│  make setup             Initial setup (copy .env files)                     │
│  make dev               Start development environment                       │
│  make dev-down          Stop development environment                        │
│  make migrate           Run database migrations                             │
│  make superuser         Create admin user                                   │
│  make test              Run test suite                                      │
│  make dev-shell         Django interactive shell                            │
│                                                                              │
│  URLs:                                                                       │
│    Django:    http://localhost:8000                                         │
│    Admin:     http://localhost:8000/admin                                   │
│    Nginx:     http://localhost                                              │
│                                                                              │
└────────────────────────────────────────────────────────────────────────────┘

┌─ PRODUCTION DEPLOYMENT ────────────────────────────────────────────────────┐
│                                                                              │
│  Automatic (via GitHub):                                                   │
│    git commit -m "your message"                                             │
│    git push origin main              # Triggers production deployment       │
│    git push origin staging           # Triggers staging deployment         │
│                                                                              │
│  Manual:                                                                     │
│    ssh ubuntu@server.ip                                                     │
│    cd /home/ubuntu/main/ai-ia-backend                                       │
│    bash scripts/deploy.sh production                                        │
│                                                                              │
│  Monitor:                                                                    │
│    GitHub: https://github.com/infoaiiaedu/ai-ia-backend/actions            │
│    Server: make healthcheck                                                 │
│                                                                              │
└────────────────────────────────────────────────────────────────────────────┘

┌─ MONITORING & HEALTH ──────────────────────────────────────────────────────┐
│                                                                              │
│  Quick Status:                                                               │
│    make healthcheck     Check if all services are healthy                   │
│    make monitor         Comprehensive system health report                  │
│    make ps              Show running containers                             │
│                                                                              │
│  View Logs:                                                                  │
│    docker-compose logs django_prod                                          │
│    docker-compose logs postgresql                                           │
│    docker-compose logs nginx -f                                             │
│                                                                              │
│  Resource Usage:                                                             │
│    docker stats                     Real-time container stats               │
│    free -h                          System memory                           │
│    df -h                            Disk usage                              │
│                                                                              │
└────────────────────────────────────────────────────────────────────────────┘

┌─ DATABASE OPERATIONS ──────────────────────────────────────────────────────┐
│                                                                              │
│  Backups:                                                                    │
│    make db-backup               Backup production database                  │
│    make db-backup-staging       Backup staging database                     │
│    ls backups/                  List all backups                            │
│                                                                              │
│  Restore:                                                                    │
│    make db-restore BACKUP_PATH=backups/db_prod_*/database.dump              │
│                                                                              │
│  Manual Database Access:                                                    │
│    docker exec aiia_postgresql psql -U aiia -d aiia_prod                    │
│                                                                              │
│  Check Connections:                                                         │
│    docker exec aiia_pgbouncer psql -U aiia -c "SHOW POOLS"                 │
│                                                                              │
└────────────────────────────────────────────────────────────────────────────┘

┌─ TROUBLESHOOTING ──────────────────────────────────────────────────────────┐
│                                                                              │
│  Container Won't Start:                                                     │
│    1. docker-compose logs <service>    # Check error message               │
│    2. docker-compose down              # Stop all                          │
│    3. docker-compose up -d             # Restart                           │
│                                                                              │
│  High Memory Usage:                                                          │
│    1. docker stats                     # Find memory hog                   │
│    2. make monitor                     # Detailed report                   │
│    3. docker-compose restart           # Restart services                  │
│                                                                              │
│  Database Connection Errors:                                                 │
│    1. docker-compose restart pgbouncer # Restart connection pool           │
│    2. docker logs aiia_pgbouncer       # Check logs                       │
│    3. docker exec aiia_postgresql pg_isready # Test connection             │
│                                                                              │
│  Slow Application:                                                           │
│    1. docker stats                     # Check if maxed out                │
│    2. make monitor                     # System metrics                    │
│    3. docker logs aiia_django_prod     # Check for errors                 │
│                                                                              │
│  SSL Certificate Issues:                                                     │
│    1. openssl x509 -in /etc/letsencrypt/live/.../cert.pem -text             │
│    2. docker exec aiia_nginx certbot renew --dry-run                        │
│    3. docker exec aiia_nginx certbot renew --force-renewal                  │
│                                                                              │
└────────────────────────────────────────────────────────────────────────────┘

┌─ ENVIRONMENT VARIABLES ────────────────────────────────────────────────────┐
│                                                                              │
│  .env File Locations:                                                       │
│    Production:  .env                                                        │
│    Staging:     .env (same file, different values)                          │
│    Development: config/dev.env                                              │
│                                                                              │
│  Critical Variables:                                                        │
│    SECRET_KEY               Django secret key (generate with secrets)      │
│    DB_PASSWORD              Database password (strong!)                     │
│    ALLOWED_HOSTS            Comma-separated domain list                    │
│    DEBUG                    Set to false in production                      │
│    ENVIRONMENT              production|staging|development                 │
│                                                                              │
│  Generate Secure Values:                                                    │
│    python -c "import secrets; print(secrets.token_urlsafe(50))"            │
│    openssl rand -base64 32                                                  │
│                                                                              │
└────────────────────────────────────────────────────────────────────────────┘

┌─ RESOURCE LIMITS ──────────────────────────────────────────────────────────┐
│                                                                              │
│  Memory Budget (512MB Total):                                               │
│    PostgreSQL:     200MB limit (150MB reserved)                             │
│    Django Prod:    150MB limit (120MB reserved)                             │
│    Django Staging: 100MB limit (80MB reserved)                              │
│    Redis:          50MB limit (40MB reserved)                               │
│    Nginx:          50MB limit (40MB reserved)                               │
│    PgBouncer:      30MB limit (20MB reserved)                               │
│    System:         ~62MB reserve                                            │
│                                                                              │
│  Performance Targets:                                                       │
│    Latency:       <200ms p95 for /admin                                     │
│    Throughput:    100 concurrent users                                      │
│    Error Rate:    <0.1%                                                     │
│    Uptime:        99.99%                                                    │
│    CPU Avg:       <40%                                                      │
│                                                                              │
└────────────────────────────────────────────────────────────────────────────┘

┌─ DOMAINS & PORTS ──────────────────────────────────────────────────────────┐
│                                                                              │
│  Production:                                                                │
│    Main:        https://eduaiia.com                                        │
│    WWW:         https://www.eduaiia.com                                    │
│    Redirect:    http://eduaiia.com → https://                              │
│                                                                              │
│  Staging:                                                                   │
│    Main:        https://staging.eduaiia.com                                │
│                                                                              │
│  Monitoring:                                                                │
│    Dashboard:   https://devstatus.eduaiia.com                              │
│    Local:       http://localhost (development only)                        │
│                                                                              │
│  Internal Ports (localhost only):                                           │
│    8000         Django Production                                           │
│    8001         Django Staging                                              │
│    5432         PostgreSQL                                                  │
│    6432         PgBouncer                                                   │
│    6379         Redis                                                       │
│                                                                              │
└────────────────────────────────────────────────────────────────────────────┘

┌─ EMERGENCY PROCEDURES ─────────────────────────────────────────────────────┐
│                                                                              │
│  Emergency Stop (if under attack):                                          │
│    1. ssh ubuntu@server.ip                                                  │
│    2. docker-compose down                                                   │
│    3. sudo systemctl stop docker                                            │
│    4. sudo iptables -I INPUT -p tcp --dport 80 -j DROP                     │
│    5. sudo iptables -I INPUT -p tcp --dport 443 -j DROP                    │
│                                                                              │
│  Emergency Rollback:                                                        │
│    1. git log --oneline                                                     │
│    2. git reset --hard <commit-hash>                                        │
│    3. git push origin main --force                                          │
│    4. Wait for GitHub Actions deployment                                    │
│                                                                              │
│  Database Corruption Recovery:                                              │
│    1. docker-compose down                                                   │
│    2. BACKUP_FILE=$(ls -t backups/db_prod_*/database.dump | head -1)        │
│    3. docker exec aiia_postgresql pg_restore -d aiia_prod -F custom $BF    │
│    4. docker-compose up -d                                                  │
│    5. make healthcheck                                                      │
│                                                                              │
│  Add Swap (if memory critical):                                             │
│    1. sudo swapoff -a                                                       │
│    2. sudo dd if=/dev/zero of=/swapfile bs=1G count=2                      │
│    3. sudo chmod 600 /swapfile                                              │
│    4. sudo mkswap /swapfile                                                 │
│    5. sudo swapon /swapfile                                                 │
│    6. echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab           │
│                                                                              │
└────────────────────────────────────────────────────────────────────────────┘

┌─ DOCUMENTATION ────────────────────────────────────────────────────────────┐
│                                                                              │
│  README.md              Quick start & general guide                         │
│  ARCHITECTURE.md        Technical architecture details                      │
│  DEPLOYMENT.md          Secrets management & procedures                     │
│  IMPLEMENTATION_SUMMARY.md  Implementation details & decisions              │
│  Makefile               Development commands reference                      │
│  .github/workflows/     CI/CD pipeline definitions                          │
│                                                                              │
│  Online:                                                                     │
│    GitHub:   https://github.com/infoaiiaedu/ai-ia-backend                  │
│    Actions:  https://github.com/infoaiiaedu/ai-ia-backend/actions          │
│                                                                              │
└────────────────────────────────────────────────────────────────────────────┘

┌─ SUPPORT & CONTACT ────────────────────────────────────────────────────────┐
│                                                                              │
│  Issues:                                                                     │
│    1. Check README troubleshooting section                                  │
│    2. Run: make monitor                                                     │
│    3. Check logs: docker-compose logs                                       │
│    4. Search GitHub issues                                                  │
│                                                                              │
│  Questions:                                                                  │
│    - Create GitHub issue or discussion                                      │
│    - Contact DevOps team                                                    │
│    - Review documentation files                                             │
│                                                                              │
│  Security Issues:                                                            │
│    - Do NOT create public issue                                             │
│    - Contact security team immediately                                      │
│                                                                              │
└────────────────────────────────────────────────────────────────────────────┘

╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║  Last Updated: 2024                                                          ║
║  Status: Production Ready                                                    ║
║  Uptime Target: 99.99%                                                       ║
║  Memory: 512MB (Fully Optimized)                                             ║
║  CPU: 2 vCPU (Efficient Allocation)                                          ║
║                                                                              ║
║  Remember: "Every byte counts in a 512MB system"                            ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

EOF
