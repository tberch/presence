// Update the service to handle POST requests at both /fingerprint and / paths
const express = require('express');
const bodyParser = require('body-parser');
const crypto = require('crypto');

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(bodyParser.json({ limit: '5mb' }));
app.use(express.json());

// Add logging middleware to see what's happening
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

// Function to process fingerprint
function processFingerprint(req, res) {
  try {
    console.log('Processing fingerprint request');
    const { audioData, location, device_id } = req.body;
    
    if (!audioData) {
      return res.status(400).json({ 
        error: 'Missing required field: audioData'
      });
    }

    console.log('Received audio data:', typeof audioData === 'string' ? 
      audioData.substring(0, 20) + '...' : 'not a string');
    
    // Generate a simple hash as fingerprint
    const hash = crypto.createHash('sha256').update(
      typeof audioData === 'string' ? audioData : JSON.stringify(audioData)
    ).digest('hex');
    
    // Randomly decide if there's a match
    const matched = Math.random() > 0.3; // 70% chance of match
    
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
}

// Fingerprint submission and matching endpoint at /fingerprint
app.post('/fingerprint', (req, res) => {
  console.log('POST to /fingerprint received');
  processFingerprint(req, res);
});

// ALSO handle fingerprint submission at root path (for ingress)
app.post('/', (req, res) => {
  console.log('POST to / received (redirected from ingress)');
  processFingerprint(req, res);
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
