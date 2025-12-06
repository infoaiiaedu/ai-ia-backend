#!/bin/bash
# Setup cron jobs for automated tasks
# Usage: ./scripts/setup-cron.sh

set -euo pipefail

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

log "Setting up cron jobs for AI-IA Backend..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Backup existing crontab
CRON_BACKUP="/tmp/crontab_backup_$(date +%Y%m%d_%H%M%S)"
crontab -l > "$CRON_BACKUP" 2>/dev/null || true
log "Backed up existing crontab to $CRON_BACKUP"

# Production paths
PROD_DIR="/home/ubuntu/main/ai-ia-backend"
STAGING_DIR="/home/ubuntu/staging/ai-ia-backend"

# Create cron jobs
CRON_JOBS=()

# Daily backup for production (2 AM)
CRON_JOBS+=("0 2 * * * cd $PROD_DIR && bash scripts/backup.sh production >> logs/cron_backup.log 2>&1")

# Daily backup for staging (3 AM)
CRON_JOBS+=("0 3 * * * cd $STAGING_DIR && bash scripts/backup.sh staging >> logs/cron_backup.log 2>&1")

# SSL certificate renewal check (3 AM daily, only renews if <30 days)
CRON_JOBS+=("0 3 * * * cd $PROD_DIR && bash scripts/ssl-renew.sh >> logs/cron_ssl.log 2>&1")

# Log rotation (weekly, Sunday at 1 AM)
CRON_JOBS+=("0 1 * * 0 cd $PROD_DIR && logrotate -f /etc/logrotate.d/aiia-backend >> logs/cron_logrotate.log 2>&1")

# Monthly backup restoration test (1st of month at 4 AM)
CRON_JOBS+=("0 4 1 * * cd $PROD_DIR && bash scripts/backup-test.sh >> logs/cron_backup_test.log 2>&1")

# System monitoring (every 5 minutes)
CRON_JOBS+=("*/5 * * * * cd $PROD_DIR && bash scripts/monitor.sh >> logs/cron_monitor.log 2>&1")

# Display cron jobs
log "Cron jobs to be added:"
for job in "${CRON_JOBS[@]}"; do
    echo "  $job"
done

# Ask for confirmation
read -p "Add these cron jobs? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Cancelled. No cron jobs added."
    exit 0
fi

# Add cron jobs
(crontab -l 2>/dev/null || true; echo ""; echo "# AI-IA Backend automated tasks"; echo "# Added on $(date)"; for job in "${CRON_JOBS[@]}"; do echo "$job"; done) | crontab -

log "${GREEN}✓ Cron jobs added successfully${NC}"
log "View current crontab with: crontab -l"
log "Edit crontab with: crontab -e"
log "Remove all cron jobs with: crontab -r"

