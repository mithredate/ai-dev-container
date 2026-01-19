# PRD: Docker Volume for Claude Authentication

## Introduction

Replace the insecure bind mount of `~/.claude` from the host with a named Docker volume for per-project Claude authentication. The current approach has a UID mismatch problem: host files are owned by UID 501 (macOS user) but the container runs as UID 1001, causing permission errors when reading credentials.

Using a named Docker volume solves this by keeping credentials entirely within Docker's managed storage, with proper permissions set by the container user. Users authenticate once per project on first run, and credentials persist in the volume for subsequent sessions.

## Goals

- Eliminate UID mismatch permission errors for Claude authentication
- Provide secure, per-project credential isolation (no host filesystem exposure)
- Maintain simple first-run experience via Claude's built-in init flow
- Document the authentication workflow clearly in README

## User Stories

### US-001: Replace bind mount with named volume in compose.yaml
**Description:** As a developer, I want Claude credentials stored in a Docker volume so that authentication works regardless of host UID.

**Acceptance Criteria:**
- [ ] Remove `~/.claude:/home/claude/.claude` bind mount from compose.yaml
- [ ] Add named volume `claude-config` mapped to `/home/claude/.claude`
- [ ] Define `claude-config` in the `volumes:` section of compose.yaml
- [ ] Container starts successfully with `docker compose up -d`
- [ ] Volume is created with project-prefixed name (e.g., `ai-dev-container_claude-config`)

### US-002: Update README with first-run authentication instructions
**Description:** As a new user, I want clear instructions on how to authenticate Claude on first run so I can get started quickly.

**Acceptance Criteria:**
- [ ] README explains that authentication is per-project and stored in a Docker volume
- [ ] README documents the first-run workflow: `docker compose up -d` then `docker attach claude`
- [ ] README explains that Claude's init script will guide through setup (colors, auth, etc.)
- [ ] README notes that subsequent runs will use cached credentials from the volume
- [ ] Remove any references to mounting `~/.claude` from host

### US-003: Document re-authentication process
**Description:** As a user who needs to re-authenticate, I want to know how to reset my credentials.

**Acceptance Criteria:**
- [ ] README documents how to delete the volume to force re-authentication
- [ ] Command provided: `docker volume rm <project>_claude-config`
- [ ] Notes that this will require going through Claude init again

## Functional Requirements

- FR-1: Replace host bind mount with named Docker volume for `/home/claude/.claude`
- FR-2: Volume must persist across container restarts and rebuilds
- FR-3: Volume name must be descriptive (e.g., `claude-config`) - Docker Compose handles project prefix
- FR-4: First-run flow must work: `docker compose up -d` followed by `docker attach claude`
- FR-5: Claude init script must successfully save credentials to the volume

## Non-Goals

- No helper scripts or Makefile targets for authentication
- No sharing credentials across different projects
- No migration of existing host `~/.claude` credentials into the volume
- No custom volume drivers or external storage

## Technical Considerations

- Docker Compose automatically prefixes volume names with the project name (directory name by default)
- Named volumes have correct permissions because they're created by the container user
- The volume persists even if the container is removed; only `docker volume rm` deletes it
- Users can inspect volume contents with `docker volume inspect <name>`

## Success Metrics

- New users can authenticate on first run without permission errors
- Credentials persist across `docker compose down` and `docker compose up` cycles
- No host filesystem exposure of sensitive credentials

## Open Questions

None - scope is well-defined.
