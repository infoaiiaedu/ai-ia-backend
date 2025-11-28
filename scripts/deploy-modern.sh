#!/bin/bash

# Modernized Deployment Script
# Supports environment-specific deployments with proper error handling and rollback

set -e

# ============================
# Configuration
# ============================
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="${PROJECT_DIR}/logs"
LOG_FILE="${LOG_DIR}/deployment_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="${PROJECT_DIR}/.backups"
ENVIRONMENT="${ENVIRONMENT:-production}"
GIT_BRANCH="${GIT_BRANCH:-main}"

# Determine compose files based on environment
case $ENVIRONMENT in
    dev|development)
        COMPOSE_FILES="-f docker-compose.base.yml -f docker-compose.dev.yml"
        GIT_BRANCH="${GIT_BRANCH:-develop}"
        ;;
    staging)
        COMPOSE_FILES="-f docker-compose.base.yml -f docker-compose.staging.yml"
        GIT_BRANCH="${GIT_BRANCH:-staging}"
        ;;
    prod|production)
        COMPOSE_FILES="-f docker-compose.base.yml -f docker-compose.prod.yml"
        GIT_BRANCH="${GIT_BRANCH:-main}"
        ;;
    *)
        echo "Unknown environment: $ENVIRONMENT"
        echo "Usage: ENVIRONMENT={dev|staging|prod} $0"
        exit 1
        ;;
esac

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}✗${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1" | tee -a "$LOG_FILE"
}

fail() {
    error "$1"
    log "Deployment failed. Check logs: $LOG_FILE"
    exit 1
}

# ============================
# Functions
# ============================

create_backup() {
    log "Creating deployment backup..."
    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_FILE"
    
    # Backup configuration
    if [ -d "config/$ENVIRONMENT" ]; then
        cp -r "config/$ENVIRONMENT" "$BACKUP_FILE/config" 2>/dev/null || true
    fi
    
    # Backup database
    if docker compose $COMPOSE_FILES ps psql | grep -q "Up"; then
        log "Creating database backup..."
        docker compose $COMPOSE_FILES exec -T psql pg_dump -U postgres ai_db > "$BACKUP_FILE/db_backup.sql" 2>/dev/null || warn "Database backup failed"
    fi
    
    success "Backup created: $BACKUP_FILE"
}

verify_prerequisites() {
    log "Verifying prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        fail "Docker is not installed"
    fi
    success "Docker found"
    
    if ! docker compose version &> /dev/null; then
        fail "Docker Compose is not installed"
    fi
    success "Docker Compose found"
    
    if ! command -v git &> /dev/null; then
        fail "Git is not installed"
    fi
    success "Git found"
}

update_repository() {
    log "Updating repository (branch: $GIT_BRANCH)..."
    
    cd "$PROJECT_DIR"
    
    # Fetch latest
    git fetch origin "$GIT_BRANCH" || fail "Failed to fetch from origin"
    
    # Checkout branch
    git checkout "$GIT_BRANCH" || fail "Failed to checkout branch"
    
    # Pull latest
    git pull origin "$GIT_BRANCH" || fail "Failed to pull latest changes"
    
    CURRENT_COMMIT=$(git rev-parse --short HEAD)
    success "Repository updated (commit: $CURRENT_COMMIT)"
}

deploy_services() {
    log "Deploying services..."
    
    # Stop existing services
    log "Stopping existing services..."
    docker compose $COMPOSE_FILES down --remove-orphans || warn "Some services may not have stopped cleanly"
    
    # Build images
    log "Building Docker images..."
    docker compose $COMPOSE_FILES build --no-cache || fail "Failed to build images"
    success "Images built successfully"
    
    # Start services
    log "Starting services..."
    docker compose $COMPOSE_FILES up -d || fail "Failed to start services"
    success "Services started"
    
    # Wait for services to be ready
    log "Waiting for services to be ready..."
    sleep 15
    
    # Verify services
    log "Verifying services..."
    for service in app psql redis nginx; do
        if docker compose $COMPOSE_FILES ps "$service" | grep -q "Up"; then
            success "$service is running"
        else
            error "$service is not running"
            HEALTH_CHECK_FAILED=true
        fi
    done
}

run_migrations() {
    log "Running database migrations..."
    
    MAX_ATTEMPTS=5
    ATTEMPT=0
    
    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        if docker compose $COMPOSE_FILES exec -T app python manage.py migrate --noinput 2>&1 | tee -a "$LOG_FILE"; then
            success "Migrations applied successfully"
            return 0
        fi
        
        ATTEMPT=$((ATTEMPT + 1))
        if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
            warn "Migration attempt $ATTEMPT/$MAX_ATTEMPTS failed, retrying..."
            sleep 5
        fi
    done
    
    fail "Failed to apply migrations after $MAX_ATTEMPTS attempts"
}

collect_static() {
    log "Collecting static files..."
    if docker compose $COMPOSE_FILES exec -T app python manage.py collectstatic --noinput --no-post-process 2>&1 | tee -a "$LOG_FILE"; then
        success "Static files collected"
    else
        warn "Static file collection had issues (may be normal)"
    fi
}

# ============================
# Main Deployment
# ============================

echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║   AI-IA Backend Modern Deployment      ║${NC}"
echo -e "${YELLOW}║   Environment: $ENVIRONMENT$(printf '%*s' $((25-${#ENVIRONMENT})) '')║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
echo ""

# Create logs directory
mkdir -p "$LOG_DIR"
log "Deployment started for environment: $ENVIRONMENT"
log "Project directory: $PROJECT_DIR"
log "Target branch: $GIT_BRANCH"

cd "$PROJECT_DIR"

# Verify prerequisites
verify_prerequisites

# Create backup
create_backup

# Update repository
update_repository

# Deploy services
deploy_services

# Run migrations
run_migrations

# Collect static files
collect_static

# Run health checks
log "Running health checks..."
if bash scripts/health-check.sh --environment "$ENVIRONMENT"; then
    success "Health checks passed"
else
    error "Health checks failed"
    warn "Consider rolling back: bash scripts/rollback.sh --environment $ENVIRONMENT"
    exit 1
fi

# Final summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Deployment completed successfully!  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
log "Deployment finished successfully"
log "Logs saved to: $LOG_FILE"
log "Backup saved to: $BACKUP_DIR"

