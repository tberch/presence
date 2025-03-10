#!/bin/bash
# This script safely handles MongoDB deployment without updating immutable fields

echo "===== Fixing MongoDB Deployment ====="

# Check if MongoDB StatefulSet already exists
if kubectl get statefulset mongodb -n presence >/dev/null 2>&1; then
  echo "MongoDB StatefulSet already exists."
  echo "Checking MongoDB pod status..."
  kubectl get pods -n presence -l app=mongodb
  
  echo "Note: StatefulSets have immutable fields that cannot be updated."
  echo "To apply a new configuration, you need to delete and recreate the StatefulSet."
  echo "Warning: This will delete existing data unless you have proper volume backups."
  
  read -p "Do you want to delete and recreate the MongoDB StatefulSet? (y/N): " confirm
  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    echo "Deleting existing MongoDB StatefulSet..."
    kubectl delete statefulset mongodb -n presence
    
    echo "Waiting for pod termination..."
    sleep 10
    
    echo "Reapplying MongoDB configuration..."
    kubectl apply -f k8s/databases/mongodb.yaml
  else
    echo "Skipping MongoDB recreation. Using the existing MongoDB instance."
    # Continue with initialization steps without updating the StatefulSet
  fi
else
  echo "No existing MongoDB found. Creating new MongoDB StatefulSet..."
  kubectl apply -f k8s/databases/mongodb.yaml
fi

# Wait for MongoDB to be ready
echo "Waiting for MongoDB to be ready..."
kubectl wait --for=condition=Ready pod -l app=mongodb -n presence --timeout=120s || echo "Warning: MongoDB not ready yet, but continuing..."

# Initialize MongoDB with sample data
echo "Creating initialization resources..."
kubectl apply -f k8s/databases/mongodb-init.yaml
kubectl apply -f k8s/databases/mongodb-init-job.yaml

echo "===== Continue with the rest of the setup ====="
echo "Updating fingerprint service with enhanced fingerprinting..."
mkdir -p src/fingerprint-service
cp enhanced-fingerprinting.js src/fingerprint-service/fingerprinting.js

echo "Building fingerprint service..."
docker build -t presence/fingerprint-service -f docker/fingerprint-service/Dockerfile .

echo "Redeploying fingerprint service..."
kubectl apply -f k8s/deployments/fingerprint-service.yaml
kubectl rollout restart deployment/fingerprint-service -n presence

echo "Building context service..."
./build-context-service.sh

echo "Deploying context service..."
./deploy-context-service.sh

echo "Waiting for services to be ready..."
kubectl rollout status deployment/fingerprint-service -n presence
kubectl rollout status deployment/context-service -n presence

echo "===== Setup Complete ====="
echo "Services have been deployed. You can now run the test scripts:"
echo "  ./test-fingerprint-service.sh"
echo "  ./test-context-service.sh"
echo "  ./test-mongodb.sh"
echo "  ./test-communication.sh"
