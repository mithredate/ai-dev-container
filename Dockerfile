# Stage 1: Build stage (for any build-time dependencies)
FROM node:20-alpine AS builder

# Stage 2: Runtime stage
FROM node:20-alpine AS runtime

# Install Docker CLI client (no daemon) and clean cache
RUN apk add --no-cache docker-cli=29.1.3-r1

# Install claude-code CLI globally
RUN npm install -g @anthropic-ai/claude-code@2.1.12 && \
    npm cache clean --force

# Configure Docker host (override via docker-compose or runtime env)
ENV DOCKER_HOST=""

# Create non-root user 'claude'
RUN addgroup -g 1000 claude && \
    adduser -u 1000 -G claude -h /home/claude -D claude

# Set working directory
WORKDIR /workspace

# Switch to non-root user
USER claude

# Default command
CMD ["sh"]
