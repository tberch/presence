#!/bin/bash
set -e

echo "Deploying Notification Service to Kubernetes..."

# Apply Kubernetes Service and Deployment
kubectl apply -f k8s/services/notification-service.yaml
kubectl apply -f k8s/services/notification-service-nodeport.yaml
kubectl apply -f k8s/deployments/notification-service.yaml

# Wait for deployment to be ready
kubectl rollout status deployment/notification-service -n presence

echo "Deploying updated ingress configuration..."
kubectl apply -f k8s/ingress/notification-ingress.yaml

echo "Notification Service deployed successfully!"
