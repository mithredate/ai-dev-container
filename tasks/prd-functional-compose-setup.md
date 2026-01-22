# PRD: Functional Docker Compose Setup

## Introduction

The current `compose.yaml` is incomplete - it lacks the socket-proxy security layer and Claude doesn't know to route commands through the bridge. This PRD addresses making the Docker Compose setup fully functional so that Claude Code running inside the container can execute commands (go, php, node, etc.) in sidecar containers transparently.

The solution uses PATH-based command interception: wrapper scripts in `/usr/local/bin/` intercept common commands and route them through the bridge, which reads `bridge.yaml` to determine the target container.

## Goals

- Fix `compose.yaml` to include socket-proxy for secure Docker exec operations
- Add command wrapper scripts that transparently route commands through the bridge
- Document the key name convention for bridge.yaml
- Merge documentation updates (from US-013) into this effort
- Verify the setup works end-to-end inside the container

## User Stories

### US-014: Add socket-proxy to compose.yaml
**Description:** As a user, I want the compose setup to use a socket proxy so that Docker operations are secure and limited to exec only.

**Acceptance Criteria:**
- [ ] `compose.yaml` includes `tecnativa/docker-socket-proxy` service
- [ ] Socket-proxy allows only CONTAINERS=1, EXEC=1, POST=1
- [ ] Claude service uses `DOCKER_HOST: tcp://socket-proxy:2375`
- [ ] Docker socket mounted read-only to socket-proxy only
- [ ] Claude service no longer mounts docker.sock directly
- [ ] Typecheck passes (go build, go vet)

### US-015: Create command wrapper scripts
**Description:** As a user, I want common commands (go, php, node, etc.) to automatically route through the bridge so that Claude can use them naturally without special syntax.

**Acceptance Criteria:**
- [ ] Create wrapper scripts in `/scripts/wrappers/` for: go, gofmt, php, composer, node, npm, npx
- [ ] Each wrapper calls `bridge <command> "$@"`
- [ ] Wrappers check `BRIDGE_ENABLED=1` env var; if not set, execute command locally (passthrough)
- [ ] Wrappers are copied to `/usr/local/bin/` in Dockerfile
- [ ] Wrappers have executable permissions (chmod +x)
- [ ] Typecheck passes (go build, go vet)

### US-016: Update Dockerfile for wrappers
**Description:** As a developer, I need the Dockerfile to include the wrapper scripts so they're available in the final image.

**Acceptance Criteria:**
- [ ] Dockerfile copies wrapper scripts from `/scripts/wrappers/` to `/usr/local/bin/`
- [ ] Wrappers are placed AFTER any package-installed binaries (to take precedence in PATH)
- [ ] `BRIDGE_ENABLED` env var defaults to "1" in compose.yaml
- [ ] Docker build completes successfully
- [ ] Typecheck passes (go build, go vet)

### US-017: Update bridge.yaml for this project
**Description:** As a developer working on ai-dev-container, I need the project's bridge.yaml to have the correct container name matching compose.yaml.

**Acceptance Criteria:**
- [ ] `.aidevcontainer/bridge.yaml` container name matches compose.yaml (`ai-dev-container-golang`)
- [ ] Command key names match wrapper script names (go, gofmt)
- [ ] Typecheck passes (go build, go vet)

### US-018: Update documentation (README.md)
**Description:** As a user, I want updated documentation so I understand how to use the new entrypoint, YOLO mode, and bridge configuration.

**Acceptance Criteria:**
- [ ] README documents new `docker compose up` usage (no manual claude start needed)
- [ ] README documents YOLO mode with security warnings
- [ ] README documents bridge.yaml key name convention (go, php, node, npm, composer, npx, gofmt)
- [ ] README documents `BRIDGE_ENABLED` env var for passthrough mode
- [ ] README removes references to yq dependency
- [ ] README mentions Go compilation in "Building the Image" section
- [ ] Typecheck passes (go build, go vet)

### US-019: Verify setup works end-to-end
**Description:** As a developer, I want to verify the compose setup works by running commands inside the container.

**Acceptance Criteria:**
- [ ] `docker compose up -d` starts all services successfully
- [ ] `docker compose exec claude bridge go version` returns Go version from golang container
- [ ] `docker compose exec claude go version` (via wrapper) returns same Go version
- [ ] Create a test file via Claude: `echo "test" > /workspace/test-output.txt`
- [ ] Verify test file exists on host filesystem
- [ ] Clean up: remove test file
- [ ] `docker compose down` stops all services
- [ ] Typecheck passes (go build, go vet)

## Functional Requirements

- FR-1: Socket-proxy service filters Docker API to allow only container listing and exec operations
- FR-2: Claude container connects to Docker via `tcp://socket-proxy:2375`, not direct socket mount
- FR-3: Wrapper scripts intercept commands: go, gofmt, php, composer, node, npm, npx
- FR-4: When `BRIDGE_ENABLED=1`, wrappers route through bridge; otherwise execute locally
- FR-5: Bridge reads `bridge.yaml` and routes to configured container based on command key name
- FR-6: Command key names in bridge.yaml must match wrapper script names exactly
- FR-7: Documentation covers all new features with examples

## Non-Goals

- No MCP server implementation (using PATH wrappers instead)
- No automatic detection of available commands (wrappers are static)
- No support for custom wrapper commands beyond the standard set
- No Windows/non-Unix support for wrapper scripts

## Technical Considerations

- **Wrapper script pattern:**
  ```sh
  #!/bin/sh
  if [ "$BRIDGE_ENABLED" = "1" ] && [ -x /usr/local/bin/bridge ]; then
    exec /usr/local/bin/bridge go "$@"
  else
    exec /usr/bin/go "$@"  # or appropriate fallback
  fi
  ```
- **Key name convention:** Wrapper filename must match bridge.yaml command key
  - `/usr/local/bin/go` → `commands.go` in bridge.yaml
  - `/usr/local/bin/php` → `commands.php` in bridge.yaml
- **PATH precedence:** Wrappers in `/usr/local/bin/` take precedence over system packages
- **Passthrough mode:** When `BRIDGE_ENABLED` is not "1", commands run locally (useful for non-sidecar usage)

## Success Metrics

- Claude can run `go build ./cmd/bridge` inside container and it executes in golang sidecar
- File changes made via Claude inside container appear on host filesystem
- Documentation is clear enough for new users to set up in <10 minutes

## Open Questions

- Should we add a health check to verify socket-proxy is ready before Claude starts?
- Should wrappers log when routing through bridge (for debugging)?
