worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Ingress: HA proxy → local FastAPI
    server {
        listen 49170 default_server;
        server_name _;
        add_header X-Frame-Options SAMEORIGIN always;
        add_header Content-Security-Policy "frame-ancestors 'self'" always;
        # Remove HA ingress prefix (/honcho/) and proxy to uvicorn
        location / {
            proxy_pass http://127.0.0.1:8000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            # Strip ingress prefix if present (/honcho/ → /)
            rewrite ^/[^/]+(/.*)$ $1 break;
        }
    }

    # Landing page (shown while Honcho starts up)
    server {
        listen 49171 default_server;
        server_name _;
        root /var/www;
        index loading.html;
    }
}