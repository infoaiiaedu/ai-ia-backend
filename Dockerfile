FROM python:3.11-alpine3.19 as builder

WORKDIR /usr/src/app

RUN apk update && apk add --no-cache build-base

RUN pip install --upgrade pip

COPY ./code/requirements.txt requirements.txt

RUN pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/app/wheels -r requirements.txt


# Final Image
FROM python:3.11-alpine3.19

RUN mkdir -p /app

RUN addgroup -S app && adduser -S -G app app

ENV HOME=/app
ENV APP_HOME=/app

WORKDIR $APP_HOME/code

RUN mkdir -p logs cache

# 🔽 Install ImageMagick, dependencies, and Postgres client
RUN apk add --no-cache \
    imagemagick \
    ghostscript \
    libjpeg-turbo \
    postgresql-client \
    bash

# Optional: link magick if needed
# RUN ln -s /usr/bin/convert /usr/bin/magick

COPY --from=builder /usr/src/app/wheels /wheels

RUN pip install --upgrade pip
RUN pip install --no-cache /wheels/*

RUN chown -R app:app $APP_HOME

USER app
