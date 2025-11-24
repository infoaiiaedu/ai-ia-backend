<<<<<<< HEAD
#!/bin/sh
=======
﻿#!/bin/sh
>>>>>>> 582c3dc12a9409382079981e07f3d17f362746f3
set -e

# Wait for Postgres
echo "Waiting for Postgres..."
until pg_isready -h psql -U postgres; do
  sleep 2
done
echo "Postgres is ready!"

# Apply migrations
echo "Applying migrations..."
python manage.py migrate --noinput

# Collect static files
echo "Collecting static files..."
python manage.py collectstatic --noinput --clear --no-post-process

# Start Gunicorn
echo "Starting Gunicorn..."
exec gunicorn main.wsgi:application \
    --bind 0.0.0.0:5000 \
    --workers 2 \
    --threads 2 \
    --log-level info
