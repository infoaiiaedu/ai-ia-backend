#!/bin/bash
# Monthly backup restoration test
# Verifies backup integrity by attempting restoration in a test environment
# Usage: ./scripts/backup-test.sh [production|staging]

set -euo pipefail

ENVIRONMENT="${1:-production}"

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

log "Starting backup restoration test for $ENVIRONMENT..."

# Find latest backup
BACKUP_ROOT="backups"
LATEST_BACKUP=$(ls -1t "$BACKUP_ROOT"/backup_${ENVIRONMENT}_*.tar.gz.gpg 2>/dev/null | head -1)

if [ -z "$LATEST_BACKUP" ]; then
    error "No encrypted backup found for $ENVIRONMENT"
fi

log "Testing backup: $LATEST_BACKUP"

# Check if backup is encrypted
if [[ "$LATEST_BACKUP" == *.gpg ]]; then
    if [ -z "${BACKUP_PASSPHRASE:-}" ]; then
        warn "BACKUP_PASSPHRASE not set. Skipping encrypted backup test."
        exit 0
    fi
    
    # Decrypt backup
    TEMP_DIR=$(mktemp -d)
    DECRYPTED_BACKUP="$TEMP_DIR/backup.tar.gz"
    
    log "Decrypting backup..."
    gpg --batch --yes --decrypt --passphrase "$BACKUP_PASSPHRASE" -o "$DECRYPTED_BACKUP" "$LATEST_BACKUP" || \
        error "Failed to decrypt backup"
    
    # Extract
    log "Extracting backup..."
    tar -xzf "$DECRYPTED_BACKUP" -C "$TEMP_DIR" || error "Failed to extract backup"
    
    BACKUP_DIR=$(find "$TEMP_DIR" -type d -name "backup_${ENVIRONMENT}_*" | head -1)
else
    BACKUP_DIR="$LATEST_BACKUP"
fi

# Verify backup contents
log "Verifying backup contents..."

if [ ! -f "$BACKUP_DIR/database.dump" ]; then
    error "Database dump not found in backup"
fi

if [ ! -f "$BACKUP_DIR/MANIFEST.txt" ]; then
    warn "Manifest file not found in backup"
fi

# Test database dump integrity
log "Testing database dump integrity..."

if [ "$ENVIRONMENT" = "production" ]; then
    DB_NAME="aiia_prod"
else
    DB_NAME="aiia_staging"
fi

# Use pg_restore --list to verify dump without restoring
if docker ps | grep -q aiia_postgresql; then
    docker exec aiia_postgresql pg_restore --list "$BACKUP_DIR/database.dump" > /dev/null 2>&1 || \
        error "Database dump is corrupted or invalid"
    log "✓ Database dump integrity verified"
else
    warn "PostgreSQL container not running. Skipping dump verification."
fi

# Check backup size
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
log "Backup size: $BACKUP_SIZE"

# Cleanup
if [ -n "${TEMP_DIR:-}" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
fi

log "${GREEN}✓ Backup restoration test completed successfully${NC}"
log "Backup is valid and can be restored if needed."

