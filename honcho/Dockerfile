# --- Stage 1: Build OpenConcho web SPA ---
# Pinned to latest stable tag. Update OPENCONCHO_VERSION to upgrade.
FROM node:22-alpine AS openconcho-builder

ARG OPENCONCHO_VERSION=v0.12.1

RUN corepack enable \
 && corepack prepare pnpm@10.33.2 --activate

WORKDIR /openconcho
RUN apk add --no-cache git \
 && git clone --depth 1 --branch ${OPENCONCHO_VERSION} \
        https://github.com/offendingcommit/openconcho.git . \
 && pnpm install --frozen-lockfile --filter @openconcho/web... \
 && pnpm --filter @openconcho/web build

# --- Stage 2: Honcho HA add-on runtime ---
ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm
FROM ${BUILD_FROM}

# Required HA labels
LABEL \
    io.hass.version="3.0.17" \
    io.hass.type="addon" \
    io.hass.arch="amd64|aarch64"

# System deps: Python, Postgres 15 + pgvector, Redis, nginx
# pgvector comes from the PostgreSQL apt repo (not in Debian bookworm)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl jq git lsb-release gnupg \
    python3 python3-venv python3-pip build-essential libffi-dev \
    postgresql-15 \
    redis-server \
    nginx \
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update && apt-get install -y --no-install-recommends \
    postgresql-15-pgvector \
    && rm -rf /var/lib/apt/lists/*

# Python uv (fast package installer)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
ENV UV_LINK_MODE=copy

# OpenConcho web SPA — served by nginx at /
COPY --from=openconcho-builder /openconcho/packages/web/dist /var/www/openconcho

# Copy add-on runtime files
COPY run.sh /
COPY nginx.conf.tpl /etc/nginx/nginx.conf.tpl
COPY landing.html.tpl /var/www/landing.html.tpl
RUN chmod +x /run.sh

RUN mkdir -p /var/www /var/log/nginx /run/nginx /config/honcho

ENV LANG=C.UTF-8
ENV PATH="/usr/lib/postgresql/15/bin:${PATH}"

CMD ["/run.sh"]
