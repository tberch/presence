#!/bin/bash
set -e

# Available services
SERVICES=(
  "fingerprint-service:3000"
  "context-service:3001"
  "chat-service:3002"
  "user-service:3003"
  "search-service:3004"
  "notification-service:3005"
  "postgres:5432"
  "mongodb:27017"
  "redis:6379"
)

# Show usage
function show_usage {
  echo "Usage: $0 [service]"
  echo "Available services:"
  for svc in "${SERVICES[@]}"; do
    IFS=':' read -ra PARTS <<< "$svc"
    echo "  ${PARTS[0]}"
  done
  exit 1
}

# If no arguments, show usage
if [ $# -eq 0 ]; then
  show_usage
fi

# Get service and port
SERVICE="$1"
PORT=""

# Find the port for the service
for svc in "${SERVICES[@]}"; do
  IFS=':' read -ra PARTS <<< "$svc"
  if [ "$SERVICE" == "${PARTS[0]}" ]; then
    PORT="${PARTS[1]}"
    break
  fi
done

# If service not found, show usage
if [ -z "$PORT" ]; then
  echo "Service '$SERVICE' not found."
  show_usage
fi

echo "Setting up port forwarding for $SERVICE on port $PORT..."
kubectl port-forward svc/$SERVICE $PORT:$PORT -n presence
