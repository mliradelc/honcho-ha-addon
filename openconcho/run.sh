#!/command/with-contenv bash
set -euo pipefail

OPTIONS_FILE="/data/options.json"
opt() { jq -r ".${1} // empty" "$OPTIONS_FILE"; }

HONCHO_URL=$(opt honcho_url)
ACCESS_PASSWORD=$(opt access_password)

echo "[openconcho] Honcho URL: $HONCHO_URL"

# ── Seed localStorage so the app skips the "connect to server" screen ──────
# OpenConcho stores config in localStorage['openconcho:instances'].
# We inject a small bootstrap script loaded before the React bundle.
# It only seeds if the user hasn't already configured an instance,
# so manual settings are preserved.
cat > /var/www/openconcho/config.js << CFGEOF
(function() {
  var KEY = 'openconcho:instances';
  if (!localStorage.getItem(KEY)) {
    var id = 'honcho-ha';
    localStorage.setItem(KEY, JSON.stringify({
      instances: [{ id: id, name: 'Local Honcho', baseUrl: '${HONCHO_URL}', token: '' }],
      activeId: id
    }));
  }
})();
CFGEOF

# Patch index.html to load config.js before the React bundle (idempotent)
if [ -f /var/www/openconcho/index.html ] && ! grep -q "config.js" /var/www/openconcho/index.html; then
    sed -i 's|</head>|<script src="/config.js"></script></head>|' /var/www/openconcho/index.html
    echo "[openconcho] Patched index.html to load config.js"
fi

# ── Optional basic auth ────────────────────────────────────────────────────
AUTH_BLOCK=""
if [ -n "$ACCESS_PASSWORD" ]; then
    HTPASSWD=/data/.htpasswd
    echo "openconcho:$(openssl passwd -apr1 <<< "$ACCESS_PASSWORD")" > "$HTPASSWD"
    AUTH_BLOCK="auth_basic \"OpenConcho\"; auth_basic_user_file $HTPASSWD;"
fi

# ── nginx config ───────────────────────────────────────────────────────────
cat > /etc/nginx/nginx.conf << NGINX_EOF
worker_processes auto;
pid /run/nginx.pid;
events { worker_connections 256; }
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log /var/log/nginx/access.log;
    error_log  /var/log/nginx/error.log;
    server {
        listen 49180 default_server;
        add_header X-Frame-Options SAMEORIGIN always;
        add_header Content-Security-Policy "frame-ancestors 'self'" always;
        root  /var/www/openconcho;
        index index.html;
        ${AUTH_BLOCK}
        # Proxy Honcho API — avoids browser CORS entirely
        location /api/ {
            proxy_pass         ${HONCHO_URL}/;
            proxy_set_header   Host \$host;
            proxy_set_header   X-Real-IP \$remote_addr;
            proxy_http_version 1.1;
        }
        # Static assets — long cache
        location ~* \.(js|mjs|css|woff2?|svg|png|ico|webp)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
            try_files \$uri =404;
        }
        # SPA fallback
        location / {
            try_files \$uri \$uri/ /index.html;
        }
    }
}
NGINX_EOF

nginx -t 2>&1 || { echo "[openconcho] nginx config FAILED"; exit 1; }
echo "[openconcho] Starting nginx on port 49180"
exec nginx -g "daemon off;"
