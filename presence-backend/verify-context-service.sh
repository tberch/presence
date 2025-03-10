#!/bin/bash

echo "===== Verifying Fixed Context Service ====="

# Wait a bit to ensure service is fully ready
sleep 5

# Set up port-forwarding
kubectl port-forward svc/context-service 3001:3001 -n presence &
PF_PID=$!
sleep 3

# Test all endpoints
echo "Testing root endpoint:"
curl http://localhost:3001/
echo -e "\n"

echo "Testing health endpoint:"
curl http://localhost:3001/health
echo -e "\n"

echo "Testing status endpoint:"
curl http://localhost:3001/status
echo -e "\n"

echo "Testing contexts endpoint:"
curl http://localhost:3001/contexts
echo -e "\n"

echo "Creating a new context:"
curl -X POST http://localhost:3001/contexts \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Context from Verification","type":"broadcast"}'
echo -e "\n"

echo "Testing contexts endpoint again to see the new context:"
curl http://localhost:3001/contexts
echo -e "\n"

# Clean up
kill $PF_PID

echo "===== Verification Complete ====="
echo "If all the endpoints returned valid JSON responses, the fix was successful."
