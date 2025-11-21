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
    postgresql-client \
    netcat-openbsd \
    imagemagick \
    ghostscript \
    libjpeg-turbo

# Create necessary dirs
RUN mkdir -p logs cache

# Copy Python wheels and install
COPY --from=builder /usr/src/app/wheels /wheels
RUN pip install --upgrade pip \
    && pip install --no-cache /wheels/*

# Copy application code
COPY ./code /app/code

# Copy entrypoint script
COPY ./entry.sh /shared/entry.sh
RUN chmod +x /shared/entry.sh

# Set permissions
RUN chown -R app:app /app

USER app

# Default command
CMD ["/bin/sh", "/shared/entry.sh"]
