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
