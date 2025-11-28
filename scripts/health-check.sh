#!/bin/bash

# Comprehensive Health Check Script
# Usage: ./health-check.sh [--environment ENV] [--comprehensive]

set -e

ENVIRONMENT="${ENVIRONMENT:-production}"
COMPREHENSIVE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --comprehensive)
            COMPREHENSIVE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Determine compose file based on environment
case $ENVIRONMENT in
    dev|development)
        COMPOSE_FILE="docker-compose.dev.yml"
        ;;
    staging)
        COMPOSE_FILE="docker-compose.staging.yml"
        ;;
    prod|production)
        COMPOSE_FILE="docker-compose.prod.yml"
        ;;
    *)
        COMPOSE_FILE="docker-compose.yml"
        ;;
esac

COMPOSE_CMD="docker compose -f docker-compose.base.yml -f $COMPOSE_FILE"

log "Running health checks for environment: $ENVIRONMENT"
log "Using compose file: $COMPOSE_FILE"

HEALTH_CHECK_FAILED=false

# Check Docker daemon
log "Checking Docker daemon..."
if ! docker info > /dev/null 2>&1; then
    error "Docker daemon is not running"
    exit 1
fi
success "Docker daemon is running"

# Check container status
log "Checking container status..."
CRITICAL_CONTAINERS=("app" "psql" "redis" "nginx")
OPTIONAL_CONTAINERS=("search" "certbot")

for container in "${CRITICAL_CONTAINERS[@]}"; do
    CONTAINER_NAME=$(docker ps --format "{{.Names}}" | grep -E "${container}|ai_.*${container}" | head -1 || echo "")
    
    if [ -z "$CONTAINER_NAME" ]; then
        error "Critical container not found: $container"
        HEALTH_CHECK_FAILED=true
        continue
    fi
    
    STATUS=$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
    
    if [ "$STATUS" = "running" ]; then
        success "$container is running ($CONTAINER_NAME)"
        
        # Check health status if available
        HEALTH=$(docker inspect -f '{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "none")
        if [ "$HEALTH" != "none" ]; then
            if [ "$HEALTH" = "healthy" ]; then
                success "$container health check: healthy"
            else
                warn "$container health check: $HEALTH"
            fi
        fi
    else
        error "$container status is: $STATUS"
        HEALTH_CHECK_FAILED=true
    fi
done

# Check optional containers
for container in "${OPTIONAL_CONTAINERS[@]}"; do
    CONTAINER_NAME=$(docker ps --format "{{.Names}}" | grep -E "${container}|ai_.*${container}" | head -1 || echo "")
    
    if [ -z "$CONTAINER_NAME" ]; then
        warn "Optional container not found: $container (may be normal)"
        continue
    fi
    
    STATUS=$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
    
    if [ "$STATUS" = "running" ]; then
        success "$container is running ($CONTAINER_NAME)"
    else
        warn "$container status is: $STATUS (optional service)"
    fi
done

# Application health endpoint check
log "Checking application health endpoint..."
APP_HEALTH_COUNT=0
APP_HEALTH_MAX=10
APP_HEALTH_PASSED=false

while [ $APP_HEALTH_COUNT -lt $APP_HEALTH_MAX ]; do
    HTTP_CODE=$(curl -f -s -o /dev/null -w '%{http_code}' http://localhost:5000/health 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
        success "Application health endpoint responding (HTTP $HTTP_CODE)"
        APP_HEALTH_PASSED=true
        break
    fi
    
    APP_HEALTH_COUNT=$((APP_HEALTH_COUNT + 1))
    sleep 2
done

if [ "$APP_HEALTH_PASSED" = false ]; then
    error "Application health endpoint not responding after ${APP_HEALTH_MAX} attempts"
    HEALTH_CHECK_FAILED=true
fi

# Comprehensive checks
if [ "$COMPREHENSIVE" = true ]; then
    log "Running comprehensive health checks..."
    
    # Database connectivity
    log "Checking database connectivity..."
    if docker exec $(docker ps --format "{{.Names}}" | grep -E "psql|ai_.*psql" | head -1) pg_isready -U postgres > /dev/null 2>&1; then
        success "Database is accessible"
    else
        error "Database connectivity check failed"
        HEALTH_CHECK_FAILED=true
    fi
    
    # Redis connectivity
    log "Checking Redis connectivity..."
    if docker exec $(docker ps --format "{{.Names}}" | grep -E "redis|ai_.*redis" | head -1) redis-cli ping > /dev/null 2>&1; then
        success "Redis is accessible"
    else
        error "Redis connectivity check failed"
        HEALTH_CHECK_FAILED=true
    fi
    
    # Disk space check
    log "Checking disk space..."
    DISK_USAGE=$(df -h . | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -lt 90 ]; then
        success "Disk usage: ${DISK_USAGE}%"
    else
        warn "Disk usage is high: ${DISK_USAGE}%"
    fi
    
    # Memory check
    log "Checking memory usage..."
    MEM_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [ "$MEM_USAGE" -lt 90 ]; then
        success "Memory usage: ${MEM_USAGE}%"
    else
        warn "Memory usage is high: ${MEM_USAGE}%"
    fi
fi

# Final status
echo ""
if [ "$HEALTH_CHECK_FAILED" = true ]; then
    error "Health checks failed. Please review the issues above."
    exit 1
else
    success "All health checks passed!"
    exit 0
fi

