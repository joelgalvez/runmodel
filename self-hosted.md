# Self-Hosted Deployment

Run **Runmodel** on your own server using Docker Compose.

## Prerequisites

- Docker with Compose (v2+)

## Quick Start

```bash
# Create your .env file
cp .env.example .env

Edit .env file

# Start the app
docker compose up -d
```

The app will be available at `http://localhost`.

## Commands

```bash
# View logs
docker compose logs -f

# Stop
docker compose down

# Rebuild after pulling updates
docker compose up -d --build
```

## Persistent Storage

All data is stored in a Docker volume mounted at `/rails/storage`. This includes:

- SQLite databases (primary, cache, queue, cable)
- Active Storage uploads

Data persists across container restarts and rebuilds.


## Updating

```bash
git pull
docker compose up -d --build
```

The entrypoint automatically runs `rails db:prepare` on startup, applying any pending migrations.

## Reverse Proxy (HTTPS)

The container runs [Thruster](https://github.com/basecamp/thruster) in front of Puma on port 80. To add HTTPS, put a reverse proxy in front:

### Caddy (automatic HTTPS)

```
example.com {
    reverse_proxy localhost:80
}
```

### Nginx

```nginx
server {
    listen 443 ssl;
    server_name example.com;

    ssl_certificate     /etc/ssl/certs/example.com.pem;
    ssl_certificate_key /etc/ssl/private/example.com.key;

    location / {
        proxy_pass http://localhost:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```
