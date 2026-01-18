# Stage 1: Build stage (for any build-time dependencies)
FROM node:20-alpine AS builder

# Stage 2: Runtime stage
FROM node:20-alpine AS runtime

# Install claude-code CLI globally
RUN npm install -g @anthropic-ai/claude-code@2.1.12 && \
    npm cache clean --force

# Create non-root user 'claude'
RUN addgroup -g 1000 claude && \
    adduser -u 1000 -G claude -h /home/claude -D claude

# Set working directory
WORKDIR /workspace

# Switch to non-root user
USER claude

# Default command
CMD ["sh"]
