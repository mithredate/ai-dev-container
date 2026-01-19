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

# Install only essential runtime dependencies:
# - docker-cli: Docker client for container communication (no daemon)
# - git: Required for Claude Code version control operations
# Multi-stage build ensures Go compiler and build tools are not included
RUN apk add --no-cache docker-cli=29.1.3-r1 git && \
    rm -rf /var/cache/apk/*

# Install claude-code CLI globally and clean npm artifacts
RUN npm install -g @anthropic-ai/claude-code@2.1.12 && \
    npm cache clean --force && \
    rm -rf /tmp/*

# Copy Go bridge binary from builder stage
COPY --from=builder /usr/local/bin/bridge /usr/local/bin/bridge

# Copy entrypoint script
COPY --chmod=755 scripts/entrypoint.sh /scripts/entrypoint.sh

# Copy wrapper scripts to /scripts/wrappers/ (not /usr/local/bin/ to avoid overwriting real binaries)
# These scripts route commands through the bridge when BRIDGE_ENABLED=1
# The node wrapper has special handling via CLAUDE_STARTING env var to allow Claude Code
# (a Node.js app) to start with native node, while routing subsequent node calls through the bridge
COPY --chmod=755 scripts/wrappers /scripts/wrappers/

# Prepend wrappers directory to PATH so wrappers take precedence
ENV PATH="/scripts/wrappers:$PATH"

# Configure Docker host (override via docker-compose or runtime env)
ENV DOCKER_HOST=""

# Set SHELL env var for Claude Code's Bash tool (Alpine uses /bin/sh)
ENV SHELL=/bin/sh

# Create non-root user 'claude' with session directory
# Note: node:20-alpine already has node user/group at 1000, so we use 1001
RUN addgroup -g 1001 claude && \
    adduser -u 1001 -G claude -h /home/claude -D claude && \
    mkdir -p /home/claude/.claude && \
    chown claude:claude /home/claude/.claude

# Set working directory
WORKDIR /workspace

# Switch to non-root user
USER claude

# Start Claude CLI via entrypoint
ENTRYPOINT ["/scripts/entrypoint.sh"]
