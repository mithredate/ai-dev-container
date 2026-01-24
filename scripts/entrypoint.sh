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

# Initialize wrapper symlinks
# Creates symlinks in /scripts/wrappers that point to the dispatcher
# This must run after firewall init and before dropping to claude user
init_wrappers() {
    log "Initializing command wrappers..."
    if bridge --init-wrappers /scripts/wrappers 2>&1; then
        log "Wrapper initialization complete"
    else
        log "Warning: Wrapper initialization failed"
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

# Run Claude CLI (as claude user)
run_claude() {
    log "Starting Claude CLI..."
    run_as_user claude "$@"
}

# Main entry point
main() {
    # Initialize firewall on container start (runs once as root)
    init_firewall

    # Initialize wrapper symlinks (runs once after firewall)
    init_wrappers

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
