# PRD: Claude-Brain Sidecar Image

## Introduction

A lightweight, language-agnostic Docker image containing Claude Code designed to be added as a service to any existing `docker-compose.yml`. It acts as the "Brain" of the project, delegating code execution to specialized sidecar containers (PHP, Go, Node, etc.) via a secure Docker socket proxy. This keeps the AI environment lean while maintaining strict security boundaries.

The key architectural principle: Claude orchestrates, sibling containers execute.

## Goals

- **Modular Integration:** Drop-in service for any Docker Compose project with 5-10 lines of YAML
- **Minimal Footprint:** Alpine-based image containing only AI tools and Docker client (~100MB target)
- **Secure Command Delegation:** Use Docker Socket Proxy to restrict Claude to `exec` operations only on sibling containers
- **Configurable Bridge:** YAML-based configuration for mapping commands to target containers
- **Credential Isolation:** Zero access to host filesystem credentials (SSH keys, AWS configs, etc.)

## User Stories

### US-001: Quick Compose Integration

**Description:** As a developer, I want to add Claude to my existing project by adding a few lines to my `docker-compose.yml`, so that I can start using AI assistance without rebuilding my stack.

**Acceptance Criteria:**
- [ ] Image available via `docker pull` from a public registry
- [ ] Example `docker-compose.yml` snippet provided in documentation
- [ ] Claude container shares project volume with other services at consistent path (`/workspace`)
- [ ] Claude container joins the same Docker network as app services
- [ ] No changes required to existing service definitions

### US-002: Docker Socket Proxy Setup

**Description:** As a security-conscious developer, I want Claude to communicate with sibling containers through a restricted proxy, so that it cannot perform dangerous Docker operations.

**Acceptance Criteria:**
- [ ] Documentation includes `tecnativa/docker-socket-proxy` service configuration
- [ ] Proxy configured to allow ONLY: `CONTAINERS=1`, `EXEC=1`, `POST=1`
- [ ] Proxy denies: `IMAGES`, `VOLUMES`, `NETWORKS`, `BUILD`, `COMMIT`, `SWARM`
- [ ] Claude container connects to proxy (port 2375), NOT the raw Docker socket
- [ ] Attempting `docker run` or `docker build` from Claude container fails with permission error

### US-003: Bridge Configuration File

**Description:** As a user, I want to define command-to-container mappings in a YAML file, so that Claude knows which container should execute which command.

**Acceptance Criteria:**
- [ ] `claude-bridge.yaml` file format documented with examples
- [ ] File mounted into Claude container at `/workspace/.claude/bridge.yaml`
- [ ] Bridge script reads config and routes commands to correct containers
- [ ] Supports command aliases (e.g., `test:php` → `docker exec app_php vendor/bin/phpunit`)
- [ ] Supports default container for unspecified commands
- [ ] Invalid config produces clear error message on container start

### US-004: Remote Command Execution

**Description:** As a user, I want Claude to run tests and commands inside the appropriate sibling container, so that I don't need language runtimes in the Claude image.

**Acceptance Criteria:**
- [ ] Running `bridge test:php` executes `phpunit` in the PHP container
- [ ] Running `bridge test:go` executes `go test` in the Go container
- [ ] Command output streams in real-time (not buffered until completion)
- [ ] Exit codes propagate correctly (non-zero exit = command failed)
- [ ] STDERR and STDOUT both captured and displayed
- [ ] Commands can include arguments (e.g., `bridge test:php --filter=UserTest`)

### US-005: Credential Isolation

**Description:** As a developer, I want to ensure the Claude container has no access to my host machine's sensitive files, so that a compromised AI cannot exfiltrate credentials.

**Acceptance Criteria:**
- [ ] Container has no volume mount to host `~/.ssh`
- [ ] Container has no volume mount to host `~/.aws`
- [ ] Container has no volume mount to host `~/.config`
- [ ] Running `ls ~/.ssh` inside container returns "No such file or directory"
- [ ] Required credentials passed as environment variables, not files
- [ ] Documentation warns against mounting home directory

### US-006: CLAUDE.md Integration

**Description:** As a user, I want to provide project-specific instructions to Claude via a CLAUDE.md file, so that it understands the project's architecture and conventions.

**Acceptance Criteria:**
- [ ] Template CLAUDE.md provided with multi-container project sections
- [ ] Claude reads `/workspace/CLAUDE.md` on startup if present
- [ ] Template includes sections for: project overview, container topology, testing commands, deployment notes
- [ ] Template includes example bridge command references

### US-007: Session Persistence

**Description:** As a user, I want my Claude authentication and settings to persist across container restarts, so that I don't need to re-authenticate each time.

**Acceptance Criteria:**
- [ ] Local `.claude/` folder can be mounted for session persistence
- [ ] Authentication tokens stored in mounted volume
- [ ] Settings and preferences preserved
- [ ] Works with or without persistence mount (graceful fallback)

### US-008: YOLO Mode Configuration

**Description:** As a power user, I want to configure Claude to run with minimal confirmation prompts, so that I can automate workflows.

**Acceptance Criteria:**
- [ ] `CLAUDE_YOLO=1` environment variable enables permissive mode
- [ ] When enabled, Claude executes commands without confirmation prompts
- [ ] Behavior clearly documented with security warnings
- [ ] Default is YOLO disabled (safe mode)

## Functional Requirements

- **FR-01:** Base image MUST be Alpine Linux with Node.js 20+ LTS
- **FR-02:** Image MUST include `claude-code` CLI installed globally via npm
- **FR-03:** Image MUST include `docker-cli` (client only, no daemon)
- **FR-04:** Image MUST include a `bridge` shell script at `/usr/local/bin/bridge`
- **FR-05:** Bridge script MUST read configuration from `/workspace/.claude/bridge.yaml`
- **FR-06:** Bridge script MUST translate aliased commands to `docker exec` calls
- **FR-07:** Bridge script MUST stream output in real-time using `docker exec -t`
- **FR-08:** Bridge script MUST propagate exit codes from remote commands
- **FR-09:** Container MUST set `DOCKER_HOST=tcp://socket-proxy:2375` when proxy is used
- **FR-10:** Image MUST NOT contain PHP, Python, Go, Ruby, or other language runtimes
- **FR-11:** Image MUST NOT include Docker daemon components
- **FR-12:** Dockerfile MUST use multi-stage build for minimal final image size
- **FR-13:** Image MUST run as non-root user by default
- **FR-14:** Image MUST set working directory to `/workspace`

## Non-Goals

- **NOT** a general-purpose development container (no language runtimes)
- **NOT** responsible for starting/stopping other containers (no `docker-compose` commands)
- **NOT** a GUI tool (CLI-first, terminal-only)
- **NOT** including other AI tools (aider, amp, cursor) — Claude Code only
- **NOT** managing secrets rotation or vault integration
- **NOT** providing container orchestration beyond `exec` commands

## Technical Considerations

### Docker Socket Proxy Configuration

The recommended `docker-compose.yml` addition for the socket proxy:

```yaml
services:
  socket-proxy:
    image: tecnativa/docker-socket-proxy
    environment:
      CONTAINERS: 1
      EXEC: 1
      POST: 1
      # Everything else defaults to 0 (denied)
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - internal

  claude:
    image: your-registry/claude-brain:latest
    environment:
      DOCKER_HOST: tcp://socket-proxy:2375
    volumes:
      - .:/workspace
      - ./.claude:/home/claude/.claude  # Session persistence
    networks:
      - internal
    depends_on:
      - socket-proxy
```

### Bridge Configuration Format

Example `claude-bridge.yaml`:

```yaml
version: "1"

# Default container if command prefix not recognized
default_container: app

# Command mappings
commands:
  # Format: alias -> container:command
  test:php:
    container: php
    exec: vendor/bin/phpunit
    workdir: /workspace

  test:go:
    container: go
    exec: go test ./...
    workdir: /workspace

  lint:php:
    container: php
    exec: vendor/bin/phpcs
    workdir: /workspace

  composer:
    container: php
    exec: composer
    workdir: /workspace

# Container name overrides (when container_name differs from service name)
containers:
  php: myproject_php_1
  go: myproject_go_1
```

### Volume Path Consistency

Critical: The project source must be mounted at the same path in ALL containers:

```yaml
services:
  php:
    volumes:
      - .:/workspace  # Same path

  claude:
    volumes:
      - .:/workspace  # Same path
```

This ensures file paths in error messages and Claude's edits match across containers.

### Image Size Budget

Target final image size: < 150MB

- Alpine base: ~5MB
- Node.js: ~50MB
- Claude Code + dependencies: ~80MB
- Docker CLI: ~15MB

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Image size | < 150MB | `docker images` output |
| Integration time | < 2 minutes | Time to add to existing compose file |
| Credential isolation | 100% | `ls ~/.ssh` returns "No such file" |
| Command delegation | Works | `bridge test:php` runs phpunit in PHP container |
| Socket security | Restricted | `docker run` from Claude fails with permission error |

## Open Questions

1. **Registry location:** Should this be published to Docker Hub, GitHub Container Registry, or both?

2. **Versioning strategy:** Should image tags follow Claude Code versions, or independent semver?

3. **Health check:** Should the Claude container include a health check endpoint/command?

4. **Logging:** Should bridge command executions be logged to a file for debugging?

5. **TTY handling:** How should we handle commands that require interactive TTY (e.g., `psql` shell)?

## Appendix: Example CLAUDE.md Template

```markdown
# Project: [Your Project Name]

## Architecture

This is a multi-container Docker project. Claude runs as a sidecar and delegates execution:

| Service | Container | Purpose |
|---------|-----------|---------|
| php | myproject_php_1 | Laravel application |
| go | myproject_go_1 | Microservices |
| db | myproject_db_1 | PostgreSQL database |

## Running Commands

Use the `bridge` command to run operations in the correct container:

- `bridge test:php` - Run PHPUnit tests
- `bridge test:go` - Run Go tests
- `bridge composer install` - Install PHP dependencies

## File Structure

- `/workspace` - Project root (same path in all containers)
- `/workspace/.claude/bridge.yaml` - Container routing config

## Testing

Always run tests through bridge:
- PHP: `bridge test:php --filter=TestName`
- Go: `bridge test:go -v ./path/to/package`

## Do Not

- Do NOT try to run `php` or `go` directly (not installed)
- Do NOT modify docker-compose.yml without asking
- Do NOT access containers not listed in bridge.yaml
```
