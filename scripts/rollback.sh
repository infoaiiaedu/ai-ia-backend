#!/bin/bash
# Deployment rollback script
# Usage: ./scripts/rollback.sh [production|staging] [commit-hash|previous]

set -euo pipefail

ENVIRONMENT="${1:-production}"
ROLLBACK_TARGET="${2:-previous}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Validate environment
if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "staging" ]]; then
    error "Invalid environment: $ENVIRONMENT"
fi

VERSION_FILE=".deployments/current_${ENVIRONMENT}.version"
PREVIOUS_VERSION_FILE=".deployments/previous_${ENVIRONMENT}.version"

log "Starting rollback for $ENVIRONMENT..."

# Determine target commit
if [ "$ROLLBACK_TARGET" = "previous" ]; then
    if [ ! -f "$PREVIOUS_VERSION_FILE" ]; then
        error "No previous version found. Cannot rollback."
    fi
    TARGET_COMMIT=$(cat "$PREVIOUS_VERSION_FILE")
    log "Rolling back to previous version: $TARGET_COMMIT"
elif [ "$ROLLBACK_TARGET" = "current" ]; then
    if [ ! -f "$VERSION_FILE" ]; then
        error "No current version found."
    fi
    TARGET_COMMIT=$(cat "$VERSION_FILE")
    log "Already at version: $TARGET_COMMIT"
    exit 0
else
    # Assume it's a commit hash
    TARGET_COMMIT="$ROLLBACK_TARGET"
    log "Rolling back to specified commit: $TARGET_COMMIT"
fi

# Verify commit exists
if ! git cat-file -e "$TARGET_COMMIT" 2>/dev/null; then
    error "Commit $TARGET_COMMIT not found in repository"
fi

# Backup current state
log "Creating backup before rollback..."
BACKUP_DIR="backups/rollback_${ENVIRONMENT}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

if [ "$ENVIRONMENT" = "production" ]; then
    DB_NAME="aiia_prod"
    CONTAINER="aiia_postgresql"
else
    DB_NAME="aiia_staging"
    CONTAINER="aiia_postgresql"
fi

docker exec "$CONTAINER" pg_dump -U aiia -d "$DB_NAME" -F custom -f /tmp/rollback_backup.dump 2>/dev/null || \
    warn "Database backup failed, continuing anyway..."

docker cp "$CONTAINER":/tmp/rollback_backup.dump "$BACKUP_DIR/database.dump" 2>/dev/null || true

# Checkout target commit
log "Checking out commit $TARGET_COMMIT..."
git checkout "$TARGET_COMMIT" || error "Failed to checkout commit"

# Save current version as previous
if [ -f "$VERSION_FILE" ]; then
    cp "$VERSION_FILE" "$PREVIOUS_VERSION_FILE" 2>/dev/null || true
fi

# Update current version
echo "$TARGET_COMMIT" > "$VERSION_FILE"

# Rebuild and restart
log "Rebuilding Docker images..."
if [ "$ENVIRONMENT" = "production" ]; then
    docker-compose build django_prod || error "Build failed"
    docker-compose up -d django_prod || error "Service restart failed"
    PORT=8000
else
    docker-compose build django_staging || error "Build failed"
    docker-compose up -d django_staging || error "Service restart failed"
    PORT=8001
fi

# Health check
log "Running health checks..."
sleep 10

HEALTH_URL="http://localhost:$PORT/health/"
for i in {1..30}; do
    if curl -sf "$HEALTH_URL" > /dev/null 2>&1; then
        log "${GREEN}✓ Rollback completed successfully!${NC}"
        log "Backup location: $BACKUP_DIR"
        exit 0
    fi
    if [ $i -eq 30 ]; then
        error "Health check failed after rollback. Manual intervention required."
    fi
    warn "Health check attempt $i/30, waiting..."
    sleep 2
done

