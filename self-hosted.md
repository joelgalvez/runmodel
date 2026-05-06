## Login to your local LLM server
`ssh root@<your-server-ip>`

## First, run llama-server something like this:

path-to/llama-server \
      --models-dir /path-to/models \
      --host 0.0.0.0 \
      --port 8080 \
      -ngl 999 \
      --models-max 1 \
      --temp 0 \
      --top-k 1 \
      --repeat-penalty 1.0


## Then setup RUNMODEL
git clone https://github.com/joelgalvez/runmodel
cd runmodel


```bash
# Create your .env file
cp .env.example .env

Edit .env file

# Start the app
docker compose up -d
```

The app will be available at `http://localhost`.

## Useful commands

```bash
# View logs
docker compose logs -f

# Stop
docker compose down

# Rebuild after pulling updates
docker compose up -d --build
```

## Setup server

go into `http://localhost/servers` and add your website/server. The URL should end with /api, such as 
`https://your-newsletter-hub.com/api`

email and password needs to match what you set up 




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

### Example if using Caddy (automatic HTTPS)

```
example.com {
    reverse_proxy localhost:80
}
```

### Example if using Nginx

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
