#!/bin/bash
# Health monitoring script
# Checks system and service health
# Usage: ./scripts/monitor.sh

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
}

check_status() {
    local name=$1
    local command=$2
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $name"
        return 0
    else
        echo -e "${RED}✗${NC} $name"
        return 1
    fi
}

print_metric() {
    local name=$1
    local value=$2
    local warn_threshold=$3
    
    if [ -z "$warn_threshold" ]; then
        echo "  $name: $value"
    else
        if (( $(echo "$value > $warn_threshold" | bc -l) )); then
            echo -e "${YELLOW}  $name: $value (WARNING)${NC}"
        else
            echo -e "  $name: $value"
        fi
    fi
}

# System information
print_header "System Resources"

# CPU
CPU_COUNT=$(nproc)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
print_metric "CPU Cores" "$CPU_COUNT"
print_metric "CPU Usage" "${CPU_USAGE}%" 80

# Memory
TOTAL_MEM=$(free -h | awk '/^Mem:/ {print $2}')
USED_MEM=$(free -h | awk '/^Mem:/ {print $3}')
MEM_PERCENT=$(free | awk '/^Mem:/ {printf("%.1f", $3/$2 * 100)}')
print_metric "Memory Total" "$TOTAL_MEM"
print_metric "Memory Used" "$USED_MEM ($MEM_PERCENT%)" 80

# Disk
DISK_INFO=$(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')
DISK_PERCENT=$(df / | tail -1 | awk '{print $5}' | cut -d'%' -f1)
print_metric "Disk Usage" "$DISK_INFO" 80

# Load average
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}')
print_metric "Load Average (1/5/15m)" "$LOAD_AVG"

# Container Status
print_header "Docker Containers"

if ! docker ps > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker daemon not running${NC}"
    exit 1
fi

CONTAINERS=("aiia_postgresql" "aiia_pgbouncer" "aiia_redis" "aiia_django_prod" "aiia_django_staging" "aiia_nginx")

for container in "${CONTAINERS[@]}"; do
    if docker ps -a --filter "name=$container" --format "table {{.Status}}" | grep -q "Up"; then
        STATUS=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓${NC} $container ($STATUS)"
    else
        echo -e "${RED}✗${NC} $container (stopped)"
    fi
done

# Database Health
print_header "Database Health"

check_status "PostgreSQL Connection" "docker exec aiia_postgresql pg_isready -U aiia" || true
check_status "PgBouncer Connection" "docker exec aiia_pgbouncer psql -U aiia -d aiia_prod -c 'SELECT 1' > /dev/null 2>&1" || true

# Get database sizes
echo ""
PROD_SIZE=$(docker exec aiia_postgresql psql -U aiia -d aiia_prod -c "SELECT pg_size_pretty(pg_database_size('aiia_prod'))" -t 2>/dev/null || echo "N/A")
STAGING_SIZE=$(docker exec aiia_postgresql psql -U aiia -d aiia_staging -c "SELECT pg_size_pretty(pg_database_size('aiia_staging'))" -t 2>/dev/null || echo "N/A")

print_metric "Production DB Size" "$PROD_SIZE"
print_metric "Staging DB Size" "$STAGING_SIZE"

# Redis Health
print_header "Redis Cache"

check_status "Redis Service" "docker exec aiia_redis redis-cli ping" || true

REDIS_INFO=$(docker exec aiia_redis redis-cli info memory 2>/dev/null | grep used_memory_human | cut -d':' -f2 || echo "N/A")
print_metric "Redis Memory Usage" "$REDIS_INFO"

# Django Health
print_header "Django Applications"

echo "Production:"
check_status "  Health Endpoint" "curl -sf http://localhost:8000/health/ > /dev/null" || true

echo "Staging:"
check_status "  Health Endpoint" "curl -sf http://localhost:8001/health/ > /dev/null" || true

# Nginx Health
print_header "Nginx Reverse Proxy"

check_status "Nginx Service" "curl -sf http://localhost/health > /dev/null" || true

# Connections
NGINX_CONNECTIONS=$(netstat -an 2>/dev/null | grep ESTABLISHED | wc -l || echo "N/A")
print_metric "Active Connections" "$NGINX_CONNECTIONS"

# Logs summary
print_header "Log Files (Recent Errors)"

echo "Django Production (last 5 errors):"
docker logs aiia_django_prod 2>&1 | grep -i error | tail -5 || echo "  No recent errors"

echo ""
echo "Nginx (last 5 errors):"
docker logs aiia_nginx 2>&1 | grep -i error | tail -5 || echo "  No recent errors"

# Storage usage
print_header "Storage Usage"

if docker volume ls --format "table {{.Name}}" | grep -q "storage_prod"; then
    PROD_VOL=$(docker volume inspect storage_prod --format='{{.Mountpoint}}' 2>/dev/null)
    if [ -n "$PROD_VOL" ] && [ -d "$PROD_VOL" ]; then
        PROD_SIZE_DIR=$(du -sh "$PROD_VOL" 2>/dev/null | cut -f1)
        print_metric "Production Storage" "$PROD_SIZE_DIR"
    fi
fi

echo ""
print_header "Summary"
echo -e "${GREEN}✓ Monitoring check completed${NC}"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
