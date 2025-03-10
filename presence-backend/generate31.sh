#!/bin/bash
# This file contains all the test scripts for the Presence application

# Create test-fingerprint-service.sh
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

# Create test-context-service.sh
cat > test-context-service.sh << 'EOF'
#!/bin/bash

echo "===== Testing Context Service ====="
kubectl -n presence port-forward svc/context-service 3001:3001 &
CS_PID=$!
sleep 3

echo "===== Testing Root Path ====="
curl http://localhost:3001/
echo -e "\n"

echo "===== Testing Health Endpoint ====="
curl http://localhost:3001/health
echo -e "\n"

echo "===== Creating a New Context ====="
curl -X POST http://localhost:3001/contexts \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Context","type":"broadcast","metadata":{"show":"News at 9"}}'
echo -e "\n"

echo "===== Getting All Contexts ====="
curl http://localhost:3001/contexts
echo -e "\n"

kill $CS_PID

echo "===== Testing Inter-Service Communication ====="
echo "Setting up port-forwarding to fingerprint-service..."
kubectl -n presence port-forward svc/fingerprint-service 3000:3000 &
FP_PID=$!
sleep 3

echo "In another terminal, run this to watch context service logs:"
echo "kubectl logs -f deployment/context-service -n presence"
echo "Press Enter when ready to continue..."
read

echo "Sending fingerprint that should trigger an event to context service:"
curl -X POST http://localhost:3000/fingerprint \
  -H "Content-Type: application/json" \
  -d '{"audioData":"dGVzdCBhdWRpbyBkYXRhIGZvciBmaW5nZXJwcmludGluZw==","device_id":"test-device-789"}'
echo -e "\n"

echo "Check the context service logs to see if it received the event."
echo "Press Enter to continue..."
read

kill $FP_PID

echo "===== Context Service Test Complete ====="
EOF
chmod +x test-context-service.sh

# Create test-mongodb.sh
cat > test-mongodb.sh << 'EOF'
#!/bin/bash

echo "===== Testing MongoDB Connection ====="

# Check if MongoDB pod is running
MONGO_POD=$(kubectl get pod -n presence -l app=mongodb -o jsonpath='{.items[0].metadata.name}')
if [ -z "$MONGO_POD" ]; then
  echo "No MongoDB pod found! Please make sure MongoDB is deployed."
  exit 1
fi

echo "MongoDB pod: $MONGO_POD"
echo "Status: $(kubectl get pod $MONGO_POD -n presence -o jsonpath='{.status.phase}')"

echo "Setting up port-forwarding to MongoDB..."
kubectl port-forward $MONGO_POD 27017:27017 -n presence &
PF_PID=$!
sleep 3

# Get MongoDB credentials from secret
MONGODB_USER=$(kubectl get secret db-credentials -n presence -o jsonpath='{.data.mongodb-user}' | base64 --decode)
MONGODB_PASSWORD=$(kubectl get secret db-credentials -n presence -o jsonpath='{.data.mongodb-password}' | base64 --decode)

echo "Testing MongoDB connection with credentials from Kubernetes secrets..."
mongosh --host localhost --port 27017 -u $MONGODB_USER -p $MONGODB_PASSWORD --authenticationDatabase admin --eval "db.runCommand({ping: 1})" || echo "Connection failed. MongoDB may not be ready or credentials may be incorrect."

echo "Listing databases..."
mongosh --host localhost --port 27017 -u $MONGODB_USER -p $MONGODB_PASSWORD --authenticationDatabase admin --eval "show dbs" || echo "Failed to list databases."

echo "Checking presence database contents..."
mongosh --host localhost --port 27017 -u $MONGODB_USER -p $MONGODB_PASSWORD --authenticationDatabase admin --eval "use presence; db.contexts.find()" || echo "Failed to query contexts collection."

# Clean up port-forwarding
kill $PF_PID

echo "===== Testing Service Connections to MongoDB ====="

echo "Checking if fingerprint-service can connect to MongoDB..."
kubectl exec -it deployment/fingerprint-service -n presence -- wget -qO- http://localhost:3000/status || echo "Failed to check fingerprint-service status"

echo "Checking if context-service can connect to MongoDB..."
kubectl exec -it deployment/context-service -n presence -- wget -qO- http://localhost:3001/status || echo "Failed to check context-service status"

echo "===== MongoDB Testing Complete ====="
EOF
chmod +x test-mongodb.sh

# Create test-communication.sh
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
if [ -z "$CONTEXT_ID" ]; then
  echo "Failed to extract context ID. Using a dummy ID instead."
  CONTEXT_ID="dummy_id"
fi
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

echo "All test scripts have been created and are ready to use."
echo ""
echo "To test the fingerprint service:      ./test-fingerprint-service.sh"
echo "To test the context service:          ./test-context-service.sh"
echo "To test MongoDB connection:           ./test-mongodb.sh"
echo "To test inter-service communication:  ./test-communication.sh"
