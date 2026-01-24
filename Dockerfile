# Stage 1: Go builder stage for compiling the bridge binary
FROM golang:1.24-alpine AS builder

WORKDIR /build

# Copy Go module files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY cmd/ ./cmd/

# Build static binary (CGO_ENABLED=0 for fully static linking)
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /usr/local/bin/bridge ./cmd/bridge

# Stage 2: Runtime stage - minimal production image
FROM node:20-alpine AS runtime

# Install runtime dependencies:
# - bash: Required by Claude Code CLI for shell execution
# - docker-cli: Docker client for container communication (no daemon)
# - git: Required for Claude Code version control operations
# - iptables: Firewall rules for network isolation
# - ipset: Efficient IP set matching for firewall
# - iproute2: Network tools including 'ip' command
# - bind-tools: DNS utilities including 'dig' for domain resolution
# - curl: HTTP client for fetching GitHub IP ranges
# - jq: JSON parsing for GitHub API responses
# Multi-stage build ensures Go compiler and build tools are not included
RUN apk add --no-cache \
    bash \
    docker-cli=29.1.3-r1 \
    git \
    iptables \
    ipset \
    iproute2 \
    bind-tools \
    curl \
    jq && \
    rm -rf /var/cache/apk/*

# Install claude-code CLI globally and clean npm artifacts
RUN npm install -g @anthropic-ai/claude-code@2.1.12 && \
    npm cache clean --force && \
    rm -rf /tmp/*

# Copy Go bridge binary from builder stage
COPY --from=builder /usr/local/bin/bridge /usr/local/bin/bridge

# Copy entrypoint and firewall init scripts
COPY --chmod=755 scripts/entrypoint.sh /scripts/entrypoint.sh
COPY --chmod=755 scripts/init-firewall.sh /scripts/init-firewall.sh

# Copy dispatcher script to /scripts/wrappers/ (not /usr/local/bin/ to avoid overwriting real binaries)
# Symlinks are generated at startup via bridge --init-wrappers, pointing to the dispatcher
COPY --chmod=755 scripts/wrappers /scripts/wrappers/

# Prepend wrappers directory to PATH so wrappers take precedence
ENV PATH="/scripts/wrappers:$PATH"

# Configure Docker host (override via docker-compose or runtime env)
ENV DOCKER_HOST=""

# Set SHELL env var for Claude Code's Bash tool
ENV SHELL=/bin/bash

# Build arguments for configurable user UID/GID and working directory
# Default to 501 (macOS default UID/GID) for seamless file ownership on macOS hosts
# For Linux hosts, override with: docker compose build --build-arg CLAUDE_UID=1000 --build-arg CLAUDE_GID=1000
ARG CLAUDE_UID=501
ARG CLAUDE_GID=501


# Create non-root user 'claude' with configurable UID/GID
# This ensures files created by Claude in /workspace are owned by your host user
RUN addgroup -g ${CLAUDE_GID} claude && \
    adduser -u ${CLAUDE_UID} -G claude -h /home/claude -D claude && \
    mkdir -p /home/claude/.claude && \
    chown claude:claude /home/claude/.claude

# Note: WORKDIR is intentionally not set here.
# Each project specifies its own working directory via docker-compose.yml (working_dir: /app)
# since mount points vary between projects (/app, /workspace, /workspaces/my-project, etc.)

# Note: Container starts as root to allow firewall initialization.
# The entrypoint script runs the firewall setup as root, then drops to 'claude' user.
# This ensures the firewall persists for the container lifetime (not re-run on every exec).

# Start via entrypoint (runs as root, drops to claude user after firewall init)
ENTRYPOINT ["/scripts/entrypoint.sh"]
