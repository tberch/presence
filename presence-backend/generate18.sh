#!/bin/bash
# This script fixes the POST request handling in the ingress configuration

echo "===== Fixing Ingress Configuration for POST Requests ====="

# Create an updated ingress configuration with fixed rewrite rules
cat > k8s/ingress/api-gateway-fixed.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-gateway
  namespace: presence
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$1
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  ingressClassName: nginx
  rules:
    - host: presence.local
      http:
        paths:
          - path: /fingerprint/?(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: fingerprint-service
                port:
                  number: 3000
          - path: /context/?(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: context-service
                port:
                  number: 3001
          - path: /chat/?(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: chat-service
                port:
                  number: 3002
          - path: /user/?(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: user-service
                port:
                  number: 3003
          - path: /search/?(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: search-service
                port:
                  number: 3004
          - path: /notification/?(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: notification-service
                port:
                  number: 3005
    - http:
        paths:
          - path: /fingerprint/?(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: fingerprint-service
                port:
                  number: 3000
          - path: /
            pathType: Prefix
            backend:
              service:
                name: fingerprint-service
                port:
                  number: 3000
EOF

# Apply the updated ingress configuration
kubectl apply -f k8s/ingress/api-gateway-fixed.yaml

echo "===== Creating Direct POST Test Service ====="
# Let's create a simple express app with an explicit POST endpoint to test
cat > src/direct-fingerprint.js << 'EOF'
const express = require('express');
const bodyParser = require('body-parser');
const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(bodyParser.json({ limit: '5mb' }));
app.use(express.json());

// Add logging middleware to see what's happening
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  console.log('Headers:', JSON.stringify(req.headers, null, 2));
  if (req.body && Object.keys(req.body).length > 0) {
    console.log('Body:', JSON.stringify(req.body, null, 2));
  }
  next();
});

// Root path handler
app.get('/', (req, res) => {
  res.json({ 
    service: 'Direct Fingerprint Service',
    message: 'This service has explicit POST handling',
    endpoints: ['/health', '/fingerprint']
  });
});

// Health endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Direct fingerprint endpoint (no path prefix)
app.post('/fingerprint', (req, res) => {
  console.log('POST to /fingerprint received');
  res.json({
    success: true,
    message: 'Direct fingerprint endpoint processed the request',
    received: req.body
  });
});

// Start the server
app.listen(port, () => {
  console.log(`Direct fingerprint service listening on port ${port}`);
});
EOF

echo "===== Creating Test Script ====="
cat > test-post-fix.sh << 'EOF'
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
EOF
chmod +x test-post-fix.sh

echo "===== Next Steps ====="
echo "1. Run the test script to check if POST requests now work:"
echo "   ./test-post-fix.sh"
echo ""
echo "2. If issues persist, you can try updating your service code with the direct-fingerprint.js:"
echo "   cp src/direct-fingerprint.js src/index.js"
echo "   docker build -t presence/fingerprint-service -f docker/fingerprint-service/Dockerfile ."
echo "   kubectl rollout restart deployment/fingerprint-service -n presence"
echo ""
echo "3. Check the ingress controller logs for any errors:"
echo "   kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller"
