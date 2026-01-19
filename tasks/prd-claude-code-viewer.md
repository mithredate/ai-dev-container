# PRD: Claude Code Viewer Integration

## Introduction

Add [claude-code-viewer](https://github.com/d-kimuson/claude-code-viewer) as a service in compose.yaml to provide a web-based UI for monitoring Claude Code sessions in real-time and reviewing historical session logs. This viewer reads from the standard Claude session logs (`~/.claude/projects/`) and provides features like full-text search, session resumption, and a progressive disclosure UI.

The viewer will run as a separate Docker service, sharing the `claude-config` volume with the main Claude container to access session logs. This enables monitoring Ralph agent runs in real-time and reviewing completed sessions through a modern web interface.

## Goals

- Enable real-time monitoring of Claude Code sessions via web UI
- Provide access to historical session logs for review and analysis
- Make the viewer available automatically when starting the compose stack
- Keep the port configurable for flexibility across different development setups
- Maintain zero authentication overhead for local development

## User Stories

### US-001: Add viewer service to compose.yaml
**Description:** As a developer, I want a viewer service defined in compose.yaml so that it starts automatically with the rest of the stack.

**Acceptance Criteria:**
- [ ] Add `viewer` service to compose.yaml using node:20-alpine base image
- [ ] Service runs `npx @kimuson/claude-code-viewer@latest` command
- [ ] Service mounts `claude-config` volume to `/home/node/.claude` for session log access
- [ ] Service depends on `claude` service (to ensure volume is initialized)
- [ ] Container starts successfully with `docker compose up -d`

### US-002: Configure viewer port via environment variable
**Description:** As a developer, I want to configure the viewer port via environment variable so I can avoid conflicts with other services.

**Acceptance Criteria:**
- [ ] Port configurable via `VIEWER_PORT` environment variable
- [ ] Default port is 3000 if `VIEWER_PORT` is not set
- [ ] Port mapping uses variable: `${VIEWER_PORT:-3000}:${VIEWER_PORT:-3000}`
- [ ] Viewer accessible at `http://localhost:<port>` after starting

### US-003: Configure viewer hostname for container access
**Description:** As a developer, I want the viewer to listen on 0.0.0.0 inside the container so it's accessible from the host.

**Acceptance Criteria:**
- [ ] Viewer runs with `--hostname 0.0.0.0` flag
- [ ] Viewer accessible from host browser at configured port
- [ ] Viewer shows sessions from the shared Claude config volume

### US-004: Update README with viewer documentation
**Description:** As a developer, I want documentation on how to use the viewer so I can monitor Claude sessions effectively.

**Acceptance Criteria:**
- [ ] README documents the viewer service and its purpose
- [ ] README explains how to access the viewer (default: http://localhost:3000)
- [ ] README documents the `VIEWER_PORT` environment variable
- [ ] README mentions key features: real-time monitoring, session search, log viewing

### US-005: Update .env.example with viewer configuration
**Description:** As a developer, I want an example environment file showing viewer configuration options.

**Acceptance Criteria:**
- [ ] Add `VIEWER_PORT=3000` to .env.example (or create if doesn't exist)
- [ ] Comment explaining the variable's purpose

## Functional Requirements

- FR-1: Add `viewer` service to compose.yaml using node:20-alpine image
- FR-2: Viewer service must run `npx @kimuson/claude-code-viewer@latest --port $PORT --hostname 0.0.0.0`
- FR-3: Viewer must share `claude-config` volume (mounted at `/home/node/.claude`)
- FR-4: Port must be configurable via `VIEWER_PORT` environment variable (default: 3000)
- FR-5: Viewer must start automatically with `docker compose up`
- FR-6: Viewer must be able to read session logs created by the claude container

## Non-Goals

- No authentication configuration (local development only)
- No custom viewer build or Dockerfile (use npx directly)
- No reverse proxy or TLS configuration
- No viewer profiles or optional startup (always starts with stack)
- No persistent viewer settings (uses defaults)

## Technical Considerations

- The viewer requires Node.js 20.19.0+ (node:20-alpine satisfies this)
- Session logs are stored in `~/.claude/projects/<project>/<session-id>.jsonl`
- The `claude-config` volume is already defined and used by the claude service
- Viewer needs `--hostname 0.0.0.0` to accept connections from outside the container
- Using `npx` ensures latest version without needing a custom Dockerfile
- The viewer runs as non-root user `node` (UID 1000) in node:20-alpine

## Success Metrics

- Viewer accessible at `http://localhost:3000` after `docker compose up -d`
- Can view active and historical Claude sessions in the web UI
- Can monitor Ralph agent runs in real-time
- Port customization works via `VIEWER_PORT` environment variable

## Open Questions

- Should we pin to a specific viewer version instead of `@latest` for reproducibility?
