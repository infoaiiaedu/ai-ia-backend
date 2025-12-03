#!/bin/bash
# Backup automation script
# Backs up database and media files
# Usage: ./scripts/backup.sh [production|staging]

set -euo pipefail

ENVIRONMENT="${1:-production}"
BACKUP_ROOT="backups"
BACKUP_DIR="$BACKUP_ROOT/backup_${ENVIRONMENT}_$(date +%Y%m%d_%H%M%S)"
KEEP_BACKUPS=3

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

mkdir -p "$BACKUP_DIR"

log "Starting $ENVIRONMENT backup..."

# Database backup
if [ "$ENVIRONMENT" = "production" ]; then
    DB_NAME="aiia_prod"
else
    DB_NAME="aiia_staging"
fi

log "Backing up PostgreSQL database: $DB_NAME..."
docker exec aiia_postgresql pg_dump -U aiia -d "$DB_NAME" -F custom -f /tmp/backup.dump || \
    error "Database backup failed"

docker cp aiia_postgresql:/tmp/backup.dump "$BACKUP_DIR/database.dump" || \
    error "Failed to copy database backup"

log "Database backup completed"

# Media files backup
if [ -d "storage_${ENVIRONMENT}/media" ]; then
    log "Backing up media files..."
    tar -czf "$BACKUP_DIR/media.tar.gz" "storage_${ENVIRONMENT}/media" 2>/dev/null || \
        warn "Media backup had issues, continuing..."
    log "Media files backed up"
fi

# Configuration backup
if [ -d "config" ]; then
    log "Backing up configuration..."
    tar -czf "$BACKUP_DIR/config.tar.gz" "config" 2>/dev/null || true
    log "Configuration backed up"
fi

# Create manifest
cat > "$BACKUP_DIR/MANIFEST.txt" << EOF
Backup Manifest
===============
Environment: $ENVIRONMENT
Timestamp: $(date)
Hostname: $(hostname)
Database: $DB_NAME

Contents:
- database.dump: PostgreSQL dump (pg_dump format)
- media.tar.gz: User uploaded media files
- config.tar.gz: Application configuration

Restoration Commands:
1. Database: pg_restore -U aiia -d $DB_NAME -F custom database.dump
2. Media: tar -xzf media.tar.gz
3. Config: tar -xzf config.tar.gz

EOF

log "Backup created: $BACKUP_DIR"

# Cleanup old backups (keep only KEEP_BACKUPS)
log "Cleaning up old backups..."
BACKUP_COUNT=$(ls -d "$BACKUP_ROOT"/backup_${ENVIRONMENT}_* 2>/dev/null | wc -l)

if [ "$BACKUP_COUNT" -gt "$KEEP_BACKUPS" ]; then
    TO_DELETE=$((BACKUP_COUNT - KEEP_BACKUPS))
    ls -d "$BACKUP_ROOT"/backup_${ENVIRONMENT}_* | sort -r | tail -n "$TO_DELETE" | xargs -r rm -rf
    log "Deleted $TO_DELETE old backups"
fi

log "${GREEN}✓ Backup completed successfully${NC}"
log "Total backups kept: $(ls -d "$BACKUP_ROOT"/backup_${ENVIRONMENT}_* 2>/dev/null | wc -l)"
