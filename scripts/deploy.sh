#!/bin/bash

# Enhanced Deployment Script with Complete Error Handling
# Handles: Disk space, ports, config files, git conflicts, database locks
# This script is production-ready and handles all edge cases

set -e

# ============================
# Configuration
# ============================
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="${PROJECT_DIR}/logs"
LOG_FILE="${LOG_DIR}/deployment_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="${PROJECT_DIR}/.backups"
GIT_BRANCH="${GIT_BRANCH:-main}"
GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/infoaiiaedu/ai-ia-backend.git}"
DOCKER_COMPOSE_FILE="${PROJECT_DIR}/docker-compose.yml"
MAX_LOGS="${MAX_DEPLOY_LOGS:-10}"
MAX_BACKUPS="${MAX_DEPLOY_BACKUPS:-3}"
MIN_FREE_SPACE_KB="${MIN_FREE_SPACE_KB:-1048576}" # ~1GB default floor
DISABLE_DEPLOY_BACKUP="${DISABLE_DEPLOY_BACKUP:-0}"

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

# Rotate and limit logs
rotate_logs() {
    if [ -d "$LOG_DIR" ] && compgen -G "$LOG_DIR/deployment_*.log" > /dev/null; then
        ls -1t "$LOG_DIR"/deployment_*.log | tail -n +$((MAX_LOGS + 1)) | xargs -r rm -- 2>/dev/null || true
    fi
}

# Rotate and limit backups
rotate_backups() {
    if [ -d "$BACKUP_DIR" ] && compgen -G "$BACKUP_DIR/backup_*.tar.gz" > /dev/null; then
        ls -1t "$BACKUP_DIR"/backup_*.tar.gz | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm -- 2>/dev/null || true
    fi
}

# Create lightweight backup (config + infra only)
create_backup() {
    if [ "$DISABLE_DEPLOY_BACKUP" = "1" ] || [ "$DISABLE_DEPLOY_BACKUP" = "true" ]; then
        warn "Backups disabled via DISABLE_DEPLOY_BACKUP; skipping snapshot."
        rotate_backups
        return
    fi

    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    log "Creating lightweight backup: $BACKUP_FILE"
    if tar -czf "$BACKUP_FILE" --ignore-failed-read \
        -C "$PROJECT_DIR" \
        config/project.toml \
        docker-compose.yml \
        Dockerfile \
        docker \
        scripts/deploy.sh; then
        success "Backup created"
    else
        warn "Backup creation encountered issues (continuing)"
    fi
    rotate_backups
}

# Check disk space
check_disk_space() {
    log "Checking available disk space..."
    
    AVAILABLE_SPACE=$(df "$PROJECT_DIR" | awk 'NR==2 {print $4}')
    
    if [ "$AVAILABLE_SPACE" -lt "$MIN_FREE_SPACE_KB" ]; then
        error "Insufficient disk space. Available: $(numfmt --to=iec $((AVAILABLE_SPACE * 1024)) 2>/dev/null || echo "${AVAILABLE_SPACE}KB"), Required: $(numfmt --to=iec $((MIN_FREE_SPACE_KB * 1024)) 2>/dev/null || echo "${MIN_FREE_SPACE_KB}KB")"
        log "Attempting automatic Docker cleanup..."
        if docker system prune -f --volumes > /dev/null 2>&1; then
            success "Docker cleanup completed"
            AVAILABLE_SPACE=$(df "$PROJECT_DIR" | awk 'NR==2 {print $4}')
            if [ "$AVAILABLE_SPACE" -lt "$MIN_FREE_SPACE_KB" ]; then
                fail "Still insufficient disk space after cleanup. Please free up space manually."
            fi
        else
            fail "Failed to clean up Docker and still insufficient disk space"
        fi
    else
        success "Disk space OK ($(numfmt --to=iec $((AVAILABLE_SPACE * 1024)) 2>/dev/null || echo "${AVAILABLE_SPACE}KB") available)"
    fi
}

# Proactive Docker cleanup
docker_garbage_collect() {
    log "Running proactive Docker cleanup..."
    if docker system prune -af --volumes > /dev/null 2>&1; then
        success "Docker cache cleared"
    else
        warn "Docker cleanup failed (continuing)"
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
    
    if ! docker compose version &> /dev/null; then
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

# Ensure git repository exists
ensure_git_repo() {
    log "Checking if git repository exists..."
    
    cd "$PROJECT_DIR"
    
    if [ ! -d ".git" ]; then
        warn "Git repository not found. Initializing/cloning repository..."
        
        # Check if essential files exist (if they do, we'll try to init git; if not, we'll clone)
        local needs_clone=false
        if [ ! -f "docker-compose.yml" ] && [ ! -f "Dockerfile" ] && [ ! -d "code" ] && [ ! -d "scripts" ]; then
            needs_clone=true
        fi
        
        if [ "$needs_clone" = true ]; then
            log "Directory appears empty or incomplete. Cloning repository..."
            
            # Backup existing directories that should be preserved
            local backup_dir=$(mktemp -d)
            for dir in config storage docker; do
                if [ -d "$dir" ]; then
                    log "Backing up existing $dir directory..."
                    mv "$dir" "$backup_dir/" 2>/dev/null || true
                fi
            done
            
            # Clone to a temporary location first
            local temp_clone=$(mktemp -d)
            log "Cloning repository from $GIT_REPO_URL..."
            if ! git clone -b "$GIT_BRANCH" --single-branch --depth 1 "$GIT_REPO_URL" "$temp_clone" 2>&1 | tee -a "$LOG_FILE"; then
                # Restore backups on failure
                if [ -d "$backup_dir" ]; then
                    mv "$backup_dir"/* "$PROJECT_DIR/" 2>/dev/null || true
                fi
                fail "Failed to clone repository from $GIT_REPO_URL"
            fi
            
            # Move all files from clone to project directory
            log "Moving files to project directory..."
            shopt -s dotglob
            mv "$temp_clone"/* "$PROJECT_DIR/" 2>/dev/null || true
            shopt -u dotglob
            rm -rf "$temp_clone"
            
            # Restore backed up directories
            if [ -d "$backup_dir" ]; then
                for dir in config storage docker; do
                    if [ -d "$backup_dir/$dir" ]; then
                        log "Restoring $dir directory..."
                        if [ -d "$PROJECT_DIR/$dir" ]; then
                            # Merge if both exist
                            cp -r "$backup_dir/$dir"/* "$PROJECT_DIR/$dir/" 2>/dev/null || true
                        else
                            mv "$backup_dir/$dir" "$PROJECT_DIR/" 2>/dev/null || true
                        fi
                    fi
                done
                rm -rf "$backup_dir"
            fi
            
            success "Repository cloned successfully"
        else
            # Directory has some files, try to initialize git and pull
            log "Initializing git repository in existing directory..."
            git init
            git remote add origin "$GIT_REPO_URL" 2>/dev/null || git remote set-url origin "$GIT_REPO_URL"
            
            # Fetch and reset to match remote
            log "Fetching from remote..."
            if ! git fetch origin "$GIT_BRANCH" 2>&1 | tee -a "$LOG_FILE"; then
                fail "Failed to fetch from git remote"
            fi
            
            # Create branch and reset to remote
            git checkout -b "$GIT_BRANCH" 2>/dev/null || git checkout "$GIT_BRANCH" 2>/dev/null || true
            if ! git reset --hard "origin/$GIT_BRANCH" 2>&1 | tee -a "$LOG_FILE"; then
                warn "Git reset had issues, but continuing..."
            fi
            
            success "Git repository initialized and synced"
        fi
    else
        # Verify remote is set correctly
        if ! git remote get-url origin >/dev/null 2>&1; then
            log "Git remote not configured. Setting remote..."
            git remote add origin "$GIT_REPO_URL" || git remote set-url origin "$GIT_REPO_URL"
        else
            # Update remote URL in case it changed
            local current_url=$(git remote get-url origin 2>/dev/null || echo "")
            if [ "$current_url" != "$GIT_REPO_URL" ]; then
                log "Updating git remote URL..."
                git remote set-url origin "$GIT_REPO_URL"
            fi
        fi
        success "Git repository found"
    fi
}

# Handle git conflicts
handle_git_conflicts() {
    log "Checking for git conflicts..."
    
    # Abort any ongoing operations first
    git merge --abort 2>/dev/null || true
    git rebase --abort 2>/dev/null || true
    git cherry-pick --abort 2>/dev/null || true
    
    if git status 2>/dev/null | grep -q "both modified\|both added\|both deleted\|Unmerged paths"; then
        warn "Git conflicts detected. Attempting to resolve..."
        log "Cleaning up git state..."
        # Reset any unmerged paths
        git reset --hard HEAD 2>/dev/null || true
        git clean -fd || true
    fi
    
    # Check for any uncommitted changes
    if ! git diff --quiet HEAD 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        log "Uncommitted changes detected, will be discarded during update"
    fi
    
    success "Git state cleaned up"
}

# Safely re-clone repository (removes old files and clones fresh)
safe_reclone_repository() {
    log "Starting safe repository re-clone..."
    
    cd "$PROJECT_DIR"
    
    # List of directories/files to preserve
    PRESERVE_DIRS=("logs" "storage" "config" "docker" ".backups")
    PRESERVE_FILES=()
    
    # Create temporary backup directory
    BACKUP_TEMP=$(mktemp -d)
    BACKUP_SUCCESS=true
    
    log "Backing up important directories and files..."
    for dir in "${PRESERVE_DIRS[@]}"; do
        if [ -d "$dir" ] || [ -e "$dir" ]; then
            log "Backing up $dir..."
            if cp -r "$dir" "$BACKUP_TEMP/" 2>/dev/null; then
                success "Backed up $dir"
            else
                warn "Failed to backup $dir (may not exist or be empty)"
            fi
        fi
    done
    
    for file in "${PRESERVE_FILES[@]}"; do
        if [ -f "$file" ]; then
            log "Backing up $file..."
            cp "$file" "$BACKUP_TEMP/" 2>/dev/null || warn "Failed to backup $file"
        fi
    done
    
    # Also preserve docker-compose.yml if it has local modifications (but we'll restore from backup)
    if [ -f "docker-compose.yml" ]; then
        cp "docker-compose.yml" "$BACKUP_TEMP/docker-compose.yml.local" 2>/dev/null || true
    fi
    
    # Verify backup was created
    if [ ! -d "$BACKUP_TEMP" ] || [ -z "$(ls -A "$BACKUP_TEMP" 2>/dev/null)" ]; then
        warn "Backup directory is empty, but continuing..."
    fi
    
    log "Removing old repository files (preserving important directories)..."
    
    # Remove everything except preserved directories
    # First, move preserved dirs to a safe location temporarily
    PRESERVE_TEMP=$(mktemp -d)
    PRESERVE_TEMP_NAME=$(basename "$PRESERVE_TEMP")
    BACKUP_TEMP_NAME=$(basename "$BACKUP_TEMP")
    
    for dir in "${PRESERVE_DIRS[@]}"; do
        if [ -d "$dir" ] || [ -e "$dir" ]; then
            mv "$dir" "$PRESERVE_TEMP/" 2>/dev/null || true
        fi
    done
    
    # Remove all other files and directories (including .git)
    # But exclude the temporary directories we're using
    log "Removing old repository..."
    for item in * .*; do
        # Skip . and .., and our temp directories
        if [ "$item" = "." ] || [ "$item" = ".." ]; then
            continue
        fi
        if [ "$item" = "$PRESERVE_TEMP_NAME" ] || [ "$item" = "$BACKUP_TEMP_NAME" ]; then
            continue
        fi
        # Remove everything else
        rm -rf "$item" 2>/dev/null || true
    done
    
    # Clone fresh repository
    log "Cloning fresh repository from $GIT_REPO_URL (branch: $GIT_BRANCH)..."
    TEMP_CLONE=$(mktemp -d)
    
    if ! git clone -b "$GIT_BRANCH" --single-branch --depth 1 "$GIT_REPO_URL" "$TEMP_CLONE" 2>&1 | tee -a "$LOG_FILE"; then
        error "Failed to clone repository"
        # Try to restore preserved directories
        if [ -d "$PRESERVE_TEMP" ]; then
            mv "$PRESERVE_TEMP"/* "$PROJECT_DIR/" 2>/dev/null || true
        fi
        rm -rf "$TEMP_CLONE" "$PRESERVE_TEMP" "$BACKUP_TEMP"
        fail "Repository re-clone failed"
    fi
    
    # Move all files from clone to project directory
    log "Moving cloned files to project directory..."
    shopt -s dotglob
    mv "$TEMP_CLONE"/* "$PROJECT_DIR/" 2>/dev/null || true
    shopt -u dotglob
    rm -rf "$TEMP_CLONE"
    
    # Restore preserved directories
    log "Restoring preserved directories..."
    if [ -d "$PRESERVE_TEMP" ]; then
        for dir in "${PRESERVE_DIRS[@]}"; do
            if [ -d "$PRESERVE_TEMP/$dir" ]; then
                if [ -d "$PROJECT_DIR/$dir" ]; then
                    # Merge: copy new files from backup, but keep existing structure
                    log "Merging $dir with existing directory..."
                    # Copy files from backup that don't exist in new clone, or merge configs
                    if [ "$dir" = "config" ]; then
                        # For config, we want to merge carefully
                        cp -rn "$PRESERVE_TEMP/$dir"/* "$PROJECT_DIR/$dir/" 2>/dev/null || true
                    elif [ "$dir" = "docker" ]; then
                        # For docker, preserve certbot (SSL certificates) but use fresh structure
                        if [ -d "$PRESERVE_TEMP/docker/certbot" ]; then
                            log "Preserving SSL certificates from docker/certbot..."
                            # Remove docker/certbot from new clone if it exists
                            rm -rf "$PROJECT_DIR/docker/certbot" 2>/dev/null || true
                            # Restore the preserved certbot directory
                            mkdir -p "$PROJECT_DIR/docker"
                            cp -r "$PRESERVE_TEMP/docker/certbot" "$PROJECT_DIR/docker/" 2>/dev/null || true
                            success "SSL certificates preserved"
                        fi
                        # Note: nginx configs come from repo, but certbot data is preserved
                    else
                        # For logs, storage, .backups - just restore
                        rm -rf "$PROJECT_DIR/$dir" 2>/dev/null || true
                        mv "$PRESERVE_TEMP/$dir" "$PROJECT_DIR/" 2>/dev/null || true
                    fi
                else
                    # Directory doesn't exist in new clone, just restore it
                    mv "$PRESERVE_TEMP/$dir" "$PROJECT_DIR/" 2>/dev/null || true
                fi
            fi
        done
        rm -rf "$PRESERVE_TEMP"
    fi
    
    # Also restore from backup temp if needed (for files that might have been modified)
    if [ -d "$BACKUP_TEMP" ]; then
        # Restore docker-compose.yml.local if it exists and docker-compose.yml from repo is different
        if [ -f "$BACKUP_TEMP/docker-compose.yml.local" ] && [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
            # Compare and warn if different, but use repo version
            if ! cmp -s "$BACKUP_TEMP/docker-compose.yml.local" "$PROJECT_DIR/docker-compose.yml" 2>/dev/null; then
                warn "docker-compose.yml differs from repository version. Using repository version."
                warn "Previous version backed up to: $BACKUP_TEMP/docker-compose.yml.local"
            fi
        fi
    fi
    
    # Clean up backup temp (keep it for a bit in case of issues, but log location)
    log "Backup preserved at: $BACKUP_TEMP (will be cleaned up on next successful deployment)"
    
    # Verify the clone was successful
    if [ ! -d ".git" ]; then
        fail "Repository re-clone completed but .git directory not found"
    fi
    
    # Verify we're on the correct branch
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    if [ "$CURRENT_BRANCH" != "$GIT_BRANCH" ]; then
        warn "Cloned branch is $CURRENT_BRANCH, expected $GIT_BRANCH. Checking out correct branch..."
        git checkout -B "$GIT_BRANCH" "origin/$GIT_BRANCH" 2>&1 | tee -a "$LOG_FILE" || true
    fi
    
    success "Repository re-cloned successfully"
    
    # Clean up old backup temp directories (keep only last 2)
    if [ -d "$PROJECT_DIR/.backup_temps" ]; then
        ls -1t "$PROJECT_DIR/.backup_temps" 2>/dev/null | tail -n +3 | xargs -r -I {} rm -rf "$PROJECT_DIR/.backup_temps/{}" 2>/dev/null || true
    else
        mkdir -p "$PROJECT_DIR/.backup_temps"
    fi
    
    # Move current backup to .backup_temps for later cleanup
    BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S)"
    mv "$BACKUP_TEMP" "$PROJECT_DIR/.backup_temps/$BACKUP_NAME" 2>/dev/null || true
}

# ============================
# Main Deployment
# ============================

echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║     AI-IA Backend Deployment Script    ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
echo ""

# Create logs directory & rotate previous files to avoid tee failures
mkdir -p "$LOG_DIR"
rotate_logs

log "Deployment started"
log "Project directory: $PROJECT_DIR"
log "Target branch: $GIT_BRANCH"
log "Docker compose file: $DOCKER_COMPOSE_FILE"

cd "$PROJECT_DIR"

# ============================
# Git Operations (must happen first)
# ============================

log ""
log "========== GIT OPERATIONS =========="
log "Step 1/7: Ensuring git repository exists..."
ensure_git_repo

# Now that we're sure the repo exists, update PROJECT_DIR paths
# (in case we cloned into a different structure)
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DOCKER_COMPOSE_FILE="${PROJECT_DIR}/docker-compose.yml"
cd "$PROJECT_DIR"

# Verify prerequisites (after ensuring repo exists)
verify_prerequisites

# Check disk space
check_disk_space

# Preemptive Docker cleanup keeps disk usage low even when space is OK
docker_garbage_collect

# Check port availability
check_port_available 5000
check_port_available 80

# Check config file
check_config_file

# Create backup
create_backup

# ============================
# Git Operations (continued)
# ============================

log ""
log "========== GIT OPERATIONS (continued) =========="
log "Step 2/7: Updating repository (using safe re-clone method)..."

# Use safe re-clone method to ensure clean state
safe_reclone_repository

log "Step 3/7: Verifying repository state..."

# Verify repository is clean and up to date
CURRENT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
REMOTE_COMMIT=$(git rev-parse origin/"$GIT_BRANCH" 2>/dev/null || echo "unknown")
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

if [ "$CURRENT_BRANCH" != "$GIT_BRANCH" ]; then
    warn "Branch mismatch: current=$CURRENT_BRANCH, expected=$GIT_BRANCH"
    git checkout -B "$GIT_BRANCH" "origin/$GIT_BRANCH" 2>&1 | tee -a "$LOG_FILE" || fail "Failed to checkout branch $GIT_BRANCH"
fi

if [ "$CURRENT_COMMIT" != "$REMOTE_COMMIT" ]; then
    warn "Commit mismatch after re-clone. This should not happen."
    warn "Current: ${CURRENT_COMMIT:0:8}, Remote: ${REMOTE_COMMIT:0:8}"
    # Try to fix it
    git fetch origin "$GIT_BRANCH" 2>&1 | tee -a "$LOG_FILE" || true
    git reset --hard origin/"$GIT_BRANCH" 2>&1 | tee -a "$LOG_FILE" || true
fi

success "Repository verified and up to date (commit: ${CURRENT_COMMIT:0:8})"

# ============================
# Docker Operations
# ============================

log ""
log "========== DOCKER OPERATIONS =========="

log "Step 4/6: Stopping containers gracefully..."
STOP_ATTEMPT=0
STOP_MAX=3
while [ $STOP_ATTEMPT -lt $STOP_MAX ]; do
    if docker compose -f "$DOCKER_COMPOSE_FILE" down --remove-orphans 2>&1 | tee -a "$LOG_FILE"; then
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
    docker compose -f "$DOCKER_COMPOSE_FILE" down --remove-orphans 2>&1 | tee -a "$LOG_FILE" || true
fi

# Fix 1: Enhanced Container Cleanup - More aggressive cleanup
log "Force removing all project containers..."
docker compose -f "$DOCKER_COMPOSE_FILE" down --remove-orphans --rmi all --volumes 2>&1 | tee -a "$LOG_FILE" || true

# Remove any dangling containers
log "Cleaning up any dangling containers..."
docker ps -aq --filter "name=main_app\|ai_redis\|ai_psql\|ai-search\|ai_nginx\|ai_certbot" | xargs -r docker rm -f 2>&1 | tee -a "$LOG_FILE" || true

log "Step 5/6: Building Docker images (this may take several minutes)..."
if ! docker compose -f "$DOCKER_COMPOSE_FILE" build --no-cache 2>&1 | tee -a "$LOG_FILE"; then
    fail "Failed to build Docker images"
fi
success "Docker images built successfully"

log "Step 6/6: Starting containers..."

# Final cleanup of any remaining conflicting containers right before starting
log "Final cleanup of conflicting containers before startup..."
docker ps -aq --filter "name=main_app\|ai_redis\|ai_psql\|ai-search\|ai_nginx\|ai_certbot" | xargs -r docker rm -f 2>&1 | tee -a "$LOG_FILE" || true
# Wait a moment for Docker to process removals
sleep 2

if ! docker compose -f "$DOCKER_COMPOSE_FILE" up -d 2>&1 | tee -a "$LOG_FILE"; then
    # If startup fails due to container name conflicts, remove them and retry
    warn "Container startup failed, checking for conflicts..."
    for container in main_app ai_redis ai_psql ai-search ai_nginx ai_certbot; do
        if docker ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
            log "Removing conflicting container: $container"
            docker rm -f "$container" 2>&1 | tee -a "$LOG_FILE" || true
        fi
    done
    sleep 2
    if ! docker compose -f "$DOCKER_COMPOSE_FILE" up -d 2>&1 | tee -a "$LOG_FILE"; then
        fail "Failed to start containers after conflict resolution"
    fi
fi

# Fix 3: Better Container Startup Verification
log "Waiting for all containers to start..."
MAX_WAIT=60
ELAPSED=0
TOTAL_SERVICES=$(docker compose -f "$DOCKER_COMPOSE_FILE" config --services 2>/dev/null | wc -l)

while [ $ELAPSED -lt $MAX_WAIT ]; do
    RUNNING_COUNT=0
    for service in $(docker compose -f "$DOCKER_COMPOSE_FILE" config --services 2>/dev/null); do
        if docker compose -f "$DOCKER_COMPOSE_FILE" ps "$service" --format json 2>/dev/null | grep -q '"State":"running"'; then
            RUNNING_COUNT=$((RUNNING_COUNT + 1))
        fi
    done
    
    if [ "$RUNNING_COUNT" -eq "$TOTAL_SERVICES" ] && [ "$TOTAL_SERVICES" -gt "0" ]; then
        success "All $TOTAL_SERVICES containers are running"
        break
    fi
    ELAPSED=$((ELAPSED + 5))
    log "Waiting for containers... ($RUNNING_COUNT/$TOTAL_SERVICES running, ${ELAPSED}s)"
    sleep 5
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    warn "Some containers failed to start within $MAX_WAIT seconds"
    log "Current container status:"
    docker compose -f "$DOCKER_COMPOSE_FILE" ps 2>&1 | tee -a "$LOG_FILE"
    docker compose -f "$DOCKER_COMPOSE_FILE" logs --tail=50 2>&1 | tee -a "$LOG_FILE" || true
fi

# ============================
# Database & Services Setup
# ============================

log ""
log "========== DATABASE & SERVICES SETUP =========="

log "Waiting 10 seconds for services to stabilize..."
for i in {10..1}; do
    echo -ne "\rWaiting: ${i}s remaining  "
    sleep 1
done
echo ""

log "Handling database initialization and locks..."
DB_READY_ATTEMPT=0
DB_READY_MAX=5
while [ $DB_READY_ATTEMPT -lt $DB_READY_MAX ]; do
    log "Database connection attempt $((DB_READY_ATTEMPT + 1))/$DB_READY_MAX..."
    if docker compose -f "$DOCKER_COMPOSE_FILE" exec -T app python manage.py migrate --noinput 2>&1 | tee -a "$LOG_FILE"; then
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
    fail "Database is still locked after $DB_READY_MAX attempts. Check database logs: docker compose logs psql"
fi

log "Collecting static files..."
if ! docker compose -f "$DOCKER_COMPOSE_FILE" exec -T app python manage.py collectstatic --noinput --no-post-process 2>&1 | tee -a "$LOG_FILE"; then
    warn "Static file collection had issues (may be normal)"
fi
success "Static files processed"

# ============================
# SSL Certificate Management
# ============================

log ""
log "========== SSL CERTIFICATE MANAGEMENT =========="

# Wait for nginx to be fully up
log "Waiting for nginx to be ready..."
NGINX_WAIT=0
NGINX_MAX_WAIT=30
while [ $NGINX_WAIT -lt $NGINX_MAX_WAIT ]; do
    if docker compose -f "$DOCKER_COMPOSE_FILE" exec -T nginx nginx -t > /dev/null 2>&1; then
        success "Nginx is ready"
        break
    fi
    NGINX_WAIT=$((NGINX_WAIT + 1))
    sleep 1
done

# Check if SSL certificates exist
SSL_CERT_PATH="${PROJECT_DIR}/docker/certbot/conf/live/eduaiia.com/fullchain.pem"
SSL_KEY_PATH="${PROJECT_DIR}/docker/certbot/conf/live/eduaiia.com/privkey.pem"

if [ -f "$SSL_CERT_PATH" ] && [ -f "$SSL_KEY_PATH" ]; then
    log "SSL certificates found - enabling HTTPS..."
    
    NGINX_CONF="${PROJECT_DIR}/docker/nginx/default.conf"
    
    # Check if HTTPS block is commented out
    if grep -q "^# server {" "$NGINX_CONF" && grep -A 2 "^# server {" "$NGINX_CONF" | grep -q "listen 443"; then
        log "Enabling HTTPS server block in nginx configuration..."
        
        # Create backup
        cp "$NGINX_CONF" "${NGINX_CONF}.backup"
        
        # Uncomment the HTTPS server block using sed
        # Match range from "# server {" to "# }" and remove one leading # from each line
        # This preserves indentation and handles nested comments correctly
        sed -i.tmp '/^# server {/,/^# }$/ {
            # For the opening comment line, update it
            /^# HTTPS server/ { s/^# HTTPS server.*/# HTTPS server - automatically enabled/; }
            # Remove one # from lines that start with # followed by space or letter (not ##)
            /^# [^#]/ { s/^# //; }
            # Handle the closing brace
            /^# }$/ { s/^# / /; }
        }' "$NGINX_CONF"
        
        # Remove temporary file
        rm -f "${NGINX_CONF}.tmp"
        
        # Also enable HTTP to HTTPS redirect (but keep ACME challenge accessible)
        if grep -q "# Redirect to HTTPS" "$NGINX_CONF" && grep -A 3 "# Redirect to HTTPS" "$NGINX_CONF" | grep -q "# location /"; then
            log "Enabling HTTP to HTTPS redirect..."
            # Uncomment the redirect block
            sed -i.tmp2 '/# Redirect to HTTPS/,/# Serve directly over HTTP/ {
                /#     location \/ {/ { s/^#     /    /; }
                /#     return 301/ { s/^#     /    /; }
                /#     }$/ { s/^#     /    /; }
            }' "$NGINX_CONF"
            rm -f "${NGINX_CONF}.tmp2"
            
            # Update the comment
            sed -i.tmp3 's/^    # Redirect to HTTPS (uncomment when SSL is ready)/    # Redirect to HTTPS (enabled automatically)/' "$NGINX_CONF"
            sed -i.tmp3 's/^    # Serve directly over HTTP (remove when HTTPS is ready)/    # HTTP proxy disabled - redirecting to HTTPS (ACME challenge still works)/' "$NGINX_CONF"
            rm -f "${NGINX_CONF}.tmp3"
        fi
        
        # Test nginx configuration
        if docker compose -f "$DOCKER_COMPOSE_FILE" exec -T nginx nginx -t 2>&1 | tee -a "$LOG_FILE"; then
            # Reload nginx
            if docker compose -f "$DOCKER_COMPOSE_FILE" exec -T nginx nginx -s reload 2>&1 | tee -a "$LOG_FILE"; then
                success "HTTPS enabled with HTTP redirect and nginx reloaded"
                rm -f "${NGINX_CONF}.backup"
            else
                warn "Failed to reload nginx, restarting container..."
                docker compose -f "$DOCKER_COMPOSE_FILE" restart nginx 2>&1 | tee -a "$LOG_FILE" || true
                if docker compose -f "$DOCKER_COMPOSE_FILE" exec -T nginx nginx -t > /dev/null 2>&1; then
                    success "HTTPS enabled after nginx restart"
                    rm -f "${NGINX_CONF}.backup"
                else
                    warn "Nginx configuration invalid, restoring backup..."
                    mv "${NGINX_CONF}.backup" "$NGINX_CONF"
                    docker compose -f "$DOCKER_COMPOSE_FILE" restart nginx 2>&1 | tee -a "$LOG_FILE" || true
                fi
            fi
        else
            warn "Nginx configuration test failed, restoring backup..."
            mv "${NGINX_CONF}.backup" "$NGINX_CONF"
            docker compose -f "$DOCKER_COMPOSE_FILE" restart nginx 2>&1 | tee -a "$LOG_FILE" || true
        fi
    else
        # Check if HTTPS is already enabled
        if grep -q "^server {" "$NGINX_CONF" && grep -A 2 "^server {" "$NGINX_CONF" | grep -q "listen 443"; then
            log "HTTPS is already enabled in nginx configuration"
        else
            warn "HTTPS server block not found in expected format - manual configuration may be needed"
        fi
    fi
else
    log "SSL certificates not found at $SSL_CERT_PATH"
    log "To enable HTTPS:"
    log "  1. Ensure domain eduaiia.com points to this server"
    log "  2. Run: docker compose exec certbot certbot certonly --webroot -w /var/www/certbot -d eduaiia.com -d www.eduaiia.com --email your-email@example.com --agree-tos --non-interactive"
    log "  3. Run this deployment script again to automatically enable HTTPS"
fi

# ============================
# Health Checks & Verification
# ============================

log ""
log "Step 7/7: Running health checks..."

# Check containers
# Use docker ps -a to see all containers including restarting ones
HEALTH_CHECK_FAILED=false

# Check app container
if docker ps -a --format "{{.Names}}" | grep -q "^main_app$"; then
    APP_STATUS=$(docker inspect -f '{{.State.Status}}' main_app 2>/dev/null || echo "unknown")
    if [ "$APP_STATUS" = "running" ]; then
        success "App container is running"
    else
        error "App container exists but status is: $APP_STATUS"
        HEALTH_CHECK_FAILED=true
    fi
else
    error "App container (main_app) is NOT found"
    HEALTH_CHECK_FAILED=true
fi

# Check PostgreSQL container
if docker ps -a --format "{{.Names}}" | grep -q "^ai_psql$"; then
    PSQL_STATUS=$(docker inspect -f '{{.State.Status}}' ai_psql 2>/dev/null || echo "unknown")
    if [ "$PSQL_STATUS" = "running" ]; then
        success "PostgreSQL container is running"
    else
        error "PostgreSQL container exists but status is: $PSQL_STATUS"
        HEALTH_CHECK_FAILED=true
    fi
else
    error "PostgreSQL container (ai_psql) is NOT found"
    HEALTH_CHECK_FAILED=true
fi

# Check Redis container
if docker ps -a --format "{{.Names}}" | grep -q "^ai_redis$"; then
    REDIS_STATUS=$(docker inspect -f '{{.State.Status}}' ai_redis 2>/dev/null || echo "unknown")
    if [ "$REDIS_STATUS" = "running" ]; then
        success "Redis container is running"
    else
        error "Redis container exists but status is: $REDIS_STATUS"
        HEALTH_CHECK_FAILED=true
    fi
else
    error "Redis container (ai_redis) is NOT found"
    HEALTH_CHECK_FAILED=true
fi

# Check search container (optional)
if docker ps -a --format "{{.Names}}" | grep -q "^ai-search$"; then
    SEARCH_STATUS=$(docker inspect -f '{{.State.Status}}' ai-search 2>/dev/null || echo "unknown")
    if [ "$SEARCH_STATUS" = "running" ]; then
        success "Search container is running"
    else
        warn "Search container exists but status is: $SEARCH_STATUS (optional service)"
    fi
else
    warn "Search container (ai-search) is not found (may be optional)"
fi

# Check nginx container
if docker ps -a --format "{{.Names}}" | grep -q "^ai_nginx$"; then
    NGINX_STATUS=$(docker inspect -f '{{.State.Status}}' ai_nginx 2>/dev/null || echo "unknown")
    if [ "$NGINX_STATUS" = "running" ]; then
        success "Nginx container is running"
    else
        error "Nginx container exists but status is: $NGINX_STATUS"
        HEALTH_CHECK_FAILED=true
    fi
else
    error "Nginx container (ai_nginx) is NOT found"
    HEALTH_CHECK_FAILED=true
fi

# Application endpoint check
log "Testing application health endpoint..."
HEALTH_CHECK_COUNT=0
HEALTH_CHECK_MAX=30
HEALTH_CHECK_PASSED=false
while [ $HEALTH_CHECK_COUNT -lt $HEALTH_CHECK_MAX ]; do
    if curl -f -s http://localhost:5000/ > /dev/null 2>&1; then
        success "Application is responding on port 5000"
        HEALTH_CHECK_PASSED=true
        break
    fi
    HEALTH_CHECK_COUNT=$((HEALTH_CHECK_COUNT + 1))
    sleep 1
done
if [ "$HEALTH_CHECK_PASSED" = false ]; then
    error "Application health check timed out after ${HEALTH_CHECK_MAX} seconds"
    HEALTH_CHECK_FAILED=true
fi

# Fail deployment if any health check failed
if [ "$HEALTH_CHECK_FAILED" = true ]; then
    log ""
    log "Final container status:"
    docker compose -f "$DOCKER_COMPOSE_FILE" ps | tee -a "$LOG_FILE"
    log ""
    fail "Health checks failed. One or more containers are not running properly. Deployment failed."
fi

# Display final status
log ""
log "Final container status:"
docker compose -f "$DOCKER_COMPOSE_FILE" ps | tee -a "$LOG_FILE"

# Final summary - if we reach here, all critical checks passed
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Deployment completed successfully!  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
log "Deployment finished successfully"
log "Logs saved to: $LOG_FILE"
log "Backup saved to: $BACKUP_DIR"
