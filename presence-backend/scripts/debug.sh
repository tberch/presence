#!/bin/bash
set -e

# Available services
SERVICES=(
  "fingerprint-service"
  "context-service"
  "chat-service"
  "user-service"
  "search-service"
  "notification-service"
)

# Show usage
function show_usage {
  echo "Usage: $0 [service]"
  echo "Available services:"
  for svc in "${SERVICES[@]}"; do
    echo "  $svc"
  done
  exit 1
}

# If no arguments, show usage
if [ $# -eq 0 ]; then
  show_usage
fi

# Parse arguments
SERVICE="$1"

# Check if service is valid
VALID_SERVICE=false
for svc in "${SERVICES[@]}"; do
  if [ "$SERVICE" == "$svc" ]; then
    VALID_SERVICE=true
    break
  fi
done

# If service not found, show usage
if [ "$VALID_SERVICE" == "false" ]; then
  echo "Service '$SERVICE' not found."
  show_usage
fi

# Get the pod name
POD_NAME=$(kubectl get pods -n presence -l app=$SERVICE -o jsonpath="{.items[0].metadata.name}")

# Add debug container to the pod
echo "Setting up debug container for $SERVICE on pod $POD_NAME..."
kubectl debug -it $POD_NAME --image=busybox:latest --target=$SERVICE -n presence -- sh
