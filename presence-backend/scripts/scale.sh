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
  echo "Usage: $0 [service] [replicas]"
  echo "Available services:"
  for svc in "${SERVICES[@]}"; do
    echo "  $svc"
  done
  echo "Example: $0 fingerprint-service 3"
  exit 1
}

# If no arguments or wrong number, show usage
if [ $# -ne 2 ]; then
  show_usage
fi

# Parse arguments
SERVICE="$1"
REPLICAS="$2"

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

# Check if replicas is a number
if ! [[ "$REPLICAS" =~ ^[0-9]+$ ]]; then
  echo "Replicas must be a number."
  show_usage
fi

echo "Scaling $SERVICE to $REPLICAS replicas..."
kubectl scale deployment $SERVICE -n presence --replicas=$REPLICAS

echo "Current deployment status:"
kubectl get deployment $SERVICE -n presence
