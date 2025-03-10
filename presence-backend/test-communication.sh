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
