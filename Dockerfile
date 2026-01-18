# Stage 1: Build stage (for any build-time dependencies)
FROM node:20-alpine AS builder

# Stage 2: Runtime stage
FROM node:20-alpine AS runtime

# Create non-root user 'claude'
RUN addgroup -g 1000 claude && \
    adduser -u 1000 -G claude -h /home/claude -D claude

# Set working directory
WORKDIR /workspace

# Switch to non-root user
USER claude

# Default command
CMD ["sh"]
