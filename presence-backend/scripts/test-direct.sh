#!/bin/bash
echo "Setting up port forwarding to fingerprint-service..."
echo "Testing direct access without ingress"
echo "Press Ctrl+C when done testing"

kubectl port-forward -n presence svc/fingerprint-service 3000:3000 &
PF_PID=$!

sleep 3
echo -e "\nTesting root endpoint:"
curl http://localhost:3000/

echo -e "\nTesting health endpoint:"
curl http://localhost:3000/health

echo -e "\nPress Ctrl+C to stop port forwarding"
wait $PF_PID
