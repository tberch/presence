#!/bin/bash
# This script fixes both the missing fingerprint endpoint and the ingress issues

echo "===== 1. Updating Fingerprint Service with POST Endpoint ====="
# Create a simpler implementation of the fingerprint endpoint
cat > src/index.js << 'EOF'
const express = require('express');
const bodyParser = require('body-parser');
const crypto = require('crypto');

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(bodyParser.json({ limit: '5mb' }));
app.use(express.json());

// Root path handler
app.get('/', (req, res) => {
  res.json({ 
    service: 'Presence API',
    message: 'Welcome to the Presence Fingerprint Service',
    version: '1.0.0',
    endpoints: [
      '/health - Service health check',
      '/status - Service status information',
      '/api - API documentation',
      '/fingerprint - Submit audio fingerprint for matching'
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
        body: { 
          audioData: 'base64-encoded audio data',
          location: { latitude: 'number', longitude: 'number' },
          device_id: 'string'
        },
        response: {
          matched: 'boolean',
          context: 'object (if matched)',
          confidence: 'number (0-100)'
        }
      },
      {
        path: '/contexts',
        method: 'GET', 
        description: 'Get all detected contexts'
      }
    ]
  });
});

// Simple fingerprint endpoint
app.post('/fingerprint', (req, res) => {
  try {
    const { audioData, location, device_id } = req.body;
    
    if (!audioData) {
      return res.status(400).json({ 
        error: 'Missing required field: audioData'
      });
    }

    console.log('Received audio data:', audioData.substring(0, 20) + '...');
    
    // Generate a simple hash as fingerprint
    const hash = crypto.createHash('sha256').update(audioData).digest('hex');
    
    // Randomly decide if there's a match
    const matched = Math.random() > 0.5;
    
    if (matched) {
      return res.json({
        matched: true,
        confidence: Math.floor(Math.random() * 20) + 80, // 80-100%
        context: {
          id: 'ctx_' + Math.floor(Math.random() * 1000000).toString(),
          name: 'Sample Context ' + Math.floor(Math.random() * 100).toString(),
          type: ['broadcast', 'concert', 'podcast'][Math.floor(Math.random() * 3)],
          users_count: Math.floor(Math.random() * 1000),
          created_at: new Date().toISOString()
        }
      });
    } else {
      return res.json({
        matched: false,
        message: 'No matching context found'
      });
    }
  } catch (error) {
    console.error('Error processing fingerprint:', error);
    res.status(500).json({ 
      error: 'Error processing fingerprint',
      details: error.message
    });
  }
});

// Get all contexts (simplified)
app.get('/contexts', (req, res) => {
  const contexts = [
    {
      id: 'ctx_123456',
      name: 'CNN News Broadcast',
      type: 'broadcast',
      count: 1245,
      created_at: '2025-03-01T12:00:00Z'
    },
    {
      id: 'ctx_789012',
      name: 'Taylor Swift Concert',
      type: 'live_event',
      count: 5432,
      created_at: '2025-03-02T20:30:00Z'
    }
  ];
  
  res.json({ contexts });
});

// Start the server
app.listen(port, () => {
  console.log(`Fingerprint service listening on port ${port}`);
});
EOF

echo "Updated the fingerprint service code with POST endpoint"

echo "===== 2. Rebuilding Docker Image ====="
# Rebuild the Docker image
docker build -t presence/fingerprint-service -f docker/fingerprint-service/Dockerfile .

echo "===== 3. Updating the Ingress Configuration ====="
# Create a fixed ingress configuration that properly handles paths
cat > k8s/ingress/fixed-ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fingerprint-ingress
  namespace: presence
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  rules:
  - host: presence.local
    http:
      paths:
      - path: /fingerprint(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: fingerprint-service
            port:
              number: 3000
  - http:
      paths:
      - path: /fingerprint(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: fingerprint-service
            port:
              number: 3000
      - path: /api(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: fingerprint-service
            port:
              number: 3000
EOF

kubectl apply -f k8s/ingress/fixed-ingress.yaml

echo "===== 4. Redeploying Fingerprint Service ====="
# Restart the deployment to apply changes
kubectl rollout restart deployment fingerprint-service -n presence

echo "Waiting for deployment to complete..."
kubectl rollout status deployment fingerprint-service -n presence

echo "===== 5. Creating Test Script ====="
# Create a test script for the updated service
cat > test-fingerprint.sh << 'EOF'
#!/bin/bash

echo "===== Testing Direct Access (Port Forward) ====="
kubectl -n presence port-forward svc/fingerprint-service 3000:3000 &
PF_PID=$!
sleep 3

echo "Testing POST to /fingerprint endpoint:"
curl -X POST http://localhost:3000/fingerprint \
  -H "Content-Type: application/json" \
  -d '{"audioData":"dGVzdCBhdWRpbyBkYXRhIGZvciBmaW5nZXJwcmludGluZw==","location":{"latitude":37.7749,"longitude":-122.4194},"device_id":"test-device-123"}'
echo -e "\n"

kill $PF_PID

echo "===== Testing Ingress Access ====="
echo "Testing /fingerprint/health via ingress:"
curl http://localhost/fingerprint/health
echo -e "\n"

echo "Testing POST to /fingerprint via ingress:"
curl -X POST http://localhost/fingerprint \
  -H "Content-Type: application/json" \
  -d '{"audioData":"dGVzdCBhdWRpbyBkYXRhIGZvciBmaW5nZXJwcmludGluZw==","location":{"latitude":37.7749,"longitude":-122.4194},"device_id":"test-device-123"}'
echo -e "\n"
EOF
chmod +x test-fingerprint.sh

echo "===== NEXT STEPS ====="
echo "1. Run the test script to verify both issues are fixed:"
echo "   ./test-fingerprint.sh"
echo ""
echo "2. Once these basic features are working, implement the full fingerprinting"
echo "   service with database integration and inter-service communication."
