FROM node:16-alpine

WORKDIR /app

# Copy package files
COPY services/fingerprint-service/package*.json ./
RUN npm install

# Copy source code
COPY services/fingerprint-service/src ./src

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Environment variables
ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

CMD ["node", "src/index.js"]
