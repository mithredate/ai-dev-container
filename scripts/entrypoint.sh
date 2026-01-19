#!/bin/sh
# shellcheck shell=dash
# Claude Container Entrypoint
# ===========================
# Starts Claude CLI automatically when the container launches.

set -e

# Log to stderr for visibility
log() {
    echo "[entrypoint] $1" >&2
}

# Main entry point
main() {
    # Set CLAUDE_STARTING=1 so the node wrapper knows to use native node
    # for Claude's startup. The wrapper will unset this for child processes,
    # allowing subsequent node/npm/npx calls to be routed through the bridge.
    export CLAUDE_STARTING=1

    # Check for YOLO mode (skip all permission prompts)
    if [ "$CLAUDE_YOLO" = "1" ]; then
        log "Starting Claude CLI in YOLO mode (--dangerously-skip-permissions)..."
        exec claude --dangerously-skip-permissions "$@"
    else
        log "Starting Claude CLI in safe mode..."
        exec claude "$@"
    fi
}

main "$@"
