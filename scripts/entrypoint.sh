#!/bin/sh
# shellcheck shell=dash
# Claude Container Entrypoint
# ===========================
# Persistent container entrypoint that keeps the container alive.
# Claude is started manually via: docker compose exec claude claude
#
# The container starts as root to initialize the firewall, then drops
# to the 'claude' user for all subsequent operations. The firewall
# persists for the lifetime of the container.

set -e

# Configuration
FIREWALL_INIT_SCRIPT="/scripts/init-firewall.sh"
FIREWALL_MARKER="/tmp/.firewall_initialized"
CONTAINER_USER="claude"

# Log to stderr for visibility
log() {
    echo "[entrypoint] $1" >&2
}

# Initialize firewall if not already done
# This runs as root and only runs once per container lifecycle
init_firewall() {
    # Skip if firewall already initialized (marker file exists)
    if [ -f "$FIREWALL_MARKER" ]; then
        log "Firewall already initialized (skipping)"
        return 0
    fi

    # Check if we have the firewall script
    if [ ! -x "$FIREWALL_INIT_SCRIPT" ]; then
        log "Warning: Firewall init script not found or not executable"
        return 0
    fi

    # Check if we're root (required for firewall setup)
    if [ "$(id -u)" -ne 0 ]; then
        log "Warning: Not running as root, skipping firewall initialization"
        return 0
    fi

    log "Initializing firewall..."
    if "$FIREWALL_INIT_SCRIPT"; then
        # Create marker file to prevent re-initialization
        touch "$FIREWALL_MARKER"
        log "Firewall initialization complete"
    else
        log "Warning: Firewall initialization failed (continuing without firewall)"
    fi
}

# Run a command as the claude user (if we're currently root)
run_as_user() {
    if [ "$(id -u)" -eq 0 ]; then
        exec su -s /bin/sh "$CONTAINER_USER" -c "$*"
    else
        exec "$@"
    fi
}

# Run Claude CLI with appropriate flags (as claude user)
run_claude() {
    # Set CLAUDE_STARTING=1 so the node wrapper knows to use native node
    # for Claude's startup. The wrapper will unset this for child processes,
    # allowing subsequent node/npm/npx calls to be routed through the bridge.
    export CLAUDE_STARTING=1

    # Check for YOLO mode (skip all permission prompts)
    if [ "$CLAUDE_YOLO" = "1" ]; then
        log "Starting Claude CLI in YOLO mode (--dangerously-skip-permissions)..."
        run_as_user claude --dangerously-skip-permissions "$@"
    else
        log "Starting Claude CLI..."
        run_as_user claude "$@"
    fi
}

# Main entry point
main() {
    # Initialize firewall on container start (runs once as root)
    init_firewall

    # If arguments provided and first arg is "claude", run Claude
    if [ "$1" = "claude" ]; then
        shift
        run_claude "$@"
    # If any other command is provided, execute it as claude user
    elif [ $# -gt 0 ]; then
        run_as_user "$@"
    # Default: keep container alive for interactive exec sessions
    else
        log "Container started in persistent mode. Run Claude with:"
        log "  docker compose exec claude claude"
        # Keep container alive (can run as root, no security concern)
        exec tail -f /dev/null
    fi
}

main "$@"
