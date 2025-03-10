#!/bin/bash
set -e

echo "Building Notification Service..."
docker build -t presence/notification-service -f docker/notification-service/Dockerfile .
echo "Notification Service built successfully!"
