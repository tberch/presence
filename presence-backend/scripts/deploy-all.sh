#!/bin/bash
set -e

echo "Deploying Presence services to Kubernetes..."

# Apply database configuration
kubectl apply -f k8s/config/database-config.yaml
kubectl apply -f k8s/config/service-config.yaml

# Apply MongoDB resources
kubectl apply -f k8s/storage/mongodb-pv.yaml
kubectl apply -f k8s/storage/mongodb-pvc.yaml
kubectl apply -f k8s/databases/mongodb.yaml

# Wait for MongoDB to be ready
echo "Waiting for MongoDB to be ready..."
kubectl wait --for=condition=Ready pod -l app=mongodb -n presence --timeout=120s || echo "Warning: MongoDB not ready yet"

# Deploy services
kubectl apply -f k8s/services/fingerprint-service.yaml
kubectl apply -f k8s/services/context-service.yaml

# Deploy applications
kubectl apply -f k8s/deployments/fingerprint-service.yaml
kubectl apply -f k8s/deployments/context-service.yaml

# Wait for deployments to be ready
echo "Waiting for deployments to complete..."
kubectl rollout status deployment/fingerprint-service -n presence
kubectl rollout status deployment/context-service -n presence

echo "Deployment complete!"
