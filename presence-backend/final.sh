#!/bin/bash
# Final setup script to coordinate all components

echo "===== Creating Master Setup Script for Presence ====="

cat > setup-presence.sh << 'EOF'
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
EOF
chmod +x setup-presence.sh

echo "===== Creating Inter-Service Communication Test Script ====="

cat > test-communication.sh << 'EOF'
#!/bin/bash

echo "===== Testing Inter-Service Communication ====="

# Set up port-forwarding to fingerprint-service
echo "Setting up port-forwarding to fingerprint-service..."
kubectl -n presence port-forward svc/fingerprint-service 3000:3000 &
FP_PID=$!
sleep 3

# Set up port-forwarding to context-service
echo "Setting up port-forwarding to context-service..."
kubectl -n presence port-forward svc/context-service 3001:3001 &
CS_PID=$!
sleep 3

# Check initial contexts
echo "Checking initial contexts..."
curl http://localhost:3001/contexts
echo -e "\n"

# Create a context
echo "Creating a test context..."
CONTEXT_RESPONSE=$(curl -X POST http://localhost:3001/contexts \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Context for Communication","type":"broadcast"}')
echo $CONTEXT_RESPONSE
echo -e "\n"

# Extract context ID
CONTEXT_ID=$(echo $CONTEXT_RESPONSE | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
echo "Created context with ID: $CONTEXT_ID"

# Start watching context service logs
echo "Starting to watch context service logs (will run in background)..."
kubectl logs -f deployment/context-service -n presence --tail=10 > context_logs.txt 2>&1 &
LOG_PID=$!

echo "Send fingerprint that references the created context..."
curl -X POST http://localhost:3000/fingerprint \
  -H "Content-Type: application/json" \
  -d "{\"audioData\":\"dGVzdCBhdWRpbyBkYXRhIGZvciBmaW5nZXJwcmludGluZw==\",\"device_id\":\"test-device-123\",\"context_id\":\"$CONTEXT_ID\"}"
echo -e "\n"

echo "Waiting 5 seconds for event processing..."
sleep 5

# Stop watching logs
kill $LOG_PID

echo "Context service logs (from context_logs.txt):"
cat context_logs.txt
rm context_logs.txt

# Check if context was updated
echo "Checking if context was updated..."
curl http://localhost:3001/contexts/$CONTEXT_ID
echo -e "\n"

# Clean up
kill $FP_PID $CS_PID

echo "===== Communication Test Complete ====="
EOF
chmod +x test-communication.sh

echo "===== Creating Test Fingerprint Service Script ====="

cat > test-fingerprint-service.sh << 'EOF'
#!/bin/bash

echo "===== Testing Fingerprint Service ====="

# Set up port-forwarding to fingerprint-service
echo "Setting up port-forwarding..."
kubectl -n presence port-forward svc/fingerprint-service 3000:3000 &
PF_PID=$!
sleep 3

echo "===== Testing Root Path ====="
curl http://localhost:3000/
echo -e "\n"

echo "===== Testing Health Endpoint ====="
curl http://localhost:3000/health
echo -e "\n"

echo "===== Testing Status Endpoint ====="
curl http://localhost:3000/status
echo -e "\n"

echo "===== Testing API Documentation ====="
curl http://localhost:3000/api
echo -e "\n"

echo "===== Testing Fingerprint Endpoint ====="
echo "Sending fingerprint request with audio data..."
curl -X POST http://localhost:3000/fingerprint \
  -H "Content-Type: application/json" \
  -d '{"audioData":"dGVzdCBhdWRpbyBkYXRhIGZvciBmaW5nZXJwcmludGluZw==","device_id":"test-device-123","location":{"latitude":37.7749,"longitude":-122.4194}}'
echo -e "\n"

echo "===== Testing Through Ingress ====="
curl http://localhost/fingerprint/health
echo -e "\n"

# Clean up
kill $PF_PID

echo "===== Fingerprint Service Test Complete ====="
EOF
chmod +x test-fingerprint-service.sh

echo "===== Final Instructions ====="
echo ""
echo "All setup scripts have been created. To complete the setup:"
echo ""
echo "1. Execute the master setup script:"
echo "   ./setup-presence.sh"
echo ""
echo "2. Test the services with the provided test scripts:"
echo "   ./test-fingerprint-service.sh"
echo "   ./test-context-service.sh"
echo "   ./test-mongodb.sh"
echo "   ./test-communication.sh"
echo ""
echo "3. Next development steps:"
echo "   - Develop the mobile application for audio capture"
echo "   - Build the web portal for context browsing and chat"
echo "   - Implement user authentication and account management"
echo "   - Add chat functionality for real-time communication"
echo ""
echo "The foundation of your Presence application is now ready!"
