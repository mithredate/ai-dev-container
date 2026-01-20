# Claude Brain Sidecar

[![Build and Publish Docker Image](https://github.com/mithredate/ai-dev-container/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/mithredate/ai-dev-container/actions/workflows/docker-publish.yml)

A lightweight Docker image containing Claude Code designed to be added as a service to any `compose.yml`, delegating code execution to specialized sidecar containers via a secure Docker socket proxy.

## Quick Start

Add these services to your existing `compose.yml`:

```yaml
services:
  socket-proxy:
    image: tecnativa/docker-socket-proxy:latest
    environment:
      CONTAINERS: 1
      EXEC: 1
      POST: 1
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

  claude:
    image: claude-brain-sidecar:latest
    depends_on:
      - socket-proxy
    stdin_open: true
    tty: true
    environment:
      DOCKER_HOST: tcp://socket-proxy:2375
      BRIDGE_ENABLED: "1"
    volumes:
      - .:/workspace
      - claude-config:/home/claude/.claude

volumes:
  claude-config:
```

Then run:

```bash
docker compose up -d claude && docker attach $(docker compose ps -q claude)
```

## How It Works

Claude Code runs in its own container and uses a **bridge script** to execute commands in your project's existing containers. Commands run in the proper environment (PHP in your PHP container, Node in your Node container) with secure isolation via Docker socket proxy.

## Bridge Configuration

Create `.claude/bridge.yaml` in your project:

```yaml
version: "1"
default_container: app

containers:
  app: myproject-app-1
  php: myproject-php-1
  node: myproject-node-1

commands:
  php:
    container: php
    exec: php
    workdir: /var/www/html
  composer:
    container: php
    exec: composer
    workdir: /var/www/html
  npm:
    container: node
    exec: npm
    workdir: /app
```

When `BRIDGE_ENABLED=1`, commands like `php`, `npm`, `go` are automatically routed to the configured containers via wrapper scripts.

## Authentication

Credentials are stored in a per-project Docker volume (`<project>_claude-config`). On first run, Claude will guide you through authentication. Subsequent runs use cached credentials automatically.

To re-authenticate, delete the config volume:

```bash
docker volume rm <project>_claude-config
```

Detach from container without stopping: `Ctrl+P` then `Ctrl+Q`

## Viewer (Optional)

Web-based interface for monitoring Claude sessions and reviewing logs. Add to your `compose.yml`:

```yaml
services:
  viewer:
    image: node:20-alpine
    container_name: ai-dev-container-viewer
    command: ["npx", "@kimuson/claude-code-viewer@latest", "--hostname", "0.0.0.0"]
    environment:
      - PORT=${VIEWER_PORT:-3000}
      # Point viewer to the mounted claude data directory (read-only)
      - CCV_GLOBAL_CLAUDE_DIR=/claude-data
    ports:
      - "${VIEWER_PORT:-3000}:${VIEWER_PORT:-3000}"
    volumes:
      # Mount claude-config volume read-only at custom path to avoid permission conflicts
      - claude-config:/claude-data:ro
    restart: unless-stopped
```

Access at [http://localhost:3000](http://localhost:3000) (or set `VIEWER_PORT` in your `.env`).

## Security

- **Socket proxy** limits Claude to container list/exec operations only
- **Never mount** sensitive directories (`~/.ssh`, `~/.aws`, `~/.config`)
- Pass credentials via environment variables only
- Container runs as non-root user (`claude`, UID 1001)

## Environment Variables

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_API_KEY` | Optional. If not set, authenticate interactively after attach |
| `BRIDGE_ENABLED` | Set to `1` to route commands to sidecar containers |
| `CLAUDE_YOLO` | Set to `1` for minimal confirmation prompts (dangerous) |

## Building

```bash
docker build -t claude-brain-sidecar .
```

## Examples

See `examples/` for complete configurations including bridge setup.

## License

MIT
