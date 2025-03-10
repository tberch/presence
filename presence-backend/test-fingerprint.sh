#!/bin/bash

echo "===== Testing Direct Access (Port Forward) ====="
echo "Setting up port forwarding..."
kubectl -n presence port-forward svc/fingerprint-service 3000:3000 &
PF_PID=$!
sleep 3

echo "Testing POST to /fingerprint endpoint:"
curl -X POST http://localhost:3000/fingerprint \
  -H "Content-Type: application/json" \
  -d '{"audioData":"dGVzdCBhdWRpbyBkYXRhIGZvciBmaW5nZXJwcmludGluZw==","location":{"latitude":37.7749,"longitude":-122.4194},"device_id":"test-device-123"}'
echo -e "\n"

# Kill port-forwarding
kill $PF_PID

echo "===== Testing Ingress Access ====="
echo "Testing service via presence.local host header:"
curl -H "Host: presence.local" http://localhost/fingerprint/health
echo -e "\n"

echo "Testing service via direct localhost access:"
curl http://localhost/fingerprint/health
echo -e "\n"

echo "Testing POST to /fingerprint via ingress (localhost):"
curl -X POST http://localhost/fingerprint \
  -H "Content-Type: application/json" \
  -d '{"audioData":"dGVzdCBhdWRpbyBkYXRhIGZvciBmaW5nZXJwcmludGluZw==","location":{"latitude":37.7749,"longitude":-122.4194},"device_id":"test-device-123"}'
echo -e "\n"

echo "Testing POST to /fingerprint via ingress (presence.local):"
curl -X POST -H "Host: presence.local" http://localhost/fingerprint \
  -H "Content-Type: application/json" \
  -d '{"audioData":"dGVzdCBhdWRpbyBkYXRhIGZvciBmaW5nZXJwcmludGluZw==","location":{"latitude":37.7749,"longitude":-122.4194},"device_id":"test-device-123"}'
echo -e "\n"
