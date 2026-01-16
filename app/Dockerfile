# Multi-stage build for React + Node.js backend
FROM node:20-alpine AS frontend-build

WORKDIR /app/frontend

# Copy frontend package files
COPY package*.json ./
RUN npm ci

# Copy frontend source
COPY . .

# Build frontend
RUN npm run build

# Backend stage
FROM node:20-alpine AS backend-build

WORKDIR /app/backend

# Copy backend package files
COPY server/package*.json ./
RUN npm ci

# Production stage
FROM node:20-alpine

WORKDIR /app

# Install production dependencies
COPY server/package*.json ./
RUN npm ci --only=production

# Copy backend code
COPY server/ ./

# Copy built frontend
COPY --from=frontend-build /app/frontend/dist ./public

# Create directory for SPCS session token
RUN mkdir -p /snowflake/session

# Set environment variables
ENV NODE_ENV=production
ENV PORT=8080
ENV SPCS_TOKEN_PATH=/snowflake/session/token

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js || exit 1

# Run as non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

USER nodejs

# Start the application
CMD ["node", "index.js"]
