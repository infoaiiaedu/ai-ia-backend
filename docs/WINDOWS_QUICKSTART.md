# 🪟 Windows Quick Start Guide

## Running AI-IA Backend on Windows

Your development environment is now **RUNNING** on Windows! 🚀

### ✅ What's Running

- **Django**: http://localhost:9000
- **Nginx**: http://localhost:9080
- **PostgreSQL**: localhost:5432
- **Redis**: localhost:6379

### 📋 Container Status

All containers started successfully:
- ✓ Django (port 9000)
- ✓ Nginx (port 9080, 9443)
- ✓ PostgreSQL (port 5432, healthy)
- ✓ Redis (port 6379, healthy)

### 🚀 Quick Commands

**Start Development:**
```powershell
docker-compose -f docker-compose.local.yml up -d
```

**View Logs:**
```powershell
docker-compose -f docker-compose.local.yml logs -f django
```

**Stop Everything:**
```powershell
docker-compose -f docker-compose.local.yml down
```

**Open Django Shell:**
```powershell
docker-compose -f docker-compose.local.yml exec django python manage.py shell
```

**Run Migrations:**
```powershell
docker-compose -f docker-compose.local.yml exec django python manage.py migrate
```

**Create Superuser:**
```powershell
docker-compose -f docker-compose.local.yml exec django python manage.py createsuperuser
```

**Access Bash:**
```powershell
docker-compose -f docker-compose.local.yml exec django /bin/bash
```

### 🔗 Access Points

| Service | URL | Purpose |
|---------|-----|---------|
| Django Dev | http://localhost:9000 | Main application |
| Django Admin | http://localhost:9000/admin | Admin panel |
| Nginx | http://localhost:9080 | Reverse proxy (optional) |
| PostgreSQL | localhost:5432 | Database |
| Redis | localhost:6379 | Cache/Queue |

### 📊 Database Access

**Connection Details:**
- **Host**: localhost
- **Port**: 5432
- **Database**: aiia_dev
- **Username**: aiia_dev
- **Password**: dev_password_123

Connect from your machine or Docker:
```bash
psql -h localhost -U aiia_dev -d aiia_dev
```

### 🔧 Useful Scripts (Windows)

Two helper scripts available:

**Using Batch File (simplest):**
```cmd
dev.bat start          # Start environment
dev.bat logs           # View logs
dev.bat stop           # Stop environment
dev.bat status         # Show container status
dev.bat shell          # Open Django shell
dev.bat help           # Show all commands
```

**Using PowerShell:**
```powershell
.\dev.ps1 start        # Start environment
.\dev.ps1 logs         # View logs
.\dev.ps1 stop         # Stop environment
```

### 🐛 Troubleshooting

**Port Already in Use?**
If ports 9000, 9080, 9432, 9379 are in use, modify docker-compose.local.yml:
```yaml
ports:
  - "9001:8000"    # Change 9000 to 9001
  - "9081:80"      # Change 9080 to 9081
  # etc...
```

**Docker Daemon Issues?**
```powershell
# Restart Docker Desktop or:
docker-compose -f docker-compose.local.yml restart
```

**Permission Denied on Port?**
Windows Firewall sometimes blocks ports. This is expected - Docker tries lower ports first. The current configuration (9000, 9080, etc.) should work.

**Can't Connect to Database?**
```powershell
# Check if PostgreSQL container is healthy
docker-compose -f docker-compose.local.yml ps

# View PostgreSQL logs
docker logs aiia_dev_postgresql
```

### 📁 Project Structure

```
c:\Users\gio20\Desktop\ai-ia-backend\
├── code/                    # Django application
├── docker/                  # Docker configuration
│   ├── Dockerfile.dev       # Development image
│   ├── nginx/              # Nginx configs
│   └── postgres/           # PostgreSQL configs
├── docker-compose.local.yml # Development orchestration
├── dev.bat                 # Windows batch helper
├── dev.ps1                 # Windows PowerShell helper
└── README.md               # Main documentation
```

### 🔄 Development Workflow

1. **Start Environment:**
   ```powershell
   docker-compose -f docker-compose.local.yml up -d
   ```

2. **Run Migrations:**
   ```powershell
   docker-compose -f docker-compose.local.yml exec django python manage.py migrate
   ```

3. **Create Admin User:**
   ```powershell
   docker-compose -f docker-compose.local.yml exec django python manage.py createsuperuser
   ```

4. **Access Application:**
   - Frontend: http://localhost:9000
   - Admin: http://localhost:9000/admin

5. **Make Changes:**
   - Edit files in `code/` - they sync to container automatically
   - Django auto-reloads on file changes

6. **View Logs:**
   ```powershell
   docker-compose -f docker-compose.local.yml logs -f django
   ```

7. **Stop When Done:**
   ```powershell
   docker-compose -f docker-compose.local.yml down
   ```

### 💾 Data Persistence

- **PostgreSQL data** → `storage/db/pgdata/`
- **Redis data** → Temporary (lost on down)
- **Media files** → `code/media/`
- **Static files** → `code/static/`

### 🚀 Next Steps

1. **Create a Superuser:**
   ```powershell
   docker-compose -f docker-compose.local.yml exec django python manage.py createsuperuser
   ```

2. **Visit Admin:**
   Navigate to http://localhost:9000/admin and log in

3. **Run Tests:**
   ```powershell
   docker-compose -f docker-compose.local.yml exec django python manage.py test
   ```

4. **Make Changes:**
   Edit code in `code/` folder - changes reflect immediately

### ⚙️ Important Notes

- **Ports Used**: 9000 (Django), 9080 (Nginx), 5432 (PostgreSQL), 6379 (Redis)
- **Auto-reload**: Django runserver auto-reloads on code changes
- **Database**: Persists between `down`/`up` cycles
- **Environment**: All set in docker-compose.local.yml

### 📚 Full Documentation

For comprehensive documentation:
- `README.md` - Complete setup guide
- `ARCHITECTURE.md` - System architecture
- `DEPLOYMENT.md` - Production deployment
- `IMPLEMENTATION_SUMMARY.md` - Feature overview

---

**Status**: ✅ Development environment running successfully on Windows!

Questions? Check logs: `docker-compose -f docker-compose.local.yml logs -f`
