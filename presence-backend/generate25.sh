# Update database ConfigMap
cat > k8s/config/database-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: database-config
  namespace: presence
data:
  POSTGRES_HOST: "postgres"
  POSTGRES_PORT: "5432"
  POSTGRES_DB: "presence"
  MONGODB_HOST: "mongodb"
  MONGODB_PORT: "27017"
  MONGODB_DB: "presence"
  REDIS_HOST: "redis"
  REDIS_PORT: "6379"
EOF

# Update service ConfigMap
cat > k8s/config/service-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: service-config
  namespace: presence
data:
  FINGERPRINT_SERVICE_URL: "http://fingerprint-service:3000"
  CONTEXT_SERVICE_URL: "http://context-service:3001"
  CHAT_SERVICE_URL: "http://chat-service:3002"
  USER_SERVICE_URL: "http://user-service:3003"
  SEARCH_SERVICE_URL: "http://search-service:3004"
  NOTIFICATION_SERVICE_URL: "http://notification-service:3005"
  LOG_LEVEL: "info"
  NODE_ENV: "production"
EOF
