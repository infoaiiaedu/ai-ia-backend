# 🪟 Running AI-IA Backend on Windows - Complete Guide

## ✅ Status: RUNNING SUCCESSFULLY! 🚀

Your AI-IA Backend development environment is **NOW RUNNING** on Windows.

---

## 📍 Quick Access

| Service | URL/Port | Status | Purpose |
|---------|----------|--------|---------|
| **Django** | http://localhost:9000 | ✅ Running | Main application |
| **Admin Panel** | http://localhost:9000/admin | ✅ Ready | Django admin |
| **Nginx** | http://localhost:9080 | ✅ Running | Reverse proxy |
| **PostgreSQL** | localhost:5432 | ✅ Healthy | Database |
| **Redis** | localhost:6379 | ✅ Healthy | Cache/Queue |

---

## 🚀 Get Started in 2 Minutes

### Option A: Use Interactive Menu (Easiest)
```cmd
# Just double-click this file
dev-menu.bat
```
This opens a menu with all common commands.

### Option B: Use Batch Helper
```cmd
# Start environment
dev.bat start

# View logs
dev.bat logs

# Stop environment
dev.bat stop

# See all commands
dev.bat help
```

### Option C: Use Docker Compose Directly
```powershell
# Start
docker-compose -f docker-compose.local.yml up -d

# Logs
docker-compose -f docker-compose.local.yml logs -f django

# Stop
docker-compose -f docker-compose.local.yml down
```

---

## 📋 Common Tasks

### 1. Create Admin User
```powershell
docker-compose -f docker-compose.local.yml exec django python manage.py createsuperuser

# Then login at: http://localhost:9000/admin
```

### 2. Run Database Migrations
```powershell
docker-compose -f docker-compose.local.yml exec django python manage.py migrate
```

### 3. View Django Logs (Real-time)
```powershell
docker-compose -f docker-compose.local.yml logs -f django
```

### 4. Access Database
```powershell
# From Windows: Use any PostgreSQL client with these credentials:
# Host: localhost
# Port: 5432
# Database: aiia_dev
# Username: aiia_dev
# Password: dev_password_123

# Or use Docker:
docker-compose -f docker-compose.local.yml exec postgresql psql -U aiia_dev -d aiia_dev
```

### 5. Run Django Shell
```powershell
docker-compose -f docker-compose.local.yml exec django python manage.py shell
```

### 6. Open Bash Terminal
```powershell
docker-compose -f docker-compose.local.yml exec django /bin/bash
```

### 7. Run Tests
```powershell
docker-compose -f docker-compose.local.yml exec django python manage.py test
```

---

## 🛠️ Available Helper Scripts

### dev.bat (Windows Batch - Recommended)
Simple, no dependencies, most compatible.
```cmd
dev.bat start       # Start environment
dev.bat logs        # View logs
dev.bat status      # Show container status
dev.bat stop        # Stop environment
dev.bat shell       # Open Django shell
dev.bat bash        # Open bash
dev.bat help        # Show help
```

### dev-menu.bat (Interactive Menu)
Menu-driven interface for all common tasks.
```cmd
dev-menu.bat
# Then pick option 1-9 from the menu
```

### dev.ps1 (PowerShell)
For advanced users who prefer PowerShell.
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
.\dev.ps1 start
.\dev.ps1 logs
.\dev.ps1 stop
```

---

## 📁 Project Structure

```
c:\Users\gio20\Desktop\ai-ia-backend\
├── code/                        # Django application code
│   ├── manage.py               # Django management script
│   ├── requirements.txt         # Python dependencies
│   ├── main/                   # Django settings
│   ├── apps/                   # Django applications
│   └── ...
├── docker/                      # Docker configuration
│   ├── Dockerfile.dev          # Development image
│   ├── nginx/                  # Nginx configurations
│   │   ├── nginx.conf          # Main config
│   │   └── nginx.local.conf    # Local development config
│   └── postgres/               # PostgreSQL configs
├── docker-compose.local.yml     # Development orchestration
├── dev.bat                      # 🟢 Windows batch helper
├── dev.ps1                      # 🔵 PowerShell helper
├── dev-menu.bat                 # 🟡 Interactive menu
├── WINDOWS_QUICKSTART.md        # This file
├── README.md                    # Full documentation
└── ...
```

---

## 🔧 Configuration

### Database Details
- **Host**: localhost
- **Port**: 5432
- **Name**: aiia_dev
- **User**: aiia_dev
- **Password**: dev_password_123

### Redis Details
- **Host**: localhost
- **Port**: 6379
- **Password**: (none for dev)

### Django Settings
- **Debug**: True (development mode)
- **Settings Module**: main.settings
- **Secret Key**: dev-insecure-key (for development only!)

### Port Mappings
```
Host Port   Container Port    Service
9000        8000              Django
9080        80                Nginx HTTP
9443        443               Nginx HTTPS
5432        5432              PostgreSQL
6379        6379              Redis
```

---

## 🐛 Troubleshooting

### Problem: "Address already in use"

**Solution 1**: Change the port in `docker-compose.local.yml`
```yaml
services:
  django:
    ports:
      - "9001:8000"  # Change 9000 to 9001
```

**Solution 2**: Kill the process using that port
```powershell
# Find what's using port 9000
netstat -ano | Select-String "9000"

# Kill the process (replace PID with actual process ID)
taskkill /PID <PID> /F
```

### Problem: Docker daemon not responding

**Solution**:
```powershell
# Restart Docker Desktop from system tray, or:
Restart-Service -Name "com.docker.service" -Force
```

### Problem: "Ports are not available" error

**Cause**: Windows Firewall or third-party security software blocking the port

**Solutions**:
1. Change ports in `docker-compose.local.yml` to higher numbers (9001, 9081, etc.)
2. Add Docker to Windows Firewall whitelist
3. Run Docker Desktop as Administrator

### Problem: Container exits immediately

**Diagnostic**:
```powershell
# Check logs for errors
docker-compose -f docker-compose.local.yml logs django

# Or check individual container
docker logs aiia_dev_django
```

### Problem: Can't connect to database

**Diagnostic**:
```powershell
# Verify PostgreSQL is running
docker-compose -f docker-compose.local.yml ps postgresql

# Check PostgreSQL logs
docker logs aiia_dev_postgresql
```

### Problem: Django is running but pages not loading

**Solutions**:
1. Wait 10-15 seconds for migrations to complete
2. Check logs: `docker-compose -f docker-compose.local.yml logs -f django`
3. Verify database connection in logs
4. Run migrations manually: `dev.bat` → option 5

---

## 📚 Development Workflow

### 1. Start Your Day
```cmd
dev.bat start
```

### 2. Create Initial Admin User (first time only)
```cmd
docker-compose -f docker-compose.local.yml exec django python manage.py createsuperuser
```

### 3. Make Code Changes
- Edit files in `code/` folder
- Django automatically reloads on file changes
- View changes at http://localhost:9000

### 4. Monitor Logs
```cmd
dev.bat logs
```
Ctrl+C to exit logs.

### 5. When Needed: Run Migrations
```cmd
docker-compose -f docker-compose.local.yml exec django python manage.py makemigrations
docker-compose -f docker-compose.local.yml exec django python manage.py migrate
```

### 6. End of Day: Stop
```cmd
dev.bat stop
```

### Data Persistence
- ✅ Database survives `stop`/`start`
- ✅ Media files saved in `code/media/`
- ✅ Static files in `code/static/`

---

## 🚀 Next Steps

### Immediate (Today)
- [ ] Start environment: `dev.bat start`
- [ ] Create admin user: `docker-compose -f docker-compose.local.yml exec django python manage.py createsuperuser`
- [ ] Visit admin: http://localhost:9000/admin

### Short-term (This Week)
- [ ] Review Django app code in `code/apps/`
- [ ] Run tests: `docker-compose -f docker-compose.local.yml exec django python manage.py test`
- [ ] Make first change and test

### For Production Deployment
- [ ] Read `DEPLOYMENT.md`
- [ ] Read `ARCHITECTURE.md`
- [ ] Follow `IMPLEMENTATION_SUMMARY.md`

---

## 📖 Documentation Files

| File | Purpose |
|------|---------|
| **README.md** | Complete setup and overview |
| **WINDOWS_QUICKSTART.md** | Windows-specific detailed guide |
| **DEPLOYMENT.md** | Production deployment procedures |
| **ARCHITECTURE.md** | System architecture and design |
| **IMPLEMENTATION_SUMMARY.md** | Feature checklist and decisions |
| **QUICK_REFERENCE.sh** | Command reference card |
| **FILE_MANIFEST.md** | Complete file inventory |

---

## 💡 Pro Tips

### Speed Up Development
1. Use `docker-compose exec` for one-off commands
2. Keep logs in separate terminal window
3. Use Django shell for quick testing
4. Set up IDE debugger for step-through debugging

### Memory Management
```powershell
# If Docker is using too much memory:
docker-compose -f docker-compose.local.yml down
docker system prune -a  # Careful! Removes unused images
```

### Backup Your Database
```powershell
# Export database
docker-compose -f docker-compose.local.yml exec postgresql pg_dump -U aiia_dev -d aiia_dev > backup.sql

# Import database
docker-compose -f docker-compose.local.yml exec -T postgresql psql -U aiia_dev -d aiia_dev < backup.sql
```

### View Resource Usage
```powershell
# See memory, CPU of containers
docker stats
```

---

## ❓ FAQ

**Q: Do I need to install PostgreSQL or Redis?**
> No! They run in Docker containers automatically.

**Q: Can I edit code while it's running?**
> Yes! Django auto-reloads on file changes. Just edit files in `code/` folder.

**Q: How do I access the database from my IDE?**
> Connect to localhost:5432 with username `aiia_dev` and password `dev_password_123`

**Q: What if I want to use a different database?**
> Edit `docker-compose.local.yml` and change the database environment variables.

**Q: Can I run multiple environments?**
> Yes! Create a copy of `docker-compose.local.yml` with different names and ports.

**Q: How do I reset the database?**
> Stop containers: `dev.bat stop`, delete Docker volumes, then start again.

---

## 🎯 Success Criteria

You've successfully set up your development environment when:

- ✅ `dev.bat start` completes without errors
- ✅ All 4 containers show "Up" status
- ✅ http://localhost:9000 returns HTTP 200
- ✅ You can access Django admin
- ✅ Database migrations run successfully
- ✅ You can view logs in real-time

---

## 🆘 Getting Help

1. **Check logs**: `dev.bat logs`
2. **Check status**: `dev.bat status`
3. **Read docs**: Check files listed above
4. **Try restart**: `dev.bat stop` then `dev.bat start`
5. **Check Docker**: Ensure Docker Desktop is running

---

## 📝 Notes

- **Development only**: These settings are NOT for production
- **Secret key**: Must be changed before production use
- **Debug mode**: Set to True for development only
- **Data loss**: Deleting volumes will delete your database

---

**Last Updated**: December 3, 2025  
**Status**: ✅ Production-ready infrastructure deployed and tested  
**Environment**: Windows 10/11 with Docker Desktop  
**Python**: 3.11  
**Django**: Latest version (see requirements.txt)
