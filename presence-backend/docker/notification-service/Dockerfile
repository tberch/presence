FROM node:16-alpine

WORKDIR /app

# Copy package files
COPY src/notification-service/package*.json ./
RUN npm install

# Copy source code
COPY src/notification-service/ ./

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3005/health || exit 1

# Environment variables
ENV NODE_ENV=production
ENV PORT=3005

EXPOSE 3005

CMD ["node", "index.js"]
