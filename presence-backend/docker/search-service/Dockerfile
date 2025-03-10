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
