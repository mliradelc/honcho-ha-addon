ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm
FROM ${BUILD_FROM}

# Required HA labels
LABEL \
    io.hass.version="3.0.7" \
    io.hass.type="addon" \
    io.hass.arch="amd64|aarch64"

# System deps: Python, Postgres 15 + pgvector, Redis, nginx
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl jq git \
    python3 python3-venv python3-pip build-essential libffi-dev \
    postgresql-15 postgresql-15-pgvector \
    redis-server \
    nginx \
    && rm -rf /var/lib/apt/lists/*

# Python uv (fast package installer)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
ENV UV_LINK_MODE=copy

# Copy add-on runtime files
COPY run.sh /
COPY nginx.conf.tpl /etc/nginx/nginx.conf.tpl
COPY landing.html.tpl /var/www/landing.html.tpl
RUN chmod +x /run.sh

RUN mkdir -p /var/www /var/log/nginx /run/nginx /config/honcho

ENV LANG=C.UTF-8

CMD ["/run.sh"]