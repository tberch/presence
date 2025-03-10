#!/bin/bash
# This script creates Kubernetes manifests for all Presence microservices

# Services to create manifests for
SERVICES=(
  "context-service:3001"
  "chat-service:3002"
  "user-service:3003"
  "search-service:3004"
  "notification-service:3005"
)

# Create deployment manifests
for service_port in "${SERVICES[@]}"; do
  # Split service and port
  IFS=':' read -r service port <<< "$service_port"
  
  echo "Creating manifests for $service on port $port..."
  
  # Create deployment manifest
  cat > "k8s/deployments/$service.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $service
  namespace: presence
  labels:
    app: $service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $service
  template:
    metadata:
      labels:
        app: $service
    spec:
      containers:
        - name: $service
          image: presence/$service:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: $port
          env:
            - name: PORT
              value: "$port"
            - name: NODE_ENV
              valueFrom:
                configMapKeyRef:
                  name: service-config
                  key: NODE_ENV
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: service-config
                  key: LOG_LEVEL
          livenessProbe:
            httpGet:
              path: /health
              port: $port
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: $port
            initialDelaySeconds: 5
            periodSeconds: 5
EOF
  
  # Create service manifest
  cat > "k8s/services/$service.yaml" << EOF
apiVersion: v1
kind: Service
metadata:
  name: $service
  namespace: presence
  labels:
    app: $service
spec:
  selector:
    app: $service
  ports:
    - port: $port
      targetPort: $port
      name: http
  type: ClusterIP
EOF

  # Create NodePort service for testing (optional)
  nodeport=$((30000 + port - 3000))
  cat > "k8s/services/$service-nodeport.yaml" << EOF
apiVersion: v1
kind: Service
metadata:
  name: $service-nodeport
  namespace: presence
  labels:
    app: $service
spec:
  selector:
    app: $service
  ports:
    - port: $port
      targetPort: $port
      nodePort: $nodeport
      name: http
  type: NodePort
EOF

done

# Update the ingress to include all services
cat > "k8s/ingress/api-gateway.yaml" << 'EOF'
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
          - path: /context(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: context-service
                port:
                  number: 3001
          - path: /chat(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: chat-service
                port:
                  number: 3002
          - path: /user(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: user-service
                port:
                  number: 3003
          - path: /search(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: search-service
                port:
                  number: 3004
          - path: /notification(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: notification-service
                port:
                  number: 3005
EOF

# Create deployment script for all services
cat > "scripts/deploy-all-services.sh" << 'EOF'
#!/bin/bash
set -e

echo "Deploying all Presence services to Kubernetes..."

# Services to deploy
SERVICES=(
  "fingerprint-service"
  "context-service"
  "chat-service"
  "user-service"
  "search-service"
  "notification-service"
)

# Deploy each service
for service in "${SERVICES[@]}"; do
  echo "Deploying $service..."
  
  # Apply the deployment
  kubectl apply -f "k8s/deployments/$service.yaml"
  
  # Apply the service
  kubectl apply -f "k8s/services/$service.yaml"
  
  # Apply the NodePort service (if you want direct access)
  # kubectl apply -f "k8s/services/$service-nodeport.yaml"
done

# Apply the updated ingress
kubectl apply -f k8s/ingress/api-gateway.yaml

echo "All services deployed. Check status with:"
echo "kubectl get pods -n presence"
EOF
chmod +x scripts/deploy-all-services.sh

# Update service source code
mkdir -p src

# Create source files for each service
for service_port in "${SERVICES[@]}"; do
  # Split service and port
  IFS=':' read -r service port <<< "$service_port"
  
  # Create source directories
  mkdir -p "src/$service"
  
  # Create index.js file
  cat > "src/$service/index.js" << EOF
const express = require('express');
const app = express();
const port = process.env.PORT || $port;

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.get('/', (req, res) => {
  res.json({ service: '$service', message: 'Welcome to the $service API' });
});

app.listen(port, () => {
  console.log(\`$service listening on port \${port}\`);
});
EOF
done

echo "Created Kubernetes manifests and source code for all services"
echo "To deploy all services, run: ./scripts/deploy-all-services.sh"
echo "Make sure to build the Docker images first with: ./scripts/build.sh"
