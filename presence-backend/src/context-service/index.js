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
