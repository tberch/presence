#!/bin/bash

echo "===== Testing Notification Service ====="
kubectl -n presence port-forward svc/notification-service 3005:3005 &
NS_PID=$!
sleep 3

echo "===== Testing Root Path ====="
curl http://localhost:3005/
echo -e "\n"

echo "===== Testing Health Endpoint ====="
curl http://localhost:3005/health
echo -e "\n"

echo "===== Creating a Test Notification ====="
curl -X POST http://localhost:3005/notifications \
  -H "Content-Type: application/json" \
  -d '{"user_id":"test-user-123","type":"test","title":"Test Notification","body":"This is a test notification","data":{"action":"test"}}'
echo -e "\n"

echo "===== Getting Notifications ====="
curl "http://localhost:3005/notifications?user_id=test-user-123"
echo -e "\n"

echo "===== Registering a Test Device ====="
curl -X POST http://localhost:3005/devices/register \
  -H "Content-Type: application/json" \
  -d '{"user_id":"test-user-123","device_id":"test-device-123","token":"test-token-123","platform":"android"}'
echo -e "\n"

echo "===== Testing Socket.IO Connection ====="
echo "To test WebSocket functionality, use a WebSocket client to connect to:"
echo "ws://localhost:3005"
echo "WebSocket testing requires a client that supports Socket.IO protocol."
echo "For a quick test, you can use tools like 'wscat' or browser-based Socket.IO testers."

# Clean up
kill $NS_PID

echo "===== Notification Service Test Complete ====="
