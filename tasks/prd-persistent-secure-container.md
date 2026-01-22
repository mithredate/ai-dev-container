# PRD: Persistent Secure Claude Container

## Introduction

Improve the headless Claude Code container to support persistent operation (stay alive between Claude sessions) and configurable network isolation. Users should be able to `docker compose exec` into the container to run Claude on demand, with the container staying alive for subsequent sessions. Network firewall rules should be configurable per-project with sensible defaults.

## Goals

- Container stays running indefinitely, Claude executed on-demand via `docker exec`
- Ctrl+C exits Claude session without killing the container
- Configurable network firewall with per-project allowlist
- Sensible default firewall rules (GitHub, npm, Anthropic API, etc.)
- Claude can read/write workspace files without permission issues
- Maintain small image size with Alpine base

## User Stories

### US-001: Persistent container with sleep entrypoint
**Description:** As a developer, I want the container to stay running so I can execute Claude multiple times without container restarts.

**Acceptance Criteria:**
- [ ] Container uses `tail -f /dev/null` or `sleep infinity` as entrypoint
- [ ] Container stays running after `docker compose up -d`
- [ ] `docker compose exec claude claude` starts Claude interactively
- [ ] Ctrl+C exits Claude but container remains running
- [ ] Can run Claude again with another `exec` command
- [ ] Container only stops on explicit `docker compose down`

### US-002: Install firewall dependencies in Alpine
**Description:** As a developer, I need the firewall tools available in the container image.

**Acceptance Criteria:**
- [ ] `iptables` package installed
- [ ] `ipset` package installed
- [ ] `iproute2` package installed (for `ip` command)
- [ ] `bind-tools` package installed (for `dig` command)
- [ ] `curl` available for fetching GitHub IP ranges
- [ ] `jq` available for parsing JSON responses
- [ ] Image size increase is minimal (<15MB)

### US-003: Create configurable firewall initialization script
**Description:** As a developer, I want network isolation with configurable allowed domains so each project can define its own network access rules.

**Acceptance Criteria:**
- [ ] `init-firewall.sh` script created and executable
- [ ] Script reads allowed domains from `/workspace/.aidevcontainer/allowed-domains.txt` if it exists
- [ ] Falls back to default allowed domains if project config doesn't exist
- [ ] Default domains include: GitHub (dynamic IPs), registry.npmjs.org, api.anthropic.com, sentry.io, statsig.anthropic.com, statsig.com
- [ ] Script uses `ipset` for efficient IP matching
- [ ] Script fetches GitHub IP ranges dynamically from api.github.com/meta
- [ ] Script resolves domain names to IPs via DNS
- [ ] Blocks all other outbound traffic
- [ ] Allows localhost and DNS traffic
- [ ] Verifies firewall works (can reach GitHub, cannot reach example.com)
- [ ] Script logs progress and errors clearly

### US-004: Docker Compose configuration for firewall
**Description:** As a developer, I want the firewall to initialize automatically when the container starts.

**Acceptance Criteria:**
- [ ] `docker-compose.yml` includes `cap_add: [NET_ADMIN, NET_RAW]`
- [ ] Firewall script runs on container start (not on every exec)
- [ ] Script runs as root, container runs as non-root user
- [ ] Firewall persists for lifetime of container

### US-005: Configurable user permissions for workspace access
**Description:** As a developer, I want Claude to create files that I can edit on the host without permission errors, with UID configurable to match my host system.

**Acceptance Criteria:**
- [ ] Container user UID is configurable via `CLAUDE_UID` build arg
- [ ] Container user GID is configurable via `CLAUDE_GID` build arg
- [ ] Default UID/GID is 501 (macOS default) for cross-platform convenience
- [ ] docker-compose.yml documents how to override for Linux (`CLAUDE_UID=1000`)
- [ ] Claude can create new files in /workspace
- [ ] Claude can edit existing files in /workspace
- [ ] New files created by Claude are owned by the configured UID
- [ ] Host user can edit files created by Claude without `sudo`

### US-006: Update documentation with new usage pattern
**Description:** As a developer, I want clear instructions on how to use the persistent container.

**Acceptance Criteria:**
- [ ] README documents the new `docker compose up -d` + `exec` workflow
- [ ] README explains how to customize allowed domains
- [ ] README shows example `.aidevcontainer/allowed-domains.txt` format
- [ ] README documents the firewall behavior
- [ ] README explains UID configuration (default 501 for macOS, use 1000 for Linux)

## Functional Requirements

- FR-1: Entrypoint must be a long-running process (`tail -f /dev/null`) that keeps container alive
- FR-2: Firewall script must run once on container start, not on every `exec`
- FR-3: Allowed domains config file format: one domain per line, comments start with `#`
- FR-4: Firewall must preserve Docker internal DNS resolution (127.0.0.11)
- FR-5: Firewall must allow established/related connections for approved traffic
- FR-6: Firewall must REJECT (not DROP) unauthorized traffic for immediate feedback
- FR-7: Container user UID/GID must be configurable via build args (default: 501 for macOS)
- FR-8: Claude config directory `/home/claude/.claude` must be writable

## Non-Goals

- No VS Code devcontainer.json (this is for headless use)
- No automatic Claude execution on container start
- No GUI or web interface
- No support for running as root
- No Windows container support
- No Debian/Ubuntu base image (staying with Alpine)

## Technical Considerations

- Alpine uses `apk` not `apt-get` for package management
- Alpine iptables syntax is the same as Debian
- The Go bridge binary should remain functional with new entrypoint
- Firewall script needs `sudo` access from non-root user, or must run as root during init
- Consider using `tini` as init process for proper signal handling
- GitHub IP ranges change frequently; fetch dynamically, don't hardcode

## File Structure

```
.
├── Dockerfile                    # Updated with firewall deps, configurable UID
├── docker-compose.yml           # Updated with caps, build args
├── scripts/
│   ├── entrypoint.sh            # Changed to sleep/tail
│   └── init-firewall.sh         # New firewall script
└── .aidevcontainer/
    └── allowed-domains.txt      # Example config (optional per-project)
```

## Configuration

### Build Args (docker-compose.yml)
```yaml
build:
  context: .
  args:
    CLAUDE_UID: 501    # macOS default, use 1000 for Linux
    CLAUDE_GID: 501
```

### Allowed Domains Format (.aidevcontainer/allowed-domains.txt)
```
# GitHub (IPs fetched dynamically)
github.com

# Package registries
registry.npmjs.org
pypi.org

# Anthropic services
api.anthropic.com
sentry.io
statsig.anthropic.com

# Custom domains for this project
api.mycompany.com
```

## Success Metrics

- Container stays running for 24+ hours without intervention
- Claude can be executed 10+ times without container restart
- Firewall blocks unauthorized domains (verified by test)
- No file permission errors when Claude creates/edits files
- Image size stays under 250MB

## Open Questions

1. Should we add `tini` as init process for better signal handling?
2. Should firewall rules be hot-reloadable without container restart?
3. Should the bridge binary be disabled by default in interactive mode?
