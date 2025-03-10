#!/bin/bash

echo "===== Testing MongoDB Connection ====="

# Check if MongoDB pod is running
MONGO_POD=$(kubectl get pod -n presence -l app=mongodb -o jsonpath='{.items[0].metadata.name}')
if [ -z "$MONGO_POD" ]; then
  echo "No MongoDB pod found! Please make sure MongoDB is deployed."
  exit 1
fi

echo "MongoDB pod: $MONGO_POD"
echo "Status: $(kubectl get pod $MONGO_POD -n presence -o jsonpath='{.status.phase}')"

echo "Setting up port-forwarding to MongoDB..."
kubectl port-forward $MONGO_POD 27017:27017 -n presence &
PF_PID=$!
sleep 3

# Get MongoDB credentials from secret
MONGODB_USER=$(kubectl get secret db-credentials -n presence -o jsonpath='{.data.mongodb-user}' | base64 --decode)
MONGODB_PASSWORD=$(kubectl get secret db-credentials -n presence -o jsonpath='{.data.mongodb-password}' | base64 --decode)

echo "Testing MongoDB connection with credentials from Kubernetes secrets..."
mongosh --host localhost --port 27017 -u $MONGODB_USER -p $MONGODB_PASSWORD --authenticationDatabase admin --eval "db.runCommand({ping: 1})" || echo "Connection failed. MongoDB may not be ready or credentials may be incorrect."

echo "Listing databases..."
mongosh --host localhost --port 27017 -u $MONGODB_USER -p $MONGODB_PASSWORD --authenticationDatabase admin --eval "show dbs" || echo "Failed to list databases."

echo "Checking presence database contents..."
mongosh --host localhost --port 27017 -u $MONGODB_USER -p $MONGODB_PASSWORD --authenticationDatabase admin --eval "use presence; db.contexts.find()" || echo "Failed to query contexts collection."

# Clean up port-forwarding
kill $PF_PID

echo "===== Testing Service Connections to MongoDB ====="

echo "Checking if fingerprint-service can connect to MongoDB..."
kubectl exec -it deployment/fingerprint-service -n presence -- wget -qO- http://localhost:3000/status || echo "Failed to check fingerprint-service status"

echo "Checking if context-service can connect to MongoDB..."
kubectl exec -it deployment/context-service -n presence -- wget -qO- http://localhost:3001/status || echo "Failed to check context-service status"

echo "===== MongoDB Testing Complete ====="
