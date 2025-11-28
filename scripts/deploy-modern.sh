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

# Resource limits for constrained servers
MAX_BACKUPS=2  # Keep only last 2 backups
MAX_LOG_FILES=5  # Keep only last 5 log files
MAX_LOG_SIZE_MB=10  # Max 10MB per log file

# Determine compose files and git branch based on environment
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

# Cleanup Docker resources to save space
cleanup_docker() {
    log "Cleaning up Docker resources..."
    
    # Remove stopped containers
    docker container prune -f > /dev/null 2>&1 || true
    
    # Remove unused images (keep only images in use)
    docker image prune -af > /dev/null 2>&1 || true
    
    # Remove build cache
    docker builder prune -af > /dev/null 2>&1 || true
    
    # Remove unused volumes (be careful with this)
    docker volume prune -f > /dev/null 2>&1 || true
    
    # Remove old/unused networks
    docker network prune -f > /dev/null 2>&1 || true
    
    success "Docker cleanup completed"
}

# Rotate backups - keep only the most recent ones
rotate_backups() {
    log "Rotating backups (keeping last $MAX_BACKUPS)..."
    if [ -d "$BACKUP_DIR" ]; then
        # Count backups and remove oldest if exceeding limit
        BACKUP_COUNT=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup_*" | wc -l)
        if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
            # Remove oldest backups
            find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup_*" -printf '%T@ %p\n' | \
                sort -n | head -n -$MAX_BACKUPS | cut -d' ' -f2- | xargs -r rm -rf
            success "Removed old backups (kept $MAX_BACKUPS most recent)"
        fi
    fi
}

# Rotate log files to prevent unlimited growth
rotate_logs() {
    log "Rotating log files (keeping last $MAX_LOG_FILES, max ${MAX_LOG_SIZE_MB}MB each)..."
    if [ -d "$LOG_DIR" ]; then
        # Remove logs older than 30 days
        find "$LOG_DIR" -name "*.log" -type f -mtime +30 -delete 2>/dev/null || true
        
        # Keep only the most recent log files
        LOG_COUNT=$(find "$LOG_DIR" -name "*.log" -type f | wc -l)
        if [ "$LOG_COUNT" -gt "$MAX_LOG_FILES" ]; then
            find "$LOG_DIR" -name "*.log" -type f -printf '%T@ %p\n' | \
                sort -n | head -n -$MAX_LOG_FILES | cut -d' ' -f2- | xargs -r rm -f
            success "Removed old log files (kept $MAX_LOG_FILES most recent)"
        fi
        
        # Truncate large log files
        find "$LOG_DIR" -name "*.log" -type f -size +${MAX_LOG_SIZE_MB}M -exec truncate -s ${MAX_LOG_SIZE_MB}M {} \; 2>/dev/null || true
    fi
}

# Clean up temporary files and build artifacts
cleanup_temp_files() {
    log "Cleaning up temporary files..."
    
    # Remove Python cache
    find "$PROJECT_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find "$PROJECT_DIR" -type f -name "*.pyc" -delete 2>/dev/null || true
    find "$PROJECT_DIR" -type f -name "*.pyo" -delete 2>/dev/null || true
    
    # Remove node_modules if not needed (be careful with this)
    # find "$PROJECT_DIR" -type d -name "node_modules" -not -path "*/code/apps/widgets/node_modules" -exec rm -rf {} + 2>/dev/null || true
    
    # Remove temporary git files
    find "$PROJECT_DIR" -type f -name ".gitkeep" -delete 2>/dev/null || true
    
    # Remove old deployment artifacts
    find "$PROJECT_DIR" -type d -name ".tmp_repo" -exec rm -rf {} + 2>/dev/null || true
    
    success "Temporary files cleaned up"
}

# Optimize git repository (shallow clone, clean history)
optimize_git() {
    log "Optimizing git repository..."
    cd "$PROJECT_DIR"
    
    # Convert to shallow repository if not already shallow
    if [ -d .git ] && ! git rev-parse --is-shallow-repository > /dev/null 2>&1; then
        log "Converting to shallow repository..."
        git fetch --depth=1 origin "$GIT_BRANCH" 2>/dev/null || true
    fi
    
    # Clean up git objects
    git gc --prune=now --aggressive > /dev/null 2>&1 || true
    
    success "Git repository optimized"
}

create_backup() {
    log "Creating deployment backup..."
    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_FILE"
    
    # Backup only essential configuration (not full directory)
    if [ -d "config/$ENVIRONMENT" ]; then
        # Only backup project.toml, not entire config directory
        if [ -f "config/$ENVIRONMENT/project.toml" ]; then
            mkdir -p "$BACKUP_FILE/config/$ENVIRONMENT"
            cp "config/$ENVIRONMENT/project.toml" "$BACKUP_FILE/config/$ENVIRONMENT/" 2>/dev/null || true
        fi
    fi
    
    # Backup database (compressed to save space)
    if docker compose $COMPOSE_FILES ps psql | grep -q "Up"; then
        log "Creating compressed database backup..."
        docker compose $COMPOSE_FILES exec -T psql pg_dump -U postgres ai_db | gzip > "$BACKUP_FILE/db_backup.sql.gz" 2>/dev/null || warn "Database backup failed"
    fi
    
    success "Backup created: $BACKUP_FILE"
    
    # Rotate backups after creating new one
    rotate_backups
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
    
    # Ensure we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        fail "Not in a git repository"
    fi
    
    # Use shallow fetch to save space
    if git rev-parse --is-shallow-repository > /dev/null 2>&1; then
        git fetch --depth=1 origin "$GIT_BRANCH" || fail "Failed to fetch from origin"
    else
        git fetch origin "$GIT_BRANCH" || fail "Failed to fetch from origin"
    fi
    
    # Checkout branch (create tracking branch if it doesn't exist locally)
    if git show-ref --verify --quiet refs/heads/"$GIT_BRANCH"; then
        git checkout "$GIT_BRANCH" || fail "Failed to checkout branch"
    else
        # Branch doesn't exist locally, create it tracking the remote
        git checkout -b "$GIT_BRANCH" "origin/$GIT_BRANCH" || fail "Failed to create and checkout branch"
    fi
    
    # Reset to match remote exactly
    git reset --hard "origin/$GIT_BRANCH" || fail "Failed to reset to origin/$GIT_BRANCH"
    
    CURRENT_COMMIT=$(git rev-parse --short HEAD)
    success "Repository updated (commit: $CURRENT_COMMIT)"
}

deploy_services() {
    log "Deploying services..."
    
    # Stop existing services
    log "Stopping existing services..."
    docker compose $COMPOSE_FILES down --remove-orphans || warn "Some services may not have stopped cleanly"
    
    # Clean up Docker before building to free space
    cleanup_docker
    
    # Build images (use cache when possible to save time, but clean up after)
    log "Building Docker images..."
    # Try with cache first, but if it fails, build without cache
    if ! docker compose $COMPOSE_FILES build 2>&1 | tee -a "$LOG_FILE"; then
        log "Build with cache failed, trying without cache..."
        docker compose $COMPOSE_FILES build --no-cache || fail "Failed to build images"
    fi
    success "Images built successfully"
    
    # Clean up build cache after building
    docker builder prune -af > /dev/null 2>&1 || true
    
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

# Rotate logs before starting
rotate_logs

log "Deployment started for environment: $ENVIRONMENT"
log "Project directory: $PROJECT_DIR"
log "Target branch: $GIT_BRANCH"

cd "$PROJECT_DIR"

# Verify prerequisites
verify_prerequisites

# Cleanup before deployment to free up space
log "Running pre-deployment cleanup..."
cleanup_temp_files
cleanup_docker

# Create backup (with rotation)
create_backup

# Update repository (optimized)
update_repository

# Optimize git after update
optimize_git

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

# Final cleanup after successful deployment
log "Running post-deployment cleanup..."
cleanup_docker
cleanup_temp_files

# Final summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Deployment completed successfully!  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
log "Deployment finished successfully"
log "Logs saved to: $LOG_FILE"
log "Backup saved to: $BACKUP_DIR"

# Show disk usage
log "Current disk usage:"
df -h "$PROJECT_DIR" | tail -1 | awk '{print "  Used: " $3 " / " $2 " (" $5 " used)"}'

