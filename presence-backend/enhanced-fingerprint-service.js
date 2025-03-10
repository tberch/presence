// src/fingerprint-service/index.js
const express = require('express');
const bodyParser = require('body-parser');
const mongoose = require('mongoose');
const axios = require('axios');
const { generateFingerprint, compareFingerprints } = require('./fingerprinting');
const { FingerprintModel, ContextModel } = require('./models');

const app = express();
const port = process.env.PORT || 3000;

// Connect to MongoDB
async function connectToMongoDB() {
  try {
    const mongoHost = process.env.MONGODB_HOST || 'mongodb';
    const mongoPort = process.env.MONGODB_PORT || '27017';
    const mongoDb = process.env.MONGODB_DB || 'presence';
    const mongoUser = process.env.MONGODB_USER || 'presence.admin';
    const mongoPass = process.env.MONGODB_PASSWORD || 'changeme';
    
    const mongoUrl = `mongodb://${mongoUser}:${mongoPass}@${mongoHost}:${mongoPort}/${mongoDb}?authSource=admin`;
    
    await mongoose.connect(mongoUrl, {
      useNewUrlParser: true,
      useUnifiedTopology: true
    });
    
    console.log('Connected to MongoDB');
    return true;
  } catch (error) {
    console.error('Failed to connect to MongoDB:', error);
    return false;
  }
}

// Middleware
app.use(bodyParser.json({ limit: '5mb' }));
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
    database: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected'
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
async function processFingerprint(req, res) {
  try {
    console.log('Processing fingerprint request');
    const { audioData, location, device_id } = req.body;
    
    if (!audioData) {
      return res.status(400).json({ 
        error: 'Missing required field: audioData'
      });
    }

    // Generate fingerprint from audio data
    console.log('Generating fingerprint from audio data...');
    const fingerprint = await generateFingerprint(audioData);
    
    // Query database for matching fingerprints
    console.log('Looking for matching fingerprints...');
    const existingFingerprints = await FingerprintModel.find().limit(100);
    
    // Find best match
    let bestMatch = null;
    let bestConfidence = 0;
    
    for (const existing of existingFingerprints) {
      const confidence = compareFingerprints(fingerprint, existing.data);
      if (confidence > bestConfidence && confidence > 75) {
        bestMatch = existing;
        bestConfidence = confidence;
      }
    }
    
    if (bestMatch) {
      // Get associated context
      const context = await ContextModel.findById(bestMatch.contextId);
      
      if (!context) {
        console.error(`Context not found for fingerprint ${bestMatch._id}`);
        return res.json({
          matched: false,
          message: 'Context not found for fingerprint'
        });
      }
      
      // Notify context service about the match
      try {
        await axios.post(`http://context-service:3001/events`, {
          type: 'fingerprint.matched',
          source: 'fingerprint-service',
          timestamp: new Date().toISOString(),
          payload: {
            device_id,
            context_id: context._id.toString(),
            confidence: bestConfidence,
            location: location || null
          }
        });
        console.log(`Notified context service about match for context ${context._id}`);
      } catch (error) {
        console.error('Failed to notify context service:', error.message);
      }
      
      return res.json({
        matched: true,
        confidence: bestConfidence,
        context: {
          id: context._id.toString(),
          name: context.name,
          type: context.type,
          users_count: context.usersCount,
          created_at: context.createdAt
        }
      });
    } else {
      // If quality is good, store as a new fingerprint/context
      if (fingerprint.quality > 0.7) {
        // Create a new context
        const newContext = await ContextModel.create({
          name: `Detected Context ${Date.now()}`,
          type: 'unknown',
          usersCount: 1,
          createdAt: new Date(),
          updatedAt: new Date()
        });
        
        // Store the fingerprint
        await FingerprintModel.create({
          data: fingerprint,
          contextId: newContext._id,
          createdAt: new Date()
        });
        
        console.log(`Created new context ${newContext._id} for unmatched fingerprint`);
        
        return res.json({
          matched: false,
          message: 'No match found, created new context',
          new_context: {
            id: newContext._id.toString(),
            name: newContext.name
          }
        });
      }
      
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

// Fingerprint submission at /fingerprint path
app.post('/fingerprint', (req, res) => {
  console.log('POST to /fingerprint received');
  processFingerprint(req, res);
});

// Handle fingerprint submission at root (for ingress)
app.post('/', (req, res) => {
  console.log('POST to / received (redirected from ingress)');
  processFingerprint(req, res);
});

// Get all contexts
app.get('/contexts', async (req, res) => {
  try {
    // Get contexts from database
    const contexts = await ContextModel.find()
      .sort({ createdAt: -1 })
      .limit(20);
    
    const result = contexts.map(ctx => ({
      id: ctx._id.toString(),
      name: ctx.name,
      type: ctx.type,
      users_count: ctx.usersCount,
      created_at: ctx.createdAt
    }));
    
    res.json({ contexts: result });
  } catch (error) {
    console.error('Error fetching contexts:', error);
    res.status(500).json({ 
      error: 'Error fetching contexts',
      details: error.message 
    });
  }
});

// Start server
async function startServer() {
  // Connect to MongoDB first
  const dbConnected = await connectToMongoDB();
  
  // Start the server even if DB connection fails
  app.listen(port, () => {
    console.log(`Fingerprint service listening on port ${port}`);
    if (!dbConnected) {
      console.warn('Warning: Running without database connection');
    }
  });
}

startServer();
