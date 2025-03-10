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
  "postgres"
  "mongodb"
  "redis"
)

# Show usage
function show_usage {
  echo "Usage: $0 [service] [--follow]"
  echo "Available services:"
  for svc in "${SERVICES[@]}"; do
    echo "  $svc"
  done
  echo "Options:"
  echo "  --follow, -f    Follow logs (like tail -f)"
  exit 1
}

# If no arguments, show usage
if [ $# -eq 0 ]; then
  show_usage
fi

# Parse arguments
SERVICE="$1"
FOLLOW=""

if [ "$2" == "--follow" ] || [ "$2" == "-f" ]; then
  FOLLOW="-f"
fi

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

echo "Fetching logs for $SERVICE..."
kubectl logs -l app=$SERVICE -n presence $FOLLOW
