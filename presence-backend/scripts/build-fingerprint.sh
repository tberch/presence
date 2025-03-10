#!/bin/bash
set -e

echo "Building fingerprint service..."

# Navigate to project root
cd "$(dirname "$0")/.."

# Build the Docker image
docker build -t presence/fingerprint-service -f docker/fingerprint-service/Dockerfile .

echo "Fingerprint service built successfully!"
