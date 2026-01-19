# Stage 1: Build stage (for downloading build-time dependencies only)
FROM node:20-alpine AS builder

# TARGETARCH is automatically set by Docker BuildKit for multi-arch builds
ARG TARGETARCH

# Download yq binary (YAML parser) - wget is used only in builder stage
# hadolint ignore=DL3018
RUN apk add --no-cache wget && \
    wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/v4.50.1/yq_linux_${TARGETARCH}" && \
    chmod +x /usr/local/bin/yq

# Stage 2: Runtime stage - minimal production image
FROM node:20-alpine AS runtime

# Install only essential runtime dependencies:
# - docker-cli: Docker client for container communication (no daemon)
# Multi-stage build ensures build tools (wget) are not included
RUN apk add --no-cache docker-cli=29.1.3-r1 && \
    rm -rf /var/cache/apk/*

# Install claude-code CLI globally and clean npm artifacts
RUN npm install -g @anthropic-ai/claude-code@2.1.12 && \
    npm cache clean --force && \
    rm -rf /tmp/*

# Copy yq binary from builder stage (avoids wget in runtime image)
COPY --from=builder /usr/local/bin/yq /usr/local/bin/yq

# Copy and set permissions for bridge script in a single layer
COPY --chmod=755 scripts/bridge /usr/local/bin/bridge

# Configure Docker host (override via docker-compose or runtime env)
ENV DOCKER_HOST=""

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

# Default command
CMD ["sh"]
