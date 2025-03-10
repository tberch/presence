FROM node:16-alpine

WORKDIR /app

# Copy package files
COPY services/context-service/package*.json ./
RUN npm install

# Copy source code
COPY services/context-service/src ./src

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3001/health || exit 1

# Environment variables
ENV NODE_ENV=production
ENV PORT=3001

EXPOSE 3001

CMD ["node", "src/index.js"]
