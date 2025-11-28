#!/bin/bash

# Automated Rollback Script
# Usage: ./rollback.sh [--environment ENV] [--backup-id ID] [--force]

set -e

ENVIRONMENT="${ENVIRONMENT:-production}"
BACKUP_ID=""
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --backup-id)
            BACKUP_ID="$2"
            shift 2
            ;;
        --force)
            FORCE=true
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

log "Starting rollback for environment: $ENVIRONMENT"

# Find latest backup if not specified
if [ -z "$BACKUP_ID" ]; then
    log "Finding latest backup..."
    BACKUP_DIR=".backups"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        error "Backup directory not found: $BACKUP_DIR"
        exit 1
    fi
    
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR" | grep "backup_" | head -1)
    
    if [ -z "$LATEST_BACKUP" ]; then
        error "No backups found in $BACKUP_DIR"
        exit 1
    fi
    
    BACKUP_ID="$LATEST_BACKUP"
    log "Using latest backup: $BACKUP_ID"
fi

BACKUP_PATH=".backups/$BACKUP_ID"

if [ ! -d "$BACKUP_PATH" ]; then
    error "Backup not found: $BACKUP_PATH"
    exit 1
fi

log "Backup found: $BACKUP_PATH"

# Confirm rollback (unless forced)
if [ "$FORCE" = false ]; then
    echo ""
    warn "This will rollback to backup: $BACKUP_ID"
    warn "Current deployment will be stopped and replaced."
    read -p "Are you sure you want to continue? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        log "Rollback cancelled by user"
        exit 0
    fi
fi

# Stop current deployment
log "Stopping current deployment..."
$COMPOSE_CMD down || true

# Restore configuration
log "Restoring configuration from backup..."
if [ -d "$BACKUP_PATH/config" ]; then
    rm -rf config
    cp -r "$BACKUP_PATH/config" config
    success "Configuration restored"
else
    warn "No configuration backup found, skipping..."
fi

# Restore database backup if available
if [ -f "$BACKUP_PATH/db_backup.sql" ]; then
    log "Restoring database backup..."
    
    # Start database service
    $COMPOSE_CMD up -d psql
    
    # Wait for database to be ready
    log "Waiting for database to be ready..."
    sleep 10
    
    # Restore database
    docker exec -i $(docker ps --format "{{.Names}}" | grep -E "psql|ai_.*psql" | head -1) psql -U postgres ai_db < "$BACKUP_PATH/db_backup.sql" || {
        error "Database restore failed"
        exit 1
    }
    
    success "Database restored"
else
    warn "No database backup found, skipping database restore..."
fi

# Restore code from git (rollback to previous commit)
log "Rolling back code to previous commit..."
PREVIOUS_COMMIT=$(git log --oneline -2 | tail -1 | awk '{print $1}')
log "Previous commit: $PREVIOUS_COMMIT"

if [ "$FORCE" = false ]; then
    read -p "Rollback code to commit $PREVIOUS_COMMIT? (yes/no): " CONFIRM_CODE
    
    if [ "$CONFIRM_CODE" = "yes" ]; then
        git reset --hard "$PREVIOUS_COMMIT" || {
            error "Code rollback failed"
            exit 1
        }
        success "Code rolled back to $PREVIOUS_COMMIT"
    fi
else
    git reset --hard "$PREVIOUS_COMMIT" || {
        error "Code rollback failed"
        exit 1
    }
    success "Code rolled back to $PREVIOUS_COMMIT"
fi

# Rebuild and start services
log "Rebuilding and starting services..."
$COMPOSE_CMD build --no-cache || {
    error "Build failed"
    exit 1
}

$COMPOSE_CMD up -d || {
    error "Startup failed"
    exit 1
}

# Wait for services to be ready
log "Waiting for services to start..."
sleep 15

# Run health checks
log "Running health checks..."
if bash scripts/health-check.sh --environment "$ENVIRONMENT"; then
    success "Rollback completed successfully"
    log "Services are healthy after rollback"
else
    error "Health checks failed after rollback"
    warn "Manual intervention may be required"
    exit 1
fi

log "Rollback to $BACKUP_ID completed"

