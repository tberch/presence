// Audio Event Detector Test Script
// This script tests all components of the audio event detector using HTTP

const API_BASE_URL = 'http://api.talkstudio.space';

// Helper function for making API requests
async function makeRequest(endpoint, method = 'GET', data = null) {
  const options = {
    method,
    headers: {
      'Content-Type': 'application/json',
    },
  };
  
  if (data) {
    options.body = JSON.stringify(data);
  }
  
  try {
    const response = await fetch(`${API_BASE_URL}${endpoint}`, options);
    const responseData = await response.json();
    return { success: response.ok, status: response.status, data: responseData };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

// Test connection to API
async function testApiConnection() {
  console.log('Testing API connection...');
  try {
    const response = await fetch(`${API_BASE_URL}/health`);
    if (response.ok) {
      console.log('✅ API connection successful');
      return true;
    } else {
      console.error(`❌ API connection failed with status: ${response.status}`);
      return false;
    }
  } catch (error) {
    console.error('❌ API connection failed:', error.message);
    return false;
  }
}

// Test audio upload functionality
async function testAudioUpload() {
  console.log('\nTesting audio upload...');
  
  // Create a test audio blob (this simulates an audio file)
  const testAudioBlob = new Blob([new Uint8Array(100)], { type: 'audio/wav' });
  
  const formData = new FormData();
  formData.append('audio', testAudioBlob, 'test-audio.wav');
  
  try {
    const response = await fetch(`${API_BASE_URL}/upload`, {
      method: 'POST',
      body: formData,
    });
    
    const result = await response.json();
    
    if (response.ok) {
      console.log('✅ Audio upload successful');
      console.log(`   File ID: ${result.fileId}`);
      return result.fileId;
    } else {
      console.error(`❌ Audio upload failed with status: ${response.status}`);
      console.error('   Error:', result.error || 'Unknown error');
      return null;
    }
  } catch (error) {
    console.error('❌ Audio upload failed:', error.message);
    return null;
  }
}

// Test audio event detection
async function testEventDetection(fileId) {
  console.log('\nTesting audio event detection...');
  
  if (!fileId) {
    console.error('❌ Cannot test event detection: No file ID provided');
    return null;
  }
  
  const detectionParams = {
    fileId,
    sensitivity: 0.5,
    minEventDuration: 0.2,
    maxSilenceDuration: 0.5
  };
  
  try {
    const result = await makeRequest('/detect-events', 'POST', detectionParams);
    
    if (result.success) {
      console.log('✅ Event detection successful');
      console.log(`   Detected ${result.data.events.length} events`);
      return result.data.jobId;
    } else {
      console.error(`❌ Event detection failed with status: ${result.status}`);
      console.error('   Error:', result.data?.error || 'Unknown error');
      return null;
    }
  } catch (error) {
    console.error('❌ Event detection failed:', error.message);
    return null;
  }
}

// Test event processing status
async function testEventProcessingStatus(jobId) {
  console.log('\nTesting event processing status...');
  
  if (!jobId) {
    console.error('❌ Cannot test processing status: No job ID provided');
    return false;
  }
  
  try {
    let completed = false;
    let attempts = 0;
    const maxAttempts = 10;
    
    while (!completed && attempts < maxAttempts) {
      attempts++;
      console.log(`   Checking status (attempt ${attempts}/${maxAttempts})...`);
      
      const result = await makeRequest(`/job-status/${jobId}`);
      
      if (result.success) {
        console.log(`   Status: ${result.data.status}`);
        
        if (result.data.status === 'completed') {
          console.log('✅ Event processing completed successfully');
          return true;
        } else if (result.data.status === 'failed') {
          console.error('❌ Event processing failed');
          console.error('   Error:', result.data?.error || 'Unknown error');
          return false;
        }
        
        // Wait 2 seconds before checking again
        await new Promise(resolve => setTimeout(resolve, 2000));
      } else {
        console.error(`❌ Status check failed with status: ${result.status}`);
        console.error('   Error:', result.data?.error || 'Unknown error');
        return false;
      }
    }
    
    if (attempts >= maxAttempts) {
      console.error('❌ Event processing timed out');
      return false;
    }
    
    return true;
  } catch (error) {
    console.error('❌ Status check failed:', error.message);
    return false;
  }
}

// Test retrieving event results
async function testEventResults(jobId) {
  console.log('\nTesting event results retrieval...');
  
  if (!jobId) {
    console.error('❌ Cannot test results retrieval: No job ID provided');
    return null;
  }
  
  try {
    const result = await makeRequest(`/events/${jobId}`);
    
    if (result.success) {
      console.log('✅ Event results retrieved successfully');
      console.log('   Events:');
      
      if (result.data.events && result.data.events.length > 0) {
        result.data.events.forEach((event, index) => {
          console.log(`   Event ${index + 1}: Start: ${event.startTime}s, End: ${event.endTime}s, Type: ${event.type}`);
        });
      } else {
        console.log('   No events detected');
      }
      
      return result.data.events;
    } else {
      console.error(`❌ Results retrieval failed with status: ${result.status}`);
      console.error('   Error:', result.data?.error || 'Unknown error');
      return null;
    }
  } catch (error) {
    console.error('❌ Results retrieval failed:', error.message);
    return null;
  }
}

// Test WebSocket connection for real-time detection
async function testWebSocket() {
  console.log('\nTesting WebSocket connection for real-time detection...');
  
  return new Promise((resolve) => {
    try {
      const ws = new WebSocket(`ws://api.talkstudio.space/realtime-detection`);
      
      ws.onopen = () => {
        console.log('✅ WebSocket connection established');
        
        // Send a test message
        ws.send(JSON.stringify({ type: 'ping' }));
        
        // Wait for a short period to receive any response
        setTimeout(() => {
          ws.close();
          resolve(true);
        }, 1000);
      };
      
      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          console.log(`   Received WebSocket message: ${JSON.stringify(data)}`);
        } catch (e) {
          console.log(`   Received WebSocket message: ${event.data}`);
        }
      };
      
      ws.onerror = (error) => {
        console.error('❌ WebSocket error:', error);
        resolve(false);
      };
      
      ws.onclose = (event) => {
        console.log(`   WebSocket connection closed with code ${event.code}`);
      };
      
      // Set a timeout in case the connection hangs
      setTimeout(() => {
        if (ws.readyState !== WebSocket.OPEN) {
          console.error('❌ WebSocket connection timed out');
          resolve(false);
        }
      }, 5000);
    } catch (error) {
      console.error('❌ WebSocket connection failed:', error.message);
      resolve(false);
    }
  });
}

// Test configuration endpoint
async function testConfiguration() {
  console.log('\nTesting configuration endpoint...');
  
  try {
    const result = await makeRequest('/config');
    
    if (result.success) {
      console.log('✅ Configuration retrieval successful');
      console.log('   Configuration:', result.data);
      return result.data;
    } else {
      console.error(`❌ Configuration retrieval failed with status: ${result.status}`);
      console.error('   Error:', result.data?.error || 'Unknown error');
      return null;
    }
  } catch (error) {
    console.error('❌ Configuration retrieval failed:', error.message);
    return null;
  }
}

// Run all tests
async function runAllTests() {
  console.log('==== AUDIO EVENT DETECTOR TEST SUITE ====');
  console.log(`Testing against: ${API_BASE_URL}`);
  console.log('========================================\n');
  
  const apiConnected = await testApiConnection();
  
  if (!apiConnected) {
    console.error('\n❌ API connection failed. Aborting remaining tests.');
    return;
  }
  
  const config = await testConfiguration();
  const fileId = await testAudioUpload();
  const jobId = fileId ? await testEventDetection(fileId) : null;
  
  if (jobId) {
    const processingSuccessful = await testEventProcessingStatus(jobId);
    
    if (processingSuccessful) {
      await testEventResults(jobId);
    }
  }
  
  await testWebSocket();
  
  console.log('\n==== TEST SUMMARY ====');
  console.log('API Connection:', apiConnected ? '✅ PASS' : '❌ FAIL');
  console.log('Configuration:', config ? '✅ PASS' : '❌ FAIL');
  console.log('Audio Upload:', fileId ? '✅ PASS' : '❌ FAIL');
  console.log('Event Detection:', jobId ? '✅ PASS' : '❌ FAIL');
  console.log('WebSocket:', '(see detailed results above)');
  console.log('====================');
}

// Execute tests
runAllTests().catch(error => {
  console.error('Test execution failed:', error);
});
