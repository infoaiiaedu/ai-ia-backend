FROM python:3.11-alpine3.19

# Install system dependencies
RUN apk add --no-cache \
    bash \
    wget \
    postgresql-client \
    netcat-openbsd \
    build-base \
    libjpeg-turbo-dev \
    zlib-dev

# Set working directory
WORKDIR /app/code

# Set environment variables
ENV PYTHONPATH=/app/code
ENV PYTHONUNBUFFERED=1

# Copy requirements first for better caching
COPY code/requirements.txt /app/code/requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY ./code /app/code

# Create necessary directories
RUN mkdir -p /app/storage /app/code/logs && \
    chmod -R 755 /app

# Expose port
EXPOSE 5000

# Default command (can be overridden in docker-compose)
CMD ["python", "manage.py", "runserver", "0.0.0.0:5000"]
