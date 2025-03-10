#!/bin/bash
# This script will fix the service code, rebuild the image, and redeploy

echo "======== CREATING UPDATED SERVICE CODE ========"
# Create src directory if it doesn't exist
mkdir -p src

# Create the updated index.js file with a root handler
cat > src/index.js << 'EOF'
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

// Root path handler
app.get('/', (req, res) => {
  res.json({ 
    service: 'Presence API',
    message: 'Welcome to the Presence Fingerprint Service',
    version: '1.0.0',
    endpoints: [
      '/health - Service health check',
      '/status - Service status information',
      '/api - API documentation'
    ]
  });
});

// Health endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Status endpoint
app.get('/status', (req, res) => {
  res.json({
    service: 'fingerprint-service',
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

// API documentation endpoint
app.get('/api', (req, res) => {
  res.json({
    name: 'Fingerprint Service API',
    description: 'Audio fingerprinting and context detection',
    endpoints: [
      {
        path: '/fingerprint',
        method: 'POST',
        description: 'Submit audio fingerprint for matching',
        body: { fingerprint: 'base64-encoded audio fingerprint' }
      },
      {
        path: '/contexts',
        method: 'GET', 
        description: 'Get all detected contexts'
      }
    ]
  });
});

// Start the server
app.listen(port, () => {
  console.log(`Fingerprint service listening on port ${port}`);
});
EOF

echo "Service code created with root path handler"

echo "======== REBUILDING DOCKER IMAGE ========"
# Rebuild the Docker image with the updated code
docker build -t presence/fingerprint-service -f docker/fingerprint-service/Dockerfile .

echo "======== REDEPLOYING SERVICE ========"
# Restart the deployment to apply changes
kubectl rollout restart deployment fingerprint-service -n presence

echo "Waiting for deployment to complete..."
kubectl rollout status deployment fingerprint-service -n presence

echo "======== TESTING NEW SERVICE ========"
echo "Wait about 10 seconds for the service to fully initialize, then try:"
echo ""
echo "1. Testing the service directly:"
echo "   kubectl port-forward -n presence svc/fingerprint-service 3000:3000"
echo "   Then in another terminal: curl http://localhost:3000/"
echo ""
echo "2. Testing through ingress (if properly configured):"
echo "   curl http://localhost/"
echo ""
echo "The service should now respond with JSON on the root path."

# Create a validation script
cat > scripts/validate-service.sh << 'EOF'
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
EOF
chmod +x scripts/validate-service.sh

echo "Validation script created. Run './scripts/validate-service.sh' to verify all endpoints."
