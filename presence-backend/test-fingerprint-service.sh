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
