#!/bin/bash
# This script creates a minimal project structure to help with Docker builds

# Create necessary directories
mkdir -p src docker/fingerprint-service docker/context-service docker/chat-service docker/user-service docker/search-service docker/notification-service

# Create a basic package.json
cat > package.json << 'EOF'
{
  "name": "presence-service",
  "version": "1.0.0",
  "description": "Presence backend service",
  "main": "dist/index.js",
  "scripts": {
    "build": "mkdir -p dist && cp -r src/* dist/",
    "start": "node dist/index.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

# Create minimal index.js file
cat > src/index.js << 'EOF'
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.listen(port, () => {
  console.log(`Service listening on port ${port}`);
});
EOF

# Update the Dockerfiles for all services
for SERVICE in fingerprint-service context-service chat-service user-service search-service notification-service; do
  cat > docker/$SERVICE/Dockerfile << 'EOF'
FROM node:16-alpine as builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Try npm ci first, fall back to npm install if package-lock.json doesn't exist
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

# Copy source code
COPY src ./src

# Build project (simple copy for JavaScript, would compile for TypeScript)
RUN mkdir -p dist && cp -r src/* dist/

FROM node:16-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production dependencies (with fallback)
RUN if [ -f package-lock.json ]; then \
      npm ci --omit=dev || npm install --omit=dev; \
    else \
      npm install --omit=dev; \
    fi

# Copy compiled code from builder stage
COPY --from=builder /app/dist ./dist

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Environment variables
ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

CMD ["node", "dist/index.js"]
EOF
done

echo "Created minimal project structure with Dockerfiles for all services"
echo "To build the images, run: ./scripts/build.sh"
