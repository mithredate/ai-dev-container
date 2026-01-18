# Stage 1: Build stage (for any build-time dependencies)
FROM node:20-alpine AS builder

# Install wget to download yq
# hadolint ignore=DL3018
RUN apk add --no-cache wget

# Download yq binary (YAML parser)
ARG YQ_VERSION=v4.50.1
RUN wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" && \
    chmod +x /usr/local/bin/yq

# Stage 2: Runtime stage
FROM node:20-alpine AS runtime

# Install Docker CLI client (no daemon) and clean cache
RUN apk add --no-cache docker-cli=29.1.3-r1

# Install claude-code CLI globally
RUN npm install -g @anthropic-ai/claude-code@2.1.12 && \
    npm cache clean --force

# Copy yq from builder stage
COPY --from=builder /usr/local/bin/yq /usr/local/bin/yq

# Copy bridge script
COPY scripts/bridge /usr/local/bin/bridge
RUN chmod +x /usr/local/bin/bridge

# Configure Docker host (override via docker-compose or runtime env)
ENV DOCKER_HOST=""

# Create non-root user 'claude'
# Note: node:20-alpine already has node user/group at 1000, so we use 1001
RUN addgroup -g 1001 claude && \
    adduser -u 1001 -G claude -h /home/claude -D claude

# Set working directory
WORKDIR /workspace

# Switch to non-root user
USER claude

# Default command
CMD ["sh"]
