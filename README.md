# runmodel

A Rails application that acts as a local LLM worker. It connects to one or more remote Rails apps, claims pending LLM jobs, runs them against a local [llama.cpp](https://github.com/ggerganov/llama.cpp) server, and pushes the results back.

## How it works

1. **Watches** remote servers via WebSocket — when new jobs are signaled, it fetches them immediately
2. **Claims** jobs atomically so multiple workers don't process the same job
3. **Runs** each job against a local llama.cpp-compatible server (`/v1/chat/completions`)
4. **Returns** the result to the originating server

The remote server must expose a JSON API with these endpoints:

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/login` | Returns `{ api_token: "..." }` |
| `GET` | `/current_user` | Returns `{ logged_in: true }` |
| `GET` | `/llm_jobs` | Returns pending jobs |
| `POST` | `/llm_jobs/claim` | Claims a batch of job IDs |
| `PUT` | `/llm_jobs/:id` | Receives the result |
| `POST` | `/available_models` | Receives the list of loaded models |

It also subscribes to an Action Cable channel (`LlmJobChannel`) on the remote server to receive real-time job notifications.

## Requirements

- Ruby 4.0.2
- A running [llama.cpp](https://github.com/ggerganov/llama.cpp) server (or any OpenAI-compatible local inference server)

## Setup

```bash
bin/setup
```

This will install dependencies, prepare the database, and copy example config files if they don't exist yet.

## Configuration

### `.env`

| Variable | Description |
|----------|-------------|
| `KAMAL_REGISTRY_PASSWORD` | Docker Hub access token (for deployment only) |
| `LLAMA_SERVER_URL` | URL of your local llama.cpp server (default: `http://172.17.0.1:8080`) |

### `config/deploy.yml`

Update with your Docker username, server IP, and any environment-specific URLs before deploying with Kamal.

## Running locally

```bash
bin/dev
```

Then open [http://localhost:3000](http://localhost:3000).

Add remote servers under **Servers**, then use the manual triggers or wait for the scheduled job to start picking up work.

## Deployment

This app deploys via [Kamal](https://kamal-deploy.org/). After configuring `config/deploy.yml`:

```bash
bin/kamal deploy
```

Jobs run automatically every 4 minutes via Solid Queue. The llama.cpp server is expected to be reachable at `LLAMA_SERVER_URL` from inside the container.
