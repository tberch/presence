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
