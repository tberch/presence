#!/bin/bash
set -e

echo "Deploying fingerprint service to Kubernetes..."

# Navigate to project root
cd "$(dirname "$0")/.."

# Apply the deployment
kubectl apply -f k8s/deployments/fingerprint-service.yaml

# Wait for deployment to be ready
kubectl -n presence rollout status deployment/fingerprint-service

echo "Fingerprint service deployed successfully!"
echo "You can access it at http://localhost/fingerprint"
