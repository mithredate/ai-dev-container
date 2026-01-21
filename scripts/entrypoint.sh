#!/bin/sh
# shellcheck shell=dash
# Claude Container Entrypoint
# ===========================
# Persistent container entrypoint that keeps the container alive.
# Claude is started manually via: docker compose exec claude claude

set -e

# Log to stderr for visibility
log() {
    echo "[entrypoint] $1" >&2
}

# Run Claude CLI with appropriate flags
run_claude() {
    # Set CLAUDE_STARTING=1 so the node wrapper knows to use native node
    # for Claude's startup. The wrapper will unset this for child processes,
    # allowing subsequent node/npm/npx calls to be routed through the bridge.
    export CLAUDE_STARTING=1

    # Check for YOLO mode (skip all permission prompts)
    if [ "$CLAUDE_YOLO" = "1" ]; then
        log "Starting Claude CLI in YOLO mode (--dangerously-skip-permissions)..."
        exec claude --dangerously-skip-permissions "$@"
    else
        log "Starting Claude CLI..."
        exec claude "$@"
    fi
}

# Main entry point
main() {
    # If arguments provided and first arg is "claude", run Claude
    if [ "$1" = "claude" ]; then
        shift
        run_claude "$@"
    # If any other command is provided, execute it directly
    elif [ $# -gt 0 ]; then
        exec "$@"
    # Default: keep container alive for interactive exec sessions
    else
        log "Container started in persistent mode. Run Claude with:"
        log "  docker compose exec claude claude"
        exec tail -f /dev/null
    fi
}

main "$@"
