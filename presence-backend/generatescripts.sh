#!/bin/bash
# This file contains all the scripts needed for the Presence backend
# The directory structure should be as follows:
#
# /scripts
# ├── build.sh                # Build all Docker images
# ├── deploy.sh               # Deploy to Kubernetes
# ├── reset.sh                # Reset local environment
# ├── init-database.sh        # Initialize databases with schemas
# ├── run-migrations.sh       # Run database migrations
# ├── generate-secrets.sh     # Generate secure secrets for production
# ├── port-forward.sh         # Set up port forwarding to services
# ├── logs.sh                 # View logs from services
# ├── debug.sh                # Set up debugging for a service
# ├── scale.sh                # Scale services up or down
# └── update-config.sh        # Update ConfigMaps and apply changes

# -------------------------
# build.sh
# -------------------------
cat > scripts/build.sh << 'EOF'
#!/bin/bash
set -e

echo "Building Docker images..."

# Check if specific services are specified
if [ $# -gt 0 ]; then
  SERVICES=$@
else
  SERVICES="fingerprint-service context-service chat-service user-service search-service notification-service"
fi

for SERVICE in $SERVICES; do
  echo "Building $SERVICE..."
  docker build -t presence/$SERVICE -f docker/$SERVICE/Dockerfile .
done

echo "All images built successfully!"
chmod +x scripts/build.sh
EOF

# -------------------------
# deploy.sh
# -------------------------
cat > scripts/deploy.sh << 'EOF'
#!/bin/bash
set -e

echo "Deploying Presence to Kubernetes..."

# Create namespace
kubectl apply -f k8s/namespaces/presence.yaml

# Apply configurations
kubectl apply -f k8s/config/
kubectl apply -f k8s/secrets/

# Deploy storage
kubectl apply -f k8s/storage/

# Deploy databases
kubectl apply -f k8s/databases/

echo "Waiting for databases to be ready..."
kubectl wait --for=condition=Ready pod -l app=postgres -n presence --timeout=120s || echo "Warning: Postgres not ready yet"
kubectl wait --for=condition=Ready pod -l app=mongodb -n presence --timeout=120s || echo "Warning: MongoDB not ready yet"
kubectl wait --for=condition=Ready pod -l app=redis -n presence --timeout=120s || echo "Warning: Redis not ready yet"

# Deploy services
kubectl apply -f k8s/services/

# Deploy applications
kubectl apply -f k8s/deployments/

# Deploy ingress
kubectl apply -f k8s/ingress/

echo "Deployment complete! Access the application at http://presence.local"
EOF
chmod +x scripts/deploy.sh

# -------------------------
# reset.sh
# -------------------------
cat > scripts/reset.sh << 'EOF'
#!/bin/bash
set -e

echo "Resetting Presence environment..."

# Confirm with the user
read -p "Are you sure you want to delete all Presence resources? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Operation cancelled."
    exit 1
fi

# Delete all resources in the presence namespace
kubectl delete namespace presence --ignore-not-found=true

echo "Reset complete!"
EOF
chmod +x scripts/reset.sh

# -------------------------
# init-database.sh
# -------------------------
cat > scripts/init-database.sh << 'EOF'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_SCRIPTS_DIR="$SCRIPT_DIR/../db-scripts"

echo "Initializing databases for Presence..."

# PostgreSQL initialization
echo "Initializing PostgreSQL..."
kubectl exec -it -n presence $(kubectl get pods -n presence -l app=postgres -o jsonpath="{.items[0].metadata.name}") -- \
  psql -U presence.admin -d presence -f /dev/stdin < "$DB_SCRIPTS_DIR/postgres-init.sql"

# MongoDB initialization
echo "Initializing MongoDB..."
kubectl exec -it -n presence $(kubectl get pods -n presence -l app=mongodb -o jsonpath="{.items[0].metadata.name}") -- \
  sh -c "cat > /tmp/mongo-init.js && mongo -u presence.admin -p changeme --authenticationDatabase admin presence /tmp/mongo-init.js" \
  < "$DB_SCRIPTS_DIR/mongo-init.js"

echo "Database initialization complete!"
EOF
chmod +x scripts/init-database.sh

# -------------------------
# run-migrations.sh
# -------------------------
cat > scripts/run-migrations.sh << 'EOF'
#!/bin/bash
set -e

echo "Running database migrations for Presence..."

# Create migration job
cat << 'EOT' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  namespace: presence
spec:
  template:
    spec:
      containers:
        - name: migration
          image: presence/user-service:latest
          command: ["node", "dist/scripts/migrate.js"]
          env:
            - name: POSTGRES_HOST
              valueFrom:
                configMapKeyRef:
                  name: database-config
                  key: POSTGRES_HOST
            - name: POSTGRES_PORT
              valueFrom:
                configMapKeyRef:
                  name: database-config
                  key: POSTGRES_PORT
            - name: POSTGRES_DB
              valueFrom:
                configMapKeyRef:
                  name: database-config
                  key: POSTGRES_DB
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: postgres-user
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: postgres-password
      restartPolicy: Never
  backoffLimit: 4
EOT

# Wait for job to complete
echo "Waiting for migration job to complete..."
kubectl wait --for=condition=complete job/db-migration -n presence --timeout=60s

# Check for success
if kubectl get job db-migration -n presence -o jsonpath='{.status.succeeded}' | grep -q 1; then
  echo "Migrations completed successfully!"
else
  echo "Migration job failed. Check logs for details:"
  kubectl logs job/db-migration -n presence
  exit 1
fi

# Clean up job
kubectl delete job db-migration -n presence

echo "Migration process complete!"
EOF
chmod +x scripts/run-migrations.sh

# -------------------------
# generate-secrets.sh
# -------------------------
cat > scripts/generate-secrets.sh << 'EOF'
#!/bin/bash
set -e

echo "Generating secure secrets for Presence..."

# Generate random passwords
POSTGRES_PASSWORD=$(openssl rand -base64 16)
MONGODB_PASSWORD=$(openssl rand -base64 16)
REDIS_PASSWORD=$(openssl rand -base64 16)
JWT_SECRET=$(openssl rand -base64 32)

# Create secrets file
cat > k8s/secrets/db-credentials.yaml << EOT
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: presence
type: Opaque
data:
  postgres-user: $(echo -n "presence.admin" | base64)
  postgres-password: $(echo -n "$POSTGRES_PASSWORD" | base64)
  mongodb-user: $(echo -n "presence.admin" | base64)
  mongodb-password: $(echo -n "$MONGODB_PASSWORD" | base64)
  redis-password: $(echo -n "$REDIS_PASSWORD" | base64)
EOT

# Create JWT secret
cat > k8s/secrets/jwt-secret.yaml << EOT
apiVersion: v1
kind: Secret
metadata:
  name: jwt-secret
  namespace: presence
type: Opaque
data:
  jwt-secret: $(echo -n "$JWT_SECRET" | base64)
EOT

echo "Secrets generated successfully!"
echo "--------------------------------"
echo "IMPORTANT: Keep these values in a secure location"
echo "PostgreSQL Password: $POSTGRES_PASSWORD"
echo "MongoDB Password: $MONGODB_PASSWORD"
echo "Redis Password: $REDIS_PASSWORD"
echo "JWT Secret: $JWT_SECRET"
echo "--------------------------------"
EOF
chmod +x scripts/generate-secrets.sh

# -------------------------
# port-forward.sh
# -------------------------
cat > scripts/port-forward.sh << 'EOF'
#!/bin/bash
set -e

# Available services
SERVICES=(
  "fingerprint-service:3000"
  "context-service:3001"
  "chat-service:3002"
  "user-service:3003"
  "search-service:3004"
  "notification-service:3005"
  "postgres:5432"
  "mongodb:27017"
  "redis:6379"
)

# Show usage
function show_usage {
  echo "Usage: $0 [service]"
  echo "Available services:"
  for svc in "${SERVICES[@]}"; do
    IFS=':' read -ra PARTS <<< "$svc"
    echo "  ${PARTS[0]}"
  done
  exit 1
}

# If no arguments, show usage
if [ $# -eq 0 ]; then
  show_usage
fi

# Get service and port
SERVICE="$1"
PORT=""

# Find the port for the service
for svc in "${SERVICES[@]}"; do
  IFS=':' read -ra PARTS <<< "$svc"
  if [ "$SERVICE" == "${PARTS[0]}" ]; then
    PORT="${PARTS[1]}"
    break
  fi
done

# If service not found, show usage
if [ -z "$PORT" ]; then
  echo "Service '$SERVICE' not found."
  show_usage
fi

echo "Setting up port forwarding for $SERVICE on port $PORT..."
kubectl port-forward svc/$SERVICE $PORT:$PORT -n presence
EOF
chmod +x scripts/port-forward.sh

# -------------------------
# logs.sh
# -------------------------
cat > scripts/logs.sh << 'EOF'
#!/bin/bash
set -e

# Available services
SERVICES=(
  "fingerprint-service"
  "context-service"
  "chat-service"
  "user-service"
  "search-service"
  "notification-service"
  "postgres"
  "mongodb"
  "redis"
)

# Show usage
function show_usage {
  echo "Usage: $0 [service] [--follow]"
  echo "Available services:"
  for svc in "${SERVICES[@]}"; do
    echo "  $svc"
  done
  echo "Options:"
  echo "  --follow, -f    Follow logs (like tail -f)"
  exit 1
}

# If no arguments, show usage
if [ $# -eq 0 ]; then
  show_usage
fi

# Parse arguments
SERVICE="$1"
FOLLOW=""

if [ "$2" == "--follow" ] || [ "$2" == "-f" ]; then
  FOLLOW="-f"
fi

# Check if service is valid
VALID_SERVICE=false
for svc in "${SERVICES[@]}"; do
  if [ "$SERVICE" == "$svc" ]; then
    VALID_SERVICE=true
    break
  fi
done

# If service not found, show usage
if [ "$VALID_SERVICE" == "false" ]; then
  echo "Service '$SERVICE' not found."
  show_usage
fi

echo "Fetching logs for $SERVICE..."
kubectl logs -l app=$SERVICE -n presence $FOLLOW
EOF
chmod +x scripts/logs.sh

# -------------------------
# debug.sh
# -------------------------
cat > scripts/debug.sh << 'EOF'
#!/bin/bash
set -e

# Available services
SERVICES=(
  "fingerprint-service"
  "context-service"
  "chat-service"
  "user-service"
  "search-service"
  "notification-service"
)

# Show usage
function show_usage {
  echo "Usage: $0 [service]"
  echo "Available services:"
  for svc in "${SERVICES[@]}"; do
    echo "  $svc"
  done
  exit 1
}

# If no arguments, show usage
if [ $# -eq 0 ]; then
  show_usage
fi

# Parse arguments
SERVICE="$1"

# Check if service is valid
VALID_SERVICE=false
for svc in "${SERVICES[@]}"; do
  if [ "$SERVICE" == "$svc" ]; then
    VALID_SERVICE=true
    break
  fi
done

# If service not found, show usage
if [ "$VALID_SERVICE" == "false" ]; then
  echo "Service '$SERVICE' not found."
  show_usage
fi

# Get the pod name
POD_NAME=$(kubectl get pods -n presence -l app=$SERVICE -o jsonpath="{.items[0].metadata.name}")

# Add debug container to the pod
echo "Setting up debug container for $SERVICE on pod $POD_NAME..."
kubectl debug -it $POD_NAME --image=busybox:latest --target=$SERVICE -n presence -- sh
EOF
chmod +x scripts/debug.sh

# -------------------------
# scale.sh
# -------------------------
cat > scripts/scale.sh << 'EOF'
#!/bin/bash
set -e

# Available services
SERVICES=(
  "fingerprint-service"
  "context-service"
  "chat-service"
  "user-service"
  "search-service"
  "notification-service"
)

# Show usage
function show_usage {
  echo "Usage: $0 [service] [replicas]"
  echo "Available services:"
  for svc in "${SERVICES[@]}"; do
    echo "  $svc"
  done
  echo "Example: $0 fingerprint-service 3"
  exit 1
}

# If no arguments or wrong number, show usage
if [ $# -ne 2 ]; then
  show_usage
fi

# Parse arguments
SERVICE="$1"
REPLICAS="$2"

# Check if service is valid
VALID_SERVICE=false
for svc in "${SERVICES[@]}"; do
  if [ "$SERVICE" == "$svc" ]; then
    VALID_SERVICE=true
    break
  fi
done

# If service not found, show usage
if [ "$VALID_SERVICE" == "false" ]; then
  echo "Service '$SERVICE' not found."
  show_usage
fi

# Check if replicas is a number
if ! [[ "$REPLICAS" =~ ^[0-9]+$ ]]; then
  echo "Replicas must be a number."
  show_usage
fi

echo "Scaling $SERVICE to $REPLICAS replicas..."
kubectl scale deployment $SERVICE -n presence --replicas=$REPLICAS

echo "Current deployment status:"
kubectl get deployment $SERVICE -n presence
EOF
chmod +x scripts/scale.sh

# -------------------------
# update-config.sh
# -------------------------
cat > scripts/update-config.sh << 'EOF'
#!/bin/bash
set -e

# Available config maps
CONFIGS=(
  "database-config"
  "service-config"
)

# Show usage
function show_usage {
  echo "Usage: $0 [config] [key] [value]"
  echo "Available configs:"
  for cfg in "${CONFIGS[@]}"; do
    echo "  $cfg"
  done
  echo "Example: $0 service-config LOG_LEVEL debug"
  exit 1
}

# If wrong number of arguments, show usage
if [ $# -ne 3 ]; then
  show_usage
fi

# Parse arguments
CONFIG="$1"
KEY="$2"
VALUE="$3"

# Check if config is valid
VALID_CONFIG=false
for cfg in "${CONFIGS[@]}"; do
  if [ "$CONFIG" == "$cfg" ]; then
    VALID_CONFIG=true
    break
  fi
done

# If config not found, show usage
if [ "$VALID_CONFIG" == "false" ]; then
  echo "Config '$CONFIG' not found."
  show_usage
fi

echo "Updating $CONFIG: setting $KEY to $VALUE..."

# Get current ConfigMap
kubectl get configmap $CONFIG -n presence -o yaml > /tmp/$CONFIG.yaml

# Update the ConfigMap
sed -i "s|$KEY:.*|$KEY: \"$VALUE\"|g" /tmp/$CONFIG.yaml

# Apply the updated ConfigMap
kubectl apply -f /tmp/$CONFIG.yaml

echo "Configuration updated. Restarting affected deployments..."

# Restart deployments that use this config
kubectl rollout restart deployment -n presence

echo "Update complete!"
EOF
chmod +x scripts/update-config.sh
