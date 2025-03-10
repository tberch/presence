const express = require('express');
const bodyParser = require('body-parser');
const { generateFingerprint, matchFingerprint } = require('./fingerprinting');
const { publishEvent } = require('./events');
const { connectToDb } = require('./database');

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
    timestamp: new Date().toISOString(),
    database: global.dbConnected ? 'connected' : 'disconnected'
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
          fingerprint: 'base64-encoded audio fingerprint',
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

// Fingerprint submission and matching endpoint
app.post('/fingerprint', async (req, res) => {
  try {
    const { audioData, location, device_id } = req.body;
    
    if (!audioData) {
      return res.status(400).json({ 
        error: 'Missing required field: audioData'
      });
    }

    // Process raw audio data into a fingerprint
    console.log('Generating fingerprint from audio data...');
    const fingerprint = await generateFingerprint(audioData);
    
    // Match the fingerprint against the database
    console.log('Matching fingerprint against database...');
    const result = await matchFingerprint(fingerprint, location);
    
    if (result.matched) {
      // Publish an event to notify other services about the match
      await publishEvent('fingerprint.matched', {
        device_id,
        context_id: result.context.id,
        timestamp: new Date().toISOString(),
        confidence: result.confidence
      });
      
      return res.json({
        matched: true,
        context: result.context,
        confidence: result.confidence
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
app.get('/contexts', async (req, res) => {
  try {
    // In a real implementation, this would query the database
    // For now, return sample data
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
  } catch (error) {
    console.error('Error fetching contexts:', error);
    res.status(500).json({ 
      error: 'Error fetching contexts',
      details: error.message 
    });
  }
});

// Start the server
const startServer = async () => {
  try {
    // Connect to database first
    await connectToDb();
    global.dbConnected = true;
    
    // Then start the server
    app.listen(port, () => {
      console.log(`Fingerprint service listening on port ${port}`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    global.dbConnected = false;
    
    // Start anyway, but mark database as disconnected
    app.listen(port, () => {
      console.log(`Fingerprint service listening on port ${port} (DB disconnected)`);
    });
  }
};

startServer();
