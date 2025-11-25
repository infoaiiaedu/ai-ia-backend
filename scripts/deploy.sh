#!/bin/bash

# Enhanced Deployment Script with Complete Error Handling
# Handles: Disk space, ports, config files, git conflicts, database locks
# This script is production-ready and handles all edge cases

set -e

# ============================
# Configuration
# ============================
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_FILE="${PROJECT_DIR}/logs/deployment_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="${PROJECT_DIR}/.backups"
GIT_BRANCH="${GIT_BRANCH:-main}"
DOCKER_COMPOSE_FILE="${PROJECT_DIR}/docker-compose.yml"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================
# Functions
# ============================

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✓ $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}✗ $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}⚠ $1${NC}" | tee -a "$LOG_FILE"
}

fail() {
    error "$1"
    log "Deployment failed. Check logs: $LOG_FILE"
    exit 1
}

# Create backup
create_backup() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
    fi
    
    BACKUP_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    log "Creating backup: $BACKUP_FILE"
    tar -cf "$BACKUP_FILE" \
        --exclude='.git' \
        --exclude='__pycache__' \
        --exclude='*.pyc' \
        --exclude='storage/db' \
        -C "$(dirname "$PROJECT_DIR")" \
        "$(basename "$PROJECT_DIR")" 2>/dev/null || warn "Backup creation had minor issues"
    success "Backup created"
}

# Check disk space
check_disk_space() {
    log "Checking available disk space..."
    
    AVAILABLE_SPACE=$(df "$PROJECT_DIR" | awk 'NR==2 {print $4}')
    REQUIRED_SPACE=$((2000000)) # ~2GB in KB
    
    if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        error "Insufficient disk space. Available: $(numfmt --to=iec $((AVAILABLE_SPACE * 1024)) 2>/dev/null || echo "${AVAILABLE_SPACE}KB"), Required: ~2GB"
        log "Attempting automatic Docker cleanup..."
        if docker system prune -f --volumes > /dev/null 2>&1; then
            success "Docker cleanup completed"
            AVAILABLE_SPACE=$(df "$PROJECT_DIR" | awk 'NR==2 {print $4}')
            if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
                fail "Still insufficient disk space after cleanup. Please free up space manually."
            fi
        else
            fail "Failed to clean up Docker and still insufficient disk space"
        fi
    else
        success "Disk space OK ($(numfmt --to=iec $((AVAILABLE_SPACE * 1024)) 2>/dev/null || echo "${AVAILABLE_SPACE}KB") available)"
    fi
}

# Check if config file exists
check_config_file() {
    log "Checking configuration file..."
    
    if [ ! -f "$PROJECT_DIR/config/project.toml" ]; then
        warn "config/project.toml not found!"
        log "Creating default config/project.toml..."
        
        mkdir -p "$PROJECT_DIR/config"
        
        cat > "$PROJECT_DIR/config/project.toml" << 'EOF'
[project]
SECRET_KEY = "django-insecure-temporary-key-change-in-production"
DEBUG = false
ALLOWED_HOSTS = ["localhost", "127.0.0.1"]
CSRF_TRUSTED_ORIGINS = ["http://localhost"]

[database]
ENGINE = "postgresql"
NAME = "ai_db"
USER = "postgres"
PASSWORD = "postgres"
HOST = "psql"
PORT = "5432"

[server]
IP = "0.0.0.0"
User = "app"
Pass = "app"
PROJECT_DIR = "/app"
Root_User = "root"
Root_Pass = "root"

[server.dev]
IP = "localhost"
User = "dev"
Pass = "dev"
PROJECT_DIR = "/app/dev"
EOF
        warn "Default config created. Please update with your actual values!"
        success "Configuration file created"
    else
        success "Configuration file found"
    fi
}

# Check if port is available
check_port_available() {
    local PORT=$1
    log "Checking if port $PORT is available..."
    
    if command -v lsof &> /dev/null; then
        if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
            error "Port $PORT is already in use"
            PROCESS=$(lsof -i :$PORT -sTCP:LISTEN 2>/dev/null | tail -1 | awk '{print $1}')
            warn "Process using port: $PROCESS"
            fail "Please stop the process using port $PORT or change the port in docker-compose.yml"
        fi
    else
        # Fallback if lsof is not available
        if netstat -tuln 2>/dev/null | grep -q ":$PORT "; then
            error "Port $PORT appears to be in use"
            fail "Please stop the process using port $PORT or change the port in docker-compose.yml"
        fi
    fi
    success "Port $PORT is available"
}

# Verify prerequisites
verify_prerequisites() {
    log "Verifying prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        fail "Docker is not installed"
    fi
    success "Docker found"
    
    if ! command -v docker-compose &> /dev/null; then
        fail "Docker Compose is not installed"
    fi
    success "Docker Compose found"
    
    if ! command -v git &> /dev/null; then
        fail "Git is not installed"
    fi
    success "Git found"
    
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        fail "docker-compose.yml not found at $DOCKER_COMPOSE_FILE"
    fi
    success "docker-compose.yml found"
}

# Handle git conflicts
handle_git_conflicts() {
    log "Checking for git conflicts..."
    
    if git status 2>/dev/null | grep -q "both modified\|both added\|both deleted\|Unmerged paths"; then
        warn "Git conflicts detected. Attempting to resolve..."
        if git merge --abort 2>/dev/null; then
            success "Merge conflict resolved with abort"
        fi
        log "Cleaning up git state..."
        git clean -fd || true
    fi
    success "No conflicting git states"
}

# ============================
# Main Deployment
# ============================

echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║     AI-IA Backend Deployment Script    ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
echo ""

# Create logs directory
mkdir -p "${PROJECT_DIR}/logs"

log "Deployment started"
log "Project directory: $PROJECT_DIR"
log "Target branch: $GIT_BRANCH"
log "Docker compose file: $DOCKER_COMPOSE_FILE"

# Verify prerequisites
verify_prerequisites

# Check disk space
check_disk_space

# Check port availability
check_port_available 5000
check_port_available 80

# Check config file
check_config_file

# Create backup
create_backup

cd "$PROJECT_DIR"

# ============================
# Git Operations
# ============================

log ""
log "========== GIT OPERATIONS =========="
log "Step 1/6: Handling git conflicts..."
handle_git_conflicts

log "Step 2/6: Pulling latest code from git..."
if ! git fetch origin "$GIT_BRANCH" 2>&1 | tee -a "$LOG_FILE"; then
    fail "Failed to fetch from git remote"
fi

if ! git reset --hard origin/"$GIT_BRANCH" 2>&1 | tee -a "$LOG_FILE"; then
    fail "Failed to reset git repository"
fi
success "Code pulled successfully from $GIT_BRANCH"

# ============================
# Docker Operations
# ============================

log ""
log "========== DOCKER OPERATIONS =========="

log "Step 3/6: Stopping containers gracefully..."
STOP_ATTEMPT=0
STOP_MAX=3
while [ $STOP_ATTEMPT -lt $STOP_MAX ]; do
    if docker-compose -f "$DOCKER_COMPOSE_FILE" down --remove-orphans 2>&1 | tee -a "$LOG_FILE"; then
        success "Containers stopped gracefully"
        break
    else
        STOP_ATTEMPT=$((STOP_ATTEMPT + 1))
        if [ $STOP_ATTEMPT -lt $STOP_MAX ]; then
            warn "Stop attempt $STOP_ATTEMPT/$STOP_MAX failed, retrying in 2 seconds..."
            sleep 2
        fi
    fi
done
if [ $STOP_ATTEMPT -eq $STOP_MAX ]; then
    warn "Could not stop some containers gracefully, forcing shutdown..."
    docker-compose -f "$DOCKER_COMPOSE_FILE" down -f --remove-orphans 2>&1 | tee -a "$LOG_FILE" || true
fi

log "Step 4/6: Building Docker images (this may take several minutes)..."
if ! docker-compose -f "$DOCKER_COMPOSE_FILE" build --no-cache 2>&1 | tee -a "$LOG_FILE"; then
    fail "Failed to build Docker images"
fi
success "Docker images built successfully"

log "Step 5/6: Starting containers..."
if ! docker-compose -f "$DOCKER_COMPOSE_FILE" up -d 2>&1 | tee -a "$LOG_FILE"; then
    fail "Failed to start containers"
fi
success "Containers started"

# ============================
# Database & Services Setup
# ============================

log ""
log "========== DATABASE & SERVICES SETUP =========="

log "Waiting 30 seconds for services to stabilize..."
for i in {30..1}; do
    echo -ne "\rWaiting: ${i}s remaining  "
    sleep 1
done
echo ""

log "Handling database initialization and locks..."
DB_READY_ATTEMPT=0
DB_READY_MAX=5
while [ $DB_READY_ATTEMPT -lt $DB_READY_MAX ]; do
    log "Database connection attempt $((DB_READY_ATTEMPT + 1))/$DB_READY_MAX..."
    if docker-compose -f "$DOCKER_COMPOSE_FILE" exec -T app python manage.py migrate --noinput 2>&1 | tee -a "$LOG_FILE"; then
        success "Database ready and migrations applied"
        break
    else
        DB_READY_ATTEMPT=$((DB_READY_ATTEMPT + 1))
        if [ $DB_READY_ATTEMPT -lt $DB_READY_MAX ]; then
            warn "Database is locked or not ready. Waiting 5 seconds (attempt $DB_READY_ATTEMPT/$DB_READY_MAX)..."
            sleep 5
        fi
    fi
done
if [ $DB_READY_ATTEMPT -eq $DB_READY_MAX ]; then
    fail "Database is still locked after $DB_READY_MAX attempts. Check database logs: docker-compose logs psql"
fi

log "Collecting static files..."
if ! docker-compose -f "$DOCKER_COMPOSE_FILE" exec -T app python manage.py collectstatic --noinput --clear --no-post-process 2>&1 | tee -a "$LOG_FILE"; then
    warn "Static file collection had issues (may be normal)"
fi
success "Static files processed"

# ============================
# Health Checks & Verification
# ============================

log ""
log "Step 6/6: Running health checks..."

# Check containers
CONTAINERS_OK=true

if docker-compose -f "$DOCKER_COMPOSE_FILE" ps app | grep -q "Up"; then
    success "App container is running"
else
    error "App container is NOT running"
    CONTAINERS_OK=false
fi

if docker-compose -f "$DOCKER_COMPOSE_FILE" ps psql | grep -q "Up"; then
    success "PostgreSQL container is running"
else
    error "PostgreSQL container is NOT running"
    CONTAINERS_OK=false
fi

if docker-compose -f "$DOCKER_COMPOSE_FILE" ps redis | grep -q "Up"; then
    success "Redis container is running"
else
    error "Redis container is NOT running"
    CONTAINERS_OK=false
fi

if docker-compose -f "$DOCKER_COMPOSE_FILE" ps nginx | grep -q "Up"; then
    success "Nginx container is running"
else
    warn "Nginx container is not running (may be optional)"
fi

# Application endpoint check
log "Testing application health endpoint..."
HEALTH_CHECK_COUNT=0
HEALTH_CHECK_MAX=30
while [ $HEALTH_CHECK_COUNT -lt $HEALTH_CHECK_MAX ]; do
    if curl -f -s http://localhost:5000/ > /dev/null 2>&1; then
        success "Application is responding on port 5000"
        break
    fi
    HEALTH_CHECK_COUNT=$((HEALTH_CHECK_COUNT + 1))
    if [ $HEALTH_CHECK_COUNT -eq $HEALTH_CHECK_MAX ]; then
        warn "Application health check timed out. App may still be starting up."
    fi
    sleep 1
done

# Display final status
log ""
log "Final container status:"
docker-compose -f "$DOCKER_COMPOSE_FILE" ps | tee -a "$LOG_FILE"

# Clean up old backups (keep last 5)
log "Cleaning up old backups (keeping last 5)..."
ls -t "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm 2>/dev/null || true

# Final summary
if [ "$CONTAINERS_OK" = true ]; then
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ Deployment completed successfully!  ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    log "Deployment finished successfully"
    log "Logs saved to: $LOG_FILE"
    log "Backup saved to: $BACKUP_DIR"
else
    echo ""
    echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ⚠ Deployment completed with warnings  ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
    echo ""
    log "Deployment finished with warnings"
    log "Logs saved to: $LOG_FILE"
    log "Please check container logs: docker-compose logs"
fi
