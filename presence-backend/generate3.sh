#!/bin/bash
# This script creates the minimal Kubernetes manifest files needed for deployment

# Create the directory structure
mkdir -p k8s/namespaces k8s/config k8s/secrets k8s/services k8s/deployments k8s/databases k8s/storage k8s/ingress

# Create the namespace manifest
cat > k8s/namespaces/presence.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: presence
  labels:
    name: presence
EOF

# Create the config manifests
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

# Create the secrets
cat > k8s/secrets/db-credentials.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: presence
type: Opaque
data:
  postgres-user: cHJlc2VuY2UuYWRtaW4=  # presence.admin (base64 encoded)
  postgres-password: Y2hhbmdlbWU=      # changeme (base64 encoded)
  mongodb-user: cHJlc2VuY2UuYWRtaW4=   # presence.admin (base64 encoded)
  mongodb-password: Y2hhbmdlbWU=       # changeme (base64 encoded)
  redis-password: Y2hhbmdlbWU=         # changeme (base64 encoded)
EOF

# Create a service manifest
cat > k8s/services/fingerprint-service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: fingerprint-service
  namespace: presence
  labels:
    app: fingerprint-service
spec:
  selector:
    app: fingerprint-service
  ports:
    - port: 3000
      targetPort: 3000
      name: http
  type: ClusterIP
EOF

# Create a deployment manifest
cat > k8s/deployments/fingerprint-service.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fingerprint-service
  namespace: presence
  labels:
    app: fingerprint-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fingerprint-service
  template:
    metadata:
      labels:
        app: fingerprint-service
    spec:
      containers:
        - name: fingerprint-service
          image: presence/fingerprint-service:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3000
          env:
            - name: PORT
              value: "3000"
            - name: NODE_ENV
              valueFrom:
                configMapKeyRef:
                  name: service-config
                  key: NODE_ENV
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 5
EOF

# Create a database service (simplified for local dev)
cat > k8s/databases/redis.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: presence
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
        - name: redis
          image: redis:6-alpine
          ports:
            - containerPort: 6379
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: presence
spec:
  selector:
    app: redis
  ports:
    - port: 6379
      targetPort: 6379
EOF

# Create an ingress
cat > k8s/ingress/api-gateway.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-gateway
  namespace: presence
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  rules:
    - host: presence.local
      http:
        paths:
          - path: /fingerprint(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: fingerprint-service
                port:
                  number: 3000
EOF

# Update the deploy script to handle missing files
cat > scripts/deploy.sh << 'EOF'
#!/bin/bash
set -e

echo "Deploying Presence to Kubernetes..."

# Create namespace
kubectl apply -f k8s/namespaces/presence.yaml

# Apply configurations if they exist
if [ -d "k8s/config" ] && [ "$(ls -A k8s/config)" ]; then
  kubectl apply -f k8s/config/
fi

# Apply secrets if they exist
if [ -d "k8s/secrets" ] && [ "$(ls -A k8s/secrets)" ]; then
  kubectl apply -f k8s/secrets/
fi

# Apply storage if it exists
if [ -d "k8s/storage" ] && [ "$(ls -A k8s/storage)" ]; then
  kubectl apply -f k8s/storage/
fi

# Apply databases if they exist
if [ -d "k8s/databases" ] && [ "$(ls -A k8s/databases)" ]; then
  kubectl apply -f k8s/databases/
  
  # Try to wait for databases if they exist
  if kubectl get pods -n presence -l app=postgres 2>/dev/null; then
    echo "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=Ready pod -l app=postgres -n presence --timeout=120s || echo "Warning: Postgres not ready yet"
  fi
  
  if kubectl get pods -n presence -l app=mongodb 2>/dev/null; then
    echo "Waiting for MongoDB to be ready..."
    kubectl wait --for=condition=Ready pod -l app=mongodb -n presence --timeout=120s || echo "Warning: MongoDB not ready yet"
  fi
  
  if kubectl get pods -n presence -l app=redis 2>/dev/null; then
    echo "Waiting for Redis to be ready..."
    kubectl wait --for=condition=Ready pod -l app=redis -n presence --timeout=120s || echo "Warning: Redis not ready yet"
  fi
fi

# Apply services if they exist
if [ -d "k8s/services" ] && [ "$(ls -A k8s/services)" ]; then
  kubectl apply -f k8s/services/
fi

# Apply deployments if they exist
if [ -d "k8s/deployments" ] && [ "$(ls -A k8s/deployments)" ]; then
  kubectl apply -f k8s/deployments/
fi

# Apply ingress if it exists
if [ -d "k8s/ingress" ] && [ "$(ls -A k8s/ingress)" ]; then
  kubectl apply -f k8s/ingress/
fi

echo "Deployment complete! Access the application at http://presence.local"
EOF
chmod +x scripts/deploy.sh

echo "Kubernetes manifest files created successfully"
echo "Now you can run ./scripts/deploy.sh to deploy to Kubernetes"
