#!/bin/bash
# Metrics API endpoint script
# Returns JSON with system metrics for monitoring dashboard
# Usage: This script is called by nginx or a simple HTTP server

set -euo pipefail

# Get system metrics
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 || echo "0")
MEMORY_TOTAL=$(free -m | awk '/^Mem:/ {print $2}')
MEMORY_USED=$(free -m | awk '/^Mem:/ {print $3}')
DISK_TOTAL=$(df -BG / | tail -1 | awk '{print $2}' | sed 's/G//')
DISK_USED=$(df -BG / | tail -1 | awk '{print $3}' | sed 's/G//')
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | xargs)

# Database metrics
DB_STATUS="unknown"
DB_PROD_SIZE="N/A"
DB_STAGING_SIZE="N/A"
PGBOUNCER_STATUS="unknown"

if docker ps | grep -q aiia_postgresql; then
    DB_STATUS="ok"
    DB_PROD_SIZE=$(docker exec aiia_postgresql psql -U aiia -d aiia_prod -c "SELECT pg_size_pretty(pg_database_size('aiia_prod'))" -t 2>/dev/null | xargs || echo "N/A")
    DB_STAGING_SIZE=$(docker exec aiia_postgresql psql -U aiia -d aiia_staging -c "SELECT pg_size_pretty(pg_database_size('aiia_staging'))" -t 2>/dev/null | xargs || echo "N/A")
else
    DB_STATUS="error"
fi

if docker ps | grep -q aiia_pgbouncer; then
    PGBOUNCER_STATUS="ok"
else
    PGBOUNCER_STATUS="error"
fi

# Redis metrics
REDIS_STATUS="unknown"
REDIS_MEMORY="N/A"

if docker ps | grep -q aiia_redis; then
    REDIS_STATUS="ok"
    REDIS_MEMORY=$(docker exec aiia_redis redis-cli info memory 2>/dev/null | grep used_memory_human | cut -d':' -f2 | xargs || echo "N/A")
else
    REDIS_STATUS="error"
fi

# Service status
SERVICES=()
CONTAINERS=("aiia_postgresql:PostgreSQL" "aiia_pgbouncer:PgBouncer" "aiia_redis:Redis" "aiia_django_prod:Django Prod" "aiia_django_staging:Django Staging" "aiia_nginx:Nginx")

for container_info in "${CONTAINERS[@]}"; do
    IFS=':' read -r container_name display_name <<< "$container_info"
    if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        SERVICES+=("{\"name\":\"${display_name}\",\"status\":\"ok\"}")
    else
        SERVICES+=("{\"name\":\"${display_name}\",\"status\":\"error\"}")
    fi
done

# Recent logs (last 50 lines)
LOGS=()
if docker ps | grep -q aiia_django_prod; then
    LOGS+=($(docker logs aiia_django_prod --tail 20 2>&1 | tail -20 | jq -R . 2>/dev/null || docker logs aiia_django_prod --tail 20 2>&1 | tail -20 | sed 's/"/\\"/g' | sed 's/^/"/' | sed 's/$/"/'))
fi
if docker ps | grep -q aiia_nginx; then
    LOGS+=($(docker logs aiia_nginx --tail 20 2>&1 | tail -20 | jq -R . 2>/dev/null || docker logs aiia_nginx --tail 20 2>&1 | tail -20 | sed 's/"/\\"/g' | sed 's/^/"/' | sed 's/$/"/'))
fi

# Build JSON response
cat <<EOF
{
  "cpu_usage": ${CPU_USAGE},
  "memory_total": ${MEMORY_TOTAL},
  "memory_used": ${MEMORY_USED},
  "disk_total": ${DISK_TOTAL},
  "disk_used": ${DISK_USED},
  "load_avg": "${LOAD_AVG}",
  "db_status": "${DB_STATUS}",
  "db_prod_size": "${DB_PROD_SIZE}",
  "db_staging_size": "${DB_STAGING_SIZE}",
  "pgbouncer_status": "${PGBOUNCER_STATUS}",
  "redis_status": "${REDIS_STATUS}",
  "redis_memory": "${REDIS_MEMORY}",
  "services": [$(IFS=','; echo "${SERVICES[*]}")],
  "logs": [$(IFS=','; echo "${LOGS[*]}")]
}
EOF

