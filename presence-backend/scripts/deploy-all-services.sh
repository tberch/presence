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
