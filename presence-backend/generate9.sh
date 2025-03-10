#!/bin/bash
# This script addresses the "Cannot GET /" error by:
# 1. Adding a root path handler to the services
# 2. Ensuring ingress is properly configured
# 3. Testing the entire path

echo "======== UPDATING SERVICE CODE ========"
# Add a root path handler to fingerprint-service
mkdir -p src/fingerprint-service

cat > src/fingerprint-service/index.js << 'EOF'
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

// Basic middleware for all requests
app.use((req, res, next) => {
  console.log(`Request received: ${req.method} ${req.url}`);
  next();
});

// Root handler
app.get('/', (req, res) => {
  res.json({ 
    service: 'fingerprint-service', 
    message: 'Welcome to the Presence API',
    endpoints: ['/health', '/status', '/info']
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
    version: '1.0.0',
    uptime: process.uptime()
  });
});

// Info endpoint
app.get('/info', (req, res) => {
  res.json({
    name: 'Presence Fingerprint Service',
    description: 'Audio fingerprinting and matching service',
    environment: process.env.NODE_ENV || 'development'
  });
});

app.listen(port, () => {
  console.log(`fingerprint-service listening on port ${port}`);
});
EOF

echo "Service code updated with proper root endpoint handler"

echo "======== REBUILDING DOCKER IMAGE ========"
# Rebuild the fingerprint-service Docker image
docker build -t presence/fingerprint-service -f docker/fingerprint-service/Dockerfile .

echo "Docker image rebuilt"

echo "======== UPDATING INGRESS CONFIGURATION ========"
# Create a very simple ingress for testing
cat > k8s/ingress/basic-test.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: basic-test
  namespace: presence
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: fingerprint-service
            port:
              number: 3000
EOF

kubectl apply -f k8s/ingress/basic-test.yaml

echo "Basic test ingress applied"

echo "======== REDEPLOYING SERVICE ========"
# Restart the deployment to apply changes
kubectl rollout restart deployment fingerprint-service -n presence

echo "Waiting for deployment to complete..."
kubectl rollout status deployment fingerprint-service -n presence

echo "======== CREATING PORT-FORWARD TO TEST DIRECTLY ========"
# Create a script to test the service directly via port-forward
cat > scripts/test-direct.sh << 'EOF'
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
EOF
chmod +x scripts/test-direct.sh

echo "======== CHECKING INGRESS CONFIG ========"
kubectl get ingress -n presence
kubectl describe ingress basic-test -n presence

echo "======== TESTING INSTRUCTIONS ========"
echo "Now test your setup with these steps:"

echo "1. Test the service DIRECTLY (bypassing ingress):"
echo "   ./scripts/test-direct.sh"

echo "2. Test via ingress:"
echo "   curl http://localhost/"
echo "   curl http://localhost/health"

echo "3. If direct test works but ingress doesn't, check ingress controller logs:"
echo "   kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50"

echo "4. Try accessing via NodePort service as a fallback:"
echo "   kubectl get svc -n presence | grep NodePort" 
