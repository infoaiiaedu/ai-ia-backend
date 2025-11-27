#!/bin/sh
set -e

# Ensure storage directory exists (for logging)
echo "Creating storage directories..."
mkdir -p /app/storage

# Wait for Postgres with timeout (max 60 seconds)
echo "Waiting for Postgres..."
TIMEOUT=60
ELAPSED=0
until pg_isready -h psql -U postgres; do
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "ERROR: PostgreSQL not ready after ${TIMEOUT}s - exiting"
    exit 1
  fi
  echo "Waiting... (${ELAPSED}s/${TIMEOUT}s)"
done
echo "Postgres is ready!"

# Apply migrations
echo "Applying migrations..."
python manage.py migrate --noinput

# Collect static files (only if changed - skip --clear for performance)
echo "Collecting static files..."
python manage.py collectstatic --noinput --no-post-process

# Start Gunicorn
echo "Starting Gunicorn..."
exec gunicorn main.wsgi:application \
    --bind 0.0.0.0:5000 \
    --workers 2 \
    --threads 2 \
    --log-level info