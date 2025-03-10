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
