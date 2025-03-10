#!/bin/bash
set -e

echo "Building all Presence services..."

# Build fingerprint service
echo "Building fingerprint service..."
docker build -t presence/fingerprint-service -f docker/fingerprint-service/Dockerfile .

# Build context service
echo "Building context service..."
docker build -t presence/context-service -f docker/context-service/Dockerfile .

echo "All services built successfully!"
