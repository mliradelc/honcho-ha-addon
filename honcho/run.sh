#!/command/with-contenv bash
# Honcho Add-on Entrypoint (adapted from Hermes)
set -euo pipefail
OPTIONS_FILE="/data/options.json"
if [ ! -f "$OPTIONS_FILE" ]; then
    echo "[run] FATAL: $OPTIONS_FILE not found"
    exit 1
fi
opt() { jq -r ".${1} // empty" "$OPTIONS_FILE"; }
opt_bool() { jq -r ".${1} // false" "$OPTIONS_FILE"; }
GIT_URL=$(opt git_url)
GIT_REF=$(opt git_ref)
GIT_TOKEN=$(opt git_token)
AUTO_UPDATE=$(opt_bool auto_update)
DB_MODE=$(opt db_mode)
DB_URL=$(opt db_url)
REDIS_MODE=$(opt redis_mode)
REDIS_URL=$(opt redis_url)
API_PORT=$(opt api_port)
ACCESS_PASSWORD=$(opt access_password)
ENV_VARS=$(jq -c ".env_vars // []" "$OPTIONS_FILE")
# Setup timezone if provided via HA env TZ
if [ -n "$TZ" ] && [ -f "/usr/share/zoneinfo/$TZ" ]; then
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
    echo "$TZ" > /etc/timezone
fi
# Persistent storage path
HONCHO_HOME="/config/honcho"
mkdir -p "$HONCHO_HOME"
# Clone or update source
SRC_DIR="$HONCHO_HOME/source"
if [ ! -d "$SRC_DIR/.git" ]; then
    git clone "$GIT_URL" "$SRC_DIR"
    cd "$SRC_DIR"
    if [ -n "$GIT_REF" ]; then git checkout "$GIT_REF"; fi
else
    cd "$SRC_DIR"
    if [ "$AUTO_UPDATE" = "true" ]; then
        git stash
        git pull --ff-only || true
        git stash pop || true
    fi
fi
# Setup virtualenv and install editable
VENV_DIR="$HONCHO_HOME/venv"
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
uv pip install -e .
# Export env vars for Honcho app
for kv in $(echo "$ENV_VARS" | jq -r '.[] | "\(.name)=\(.value)"'); do
    export "$kv"
done
# Configure DB connection
if [ "$DB_MODE" = "embedded" ]; then
    # Start embedded Postgres and Redis
    PGDATA="$HONCHO_HOME/pgdata"
    mkdir -p "$PGDATA"
    if [ -z "$(ls -A "$PGDATA")" ]; then
        initdb -D "$PGDATA"
    fi
    pg_ctl -D "$PGDATA" -o "-p 5433" -w start
    psql -p 5433 -c "CREATE EXTENSION IF NOT EXISTS vector;" || true
    REDIS_CONF="$HONCHO_HOME/redis.conf"
    echo "save 900 1" > "$REDIS_CONF"
    redis-server "$REDIS_CONF" --port 6380 &
    export DB_CONNECTION_URI="postgresql+psycopg://postgres:postgres@127.0.0.1:5433/postgres"
    export CACHE_URL="redis://127.0.0.1:6380/0"
else
    export DB_CONNECTION_URI="$DB_URL"
    export CACHE_URL="$REDIS_URL"
fi
# Start FastAPI app via uvicorn
exec uvicorn src.main:app --host 0.0.0.0 --port "$API_PORT"
