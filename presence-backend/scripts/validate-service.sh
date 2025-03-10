#!/bin/bash
echo "Setting up port forwarding to fingerprint-service..."
kubectl port-forward -n presence svc/fingerprint-service 3000:3000 &
PF_PID=$!

# Wait for port forwarding to establish
sleep 3

echo -e "\n===== Testing Root Path ====="
curl http://localhost:3000/
echo -e "\n"

echo -e "===== Testing Health Endpoint ====="
curl http://localhost:3000/health
echo -e "\n"

echo -e "===== Testing Status Endpoint ====="
curl http://localhost:3000/status
echo -e "\n"

echo -e "===== Testing API Endpoint ====="
curl http://localhost:3000/api
echo -e "\n"

# Stop port forwarding
kill $PF_PID
