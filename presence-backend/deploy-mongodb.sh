#!/bin/bash
set -e

echo "Deploying MongoDB to Kubernetes..."

# Create storage resources
kubectl apply -f k8s/storage/mongodb-pv.yaml
kubectl apply -f k8s/storage/mongodb-pvc.yaml

# Deploy MongoDB
kubectl apply -f k8s/databases/mongodb.yaml

# Wait for MongoDB to be ready
echo "Waiting for MongoDB to be ready..."
kubectl wait --for=condition=Ready pod -l app=mongodb -n presence --timeout=120s || echo "Warning: MongoDB not ready yet, but continuing..."

# Initialize MongoDB with sample data
kubectl apply -f k8s/databases/mongodb-init.yaml
kubectl apply -f k8s/databases/mongodb-init-job.yaml

echo "MongoDB deployment started. You can check status with:"
echo "kubectl get pods -n presence -l app=mongodb"
echo "kubectl logs -f job/mongodb-init-job -n presence"
