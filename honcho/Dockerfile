ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm

FROM ${BUILD_FROM}

LABEL \
    io.hass.version="3.0.40" \
    io.hass.type="addon" \
    io.hass.arch="amd64|aarch64"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl jq git lsb-release gnupg \
    python3 python3-venv python3-pip build-essential libffi-dev \
    postgresql-15 \
    redis-server \
    nginx \
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
       | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] \
       http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
       > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update && apt-get install -y --no-install-recommends \
       postgresql-15-pgvector \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
ENV UV_LINK_MODE=copy

COPY run.sh /
RUN chmod +x /run.sh

RUN mkdir -p /var/www /var/log/nginx /run/nginx /config/honcho

ENV LANG=C.UTF-8
ENV PATH="/usr/lib/postgresql/15/bin:${PATH}"

CMD ["/run.sh"]
