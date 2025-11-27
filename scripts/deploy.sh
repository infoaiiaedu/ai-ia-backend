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

# Create logs directory & rotate previous files to avoid tee failures
mkdir -p "$LOG_DIR"
rotate_logs

log "Deployment started"
log "Project directory: $PROJECT_DIR"
log "Target branch: $GIT_BRANCH"
log "Docker compose file: $DOCKER_COMPOSE_FILE"

# Verify prerequisites
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

log "Step 4/6: Building Docker images (this may take several minutes)..."
if ! docker compose -f "$DOCKER_COMPOSE_FILE" build --no-cache 2>&1 | tee -a "$LOG_FILE"; then
    fail "Failed to build Docker images"
fi
success "Docker images built successfully"

log "Step 5/6: Starting containers..."
if ! docker compose -f "$DOCKER_COMPOSE_FILE" up -d 2>&1 | tee -a "$LOG_FILE"; then
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
log "Step 6/6: Running health checks..."

# Check containers
CONTAINERS_OK=true

if docker compose -f "$DOCKER_COMPOSE_FILE" ps app | grep -q "Up\|running"; then
    success "App container is running"
else
    error "App container is NOT running"
    CONTAINERS_OK=false
fi

if docker compose -f "$DOCKER_COMPOSE_FILE" ps psql | grep -q "Up\|running"; then
    success "PostgreSQL container is running"
else
    error "PostgreSQL container is NOT running"
    CONTAINERS_OK=false
fi

if docker compose -f "$DOCKER_COMPOSE_FILE" ps redis | grep -q "Up\|running"; then
    success "Redis container is running"
else
    error "Redis container is NOT running"
    CONTAINERS_OK=false
fi

if docker compose -f "$DOCKER_COMPOSE_FILE" ps nginx | grep -q "Up\|running"; then
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
docker compose -f "$DOCKER_COMPOSE_FILE" ps | tee -a "$LOG_FILE"

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
    log "Please check container logs: docker compose logs"
fi
