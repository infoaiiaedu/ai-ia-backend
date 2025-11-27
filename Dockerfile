# ============================
# BUILDER
# ============================
FROM python:3.11-alpine3.19 AS builder

WORKDIR /usr/src/app

# Build dependencies
RUN apk add --no-cache build-base \
    && pip install --upgrade pip

# Copy requirements and build wheels
COPY code/requirements.txt requirements.txt
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/app/wheels -r requirements.txt

# ============================
# FINAL IMAGE
# ============================
FROM python:3.11-alpine3.19

# Create app user
RUN addgroup -S app && adduser -S -G app app

ENV HOME=/app
ENV APP_HOME=/app
WORKDIR $APP_HOME/code
ENV PYTHONPATH="/app/code"

# Install runtime dependencies
RUN apk add --no-cache \
    bash \
    wget \
    postgresql-client \
    netcat-openbsd \
    imagemagick \
    ghostscript \
    libjpeg-turbo

# Create necessary directories with proper permissions
RUN mkdir -p /app/storage /app/logs /app/cache && \
    chown -R app:app /app && \
    chmod -R 755 /app

# Copy Python wheels and install
COPY --from=builder /usr/src/app/wheels /wheels
RUN pip install --upgrade pip \
    && pip install --no-cache /wheels/*

# Copy application code
COPY ./code /app/code

# Set proper permissions for the entire app directory
RUN chown -R app:app /app && \
    chmod -R 755 /app && \
    chmod -R 775 /app/storage && \
    chmod -R 775 /app/logs

USER app

# Create entrypoint script to handle initialization
RUN echo '#!/bin/sh\n\
set -e\n\
echo "Creating storage directories..."\n\
mkdir -p /app/storage /app/logs /app/cache\n\
echo "Setting permissions..."\n\
chmod -R 755 /app\n\
chmod -R 775 /app/storage /app/logs\n\
echo "Waiting for Postgres..."\n\
TIMEOUT=60\n\
ELAPSED=0\n\
until pg_isready -h psql -U postgres; do\n\
  sleep 2\n\
  ELAPSED=$((ELAPSED + 2))\n\
  if [ $ELAPSED -ge $TIMEOUT ]; then\n\
    echo "ERROR: PostgreSQL not ready after ${TIMEOUT}s - exiting"\n\
    exit 1\n\
  fi\n\
  echo "Waiting... (${ELAPSED}s/${TIMEOUT}s)"\n\
done\n\
echo "Postgres is ready!"\n\
echo "Applying migrations..."\n\
python manage.py migrate --noinput\n\
echo "Collecting static files..."\n\
python manage.py collectstatic --noinput --no-post-process\n\
echo "Starting Gunicorn..."\n\
exec gunicorn main.wsgi:application --bind 0.0.0.0:5000 --workers 2 --threads 2 --log-level info\n\
' > /app/entrypoint.sh && chmod +x /app/entrypoint.sh

CMD ["/app/entrypoint.sh"]