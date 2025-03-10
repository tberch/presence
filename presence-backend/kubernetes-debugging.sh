#!/bin/bash
# Debugging commands for Audio Event Detection App

# Check if pods are running
echo "Checking pods status..."
kubectl get pods -l app=audio-detection

# Check pod details and events
echo "Checking pod details..."
POD_NAME=$(kubectl get pods -l app=audio-detection -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod $POD_NAME

# Check logs
echo "Checking pod logs..."
kubectl logs $POD_NAME

# Check if service is properly configured
echo "Checking service configuration..."
kubectl describe service audio-detection-service

# Test service connectivity from inside the cluster
echo "Testing service connectivity from inside the cluster..."
kubectl run -i --tty --rm debug --image=busybox --restart=Never -- wget -O- http://audio-detection-service:80

# Check Ingress
echo "Checking Ingress status..."
kubectl describe ingress audio-detection-ingress

# Port forward to test directly (bypassing service)
echo "Setting up port forwarding for direct testing..."
echo "Run this in a separate terminal:"
echo "kubectl port-forward $POD_NAME 8081:8081"
echo "Then access http://localhost:8081 in your browser"

# Additional commands to check endpoints
echo "Checking endpoints..."
kubectl get endpoints audio-detection-service
