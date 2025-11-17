#!/bin/sh
set -e

# Wait for Postgres
echo "Waiting for Postgres..."
until pg_isready -h psql -U postgres; do
  sleep 2
done
echo "Postgres is ready!"

echo "Collecting static files..."
python manage.py collectstatic --noinput --clear --no-post-process

echo "Applying migrations..."
python manage.py migrate --noinput

# Start Gunicorn
echo "Starting Gunicorn..."
exec gunicorn --workers 4 --threads=4 \
    main.wsgi:application \
    --bind "0.0.0.0:5000" \
    --timeout 400
