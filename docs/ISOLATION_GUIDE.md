# Environment Isolation Guide

## ✅ Complete Isolation Between Production and Staging

This document explains how production (`eduaiia.com`) and staging (`staging.eduaiia.com`) are completely isolated.

---

## 🏗️ Architecture Overview

### Directory Structure
```
/home/ubuntu/
├── main/
│   └── ai-ia-backend/          # Production deployment
│       ├── docker-compose.prod.yml
│       ├── .env                 # Production secrets
│       └── code/                # Production code
│
└── staging/
    └── ai-ia-backend/          # Staging deployment
        ├── docker-compose.staging.yml
        ├── .env                 # Staging secrets
        └── code/                # Staging code
```

### Key Isolation Points

1. **Separate Docker Compose Files**
   - Production: `docker-compose.prod.yml`
   - Staging: `docker-compose.staging.yml`
   - **No shared containers or networks**

2. **Separate Container Names**
   - Production: `aiia_prod_*` (e.g., `aiia_prod_django`, `aiia_prod_postgresql`)
   - Staging: `aiia_staging_*` (e.g., `aiia_staging_django`, `aiia_staging_postgresql`)

3. **Separate Docker Networks**
   - Production: `aiia_prod_network`
   - Staging: `aiia_staging_network`
   - **Complete network isolation**

4. **Separate Databases**
   - Production: `aiia_prod` database in `aiia_prod_postgresql`
   - Staging: `aiia_staging` database in `aiia_staging_postgresql`
   - **No shared database instance**

5. **Separate Storage Volumes**
   - Production: `storage_prod`, `pgdata_prod`, `redis_data_prod`
   - Staging: `storage_staging`, `pgdata_staging`, `redis_data_staging`

6. **Separate Ports**
   - Production Nginx: `80:80`, `443:443`
   - Staging Nginx: `8080:80`, `8443:443` (internal, nginx routes by domain)
   - Production Django: `8000` (internal)
   - Staging Django: `8001` (internal)

7. **Separate Environment Variables**
   - Production: `.env` in `/home/ubuntu/main/ai-ia-backend/`
   - Staging: `.env` in `/home/ubuntu/staging/ai-ia-backend/`
   - Different `SECRET_KEY`, `ALLOWED_HOSTS`, etc.

---

## 🔒 Isolation Guarantees

### ✅ When You Deploy to Production (`main` branch)

**What happens:**
1. GitHub Actions deploys to `/home/ubuntu/main/ai-ia-backend/`
2. Uses `docker-compose.prod.yml`
3. Creates/updates only `aiia_prod_*` containers
4. Uses `aiia_prod_network` network
5. Connects to `aiia_prod` database only
6. Nginx routes `eduaiia.com` → `aiia_prod_django:8000`

**What does NOT happen:**
- ❌ Does NOT touch staging containers
- ❌ Does NOT use staging database
- ❌ Does NOT affect `staging.eduaiia.com`
- ❌ Does NOT use staging routes/configs

### ✅ When You Deploy to Staging (`staging` branch)

**What happens:**
1. GitHub Actions deploys to `/home/ubuntu/staging/ai-ia-backend/`
2. Uses `docker-compose.staging.yml`
3. Creates/updates only `aiia_staging_*` containers
4. Uses `aiia_staging_network` network
5. Connects to `aiia_staging` database only
6. Nginx routes `staging.eduaiia.com` → `aiia_staging_django:8001`

**What does NOT happen:**
- ❌ Does NOT touch production containers
- ❌ Does NOT use production database
- ❌ Does NOT affect `eduaiia.com`
- ❌ Does NOT use production routes/configs

---

## 🌐 Nginx Routing

### Production Nginx (`aiia_prod_nginx`)
- **Domain:** `eduaiia.com`, `www.eduaiia.com`
- **Config:** `docker/nginx/prod.conf`
- **Backend:** `aiia_prod_django:8000`
- **Ports:** `80:80`, `443:443` (host)

### Staging Nginx (`aiia_staging_nginx`)
- **Domain:** `staging.eduaiia.com`
- **Config:** `docker/nginx/staging.conf`
- **Backend:** `aiia_staging_django:8001`
- **Ports:** `8080:80`, `8443:443` (host, but nginx routes by domain)

**Note:** Both nginx containers can run simultaneously because:
- They use different container names
- They're on different networks
- They route by `server_name` (domain), not port

---

## 🧪 Verification Commands

### Check Production Containers
```bash
cd /home/ubuntu/main/ai-ia-backend
docker-compose -f docker-compose.prod.yml ps
# Should show: aiia_prod_django, aiia_prod_postgresql, aiia_prod_nginx, etc.
```

### Check Staging Containers
```bash
cd /home/ubuntu/staging/ai-ia-backend
docker-compose -f docker-compose.staging.yml ps
# Should show: aiia_staging_django, aiia_staging_postgresql, aiia_staging_nginx, etc.
```

### Verify Network Isolation
```bash
# Production network
docker network inspect aiia_prod_network
# Should only contain aiia_prod_* containers

# Staging network
docker network inspect aiia_staging_network
# Should only contain aiia_staging_* containers
```

### Verify Database Isolation
```bash
# Production database
docker exec aiia_prod_postgresql psql -U aiia -l
# Should show: aiia_prod (only)

# Staging database
docker exec aiia_staging_postgresql psql -U aiia -l
# Should show: aiia_staging (only)
```

---

## 🚀 Deployment Process

### Production Deployment (`main` branch)
```bash
# GitHub Actions automatically:
1. cd /home/ubuntu/main/ai-ia-backend
2. git checkout origin/main
3. docker-compose -f docker-compose.prod.yml build django_prod
4. docker-compose -f docker-compose.prod.yml up -d
```

### Staging Deployment (`staging` branch)
```bash
# GitHub Actions automatically:
1. cd /home/ubuntu/staging/ai-ia-backend
2. git checkout origin/staging
3. docker-compose -f docker-compose.staging.yml build django_staging
4. docker-compose -f docker-compose.staging.yml up -d
```

---

## ⚠️ Important Notes

1. **No Shared State**: Production and staging are completely independent
2. **Separate Secrets**: Each environment has its own `.env` file
3. **Separate Code**: Each directory has its own code checkout
4. **Separate Deployments**: Pushing to `main` only affects production, pushing to `staging` only affects staging
5. **No Conflicts**: Container names, networks, and volumes are all prefixed differently

---

## 🔍 Troubleshooting

### Issue: Containers conflict
**Solution:** Make sure you're using the correct compose file:
- Production: `docker-compose -f docker-compose.prod.yml`
- Staging: `docker-compose -f docker-compose.staging.yml`

### Issue: Wrong domain routing
**Solution:** Check nginx configs:
- Production: `docker/nginx/prod.conf` → `server_name eduaiia.com`
- Staging: `docker/nginx/staging.conf` → `server_name staging.eduaiia.com`

### Issue: Database connection errors
**Solution:** Verify environment variables:
- Production: `DB_NAME=aiia_prod`, `DB_HOST=pgbouncer` (resolves to `aiia_prod_pgbouncer`)
- Staging: `DB_NAME=aiia_staging`, `DB_HOST=pgbouncer` (resolves to `aiia_staging_pgbouncer`)

---

## ✅ Summary

**Production and staging are 100% isolated:**
- ✅ Separate directories
- ✅ Separate docker-compose files
- ✅ Separate containers
- ✅ Separate networks
- ✅ Separate databases
- ✅ Separate storage
- ✅ Separate nginx configs
- ✅ Separate environment variables

**Deploying to one environment will NEVER affect the other!**

