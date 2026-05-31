ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm

# Build OpenConcho web SPA — always on amd64 (static assets, no arch dep)
FROM --platform=linux/amd64 node:22-alpine AS builder

ARG OPENCONCHO_VERSION=v0.12.1

RUN corepack enable && corepack prepare pnpm@10.33.2 --activate

WORKDIR /openconcho
RUN apk add --no-cache git \
 && git clone --depth 1 --branch ${OPENCONCHO_VERSION} \
        https://github.com/offendingcommit/openconcho.git . \
 && pnpm install --frozen-lockfile --filter @openconcho/web... \
 && pnpm --filter @openconcho/web build

# Runtime image
FROM ${BUILD_FROM}

LABEL \
    io.hass.version="1.0.0" \
    io.hass.type="addon" \
    io.hass.arch="amd64|aarch64"

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /openconcho/packages/web/dist /var/www/openconcho

COPY run.sh /
RUN chmod +x /run.sh

RUN mkdir -p /var/log/nginx /run/nginx

ENV LANG=C.UTF-8

CMD ["/run.sh"]
