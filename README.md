# Claude Brain Sidecar

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
    environment:
      DOCKER_HOST: tcp://socket-proxy:2375
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
    volumes:
      - .:/workspace
```

Then run:

```bash
docker-compose run claude
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

## Session Persistence

To persist authentication across container restarts, add a volume mount:

```yaml
claude:
  volumes:
    - .:/workspace
    - ./.claude:/home/claude/.claude  # Persists auth tokens and settings
```

This is optional. Without it, you'll need to re-authenticate each time the container starts.

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

The image is built on Alpine Linux and includes:
- Node.js 20 LTS
- Claude Code CLI
- Docker CLI (client only)
- yq YAML parser
- Bridge script

## Requirements

- Docker and Docker Compose
- Anthropic API key
- Existing containerized application

## License

MIT
