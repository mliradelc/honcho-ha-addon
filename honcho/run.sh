#!/command/with-contenv bash
# Honcho Add-on Entrypoint
set -euo pipefail

OPTIONS_FILE="/data/options.json"
if [ ! -f "$OPTIONS_FILE" ]; then
    echo "[run] FATAL: $OPTIONS_FILE not found"
    exit 1
fi

opt()    { jq -r ".${1} // empty" "$OPTIONS_FILE"; }
opt_bool() { jq -r ".${1} // false" "$OPTIONS_FILE"; }

# Read options
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


# LLM / Embedding configuration for Honcho Deriver
LLM_TRANSPORT=$(opt llm_transport)
LLM_MODEL=$(opt llm_model)
LLM_BASE_URL=$(opt llm_base_url)
LLM_API_KEY=$(opt llm_api_key)
EMBEDDING_TRANSPORT=$(opt embedding_transport)
EMBEDDING_MODEL=$(opt embedding_model)
EMBEDDING_BASE_URL=$(opt embedding_base_url)
EMBEDDING_API_KEY=$(opt embedding_api_key)

# Persistent storage
HONCHO_HOME="/config/honcho"
mkdir -p "$HONCHO_HOME"/{source,venv,pgdata,redis,logs}
# postgres user must own pgdata — HA containers run as root
chown postgres "$HONCHO_HOME/pgdata"
# postgres user must also own the logs dir to write postgres.log
chown postgres "$HONCHO_HOME/logs"

# Timezone (from HA env TZ)
if [ -n "${TZ:-}" ] && [ -f "/usr/share/zoneinfo/$TZ" ]; then
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
    echo "$TZ" > /etc/timezone
fi

# Postgres (embedded mode)
start_postgres() {
    local pgdata="$HONCHO_HOME/pgdata"
    # All postgres commands must run as the postgres user (initdb/pg_ctl refuse root)
    chown postgres "$pgdata"
    if [ ! -f "$pgdata/PG_VERSION" ]; then
        echo "[run] Initialising Postgres data directory..."
        su -s /bin/bash postgres -c             "initdb -D \"$pgdata\" --username=postgres --auth=trust"             2>&1 | tee -a "$HONCHO_HOME/logs/initdb.log"
    fi
    echo "[run] Starting Postgres on 127.0.0.1:5433..."
    # Pre-create log file owned by postgres so pg_ctl can open it
    touch "$HONCHO_HOME/logs/postgres.log"
    chown postgres "$HONCHO_HOME/logs/postgres.log"
    su -s /bin/bash postgres -c         "pg_ctl -D \"$pgdata\" -o \"-p 5433 -k /tmp\" -w start -l \"$HONCHO_HOME/logs/postgres.log\""
    # Stream postgres log to stdout so entries appear in HA log viewer
    tail -F "$HONCHO_HOME/logs/postgres.log" &
    # Ensure pgvector extension
    su -s /bin/bash postgres -c         "psql -h 127.0.0.1 -p 5433 -U postgres -d postgres -c \"CREATE EXTENSION IF NOT EXISTS vector;\""         2>&1 | tee -a "$HONCHO_HOME/logs/psql.log"
}

stop_postgres() {
    if su -s /bin/bash postgres -c             "pg_ctl -D \"$HONCHO_HOME/pgdata\" status" >/dev/null 2>&1; then
        su -s /bin/bash postgres -c             "pg_ctl -D \"$HONCHO_HOME/pgdata\" -w stop"
    fi
}

# Redis (embedded mode)
start_redis() {
    local redis_dir="$HONCHO_HOME/redis"
    local redis_conf="$redis_dir/redis.conf"
    if [ ! -f "$redis_conf" ]; then
        cat > "$redis_conf" << REDIS_EOF
port 6380
daemonize no
dir $redis_dir
appendonly yes
appendfsync everysec
save 900 1
save 300 10
save 60 10000
bind 127.0.0.1
REDIS_EOF
    fi
    echo "[run] Starting Redis on 127.0.0.1:6380..."
    redis-server "$redis_conf" > "$HONCHO_HOME/logs/redis.log" 2>&1 &
}

# Clone / update Honcho source
sync_source() {
    local src="$HONCHO_HOME/source"
    if [ ! -d "$src/.git" ]; then
        echo "[run] Cloning Honcho from $GIT_URL..."
        if [ -n "$GIT_TOKEN" ]; then
            local auth_url
            auth_url=$(echo "$GIT_URL" | sed "s|://|://oauth2:${GIT_TOKEN}@|")
            git clone --depth 1 "$auth_url" "$src"
        else
            git clone --depth 1 "$GIT_URL" "$src"
        fi
        cd "$src"
        if [ -n "$GIT_REF" ]; then
            echo "[run] Checking out ref: $GIT_REF"
            git fetch --depth 1 origin "$GIT_REF"
            git checkout "$GIT_REF"
        fi
    else
        cd "$src"
        if [ "$AUTO_UPDATE" = "true" ]; then
            echo "[run] Auto-updating Honcho source..."
            # Hard-reset to origin to discard any local changes (uv.lock, .pth files, etc.)
            git fetch origin 2>&1
            git reset --hard origin/"${GIT_REF:-main}" 2>&1 || echo "[run] WARNING: git reset failed"
        fi
        if [ -n "$GIT_REF" ]; then
            git checkout "$GIT_REF" 2>/dev/null || true
        fi
    fi
}

# Marker-gated install
ensure_installed() {
    local src="$HONCHO_HOME/source"
    local marker="$HONCHO_HOME/.install-marker"
    local current_head
    current_head=$(cd "$src" && git rev-parse HEAD 2>/dev/null || echo "unknown")
    local current_url="${GIT_URL}"
    local current_ref="${GIT_REF:-main}"
    local marker_value="${current_url}|${current_ref}|${current_head}"

    if [ -f "$marker" ] && [ "$(cat "$marker")" = "$marker_value" ]; then
        echo "[run] Marker unchanged — skipping pip install"
        return 0
    fi

    echo "[run] Marker changed — installing dependencies..."
    cd "$src"

    if [ ! -d "$HONCHO_HOME/venv/bin" ]; then
        python3 -m venv "$HONCHO_HOME/venv"
    fi
    source "$HONCHO_HOME/venv/bin/activate"

    uv pip install -e ".[dev]" 2>&1 | tee "$HONCHO_HOME/logs/install.log" || {
        echo "[run] ERROR: pip install failed — see $HONCHO_HOME/logs/install.log"
        return 1
    }

    # Alembic migrations
    if [ -f alembic.ini ]; then
        echo "[run] Running Alembic migrations..."
        uv run alembic upgrade head 2>&1 | tee "$HONCHO_HOME/logs/migrate.log" || true
    fi

    echo "$marker_value" > "$marker"
}

# Render config.toml — always rewrite if vector_dimensions changed
render_config() {
    local cfg="$HONCHO_HOME/config.toml"
    local target_dims="${EMBEDDING_VECTOR_DIMENSIONS:-1536}"

    if [ -f "$cfg" ]; then
        local current_dims
        current_dims=$(grep "^vector_dimensions" "$cfg" 2>/dev/null | awk -F'=' '{print $2}' | tr -d ' ')
        if [ "$current_dims" = "$target_dims" ]; then
            return 0
        fi
        echo "[run] vector_dimensions changed ($current_dims → $target_dims) — rewriting $cfg"
        rm -f "$cfg"
    fi

    echo "[run] Writing $cfg..."
    cat > "$cfg" << CONFIG_EOF
[database]
connection_uri = "${DB_CONNECTION_URI}"

[auth]
use_auth = ${USE_AUTH:-false}
jwt_secret = "${JWT_SECRET:-change-me-in-production}"

[llm]
default_max_tokens = ${DEFAULT_MAX_TOKENS:-4096}

[embedding]
vector_dimensions = ${target_dims}

[deriver]
enabled = ${DERIVER_ENABLED:-true}
workers = ${DERIVER_WORKERS:-2}
polling_sleep_interval_seconds = ${POLL_INTERVAL:-30}
CONFIG_EOF
}

# Alter vector columns to match VECTOR_DIMENSIONS if they were created with a different dimension.
# Called after postgres starts, before Alembic runs.  Safe to call on fresh installs (no-op).
fix_vector_dimensions() {
    local target_dim="${EMBEDDING_VECTOR_DIMENSIONS:-1536}"
    echo "[run] Checking pgvector column dimensions (target: $target_dim)..."
    su -s /bin/bash postgres -c \
        "psql -h 127.0.0.1 -p 5433 -U postgres -d postgres" << PGSQL 2>&1 | tee -a "$HONCHO_HOME/logs/psql.log" || true
DO \$\$
DECLARE
    r      RECORD;
    cur_dim INT;
    target  INT := $target_dim;
BEGIN
    FOR r IN
        SELECT c.table_name, c.column_name
        FROM information_schema.columns c
        WHERE c.udt_name = 'vector' AND c.table_schema = 'public'
    LOOP
        SELECT a.atttypmod INTO cur_dim
        FROM pg_attribute a
        JOIN pg_class cl ON a.attrelid = cl.oid
        WHERE cl.relname = r.table_name AND a.attname = r.column_name;

        IF cur_dim IS NOT NULL AND cur_dim <> target THEN
            RAISE NOTICE 'Resetting %.% from vector(%) to vector(%)',
                r.table_name, r.column_name, cur_dim, target;
            -- Clear embeddings so ALTER TYPE succeeds (no cast between different dims)
            EXECUTE format('UPDATE %I SET %I = NULL', r.table_name, r.column_name);
            EXECUTE format('ALTER TABLE %I ALTER COLUMN %I TYPE vector(%s)',
                r.table_name, r.column_name, target);
        END IF;
    END LOOP;
END \$\$;
PGSQL
}

# Start nginx — simple reverse proxy to Honcho FastAPI
start_nginx() {
    echo "[run] Starting nginx..."

    local auth_block=""
    if [ -n "$ACCESS_PASSWORD" ]; then
        echo "[run] Enabling basic auth..."
        local htpasswd_file="$HONCHO_HOME/.htpasswd"
        printf '%s' "honcho:$(openssl passwd -apr1 <<< "$ACCESS_PASSWORD")" > "$htpasswd_file"
        auth_block="auth_basic \"Honcho\"; auth_basic_user_file ${htpasswd_file};"
    fi

    cat > /etc/nginx/nginx.conf << NGINX_EOF
worker_processes auto;
pid /run/nginx.pid;
events { worker_connections 768; }
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    server {
        listen 49170 default_server;
        add_header X-Frame-Options SAMEORIGIN always;
        add_header Content-Security-Policy "frame-ancestors 'self'" always;
        ${auth_block}
        location / {
            proxy_pass         http://127.0.0.1:${API_PORT};
            proxy_set_header   Host \$host;
            proxy_set_header   X-Real-IP \$remote_addr;
            proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header   X-Forwarded-Proto \$scheme;
            proxy_http_version 1.1;
            proxy_set_header   Upgrade \$http_upgrade;
            proxy_set_header   Connection "upgrade";
        }
    }
}
NGINX_EOF

    nginx -t 2>&1 || { echo "[run] nginx config test FAILED"; exit 1; }
    nginx
}

# Environment variables passthrough
load_env_vars() {
    # Read from HA options
    eval "$(jq -r '.env_vars // [] | .[] | "export \(.name)=\(.value|@sh)"' "$OPTIONS_FILE")"
    # Also source .env file if present
    local env_file="$HONCHO_HOME/.env"
    if [ -f "$env_file" ]; then
        set -a
        source "$env_file"
        set +a
    fi
}

# ===== MAIN =====
echo "[run] Honcho add-on starting"
echo "[run] DB mode: $DB_MODE | Redis mode: $REDIS_MODE | API port: $API_PORT"

# 1. Database and cache
case "$DB_MODE" in
    embedded)
        start_postgres
        export DB_CONNECTION_URI="postgresql+psycopg://postgres@127.0.0.1:5433/postgres"
        ;;
    external)
        export DB_CONNECTION_URI="$DB_URL"
        ;;
esac

case "$REDIS_MODE" in
    embedded)
        start_redis
        export CACHE_URL="redis://127.0.0.1:6380/0"
        ;;
    external)
        export CACHE_URL="$REDIS_URL"
        ;;
esac

# 2. Load environment variables
load_env_vars

# 2b. Apply LLM/embedding config from HA options → Honcho env vars
# Honcho reads per-subsystem MODEL_CONFIG__ vars for Deriver, Dialectic, Summary, and Dream.
# LLM_OPENAI_API_KEY / LLM_OPENAI_BASE_URL are the shared credentials for all openai-transport calls.
apply_llm_config() {
    local env_file="$HONCHO_HOME/.env"
    touch "$env_file"
    # Remove stale LLM/embedding lines
    sed -i '/^LLM_\|^EMBEDDING_\|^DERIVER_MODEL_CONFIG\|^DIALECTIC_\|^SUMMARY_MODEL_CONFIG\|^DREAM_/d' "$env_file" 2>/dev/null || true
    {
        # Shared OpenAI-compat credentials (used by all subsystems with transport=openai)
        [ -n "${LLM_API_KEY:-}" ]          && echo "LLM_OPENAI_API_KEY=$LLM_API_KEY"
        [ -n "${LLM_BASE_URL:-}" ]         && echo "LLM_OPENAI_BASE_URL=$LLM_BASE_URL"

        # Per-subsystem model overrides — each subsystem defaults to gpt-5.4-mini
        # Deriver (memory extraction)
        [ -n "${LLM_TRANSPORT:-}" ]        && echo "DERIVER_MODEL_CONFIG__TRANSPORT=$LLM_TRANSPORT"
        [ -n "${LLM_MODEL:-}" ]            && echo "DERIVER_MODEL_CONFIG__MODEL=$LLM_MODEL"
        [ -n "${LLM_BASE_URL:-}" ]         && echo "DERIVER_MODEL_CONFIG__OVERRIDES__BASE_URL=$LLM_BASE_URL"
        [ -n "${LLM_API_KEY:-}" ]          && echo "DERIVER_MODEL_CONFIG__OVERRIDES__API_KEY=$LLM_API_KEY"
        # Dialectic (reasoning — applies to all levels: minimal/low/medium/high/max)
        [ -n "${LLM_TRANSPORT:-}" ]        && echo "DIALECTIC_LEVELS__minimal__MODEL_CONFIG__TRANSPORT=$LLM_TRANSPORT"
        [ -n "${LLM_MODEL:-}" ]            && echo "DIALECTIC_LEVELS__minimal__MODEL_CONFIG__MODEL=$LLM_MODEL"
        [ -n "${LLM_BASE_URL:-}" ]         && echo "DIALECTIC_LEVELS__minimal__MODEL_CONFIG__OVERRIDES__BASE_URL=$LLM_BASE_URL"
        [ -n "${LLM_API_KEY:-}" ]          && echo "DIALECTIC_LEVELS__minimal__MODEL_CONFIG__OVERRIDES__API_KEY=$LLM_API_KEY"
        [ -n "${LLM_TRANSPORT:-}" ]        && echo "DIALECTIC_LEVELS__low__MODEL_CONFIG__TRANSPORT=$LLM_TRANSPORT"
        [ -n "${LLM_MODEL:-}" ]            && echo "DIALECTIC_LEVELS__low__MODEL_CONFIG__MODEL=$LLM_MODEL"
        [ -n "${LLM_BASE_URL:-}" ]         && echo "DIALECTIC_LEVELS__low__MODEL_CONFIG__OVERRIDES__BASE_URL=$LLM_BASE_URL"
        [ -n "${LLM_API_KEY:-}" ]          && echo "DIALECTIC_LEVELS__low__MODEL_CONFIG__OVERRIDES__API_KEY=$LLM_API_KEY"
        [ -n "${LLM_TRANSPORT:-}" ]        && echo "DIALECTIC_LEVELS__medium__MODEL_CONFIG__TRANSPORT=$LLM_TRANSPORT"
        [ -n "${LLM_MODEL:-}" ]            && echo "DIALECTIC_LEVELS__medium__MODEL_CONFIG__MODEL=$LLM_MODEL"
        [ -n "${LLM_BASE_URL:-}" ]         && echo "DIALECTIC_LEVELS__medium__MODEL_CONFIG__OVERRIDES__BASE_URL=$LLM_BASE_URL"
        [ -n "${LLM_API_KEY:-}" ]          && echo "DIALECTIC_LEVELS__medium__MODEL_CONFIG__OVERRIDES__API_KEY=$LLM_API_KEY"
        [ -n "${LLM_TRANSPORT:-}" ]        && echo "DIALECTIC_LEVELS__high__MODEL_CONFIG__TRANSPORT=$LLM_TRANSPORT"
        [ -n "${LLM_MODEL:-}" ]            && echo "DIALECTIC_LEVELS__high__MODEL_CONFIG__MODEL=$LLM_MODEL"
        [ -n "${LLM_BASE_URL:-}" ]         && echo "DIALECTIC_LEVELS__high__MODEL_CONFIG__OVERRIDES__BASE_URL=$LLM_BASE_URL"
        [ -n "${LLM_API_KEY:-}" ]          && echo "DIALECTIC_LEVELS__high__MODEL_CONFIG__OVERRIDES__API_KEY=$LLM_API_KEY"
        [ -n "${LLM_TRANSPORT:-}" ]        && echo "DIALECTIC_LEVELS__max__MODEL_CONFIG__TRANSPORT=$LLM_TRANSPORT"
        [ -n "${LLM_MODEL:-}" ]            && echo "DIALECTIC_LEVELS__max__MODEL_CONFIG__MODEL=$LLM_MODEL"
        [ -n "${LLM_BASE_URL:-}" ]         && echo "DIALECTIC_LEVELS__max__MODEL_CONFIG__OVERRIDES__BASE_URL=$LLM_BASE_URL"
        [ -n "${LLM_API_KEY:-}" ]          && echo "DIALECTIC_LEVELS__max__MODEL_CONFIG__OVERRIDES__API_KEY=$LLM_API_KEY"
        # Summary
        [ -n "${LLM_TRANSPORT:-}" ]        && echo "SUMMARY_MODEL_CONFIG__TRANSPORT=$LLM_TRANSPORT"
        [ -n "${LLM_MODEL:-}" ]            && echo "SUMMARY_MODEL_CONFIG__MODEL=$LLM_MODEL"
        [ -n "${LLM_BASE_URL:-}" ]         && echo "SUMMARY_MODEL_CONFIG__OVERRIDES__BASE_URL=$LLM_BASE_URL"
        [ -n "${LLM_API_KEY:-}" ]          && echo "SUMMARY_MODEL_CONFIG__OVERRIDES__API_KEY=$LLM_API_KEY"
        # Dream (deduction + induction)
        [ -n "${LLM_TRANSPORT:-}" ]        && echo "DREAM_DEDUCTION_MODEL_CONFIG__TRANSPORT=$LLM_TRANSPORT"
        [ -n "${LLM_MODEL:-}" ]            && echo "DREAM_DEDUCTION_MODEL_CONFIG__MODEL=$LLM_MODEL"
        [ -n "${LLM_BASE_URL:-}" ]         && echo "DREAM_DEDUCTION_MODEL_CONFIG__OVERRIDES__BASE_URL=$LLM_BASE_URL"
        [ -n "${LLM_API_KEY:-}" ]          && echo "DREAM_DEDUCTION_MODEL_CONFIG__OVERRIDES__API_KEY=$LLM_API_KEY"
        [ -n "${LLM_TRANSPORT:-}" ]        && echo "DREAM_INDUCTION_MODEL_CONFIG__TRANSPORT=$LLM_TRANSPORT"
        [ -n "${LLM_MODEL:-}" ]            && echo "DREAM_INDUCTION_MODEL_CONFIG__MODEL=$LLM_MODEL"
        [ -n "${LLM_BASE_URL:-}" ]         && echo "DREAM_INDUCTION_MODEL_CONFIG__OVERRIDES__BASE_URL=$LLM_BASE_URL"
        [ -n "${LLM_API_KEY:-}" ]          && echo "DREAM_INDUCTION_MODEL_CONFIG__OVERRIDES__API_KEY=$LLM_API_KEY"

        # Embedding
        [ -n "${EMBEDDING_TRANSPORT:-}" ]  && echo "EMBEDDING_MODEL_CONFIG__TRANSPORT=$EMBEDDING_TRANSPORT"
        [ -n "${EMBEDDING_MODEL:-}" ]      && echo "EMBEDDING_MODEL_CONFIG__MODEL=$EMBEDDING_MODEL"
        [ -n "${EMBEDDING_BASE_URL:-}" ]   && echo "EMBEDDING_MODEL_CONFIG__OVERRIDES__BASE_URL=$EMBEDDING_BASE_URL"
        [ -n "${EMBEDDING_API_KEY:-}" ]    && echo "EMBEDDING_MODEL_CONFIG__OVERRIDES__API_KEY=$EMBEDDING_API_KEY"
        # Remap EMBEDDING_DIMENSIONS_MODE to EMBEDDING_MODEL_CONFIG__DIMENSIONS_MODE
        # Honcho reads the pydantic nested field; the flat name is silently ignored.
        local dims_mode
        dims_mode=$(jq -r '.env_vars // [] | .[] | select(.name == "EMBEDDING_DIMENSIONS_MODE") | .value' "$OPTIONS_FILE" 2>/dev/null || true)
        [ -n "${dims_mode:-}" ] && echo "EMBEDDING_MODEL_CONFIG__DIMENSIONS_MODE=$dims_mode"
    } >> "$env_file"
    echo "[run] LLM config applied: transport=${LLM_TRANSPORT:-unset} model=${LLM_MODEL:-unset}"
}
apply_llm_config

# Required deriver feature flags for single-user self-hosted deployments.
# Honcho defaults these to false (designed for high-throughput SaaS).
# Without them, low-volume deployments never trigger memory extraction
# because the token batch threshold (~1,000 tokens) is never reached.
# See: https://github.com/plastic-labs/honcho/issues/494
cat >> "$HONCHO_HOME/.env" << 'DERIVER_FEATURES'
DERIVER_FLUSH_ENABLED=true
PEER_CARD_ENABLED=true
SUMMARY_ENABLED=true
DREAM_ENABLED=true
DREAM_SURPRISAL__ENABLED=true
DERIVER_FEATURES
echo "[run] Deriver feature flags appended to .env"

# 3. Sync source and install dependencies, then migrate
sync_source
ensure_installed

# 3b. Always resize vector columns to EMBEDDING_VECTOR_DIMENSIONS (idempotent — fast no-op when already correct)
if [ -f "$HONCHO_HOME/source/scripts/configure_embeddings.py" ]; then
    echo "[run] Configuring embedding dimensions to ${EMBEDDING_VECTOR_DIMENSIONS:-1536}..."
    cd "$HONCHO_HOME/source"
    source "$HONCHO_HOME/venv/bin/activate"
    uv run python scripts/configure_embeddings.py --yes 2>&1 | tee -a "$HONCHO_HOME/logs/migrate.log" || true
fi

# 4. Render config
render_config

# 5. Start nginx
start_nginx

# 6. Start Honcho API
echo "[run] Starting Honcho FastAPI on 0.0.0.0:${API_PORT}..."

cd "$HONCHO_HOME/source"
source "$HONCHO_HOME/venv/bin/activate"

# Start the deriver worker in the background (queue consumer for memory extraction)
echo "[run] Starting Honcho deriver worker..."
python -m src.deriver >> "$HONCHO_HOME/logs/deriver.log" 2>&1 &
DERIVER_PID=$!
echo "[run] Deriver PID: $DERIVER_PID"
# Stream deriver log to stdout so entries appear in HA log viewer
tail -F "$HONCHO_HOME/logs/deriver.log" &

exec uvicorn src.main:app \
    --host 0.0.0.0 \
    --port "$API_PORT" \
    --log-level info \
    --forwarded-allow-ips "*"

# --- Honcho Auth Fallbacks (Watchdog patch) ---
if [ -z "${DIALECTIC_LEVELS__minimal__MODEL_CONFIG__TRANSPORT:-}" ]; then
    echo "[run] WARNING: EXPLICIT Dialectic OVERRIDES missing for level minimal — falling back to inherited from LLM_* variables" >&2
fi
if [ -z "${LLM_TRANSPORT:-}" ]; then
    echo "[run] ERROR: Missing LLM/MODEL OVERRIDES — cannot start without any model transport configured" >&2
    exit 1
fi
# --- End Auth Fallbacks ---

    --forwarded-allow-ips "*"