#!/bin/bash
# Backup automation script
# Backs up database and media files
# Usage: ./scripts/backup.sh [production|staging]

set -euo pipefail

ENVIRONMENT="${1:-production}"
BACKUP_ROOT="backups"
BACKUP_DIR="$BACKUP_ROOT/backup_${ENVIRONMENT}_$(date +%Y%m%d_%H%M%S)"
# Keep only the latest encrypted backup due to storage constraints
KEEP_BACKUPS=1

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

# Create a compressed tarball of the backup directory
TAR_FILE="${BACKUP_DIR}.tar.gz"
log "Creating archive $TAR_FILE"
tar -C "$(dirname "$BACKUP_DIR")" -czf "$TAR_FILE" "$(basename "$BACKUP_DIR")" || error "Failed to create tar archive"

# Encrypt the tarball using GPG symmetric encryption (AES256)
if ! command -v gpg > /dev/null 2>&1; then
    error "gpg is required for encryption but not installed. Install gpg and retry."
fi

if [ -z "${BACKUP_PASSPHRASE:-}" ]; then
    error "BACKUP_PASSPHRASE is not set. Export BACKUP_PASSPHRASE before running this script to encrypt backups."
fi

ENC_FILE="${TAR_FILE}.gpg"
log "Encrypting backup to $ENC_FILE"
gpg --batch --yes --symmetric --cipher-algo AES256 --passphrase "$BACKUP_PASSPHRASE" -o "$ENC_FILE" "$TAR_FILE" || error "Encryption failed"

# Remove unencrypted artifacts to save space
rm -rf "$BACKUP_DIR" "$TAR_FILE"

# Cleanup old encrypted backups (keep only $KEEP_BACKUPS)
log "Cleaning up old encrypted backups (keeping $KEEP_BACKUPS)..."
OLD_BACKUPS=$(ls -1t "$BACKUP_ROOT"/backup_${ENVIRONMENT}_*.tar.gz.gpg 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) || true)
if [ -n "$OLD_BACKUPS" ]; then
    echo "$OLD_BACKUPS" | xargs -r rm -f
    log "Deleted old encrypted backups" 
fi

log "${GREEN}✓ Backup completed successfully${NC}"
log "Total encrypted backups kept: $(ls -1 "$BACKUP_ROOT"/backup_${ENVIRONMENT}_*.tar.gz.gpg 2>/dev/null | wc -l)"
