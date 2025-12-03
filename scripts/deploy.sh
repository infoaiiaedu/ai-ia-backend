#!/bin/bash
# Production deployment script
# Usage: ./scripts/deploy.sh production

set -euo pipefail

ENVIRONMENT="${1:-production}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="logs/deploy_${ENVIRONMENT}_${TIMESTAMP}.log"
BACKUP_DIR="backups/db_${ENVIRONMENT}_${TIMESTAMP}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Create log directory
mkdir -p logs

log "Starting $ENVIRONMENT deployment..."

# 1. Pre-deployment validation
log "Step 1: Validating environment..."
if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "staging" ]]; then
    error "Invalid environment: $ENVIRONMENT"
fi

# Check Docker daemon
if ! docker info > /dev/null 2>&1; then
    error "Docker daemon is not running"
fi

log "Environment validation passed"

# 2. Database backup
log "Step 2: Backing up database..."
mkdir -p "$BACKUP_DIR"

if [ "$ENVIRONMENT" = "production" ]; then
    DB_NAME="aiia_prod"
    CONTAINER="aiia_postgresql"
else
    DB_NAME="aiia_staging"
    CONTAINER="aiia_postgresql"
fi

docker exec "$CONTAINER" pg_dump -U aiia -d "$DB_NAME" -F custom -f /tmp/backup.dump 2>> "$LOG_FILE" || \
    error "Database backup failed"

docker cp "$CONTAINER":/tmp/backup.dump "$BACKUP_DIR/db_backup.dump" 2>> "$LOG_FILE" || \
    error "Failed to copy backup from container"

# Clean old backups (keep only 3)
find backups/db_${ENVIRONMENT}_* -maxdepth 0 -type d -mtime +7 -exec rm -rf {} \; 2>> "$LOG_FILE" || true

log "Database backup completed: $BACKUP_DIR"

# 3. Pull latest code
log "Step 3: Pulling latest code from Git..."
git fetch origin >> "$LOG_FILE" 2>&1 || error "Git fetch failed"

if [ "$ENVIRONMENT" = "production" ]; then
    BRANCH="main"
else
    BRANCH="staging"
fi

git checkout origin/$BRANCH >> "$LOG_FILE" 2>&1 || error "Git checkout failed"
log "Latest code pulled from $BRANCH branch"

# 4. Build Docker images
log "Step 4: Building Docker images..."
if [ "$ENVIRONMENT" = "production" ]; then
    docker-compose build django_prod >> "$LOG_FILE" 2>&1 || error "Build failed"
else
    docker-compose build django_staging >> "$LOG_FILE" 2>&1 || error "Build failed"
fi

log "Docker images built successfully"

# 5. Run migrations
log "Step 5: Running database migrations..."
if [ "$ENVIRONMENT" = "production" ]; then
    docker-compose run --rm django_prod python manage.py migrate --noinput >> "$LOG_FILE" 2>&1 || \
        error "Migrations failed"
else
    docker-compose run --rm django_staging python manage.py migrate --noinput >> "$LOG_FILE" 2>&1 || \
        error "Migrations failed"
fi

log "Migrations completed"

# 6. Collect static files
log "Step 6: Collecting static files..."
if [ "$ENVIRONMENT" = "production" ]; then
    docker-compose run --rm django_prod python manage.py collectstatic --noinput --clear >> "$LOG_FILE" 2>&1 || \
        error "Static file collection failed"
else
    docker-compose run --rm django_staging python manage.py collectstatic --noinput --clear >> "$LOG_FILE" 2>&1 || \
        error "Static file collection failed"
fi

log "Static files collected"

# 7. Restart services
log "Step 7: Restarting services..."
if [ "$ENVIRONMENT" = "production" ]; then
    docker-compose up -d django_prod >> "$LOG_FILE" 2>&1 || error "Service restart failed"
else
    docker-compose up -d django_staging >> "$LOG_FILE" 2>&1 || error "Service restart failed"
fi

# 8. Health checks
log "Step 8: Running health checks..."
sleep 10

if [ "$ENVIRONMENT" = "production" ]; then
    PORT=8000
    HEALTH_URL="http://localhost:$PORT/health/"
else
    PORT=8001
    HEALTH_URL="http://localhost:$PORT/health/"
fi

for i in {1..30}; do
    if curl -sf "$HEALTH_URL" > /dev/null 2>&1; then
        log "Health check passed"
        break
    fi
    if [ $i -eq 30 ]; then
        error "Health check failed after 30 attempts"
    fi
    warn "Health check attempt $i/30, waiting..."
    sleep 2
done

# 9. Verify deployment
log "Step 9: Verifying deployment..."
docker-compose ps >> "$LOG_FILE" 2>&1

log "${GREEN}✓ Deployment completed successfully!${NC}"
log "Backup location: $BACKUP_DIR"
log "Log file: $LOG_FILE"
