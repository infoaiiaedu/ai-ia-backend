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

# Create necessary dirs (logs, cache, storage for app logs)
RUN mkdir -p logs cache /app/storage

# Copy Python wheels and install
COPY --from=builder /usr/src/app/wheels /wheels
RUN pip install --upgrade pip \
    && pip install --no-cache /wheels/*

# Copy application code
COPY ./code /app/code

# Set permissions
RUN chown -R app:app /app

USER app

# Default command (matches docker-compose.yml)
CMD ["/bin/sh", "-c", "set -e && echo 'Creating storage directories...' && mkdir -p /app/storage && echo 'Waiting for Postgres...' && TIMEOUT=60 && ELAPSED=0 && until pg_isready -h psql -U postgres; do sleep 2 && ELAPSED=$((ELAPSED + 2)) && if [ $ELAPSED -ge $TIMEOUT ]; then echo 'ERROR: PostgreSQL not ready after '$TIMEOUT's - exiting' && exit 1; fi && echo 'Waiting... ('$ELAPSED's/'$TIMEOUT's)'; done && echo 'Postgres is ready!' && echo 'Applying migrations...' && python manage.py migrate --noinput && echo 'Collecting static files...' && python manage.py collectstatic --noinput --no-post-process && echo 'Starting Gunicorn...' && exec gunicorn main.wsgi:application --bind 0.0.0.0:5000 --workers 2 --threads 2 --log-level info"]
