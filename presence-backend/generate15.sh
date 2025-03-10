# Create a script for building the fingerprint service
mkdir -p scripts
cat > scripts/build-fingerprint.sh << 'EOF'
#!/bin/bash
set -e

echo "Building fingerprint service..."

# Navigate to project root
cd "$(dirname "$0")/.."

# Build the Docker image
docker build -t presence/fingerprint-service -f docker/fingerprint-service/Dockerfile .

echo "Fingerprint service built successfully!"
EOF
chmod +x scripts/build-fingerprint.sh

# Create a script for deploying the fingerprint service
cat > scripts/deploy-fingerprint.sh << 'EOF'
#!/bin/bash
set -e

echo "Deploying fingerprint service to Kubernetes..."

# Navigate to project root
cd "$(dirname "$0")/.."

# Apply the deployment
kubectl apply -f k8s/deployments/fingerprint-service.yaml

# Wait for deployment to be ready
kubectl -n presence rollout status deployment/fingerprint-service

echo "Fingerprint service deployed successfully!"
echo "You can access it at http://localhost/fingerprint"
EOF
chmod +x scripts/deploy-fingerprint.sh
