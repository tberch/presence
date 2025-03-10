#!/bin/bash
# Deployment script for Audio Event Detection App to Kubernetes

# Set variables
IMAGE_NAME="tberchenbriter/audio-event-detector"
IMAGE_TAG="latest"
NAMESPACE="default"              # Change if using a different namespace

# Note: Skipping build and push steps as we're using an existing image
echo "Using existing image: ${IMAGE_NAME}:${IMAGE_TAG}"

# Step 4: Apply Kubernetes configurations
echo "Applying Kubernetes configurations..."
kubectl apply -f kubernetes-deployment.yaml -n ${NAMESPACE}

# Step 5: Wait for deployment to be ready
echo "Waiting for deployment to be ready..."
kubectl rollout status deployment/audio-detection-app -n ${NAMESPACE}

# Step 6: Get service information
echo "Deployment complete! Here's how to access your application:"
echo "Service: "
kubectl get service audio-detection-service -n ${NAMESPACE}
echo "Ingress: "
kubectl get ingress audio-detection-ingress -n ${NAMESPACE}

echo "Note: Make sure to configure your DNS to point audio-detection.example.com to your Ingress controller's external IP"
