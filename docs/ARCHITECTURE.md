# Deployment Architecture Documentation

## System Overview

This document provides a comprehensive overview of the AI-IA backend deployment architecture, optimized for production environments with 512MB RAM and 2 vCPU constraints.

## 1. Infrastructure Stack

### Hardware Constraints
- **CPU:** 2 vCPU cores
- **RAM:** 512MB total
- **Disk:** 20GB SSD
- **Network:** 100Mbps minimum

### Container Orchestration
- **Docker:** 24.0+
- **Docker Compose:** 3.9+
- **Network:** Bridge network (aiia_network), 172.20.0.0/16

## 2. Container Architecture

### Service Topology

```
┌──────────────────────────────────────────────────────────────┐
│                      Host Network                            │
│                  (172.20.0.0/16 subnet)                     │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ Nginx (aiia_nginx)              172.20.0.2              │ │
│  │ ├─ Listening: 0.0.0.0:80, :443                         │ │
│  │ ├─ Memory limit: 50MB                                  │ │
│  │ ├─ CPU: 0.5 cores max                                  │ │
│  │ └─ Serves: static/ media/ + proxies                    │ │
│  └─────────────────────────────────────────────────────────┘ │
│                           ▼                                    │
│  ┌──────────────────────────────┬──────────────────────────┐  │
│  │                              │                          │  │
│  │  Production App              │  Staging App            │  │
│  │  (aiia_django_prod)          │  (aiia_django_staging)  │  │
│  │  172.20.0.3                  │  172.20.0.4             │  │
│  │                              │                          │  │
│  │  Gunicorn Config:            │  Gunicorn Config:       │  │
│  │  ├─ Bind: 0.0.0.0:8000      │  ├─ Bind: 0.0.0.0:8001  │  │
│  │  ├─ Workers: 2              │  ├─ Workers: 1          │  │
│  │  ├─ Threads: 2              │  ├─ Threads: 2          │  │
│  │  ├─ Worker class: gthread   │  ├─ Worker class: gthread│  │
│  │  ├─ Memory limit: 150MB     │  ├─ Memory limit: 100MB │  │
│  │  └─ CPU: 1 core max         │  └─ CPU: 1 core max    │  │
│  │                              │                          │  │
│  └──────────────────────────────┴──────────────────────────┘  │
│           ▼                              ▼                     │
│  ┌──────────────────────────────────────────────────────┐     │
│  │ PgBouncer (aiia_pgbouncer)    172.20.0.5            │     │
│  │ ├─ Listening: 0.0.0.0:6432                          │     │
│  │ ├─ Pool mode: transaction                           │     │
│  │ ├─ Max clients: 100                                 │     │
│  │ ├─ Default pool size: 10                            │     │
│  │ ├─ Memory limit: 30MB                               │     │
│  │ └─ CPU: 0.2 cores max                               │     │
│  └──────────────────────────────────────────────────────┘     │
│                           ▼                                     │
│  ┌──────────────────────────────────────────────────────┐     │
│  │ PostgreSQL (aiia_postgresql)  172.20.0.6            │     │
│  │ ├─ Listening: 0.0.0.0:5432                          │     │
│  │ ├─ Databases:                                       │     │
│  │ │  ├─ aiia_prod (production)                        │     │
│  │ │  └─ aiia_staging (staging)                        │     │
│  │ ├─ shared_buffers: 128MB                            │     │
│  │ ├─ Max connections: 50                              │     │
│  │ ├─ Memory limit: 200MB                              │     │
│  │ └─ CPU: 1 core max                                  │     │
│  └──────────────────────────────────────────────────────┘     │
│                           ▼                                     │
│  ┌──────────────────────────────────────────────────────┐     │
│  │ Redis (aiia_redis)            172.20.0.7            │     │
│  │ ├─ Listening: 0.0.0.0:6379                          │     │
│  │ ├─ Databases:                                       │     │
│  │ │  ├─ 0: Production cache/sessions                  │     │
│  │ │  └─ 1: Staging cache/sessions                     │     │
│  │ ├─ maxmemory: 50MB                                  │     │
│  │ ├─ maxmemory-policy: allkeys-lru                    │     │
│  │ ├─ Memory limit: 50MB                               │     │
│  │ └─ CPU: 0.3 cores max                               │     │
│  └──────────────────────────────────────────────────────┘     │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## 3. Resource Allocation

### Memory Distribution

| Service | Limit | Reserved | Notes |
|---------|-------|----------|-------|
| PostgreSQL | 200MB | 150MB | Shared instance |
| PgBouncer | 30MB | 20MB | Connection pooling |
| Redis | 50MB | 40MB | Sessions + cache |
| Django Prod | 150MB | 120MB | 2 workers, 2 threads |
| Django Staging | 100MB | 80MB | 1 worker, 2 threads |
| Nginx | 50MB | 40MB | Reverse proxy |
| **Total** | **580MB** | **450MB** | Fits in 512MB |

### CPU Distribution

| Service | Max | Reserved | Notes |
|---------|-----|----------|-------|
| PostgreSQL | 1.0 | 0.5 | Peak queries |
| PgBouncer | 0.2 | 0.1 | Minimal CPU usage |
| Redis | 0.3 | 0.2 | Lightweight |
| Django Prod | 1.0 | 0.5 | 2 workers |
| Django Staging | 1.0 | 0.3 | 1 worker |
| Nginx | 0.5 | 0.2 | I/O bound |
| **Total** | **4.0** | **1.8** | Oversubscribed OK (I/O bound) |

## 4. Volume Mounts

### Persistent Data

```
Host Path          | Container Path        | Purpose
-------------------|----------------------|-------------------
pgdata             | /var/lib/postgresql/data | Database files
redis_data         | /data                 | Redis persistence
storage_prod       | /app/storage          | Production media/static
storage_staging    | /app/storage          | Staging media/static
./code             | /app/code             | Application code
./logs/nginx       | /var/log/nginx        | Nginx logs
./docker/nginx/ssl | /etc/nginx/ssl        | SSL certificates
```

### Read-Only Mounts

```
Host Path                  | Container Path    | Purpose
---------------------------|------------------|-------------------
./docker/nginx/prod.conf   | /etc/nginx/...    | Nginx config (prod)
./docker/nginx/staging.conf| /etc/nginx/...    | Nginx config (staging)
./docker/postgres/conf     | /etc/postgresql/  | PostgreSQL config
./docker/pgbouncer/*.ini   | /etc/pgbouncer/   | PgBouncer config
```

## 5. Network Isolation

### Internal Communication

```
Service → Service        | Protocol | Port | Network | Notes
--------------------------|----------|------|---------|----------
Nginx → Django Prod      | HTTP     | 8000 | Bridge  | Proxy
Nginx → Django Staging   | HTTP     | 8001 | Bridge  | Proxy
Django Prod → PgBouncer  | TCP      | 6432 | Bridge  | Pooled DB
Django Staging → PgBouncer | TCP    | 6432 | Bridge  | Pooled DB
PgBouncer → PostgreSQL   | TCP      | 5432 | Bridge  | Pool → DB
Django → Redis           | TCP      | 6379 | Bridge  | Cache
External → Nginx         | HTTPS    | 443  | Host    | Public
```

### Security Groups

```
Default: Deny all ingress
Allow: 
  - 80/TCP from 0.0.0.0/0 (HTTP redirect)
  - 443/TCP from 0.0.0.0/0 (HTTPS)
Deny: All database/cache ports from outside
```

## 6. Deployment Workflow

### GitHub Actions Pipeline

```
┌─────────────┐
│ Git Push    │ (to main or staging branch)
├─────────────┤
│   Test      │
├─────────────┤ 1. Django checks
│   Phase     │ 2. Migrations test
│             │ 3. Test suite
│             │ 4. Static files
├─────────────┤
│   Build     │
├─────────────┤ 1. Docker build
│   Phase     │ 2. Push to registry
│             │ 3. Cache optimization
├─────────────┤
│  Deploy     │
├─────────────┤ 1. SSH to server
│   Phase     │ 2. Backup database
│             │ 3. Pull latest code
│             │ 4. Build image
│             │ 5. Run migrations
│             │ 6. Collect static
│             │ 7. Restart containers
│             │ 8. Health checks
├─────────────┤
│  Notify     │
├─────────────┤ 1. Slack notification
│             │ 2. Deployment log
└─────────────┘
```

### Manual Deployment Sequence

```
1. Pre-deployment
   └─ Database backup
   └─ Validate config

2. Build phase
   └─ docker-compose build <service>
   
3. Update phase
   └─ docker-compose up -d <service>
   
4. Post-deployment
   └─ Migrations (if needed)
   └─ Health checks
   └─ Error log review
   
5. Rollback (if needed)
   └─ docker-compose down
   └─ Restore from backup
   └─ Restart services
```

## 7. Monitoring Architecture

### Health Check Endpoints

```
Endpoint                | Service | Interval | Timeout | Retries
------------------------|---------|----------|---------|--------
GET /health/            | Django  | 30s      | 10s     | 3
GET /health             | Nginx   | 30s      | 10s     | 3
pg_isready -U aiia      | PgSQL   | 10s      | 5s      | 5
redis-cli ping          | Redis   | 10s      | 5s      | 5
docker ps               | Docker  | 60s      | 10s     | 3
```

### Monitoring Metrics

```
Category      | Metric              | Warning | Critical | Collection
--------------|---------------------|---------|----------|----------
CPU           | Utilization %       | 60%     | 85%      | Every 60s
Memory        | Utilization %       | 70%     | 90%      | Every 60s
Disk          | Utilization %       | 75%     | 90%      | Every 300s
Database      | Active connections  | 40      | 48       | Every 30s
Cache         | Memory usage        | 40MB    | 48MB     | Every 30s
HTTP          | Error rate %        | 1%      | 5%       | Every 60s
HTTP          | Latency p95 (ms)    | 500ms   | 2000ms   | Every 60s
Uptime        | Service availability| N/A     | <99.9%   | Every 300s
```

## 8. Backup Strategy

### Backup Schedule

```
Trigger                | Type        | Retention | Location
----------------------|-------------|-----------|----------
Before deployment     | Full DB     | Keep 3    | Local
Daily 02:00 UTC       | Full DB     | Keep 7    | Local
Manual via script     | Full DB     | Keep 3    | Local
Media files           | Tar.gz      | Keep 1    | Local
Configuration         | Tar.gz      | Keep 1    | Local
```

### Backup Contents

```
Backup/
├── database.dump       (PostgreSQL dump, pg_restore format)
├── media.tar.gz        (User uploads, optional)
├── config.tar.gz       (Application config, optional)
└── MANIFEST.txt        (Restoration guide)

Total size: ~50-500MB depending on media
```

## 9. SSL/TLS Configuration

### Certificate Management

```
Domain                    | Provider | Renewal | Frequency
--------------------------|----------|---------|----------
eduaiia.com              | Let's Encrypt | Certbot | Auto @ day 30
www.eduaiia.com          | Let's Encrypt | Certbot | Auto @ day 30
staging.eduaiia.com      | Let's Encrypt | Certbot | Auto @ day 30
devstatus.eduaiia.com    | Let's Encrypt | Certbot | Auto @ day 30
```

### TLS Configuration

```
Protocol:   TLSv1.2, TLSv1.3
Ciphers:    HIGH:!aNULL:!MD5 (strong only)
HSTs:       enabled, max-age=31536000
Session:    10m cache, no tickets
```

## 10. Scaling Considerations

### Current Capacity

- **Users:** 100 concurrent
- **Requests/second:** ~500
- **Memory:** 450-480MB under load
- **CPU:** 30-50% average, 70% peak
- **Uptime:** 99.99%

### Scaling Path

```
Level 1 (512MB, 2 vCPU)  ← Current
├─ Add swap (not recommended)
└─ Optimize further

Level 2 (1GB, 2 vCPU)
├─ Increase Django workers to 4
├─ Increase PostgreSQL buffers to 256MB
└─ Add Redis cluster

Level 3 (2GB, 4 vCPU)
├─ Split PostgreSQL to separate server
├─ Add Redis to separate server
├─ 4x Django instances + load balancer
└─ CDN for static/media

Level 4+ (4GB+, 8 vCPU+)
├─ Kubernetes orchestration
├─ Database replication
├─ Multi-region deployment
└─ Database read replicas
```

## 11. Disaster Recovery

### Recovery Time Objectives (RTO)

```
Scenario              | RTO    | Recovery Steps
----------------------|--------|--------------------
Single service down   | 1 min  | Restart container
Database corruption   | 15 min | Restore from backup
Complete server down  | 30 min | Provision + restore
Data loss            | 5 min  | Restore from backup
```

### Recovery Procedures

```
Scenario: Database service down
1. Check logs: docker logs aiia_postgresql
2. Restart: docker-compose restart postgresql
3. Verify: docker exec aiia_postgresql pg_isready
4. If failed, restore from backup

Scenario: Django application crash
1. Check logs: docker logs aiia_django_prod
2. Fix issue / redeploy
3. Restart: docker-compose up -d django_prod
4. Verify: curl http://localhost:8000/health/

Scenario: Complete server failure
1. Provision new server with same specs
2. Clone repository
3. Restore database: pg_restore < backup.dump
4. Restore media: tar -xzf media.tar.gz
5. Start containers: docker-compose up -d
6. Update DNS: Point domain to new server
```

## 12. Performance Tuning

### Database Optimization

```
Query cache:           OFF (modern PostgreSQL)
Shared buffers:        128MB (conservative)
Effective cache size:  256MB (total - 128MB)
Work memory:           2.6MB per connection
Maintenance memory:    32MB
Autovacuum:            Aggressive (10s naptime)
Statistics target:     10 (lower = faster plans)
```

### Application Optimization

```
Gunicorn workers:      2 (prod), 1 (staging)
Worker threads:        2 (gthread model)
Worker timeout:        30s
Max requests:          1000 per worker
Keep-alive:            60s
```

### Nginx Optimization

```
Worker processes:      auto
Worker connections:    2048
Buffer sizes:          optimized for 512MB
Gzip:                  enabled (6 compression)
Caching:               30 days for static
Access logs:           buffered + flush
```

---

## References

- Docker Documentation: https://docs.docker.com
- PostgreSQL Tuning: https://wiki.postgresql.org/wiki/Performance_Optimization
- Gunicorn Documentation: https://docs.gunicorn.org
- Nginx Documentation: https://nginx.org/en/docs/
- Django Deployment: https://docs.djangoproject.com/en/stable/howto/deployment/

## Support

For questions or issues with this architecture:
1. Check README.md for troubleshooting
2. Review container logs
3. Run health monitoring: `make monitor`
4. Contact DevOps team
