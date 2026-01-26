# Claude Sidecar

Headless Claude Code container that routes commands to sidecar containers via a Go bridge.

## Project Purpose

Provides a Docker image with Claude Code that:
- Uses a single dispatcher + symlinks to intercept binary calls (go, php, npm, etc.)
- Forwards calls to a Go bridge that routes them to the correct sidecar container
- Provides secure Docker socket access via proxy
- Includes network firewall with allowed domain whitelist

## Project Structure

```
cmd/bridge/         # Go bridge binary (main.go, config.go)
scripts/
  entrypoint.sh     # Container entrypoint (firewall init, drops to claude user)
  init-firewall.sh  # iptables + ipset firewall setup
  wrappers/
    dispatcher      # Single script that routes all commands through bridge
    <symlinks>      # Generated at startup, point to dispatcher
.sidecar/           # Config dir (bridge.yaml, allowed-domains.txt)
examples/           # Example compose and bridge configs
```

## Build & Test

```bash
docker build -t claude-sidecar .          # Build image
docker compose up -d claude                  # Start container
docker compose exec claude claude            # Run Claude interactively
```

## Key Components

- **Bridge** (`cmd/bridge/`): Go binary that routes commands. Supports two execution paths:
  1. Sidecar routing - commands configured in `commands` run via `docker exec`
  2. Fallthrough - unknown commands attempt native execution via `exec.LookPath`
- **Dispatcher** (`scripts/wrappers/dispatcher`): Single script that routes all commands through the bridge
- **Symlinks**: Generated at startup via `bridge --init-wrappers`, point to dispatcher
- **Firewall** (`scripts/init-firewall.sh`): Uses ipset + iptables to whitelist domains. Config from `$SIDECAR_CONFIG_DIR/allowed-domains.txt`

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `SIDECAR_CONFIG_DIR` | Config directory (default: `$PWD/.sidecar`) |
| `CLAUDE_YOLO` | Set `1` for `--dangerously-skip-permissions` |
| `PUID` | Set container user UID at runtime (for volume permissions) |
| `PGID` | Set container group GID at runtime (for volume permissions) |

## Development Workflow

The `ralph/` directory contains an autonomous agent loop for feature development. It is NOT part of the core project functionality.

When working on features:
1. Read `./ralph/claude.prompt.md` for current task context
2. Keep `./ralph/progress.txt` updated with progress

## References

- More about claude code (claude binary inside the claude container): ./agent-docs/claude-code.md