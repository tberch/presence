#!/bin/bash

# Function to display a header
function header() {
  echo ""
  echo "===== $1 ====="
  echo ""
}

# Test script specifically for testing POST requests to the fingerprint endpoint

header "Testing Direct POST to fingerprint endpoint (via port-forward)"
kubectl -n presence port-forward svc/fingerprint-service 3000:3000 &
PF_PID=$!
sleep 3

curl -X POST http://localhost:3000/fingerprint \
  -H "Content-Type: application/json" \
  -d '{"audioData":"test123","device_id":"test-device"}'
echo ""

kill $PF_PID

header "Testing POST to /fingerprint via ingress (localhost)"
curl -v -X POST http://localhost/fingerprint \
  -H "Content-Type: application/json" \
  -d '{"audioData":"test123","device_id":"test-device"}'
echo ""

header "Testing POST to /fingerprint via ingress (presence.local)"
curl -v -X POST -H "Host: presence.local" http://localhost/fingerprint \
  -H "Content-Type: application/json" \
  -d '{"audioData":"test123","device_id":"test-device"}'
echo ""

header "Debugging Ingress Configuration"
kubectl get ingress -n presence -o yaml
