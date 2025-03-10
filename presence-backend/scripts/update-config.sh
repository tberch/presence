#!/bin/bash
set -e

# Available config maps
CONFIGS=(
  "database-config"
  "service-config"
)

# Show usage
function show_usage {
  echo "Usage: $0 [config] [key] [value]"
  echo "Available configs:"
  for cfg in "${CONFIGS[@]}"; do
    echo "  $cfg"
  done
  echo "Example: $0 service-config LOG_LEVEL debug"
  exit 1
}

# If wrong number of arguments, show usage
if [ $# -ne 3 ]; then
  show_usage
fi

# Parse arguments
CONFIG="$1"
KEY="$2"
VALUE="$3"

# Check if config is valid
VALID_CONFIG=false
for cfg in "${CONFIGS[@]}"; do
  if [ "$CONFIG" == "$cfg" ]; then
    VALID_CONFIG=true
    break
  fi
done

# If config not found, show usage
if [ "$VALID_CONFIG" == "false" ]; then
  echo "Config '$CONFIG' not found."
  show_usage
fi

echo "Updating $CONFIG: setting $KEY to $VALUE..."

# Get current ConfigMap
kubectl get configmap $CONFIG -n presence -o yaml > /tmp/$CONFIG.yaml

# Update the ConfigMap
sed -i "s|$KEY:.*|$KEY: \"$VALUE\"|g" /tmp/$CONFIG.yaml

# Apply the updated ConfigMap
kubectl apply -f /tmp/$CONFIG.yaml

echo "Configuration updated. Restarting affected deployments..."

# Restart deployments that use this config
kubectl rollout restart deployment -n presence

echo "Update complete!"
