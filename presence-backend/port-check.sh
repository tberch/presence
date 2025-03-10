#!/bin/bash
# Script to identify the correct running pod and ports

# Find the RUNNING pod for audio-detection-app
echo "Finding running pods..."
kubectl get pods -l app=audio-detection --field-selector=status.phase=Running -o wide

echo ""
echo "Checking container ports in the deployment spec..."
kubectl get deployment audio-detection-app -o jsonpath='{.spec.template.spec.containers[0].ports}'

echo ""
echo "Checking if nginx is actually running inside the pod..."
RUNNING_POD=$(kubectl get pods -l app=audio-detection --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
echo "Using pod: $RUNNING_POD"
kubectl exec $RUNNING_POD -- ps aux

echo ""
echo "Checking what's actually listening on ports inside the container..."
kubectl exec $RUNNING_POD -- netstat -tulpn 2>/dev/null || echo "netstat not available"

echo ""
echo "Try port-forwarding to the RUNNING pod with port 8080:80:"
echo "kubectl port-forward $RUNNING_POD 8080:80"

echo ""
echo "If that fails, try other ports that might be in use:"
echo "kubectl port-forward $RUNNING_POD 8080:8080"
