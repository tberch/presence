#!/bin/bash

# Direct test (via port-forward)
kubectl -n presence port-forward svc/fingerprint-service 3000:3000 &
PF_PID=$!

# Wait for port-forward to establish
sleep 3

echo -e "\n===== Testing Root Path ====="
curl http://localhost:3000/
echo -e "\n"

echo -e "===== Testing Health Endpoint ====="
curl http://localhost:3000/health
echo -e "\n"

echo -e "===== Testing API Endpoint ====="
curl http://localhost:3000/api
echo -e "\n"

echo -e "===== Testing Fingerprint Endpoint ====="
curl -X POST http://localhost:3000/fingerprint \
  -H "Content-Type: application/json" \
  -d '{"audioData":"dGVzdCBhdWRpbyBkYXRhIGZvciBmaW5nZXJwcmludGluZw==","location":{"latitude":37.7749,"longitude":-122.4194},"device_id":"test-device-123"}'
echo -e "\n"

# Kill the port-forwarding
kill $PF_PID

echo -e "===== Testing Through Ingress ====="
curl http://localhost/fingerprint/health
