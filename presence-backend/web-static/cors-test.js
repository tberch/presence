// This is a simple script to test if your API has CORS enabled
// Run this in the browser console where you're hosting your test page

async function testCORS() {
  console.log("Testing CORS configuration of your API...");
  
  try {
    // Method 1: Simple GET request with no credentials
    const simpleResponse = await fetch('http://api.talkstudio.space/health', {
      method: 'GET',
      mode: 'cors'
    });
    
    console.log("Simple GET request:");
    console.log("Status:", simpleResponse.status);
    console.log("Headers:", [...simpleResponse.headers.entries()]);
    console.log("Has Access-Control-Allow-Origin:", simpleResponse.headers.has('access-control-allow-origin'));
    
    // Method 2: OPTIONS preflight request (simulated)
    const preflightResponse = await fetch('http://api.talkstudio.space/health', {
      method: 'OPTIONS',
      mode: 'cors',
      headers: {
        'Access-Control-Request-Method': 'POST',
        'Access-Control-Request-Headers': 'Content-Type',
        'Origin': window.location.origin
      }
    });
    
    console.log("\nPreflight OPTIONS request:");
    console.log("Status:", preflightResponse.status);
    console.log("Headers:", [...preflightResponse.headers.entries()]);
    console.log("Has CORS headers:", 
      preflightResponse.headers.has('access-control-allow-origin') && 
      preflightResponse.headers.has('access-control-allow-methods'));
    
    // Check if the current URL is HTTPS but trying to access HTTP
    if (window.location.protocol === 'https:' && !simpleResponse.ok) {
      console.warn("\nWarning: You're on an HTTPS page trying to access an HTTP API.");
      console.warn("This is likely being blocked by your browser's mixed content security policy.");
      console.warn("Solutions:");
      console.warn("1. Load your test page over HTTP instead of HTTPS");
      console.warn("2. Set up HTTPS for your API server");
      console.warn("3. Add a reverse proxy with HTTPS termination");
    }
    
  } catch (error) {
    console.error("CORS Test Failed:", error);
    
    if (window.location.protocol === 'https:') {
      console.warn("\nWarning: You're on an HTTPS page trying to access an HTTP API.");
      console.warn("This is likely being blocked by your browser's mixed content security policy.");
      console.warn("Solutions:");
      console.warn("1. Load your test page over HTTP instead of HTTPS");
      console.warn("2. Set up HTTPS for your API server");
      console.warn("3. Add a reverse proxy with HTTPS termination");
    }
  }
}

// Call the test function
testCORS();

// Additional server-side CORS configuration (for your API server)
/*
For Express.js:
--------------
const cors = require('cors');

// Option 1: Enable CORS for all origins
app.use(cors());

// Option 2: Configure specific CORS options
app.use(cors({
  origin: '*', // or specify allowed origins like 'http://yourtestsite.com'
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true
}));

For Node.js (without Express):
-----------------------------
// Add these headers to all responses
response.setHeader('Access-Control-Allow-Origin', '*');
response.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, DELETE');
response.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
response.setHeader('Access-Control-Allow-Credentials', 'true');

// Handle OPTIONS requests for preflight
if (request.method === 'OPTIONS') {
  response.writeHead(204);
  response.end();
  return;
}
*/
