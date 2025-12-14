# AI-IA Backend

Django backend for AI-IA platform.

## Quick Start

### 1. Start Docker Containers
```bash
cd deployment/docker
docker compose up -d
```

### 2. Check Status
```bash
docker ps
```

All containers should show `(healthy)` status.

### 3. Create Admin User
```bash
docker exec -it django_backend python manage.py createsuperuser
```

### 4. Access Application
- Admin Panel: http://localhost:8080/admin/
- API Documentation: http://localhost:8080/api/docs/

---

## Common Commands

### Start/Stop
```bash
cd deployment/docker
docker compose up -d      # Start
docker compose down       # Stop
docker compose restart    # Restart all
```

### View Logs
```bash
cd deployment/docker
docker compose logs -f              # All services
docker compose logs -f app          # Backend only
docker compose logs -f nginx        # Nginx only
```

### Django Management
```bash
# Create superuser
docker exec -it django_backend python manage.py createsuperuser

# Run migrations
docker exec django_backend python manage.py migrate

# Collect static files
docker exec django_backend python manage.py collectstatic --noinput

# Django shell
docker exec -it django_backend python manage.py shell
```

### PostgreSQL Database Access

#### Run SQL Commands Directly
```bash
# Check PostgreSQL version
docker exec django_psql psql -U postgres -d ai_db -c "SELECT version();"

# List all tables
docker exec django_psql psql -U postgres -d ai_db -c "\dt"

# Query users
docker exec django_psql psql -U postgres -d ai_db -c "SELECT * FROM user_user;"

# Count migrations
docker exec django_psql psql -U postgres -d ai_db -c "SELECT COUNT(*) FROM django_migrations;"
```

#### Interactive PostgreSQL Shell
```bash
# For Windows (use cmd.exe)
cmd /c "docker exec -it django_psql psql -U postgres -d ai_db"

# For Linux/Mac
docker exec -it django_psql psql -U postgres -d ai_db
```

Once inside PostgreSQL shell:
- `\dt` - List all tables
- `\d table_name` - Describe table structure
- `\l` - List all databases
- `SELECT * FROM auth_user;` - Query data
- `\q` - Exit

---

## Configuration

Application configuration: `config/project.toml`

```toml
[project]
SECRET_KEY = "your-secret-key"
DEBUG = false
ALLOWED_HOSTS = ["*"]

[database]
ENGINE = "postgresql"
NAME = "ai_db"
USER = "postgres"
PASSWORD = "postgres"
HOST = "psql"
PORT = "5432"
```

---

## Troubleshooting

### Services not starting
```bash
cd deployment/docker
docker compose logs -f
```

### Database connection error
```bash
docker exec django_psql pg_isready -U postgres -d ai_db
```

### Reset everything (CAUTION: Deletes all data!)
```bash
cd deployment/docker
docker compose down -v
rm -rf ../../storage/db/pgdata
docker compose up -d
```
