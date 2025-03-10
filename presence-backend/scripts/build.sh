#!/bin/bash
set -e

echo "Building Docker images..."

# Check if specific services are specified
if [ $# -gt 0 ]; then
  SERVICES=$@
else
  SERVICES="fingerprint-service context-service chat-service user-service search-service notification-service"
fi

for SERVICE in $SERVICES; do
  echo "Building $SERVICE..."
  docker build -t presence/$SERVICE -f docker/$SERVICE/Dockerfile .
done

echo "All images built successfully!"
chmod +x scripts/build.sh
