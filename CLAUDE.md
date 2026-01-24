# AI Dev Container

Headless Claude Code container that routes commands to sidecar containers via a Go bridge.

## Project Purpose

Provides a Docker image with Claude Code that:
- Uses wrapper scripts to intercept binary calls (go, php, npm, etc.)
- Forwards calls to a Go bridge that routes them to the correct sidecar container
- Provides secure Docker socket access via proxy
- Includes network firewall with allowed domain whitelist

## Project Structure

```
cmd/bridge/         # Go bridge binary (main.go, config.go)
scripts/
  entrypoint.sh     # Container entrypoint (firewall init, drops to claude user)
  init-firewall.sh  # iptables + ipset firewall setup
  wrappers/         # Command wrappers that route to bridge
.aidevcontainer/    # Config dir (bridge.yaml, allowed-domains.txt)
examples/           # Example compose and bridge configs
```

## Build & Test

```bash
docker build -t ai-dev-container .          # Build image
docker compose up -d claude                  # Start container
docker compose exec claude claude            # Run Claude interactively
```

## Key Components

- **Bridge** (`cmd/bridge/`): Go binary that executes `docker exec` to route commands. Config from `$AIDEV_CONFIG_DIR/bridge.yaml`
- **Wrappers** (`scripts/wrappers/`): Shell scripts that call `bridge <cmd> <args>` when `BRIDGE_ENABLED=1`
- **Firewall** (`scripts/init-firewall.sh`): Uses ipset + iptables to whitelist domains. Config from `$AIDEV_CONFIG_DIR/allowed-domains.txt`

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `BRIDGE_ENABLED` | Set `1` to route commands through bridge |
| `AIDEV_CONFIG_DIR` | Config directory (default: `$PWD/.aidevcontainer`) |
| `CLAUDE_YOLO` | Set `1` for `--dangerously-skip-permissions` |

## Development Workflow

The `ralph/` directory contains an autonomous agent loop for feature development. It is NOT part of the core project functionality.

When working on features:
1. Read `./ralph/claude.prompt.md` for current task context
2. Keep `./ralph/progress.txt` updated with progress
