# PRD: Claude Brain Sidecar v2

## Introduction

Overhaul the Claude Brain Sidecar Docker image to provide a better developer experience. The current implementation requires users to manually start Claude after entering the container, and the shell-based bridge script has complexity issues. This update makes Claude the default entrypoint, adds YOLO mode support via `--dangerously-skip-permissions`, and migrates the bridge script from shell to Go for reliability and maintainability.

**Key architectural principle:** Claude orchestrates, sibling containers execute.

## Goals

- Run Claude automatically when container starts (`docker run --rm -it {image}` → interactive Claude session)
- Support YOLO mode via `CLAUDE_YOLO=1` environment variable (runs `claude --dangerously-skip-permissions`)
- Replace shell bridge script with Go binary for reliability and better error handling
- Support real-time output streaming from sidecar container commands
- Support path translation between Claude's `/workspace` and container-specific paths via config
- Remove yq dependency (Go handles YAML natively)
- Maintain image size under 150MB

## User Stories

### US-001: Create entrypoint wrapper script
**Description:** As a user, I want the container to start Claude automatically so that I don't have to manually run it after entering the container.

**Acceptance Criteria:**
- [ ] Create `/scripts/entrypoint.sh` wrapper script
- [ ] Script runs `claude` by default when container starts
- [ ] Running `docker run --rm -it {image}` gives interactive Claude session immediately
- [ ] Dockerfile uses `ENTRYPOINT ["/scripts/entrypoint.sh"]`
- [ ] Remove `CMD ["sh"]` from Dockerfile
- [ ] Script is executable (chmod +x)

### US-002: Implement YOLO mode in entrypoint
**Description:** As a power user, I want to run Claude with minimal confirmation prompts so that I can automate workflows in isolated environments.

**Acceptance Criteria:**
- [ ] When `CLAUDE_YOLO=1` is set, entrypoint runs `claude --dangerously-skip-permissions`
- [ ] When `CLAUDE_YOLO` is unset or `0`, entrypoint runs `claude` (safe mode)
- [ ] Running `docker run --rm -it -e CLAUDE_YOLO=1 {image}` starts Claude in permissive mode
- [ ] Entrypoint script logs which mode is being used to stderr

### US-003: Initialize Go module for bridge
**Description:** As a developer, I need a Go module structure so that I can build the bridge binary.

**Acceptance Criteria:**
- [ ] Create `/cmd/bridge/main.go` with basic CLI skeleton
- [ ] Create `/go.mod` with module path `github.com/mithredate/ai-dev-container`
- [ ] Add dependency on `gopkg.in/yaml.v3` for config parsing
- [ ] `go build ./cmd/bridge` compiles successfully
- [ ] Binary shows help text when run with `--help`

### US-004: Implement config parsing in Go bridge
**Description:** As a user, I want the Go bridge to read my bridge.yaml configuration so that commands route to the correct containers.

**Acceptance Criteria:**
- [ ] Bridge reads config from `/workspace/.claude/bridge.yaml` by default
- [ ] Bridge supports `BRIDGE_CONFIG` env var to override config path
- [ ] Config schema supports: `version`, `default_container`, `containers`, `commands`
- [ ] Invalid YAML produces clear error message with line number
- [ ] Missing required fields produce specific error messages
- [ ] Missing config file produces error with example config path

### US-005: Implement path mapping in Go bridge
**Description:** As a user, I want the bridge to translate file paths between Claude's workspace and container working directories so that file references work correctly.

**Acceptance Criteria:**
- [ ] Config schema supports `paths` section for path mappings
- [ ] Example: `paths: { "/workspace": "/var/www/html" }` translates paths in commands
- [ ] Path translation applied to command arguments containing mapped prefixes
- [ ] Path translation is optional (works without `paths` section)
- [ ] Multiple path mappings supported per container

### US-006: Implement command routing in Go bridge
**Description:** As a user, I want the bridge to execute commands in the correct sidecar container based on my configuration.

**Acceptance Criteria:**
- [ ] `bridge <command> [args...]` executes command in configured container
- [ ] Uses `docker exec` to run commands in target container
- [ ] Supports `workdir` option to set working directory in container
- [ ] Supports `exec` option to map command alias to actual command
- [ ] Unrecognized commands use `default_container` if configured
- [ ] Unrecognized commands without default produce clear error
- [ ] Container name resolution uses `containers` section overrides

### US-007: Implement real-time output streaming
**Description:** As a user, I want to see command output in real-time so that I can monitor long-running operations like test suites or package installations.

**Acceptance Criteria:**
- [ ] stdout from docker exec streams to bridge stdout in real-time
- [ ] stderr from docker exec streams to bridge stderr in real-time
- [ ] No buffering of output (visible as commands produce it)
- [ ] TTY allocated when bridge is run in a terminal (for colored output)
- [ ] Works correctly with commands that produce incremental output (e.g., `npm install`)

### US-008: Implement exit code propagation
**Description:** As a user, I want the bridge to return the same exit code as the remote command so that scripts can detect failures.

**Acceptance Criteria:**
- [ ] Bridge exits with same code as the docker exec command
- [ ] Exit code 0 when command succeeds
- [ ] Non-zero exit code when command fails
- [ ] Exit code 1 when bridge itself fails (config error, docker error)

### US-009: Update Dockerfile for Go multi-stage build
**Description:** As a developer, I need the Dockerfile to compile the Go bridge and include it in the final image.

**Acceptance Criteria:**
- [ ] Add Go builder stage using `golang:1.22-alpine`
- [ ] Compile bridge with `CGO_ENABLED=0` for static binary
- [ ] Copy bridge binary to `/usr/local/bin/bridge` in runtime stage
- [ ] Remove yq binary and wget from builder stage
- [ ] Remove `/scripts/bridge` shell script
- [ ] Final image size remains under 150MB
- [ ] `docker build` completes successfully

### US-010: Update examples with path mapping
**Description:** As a user reading the documentation, I want to see how to configure path mapping so that I can set it up for my project.

**Acceptance Criteria:**
- [ ] Update `examples/claude-bridge.yaml` with `paths` section example
- [ ] Show mapping from `/workspace` to container-specific paths
- [ ] Include comments explaining when path mapping is needed
- [ ] Example demonstrates PHP container with `/var/www/html` mapping

### US-011: Update documentation
**Description:** As a user, I want updated documentation reflecting the new entrypoint and Go bridge so that I can use the image correctly.

**Acceptance Criteria:**
- [ ] Update README.md with new `docker run` usage (no manual claude start)
- [ ] Document YOLO mode with security warnings
- [ ] Update bridge configuration docs for path mapping feature
- [ ] Remove references to yq dependency
- [ ] Update "Building the Image" section to mention Go compilation

## Functional Requirements

- FR-01: Container MUST run `claude` as the default entrypoint command
- FR-02: When `CLAUDE_YOLO=1`, container MUST run `claude --dangerously-skip-permissions`
- FR-03: Bridge binary MUST be compiled from Go source in `/cmd/bridge`
- FR-04: Bridge MUST read configuration from `/workspace/.claude/bridge.yaml`
- FR-05: Bridge MUST support path translation via `paths` config section
- FR-06: Bridge MUST stream stdout/stderr in real-time (no buffering)
- FR-07: Bridge MUST propagate exit codes from remote commands
- FR-08: Bridge MUST use `docker exec` via Docker CLI (not Docker API directly)
- FR-09: Bridge MUST allocate TTY when running in a terminal
- FR-10: Image MUST NOT contain yq binary in final stage
- FR-11: Image MUST remain under 150MB total size
- FR-12: Bridge MUST provide clear error messages for config issues

## Non-Goals

- No Docker API client library (shell out to `docker` CLI for simplicity)
- No bridge daemon mode (runs as one-shot command)
- No automatic container discovery (requires explicit config)
- No support for `docker run` or `docker build` (exec only)
- No Windows container support
- No GUI or web interface
- No changes to PRD 1 (GHCR GitHub Actions workflow)

## Technical Considerations

### Go Bridge Architecture

```
cmd/bridge/
├── main.go           # CLI entry point, flag parsing
├── config.go         # YAML config loading and validation
├── executor.go       # Docker exec command building and running
└── paths.go          # Path translation logic
```

### Config Schema (v1)

```yaml
version: "1"

default_container: app  # Optional fallback

containers:             # Optional name overrides
  php: myproject-php-1
  node: myproject-node-1

paths:                  # Optional path mappings
  /workspace: /var/www/html

commands:
  artisan:
    container: php
    exec: php artisan
    workdir: /var/www/html
```

### Entrypoint Script

```bash
#!/bin/sh
if [ "$CLAUDE_YOLO" = "1" ]; then
    echo "Starting Claude in YOLO mode (--dangerously-skip-permissions)" >&2
    exec claude --dangerously-skip-permissions "$@"
else
    exec claude "$@"
fi
```

### Docker Exec Command Building

```
docker exec [-t] [-w workdir] <container> <command> [args...]
```

- `-t` added when stdin is a TTY
- `-w` added when `workdir` is configured
- Path translation applied to args before execution

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Container starts Claude directly | Pass/Fail | `docker run --rm -it {image}` shows Claude prompt |
| YOLO mode works | Pass/Fail | Verify `--dangerously-skip-permissions` in process list |
| Bridge streams real-time | Pass/Fail | `bridge npm install` shows progress as it happens |
| Exit codes propagate | Pass/Fail | `bridge false; echo $?` returns 1 |
| Image size | < 150MB | `docker images` output |
| No yq in image | Pass/Fail | `docker run {image} which yq` returns not found |

## Open Questions

1. Should the bridge support a `--dry-run` flag to show the docker command without executing?
2. Should path translation work bidirectionally (container paths back to /workspace in output)?
3. Should we add a `bridge init` command to generate a starter bridge.yaml?
4. Should the entrypoint support passing additional flags to claude (e.g., `docker run {image} --model opus`)?
