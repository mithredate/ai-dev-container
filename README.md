# Claude Brain Sidecar

[![Build and Publish Docker Image](https://github.com/mithredate/ai-dev-container/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/mithredate/ai-dev-container/actions/workflows/docker-publish.yml)

A lightweight Docker image containing Claude Code designed to be added as a service to any `docker-compose.yml`, delegating code execution to specialized sidecar containers via a secure Docker socket proxy.

## Quick Start

Add these services to your existing `docker-compose.yml`:

```yaml
services:
  # Secure Docker socket proxy
  socket-proxy:
    image: tecnativa/docker-socket-proxy:latest
    environment:
      CONTAINERS: 1
      EXEC: 1
      POST: 1
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

  # Claude Code sidecar
  claude:
    image: claude-brain-sidecar:latest
    depends_on:
      - socket-proxy
    stdin_open: true
    tty: true
    environment:
      DOCKER_HOST: tcp://socket-proxy:2375
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
      BRIDGE_ENABLED: "1"
    volumes:
      - .:/workspace
```

Then run:

```bash
docker compose up claude
```

Claude starts automatically via the entrypoint script. To run in detached mode with attach:

```bash
docker compose up -d claude
docker attach <container-name>
```

## How It Works

Claude Code runs in its own lightweight container and uses a **bridge script** to execute commands in your project's existing containers. This means:

- No language runtimes needed in the Claude container
- Commands run in the proper environment (PHP in your PHP container, Node in your Node container)
- Secure isolation via Docker socket proxy

## Bridge Configuration

Create `.claude/bridge.yaml` in your project to map commands to containers:

```yaml
version: "1"

# Default container for unrecognized commands
default_container: app

# Map logical names to actual container names
containers:
  app: myproject-app-1
  php: myproject-php-1
  node: myproject-node-1
  db: myproject-db-1

# Command mappings
commands:
  # PHP commands
  php:
    container: php
    exec: php
    workdir: /var/www/html

  composer:
    container: php
    exec: composer
    workdir: /var/www/html

  artisan:
    container: php
    exec: php artisan
    workdir: /var/www/html

  "test:php":
    container: php
    exec: php artisan test
    workdir: /var/www/html

  # Node.js commands
  npm:
    container: node
    exec: npm
    workdir: /app

  # Database
  mysql:
    container: db
    exec: mysql
```

### Bridge Usage

```bash
# Run commands via the bridge
bridge php -v                     # Run 'php -v' in PHP container
bridge artisan migrate            # Run Laravel migrations
bridge test:php --filter=User     # Run tests with filter
bridge npm install                # Install npm packages
bridge composer require foo/bar   # Install composer package
```

## Configuration Reference

### bridge.yaml Schema

| Field | Required | Description |
|-------|----------|-------------|
| `version` | Yes | Schema version. Currently: `"1"` |
| `default_container` | No | Container for unrecognized commands |
| `containers` | No | Map logical names to actual container names |
| `commands` | Yes | Command-to-container mappings |

### Command Entry Fields

| Field | Required | Description |
|-------|----------|-------------|
| `container` | Yes | Logical container name |
| `exec` | Yes | Command to execute in container |
| `workdir` | No | Working directory inside container |
| `paths` | No | Path mappings (source → dest) for argument translation |

### Command Key Naming Convention

When using wrapper scripts for automatic command routing, the command key in `bridge.yaml` must match the wrapper script name exactly:

| Command Key | Wrapper Script | Description |
|-------------|----------------|-------------|
| `go` | `/scripts/wrappers/go` | Go compiler |
| `gofmt` | `/scripts/wrappers/gofmt` | Go code formatter |
| `php` | `/scripts/wrappers/php` | PHP interpreter |
| `composer` | `/scripts/wrappers/composer` | PHP package manager |
| `node` | `/scripts/wrappers/node` | Node.js runtime |
| `npm` | `/scripts/wrappers/npm` | Node.js package manager |
| `npx` | `/scripts/wrappers/npx` | Node.js package runner |

Example configuration:

```yaml
commands:
  go:
    container: golang
    exec: go
    workdir: /workspace
  gofmt:
    container: golang
    exec: gofmt
    workdir: /workspace
```

### BRIDGE_ENABLED Environment Variable

The `BRIDGE_ENABLED` environment variable controls wrapper script behavior:

| Value | Behavior |
|-------|----------|
| `BRIDGE_ENABLED=1` | Commands route through the bridge to sidecar containers |
| Not set or `0` | Commands execute locally (passthrough mode) |

When `BRIDGE_ENABLED=1` is set, running `go build` in the Claude container will automatically:
1. Invoke the `/scripts/wrappers/go` wrapper
2. Look up the `go` command in `bridge.yaml`
3. Execute the command in the configured sidecar container

When not set, wrapper scripts fall back to local binaries, allowing the container to work standalone.

## Authentication

Authentication is handled **per-project** using a Docker named volume. This approach is more secure and portable than host bind mounts, as it doesn't require matching UIDs between host and container.

### First Run

1. Start the container in detached mode:
   ```bash
   docker compose up -d claude
   ```

2. Attach to the container:
   ```bash
   docker attach ai-dev-container-claude
   ```

3. Claude's init script will guide you through first-time setup:
   - Color/theme preferences
   - Authentication (sign in with your Anthropic account)
   - Other configuration options

4. Detach from the container without stopping it: press `Ctrl+P` followed by `Ctrl+Q`

### Subsequent Runs

After initial setup, your credentials are cached in the `claude-config` Docker volume. Future container starts will automatically use the cached credentials - no re-authentication needed.

The volume is project-specific (named `<project>_claude-config`, e.g., `ai-dev-container_claude-config`) so different projects maintain separate authentication states.

### Re-authentication

To force re-authentication (e.g., to switch accounts or fix auth issues), delete the config volume:

```bash
docker volume rm ai-dev-container_claude-config
```

Replace `ai-dev-container` with your project's directory name. After deletion, the next container start will trigger the first-run setup flow again.

## Claude Code Viewer

The Claude Code Viewer is a web-based interface for monitoring Claude sessions in real-time and reviewing historical logs. It runs as a separate service in the Docker Compose setup.

### Features

- **Real-time monitoring**: Watch Claude sessions as they happen
- **Session search**: Find specific sessions by project or content
- **Log viewing**: Review detailed session logs and conversation history

### Accessing the Viewer

The viewer is accessible at [http://localhost:3000](http://localhost:3000) by default when running with `docker compose up -d`.

To use a different port, set the `VIEWER_PORT` environment variable:

```bash
VIEWER_PORT=8080 docker compose up -d
```

Or add it to your `.env` file:

```
VIEWER_PORT=8080
```

The viewer reads session data from the same `claude-config` volume used by the Claude container, so it automatically has access to all session logs.

## Security Best Practices

### Socket Proxy Configuration

The Docker socket proxy limits Claude's access to only required operations:

```yaml
socket-proxy:
  image: tecnativa/docker-socket-proxy:latest
  environment:
    CONTAINERS: 1  # Required: list containers
    EXEC: 1        # Required: exec into containers
    POST: 1        # Required: create exec sessions
    # All other operations denied by default
```

### Credential Isolation

**Do NOT mount sensitive host directories:**

```yaml
# NEVER DO THIS - exposes your credentials to Claude
volumes:
  - ~/.ssh:/home/claude/.ssh        # DO NOT MOUNT
  - ~/.aws:/home/claude/.aws        # DO NOT MOUNT
  - ~/.config:/home/claude/.config  # DO NOT MOUNT
  - ~:/home/claude/host             # DO NOT MOUNT YOUR HOME DIRECTORY
```

**Instead, pass only required credentials as environment variables:**

```yaml
environment:
  ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
  # Add other required API keys here
```

### File Access

Claude only has access to:
- Files mounted at `/workspace` (your project directory)
- Docker socket proxy (limited to container exec operations)

### Non-Root User

The Claude container runs as a non-root user (`claude`, UID 1001) for additional security.

## YOLO Mode (Advanced)

For power users who want minimal confirmation prompts:

```yaml
environment:
  CLAUDE_YOLO: "1"
```

**WARNING:** This is dangerous and should only be used in isolated development environments. Claude may execute destructive commands without confirmation.

## Examples

See the `examples/` directory for:

- `docker-compose.yml` - Complete example with socket proxy, Claude, and sample app containers
- `compose.yml` - Same example in Docker Compose V2 format
- `claude-bridge.yaml` - Comprehensive bridge configuration with PHP, Node.js, and database commands
- `CLAUDE.md.template` - Template for project-specific Claude instructions

## Building the Image

```bash
docker build -t claude-brain-sidecar .
```

The image uses a multi-stage build:

1. **Go builder stage**: Compiles the bridge binary using `golang:1.24-alpine`
   - Bridge is compiled with `CGO_ENABLED=0` for a static binary
   - Binary is stripped with `-ldflags="-s -w"` to reduce size

2. **Runtime stage**: Based on `node:20-alpine` and includes:
   - Node.js 20 LTS
   - Claude Code CLI
   - Docker CLI (client only)
   - Go bridge binary (compiled from source)
   - Wrapper scripts for automatic command routing

## Requirements

- Docker and Docker Compose
- Anthropic API key
- Existing containerized application

## License

MIT
