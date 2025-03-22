// This script creates a local test server that can help debug API issues
// by simulating the audio detection service locally

const express = require('express');
const cors = require('cors');
const multer = require('multer');
const WebSocket = require('ws');
const path = require('path');
const http = require('http');

// Create Express app
const app = express();
const port = 3000;

// Configure CORS - this is critical for browser access
app.use(cors({
  origin: '*', // Allow all origins
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true
}));

// Parse JSON bodies
app.use(express.json());

// Set up file upload using multer
const storage = multer.diskStorage({
  destination: function(req, file, cb) {
    cb(null, 'uploads/');
  },
  filename: function(req, file, cb) {
    cb(null, Date.now() + path.extname(file.originalname));
  }
});

const upload = multer({ storage: storage });

// In-memory storage for demo purposes
const uploads = {};
const jobs = {};
const events = {};

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'API is running' });
});

// Configuration endpoint
app.get('/config', (req, res) => {
  res.json({
    version: '1.0.0',
    supportedAudioFormats: ['mp3', 'wav', 'ogg'],
    maxFileSize: 10 * 1024 * 1024, // 10MB
    detectionOptions: {
      minSensitivity: 0,
      maxSensitivity: 1,
      defaultSensitivity: 0.5
    }
  });
});

// File upload endpoint
app.post('/upload', upload.single('audio'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }
  
  const fileId = 'file_' + Date.now();
  uploads[fileId] = {
    id: fileId,
    path: req.file.path,
    originalName: req.file.originalname,
    mimeType: req.file.mimetype,
    size: req.file.size,
    uploadedAt: new Date()
  };
  
  res.json({ fileId });
});

// Event detection endpoint
app.post('/detect-events', (req, res) => {
  const { fileId, sensitivity, minEventDuration, maxSilenceDuration } = req.body;
  
  if (!fileId) {
    return res.status(400).json({ error: 'File ID is required' });
  }
  
  if (!uploads[fileId]) {
    return res.status(404).json({ error: 'File not found' });
  }
  
  const jobId = 'job_' + Date.now();
  
  // Store job
  jobs[jobId] = {
    id: jobId,
    fileId,
    status: 'pending',
    createdAt: new Date(),
    params: {
      sensitivity: sensitivity || 0.5,
      minEventDuration: minEventDuration || 0.2,
      maxSilenceDuration: maxSilenceDuration || 0.5
    }
  };
  
  // Simulate async processing
  setTimeout(() => {
    jobs[jobId].status = 'processing';
    
    // Simulate event detection (after 2 seconds)
    setTimeout(() => {
      // Generate some random events
      const numEvents = Math.floor(Math.random() * 5) + 2; // 2-6 events
      const detectedEvents = [];
      
      let lastEndTime = 0;
      for (let i = 0; i < numEvents; i++) {
        const startTime = lastEndTime + Math.random() * 2;
        const endTime = startTime + (Math.random() * 1.5) + 0.5;
        
        detectedEvents.push({
          id: `event_${i}`,
          startTime,
          endTime,
          type: Math.random() > 0.5 ? 'speech' : 'noise',
          confidence: Math.random() * 0.3 + 0.7 // 0.7-1.0
        });
        
        lastEndTime = endTime;
      }
      
      // Store events
      events[jobId] = detectedEvents;
      
      // Mark job as completed
      jobs[jobId].status = 'completed';
      jobs[jobId].completedAt = new Date();
      
    }, 2000);
    
  }, 1000);
  
  res.json({ jobId });
});

// Job status endpoint
app.get('/job-status/:jobId', (req, res) => {
  const { jobId } = req.params;
  
  if (!jobs[jobId]) {
    return res.status(404).json({ error: 'Job not found' });
  }
  
  res.json({
    id: jobId,
    status: jobs[jobId].status,
    progress: jobs[jobId].status === 'completed' ? 100 : 
              jobs[jobId].status === 'processing' ? Math.floor(Math.random() * 80) + 20 : 
              jobs[jobId].status === 'pending' ? 0 : null
  });
});

// Events result endpoint
app.get('/events/:jobId', (req, res) => {
  const { jobId } = req.params;
  
  if (!jobs[jobId]) {
    return res.status(404).json({ error: 'Job not found' });
  }
  
  if (jobs[jobId].status !== 'completed') {
    return res.status(400).json({ error: 'Job not completed yet' });
  }
  
  if (!events[jobId]) {
    return res.json({ events: [] });
  }
  
  res.json({
    jobId,
    fileId: jobs[jobId].fileId,
    events: events[jobId]
  });
});

// Create HTTP server
const server = http.createServer(app);

// Set up WebSocket server
const wss = new WebSocket.Server({ server });

wss.on('connection', (ws) => {
  console.log('WebSocket client connected');
  
  // Send welcome message
  ws.send(JSON.stringify({ type: 'connected', message: 'Connected to audio detection WebSocket' }));
  
  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      console.log('Received:', data);
      
      // Echo back any message
      if (data.type === 'ping') {
        ws.send(JSON.stringify({ type: 'pong', timestamp: Date.now() }));
      }
      
    } catch (error) {
      console.error('Error processing message:', error);
      ws.send(JSON.stringify({ type: 'error', message: 'Invalid message format' }));
    }
  });
  
  ws.on('close', () => {
    console.log('WebSocket client disconnected');
  });
});

// Start the server
server.listen(port, () => {
  console.log(`Local test server running at http://localhost:${port}`);
});

/*
To run this server:
1. Make sure you have Node.js installed
2. Create a directory for this project
3. Run 'npm init -y' to create a package.json
4. Run 'npm install express cors multer ws'
5. Create an 'uploads' directory: mkdir uploads
6. Save this file as 'local-server.js'
7. Run 'node local-server.js'

Then update your test client to point to http://localhost:3000 instead of api.talkstudio.space
*/
