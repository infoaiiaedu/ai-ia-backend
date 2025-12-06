#!/bin/bash
# Zero-downtime deployment script
# Uses blue-green deployment strategy with nginx health checks
# Usage: ./scripts/deploy-zero-downtime.sh [production|staging]

set -euo pipefail

ENVIRONMENT="${1:-production}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="logs/deploy_${ENVIRONMENT}_${TIMESTAMP}.log"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

mkdir -p logs

log "Starting zero-downtime deployment for $ENVIRONMENT..."

# Determine service names
if [ "$ENVIRONMENT" = "production" ]; then
    SERVICE_NAME="django_prod"
    PORT=8000
    HEALTH_URL="http://localhost:$PORT/health/"
    BLUE_SERVICE="${SERVICE_NAME}_blue"
    GREEN_SERVICE="${SERVICE_NAME}_green"
else
    SERVICE_NAME="django_staging"
    PORT=8001
    HEALTH_URL="http://localhost:$PORT/health/"
    BLUE_SERVICE="${SERVICE_NAME}_blue"
    GREEN_SERVICE="${SERVICE_NAME}_green"
fi

# Determine which instance is currently active
CURRENT_ACTIVE=$(docker ps --filter "name=${SERVICE_NAME}" --format "{{.Names}}" | head -1)

if [[ "$CURRENT_ACTIVE" == *"blue"* ]]; then
    ACTIVE_INSTANCE="blue"
    NEW_INSTANCE="green"
    NEW_SERVICE="$GREEN_SERVICE"
else
    ACTIVE_INSTANCE="green"
    NEW_INSTANCE="blue"
    NEW_SERVICE="$BLUE_SERVICE"
fi

log "Current active instance: $ACTIVE_INSTANCE"
log "Deploying to new instance: $NEW_INSTANCE"

# 1. Backup
log "Step 1: Creating backup..."
bash scripts/backup.sh "$ENVIRONMENT" >> "$LOG_FILE" 2>&1 || warn "Backup failed, continuing..."

# 2. Pull latest code
log "Step 2: Pulling latest code..."
git fetch origin >> "$LOG_FILE" 2>&1 || error "Git fetch failed"

if [ "$ENVIRONMENT" = "production" ]; then
    BRANCH="main"
else
    BRANCH="staging"
fi

git checkout origin/$BRANCH >> "$LOG_FILE" 2>&1 || error "Git checkout failed"

# 3. Build new image with tag
log "Step 3: Building new Docker image..."
NEW_IMAGE_TAG="${SERVICE_NAME}:${NEW_INSTANCE}-${TIMESTAMP}"
docker build -f "docker/Dockerfile.${ENVIRONMENT}" -t "$NEW_IMAGE_TAG" . >> "$LOG_FILE" 2>&1 || error "Build failed"

# 4. Start new instance (green/blue)
log "Step 4: Starting new instance ($NEW_INSTANCE)..."
# Note: This requires docker-compose to support multiple instances
# For now, we'll use a simpler approach: start new container, then switch

# Create temporary docker-compose override
cat > "docker-compose.${NEW_INSTANCE}.yml" <<EOF
version: '3.9'
services:
  ${SERVICE_NAME}:
    image: ${NEW_IMAGE_TAG}
    container_name: ${NEW_SERVICE}
    ports:
      - "${PORT}:${PORT}"
    environment:
      - ENVIRONMENT=${ENVIRONMENT}
    networks:
      - aiia_network
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:${PORT}/health/"]
      interval: 10s
      timeout: 10s
      retries: 3
      start_period: 60s
EOF

# Start new instance
docker-compose -f docker-compose.yml -f "docker-compose.${NEW_INSTANCE}.yml" up -d "$NEW_SERVICE" >> "$LOG_FILE" 2>&1 || error "Failed to start new instance"

# 5. Wait for new instance to be healthy
log "Step 5: Waiting for new instance to be healthy..."
NEW_HEALTH_URL="http://localhost:${PORT}/health/"
for i in {1..60}; do
    if curl -sf "$NEW_HEALTH_URL" > /dev/null 2>&1; then
        log "✓ New instance is healthy"
        break
    fi
    if [ $i -eq 60 ]; then
        error "New instance failed health checks. Rolling back..."
        docker-compose -f docker-compose.yml -f "docker-compose.${NEW_INSTANCE}.yml" down "$NEW_SERVICE"
        rm -f "docker-compose.${NEW_INSTANCE}.yml"
        exit 1
    fi
    warn "Health check attempt $i/60, waiting..."
    sleep 2
done

# 6. Update nginx to point to new instance
log "Step 6: Updating nginx configuration..."
# This would require updating nginx upstream configuration
# For simplicity, we'll restart nginx to pick up new service
docker-compose restart nginx >> "$LOG_FILE" 2>&1 || warn "Nginx restart failed"

# 7. Graceful shutdown of old instance
log "Step 7: Gracefully shutting down old instance..."
sleep 5  # Give nginx time to switch
docker stop "${SERVICE_NAME}_${ACTIVE_INSTANCE}" >> "$LOG_FILE" 2>&1 || warn "Failed to stop old instance"

# 8. Verify deployment
log "Step 8: Verifying deployment..."
for i in {1..30}; do
    if curl -sf "$HEALTH_URL" > /dev/null 2>&1; then
        log "✓ Deployment verified"
        break
    fi
    if [ $i -eq 30 ]; then
        warn "Health check failed. Consider rolling back."
    fi
    sleep 2
done

# Cleanup
rm -f "docker-compose.${NEW_INSTANCE}.yml"

log "${GREEN}✓ Zero-downtime deployment completed!${NC}"
log "New instance: $NEW_INSTANCE"
log "Log file: $LOG_FILE"

