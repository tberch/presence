#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================================${NC}"
echo -e "${BLUE}         Setting up Presence Application                 ${NC}"
echo -e "${BLUE}=========================================================${NC}"

# Step 1: Make all scripts executable
echo -e "${YELLOW}Making all scripts executable...${NC}"
chmod +x *.sh

# Step 2: Deploy MongoDB
echo -e "${YELLOW}Deploying MongoDB...${NC}"
./deploy-mongodb.sh

# Step 3: Build fingerprint service with enhanced fingerprinting
echo -e "${YELLOW}Updating fingerprint service with enhanced fingerprinting...${NC}"
mkdir -p src/fingerprint-service
cp enhanced-fingerprinting.js src/fingerprint-service/fingerprinting.js

echo -e "${YELLOW}Building fingerprint service...${NC}"
docker build -t presence/fingerprint-service -f docker/fingerprint-service/Dockerfile .

# Step 4: Update fingerprint service deployment
echo -e "${YELLOW}Redeploying fingerprint service...${NC}"
kubectl apply -f k8s/deployments/fingerprint-service.yaml
kubectl rollout restart deployment/fingerprint-service -n presence

# Step 5: Build and deploy context service
echo -e "${YELLOW}Building context service...${NC}"
./build-context-service.sh

echo -e "${YELLOW}Deploying context service...${NC}"
./deploy-context-service.sh

# Step 6: Wait for services to be ready
echo -e "${YELLOW}Waiting for services to be ready...${NC}"
kubectl rollout status deployment/fingerprint-service -n presence
kubectl rollout status deployment/context-service -n presence

echo -e "${GREEN}=========================================================${NC}"
echo -e "${GREEN}         Presence Application Setup Complete!            ${NC}"
echo -e "${GREEN}=========================================================${NC}"
echo ""
echo -e "To test the fingerprint service:      ${BLUE}./test-fingerprint-service.sh${NC}"
echo -e "To test the context service:          ${BLUE}./test-context-service.sh${NC}"
echo -e "To test MongoDB connection:           ${BLUE}./test-mongodb.sh${NC}"
echo -e "To test inter-service communication:  ${BLUE}./test-communication.sh${NC}"
echo ""
echo -e "Access the API through ingress at:    ${BLUE}http://localhost/fingerprint${NC}"
echo -e "                                    ${BLUE}http://localhost/context${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Develop the mobile application to capture audio and generate fingerprints"
echo -e "2. Build a web portal for context and chat management"
echo -e "3. Implement user authentication and account management"
echo -e "4. Add chat functionality and real-time communication"
