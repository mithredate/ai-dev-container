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
    log "Starting Claude CLI..."

    # Execute Claude CLI
    exec claude "$@"
}

main "$@"
