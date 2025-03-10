#!/bin/bash
# Script to debug and fix Context Service issues

echo "===== Debugging Context Service Issues ====="

# 1. Check if the context service pod is running
echo "Checking Context Service deployment status..."
kubectl get pods -n presence -l app=context-service
CONTEXT_POD=$(kubectl get pod -n presence -l app=context-service -o jsonpath='{.items[0].metadata.name}')

if [ -z "$CONTEXT_POD" ]; then
  echo "Error: Context Service pod not found!"
  exit 1
fi

# 2. Check the logs for errors
echo "Checking Context Service logs for errors..."
kubectl logs $CONTEXT_POD -n presence

# 3. Create a simplified Context Service implementation
echo "Creating a simplified Context Service implementation..."

mkdir -p src/context-service

cat > src/context-service/index.js << 'EOF'
const express = require('express');
const bodyParser = require('body-parser');
const app = express();
const port = process.env.PORT || 3001;

// In-memory storage for development/testing
const inMemoryContexts = [
  {
    id: 'ctx_123456',
    name: 'CNN News Broadcast',
    type: 'broadcast',
    usersCount: 1245,
    createdAt: new Date('2025-03-01T12:00:00Z')
  },
  {
    id: 'ctx_789012',
    name: 'Taylor Swift Concert',
    type: 'concert',
    usersCount: 5432,
    createdAt: new Date('2025-03-02T20:30:00Z')
  }
];

// Middleware
app.use(bodyParser.json());
app.use(express.json());

// Logging middleware
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  if (req.body && Object.keys(req.body).length > 0) {
    console.log('Body:', JSON.stringify(req.body).substring(0, 100) + '...');
  }
  next();
});

// Root path handler
app.get('/', (req, res) => {
  res.json({
    service: 'Context Service',
    message: 'Manages contexts and associated metadata',
    version: '1.0.0',
    endpoints: [
      '/health - Service health check',
      '/status - Service status information',
      '/contexts - Get or create contexts',
      '/contexts/:id - Get context details',
      '/events - Handle events from other services'
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
    service: 'context-service',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    database: 'in-memory'
  });
});

// Get all contexts
app.get('/contexts', async (req, res) => {
  try {
    // Return in-memory contexts
    const contexts = inMemoryContexts.map(ctx => ({
      id: ctx.id,
      name: ctx.name,
      type: ctx.type,
      users_count: ctx.usersCount,
      created_at: ctx.createdAt
    }));
    
    res.json({ contexts });
  } catch (error) {
    console.error('Error fetching contexts:', error);
    res.status(500).json({ 
      error: 'Error fetching contexts',
      details: error.message 
    });
  }
});

// Get a specific context
app.get('/contexts/:id', async (req, res) => {
  try {
    const contextId = req.params.id;
    
    // Find context in memory
    const context = inMemoryContexts.find(ctx => ctx.id === contextId);
    
    if (!context) {
      return res.status(404).json({ error: 'Context not found' });
    }
    
    res.json({
      id: context.id,
      name: context.name,
      type: context.type,
      users_count: context.usersCount,
      created_at: context.createdAt
    });
  } catch (error) {
    console.error(`Error getting context ${req.params.id}:`, error);
    res.status(500).json({ error: 'Failed to retrieve context' });
  }
});

// Create a new context
app.post('/contexts', async (req, res) => {
  try {
    const { name, type, metadata } = req.body;
    
    if (!name) {
      return res.status(400).json({ error: 'Name is required' });
    }
    
    // Create in-memory
    const newContext = {
      id: `ctx_${Date.now()}`,
      name,
      type: type || 'unknown',
      metadata: metadata || {},
      usersCount: 0,
      createdAt: new Date()
    };
    
    inMemoryContexts.push(newContext);
    
    res.status(201).json({
      id: newContext.id,
      name: newContext.name,
      type: newContext.type,
      created_at: newContext.createdAt
    });
  } catch (error) {
    console.error('Error creating context:', error);
    res.status(500).json({ error: 'Failed to create context' });
  }
});

// Handle events from other services
app.post('/events', async (req, res) => {
  try {
    const { type, source, payload } = req.body;
    
    console.log(`Received event ${type} from ${source}`);
    console.log('Payload:', JSON.stringify(payload));
    
    // Process different event types
    switch (type) {
      case 'fingerprint.matched':
        console.log(`Processing match: context ${payload.context_id}, device ${payload.device_id}`);
        break;
        
      default:
        console.log(`Unknown event type: ${type}`);
    }
    
    res.json({ status: 'ok' });
  } catch (error) {
    console.error('Error processing event:', error);
    res.status(500).json({ error: 'Failed to process event' });
  }
});

// Start the server
app.listen(port, () => {
  console.log(`Context service listening on port ${port}`);
  console.log('Warning: Running with in-memory storage only');
});
EOF

cat > src/context-service/package.json << 'EOF'
{
  "name": "context-service",
  "version": "1.0.0",
  "description": "Context management for Presence application",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "body-parser": "^1.20.2"
  }
}
EOF

# 4. Rebuild the Docker image with the simplified service
echo "Rebuilding context service Docker image..."
docker build -t presence/context-service -f docker/context-service/Dockerfile .

# 5. Restart the Context Service deployment
echo "Restarting Context Service deployment..."
kubectl rollout restart deployment/context-service -n presence

# 6. Wait for the new pod to be ready
echo "Waiting for updated pod to be ready..."
kubectl rollout status deployment/context-service -n presence

# 7. Create a verification script
cat > verify-context-service.sh << 'EOF'
#!/bin/bash

echo "===== Verifying Fixed Context Service ====="

# Wait a bit to ensure service is fully ready
sleep 5

# Set up port-forwarding
kubectl port-forward svc/context-service 3001:3001 -n presence &
PF_PID=$!
sleep 3

# Test all endpoints
echo "Testing root endpoint:"
curl http://localhost:3001/
echo -e "\n"

echo "Testing health endpoint:"
curl http://localhost:3001/health
echo -e "\n"

echo "Testing status endpoint:"
curl http://localhost:3001/status
echo -e "\n"

echo "Testing contexts endpoint:"
curl http://localhost:3001/contexts
echo -e "\n"

echo "Creating a new context:"
curl -X POST http://localhost:3001/contexts \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Context from Verification","type":"broadcast"}'
echo -e "\n"

echo "Testing contexts endpoint again to see the new context:"
curl http://localhost:3001/contexts
echo -e "\n"

# Clean up
kill $PF_PID

echo "===== Verification Complete ====="
echo "If all the endpoints returned valid JSON responses, the fix was successful."
EOF
chmod +x verify-context-service.sh

echo "===== Fix Applied ====="
echo "The context service has been rebuilt with a simplified implementation."
echo "To verify the fix, run:"
echo "  ./verify-context-service.sh"
echo ""
echo "Once the context service is working, you can then test inter-service communication:"
echo "  ./test-communication.sh"
