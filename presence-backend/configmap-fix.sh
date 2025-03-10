#!/bin/bash
# Fix for audio detection app using ConfigMap instead of direct file modification

# Define target
DEPLOYMENT_NAME="audio-detection-app"
echo "Targeting deployment: $DEPLOYMENT_NAME"

# Create a temporary directory for our files
TEMP_DIR="./audio-fix-files"
mkdir -p $TEMP_DIR
echo "Created temporary directory: $TEMP_DIR"

# Create a simple canvas test file
echo "Creating canvas test file..."
cat > $TEMP_DIR/canvas-test.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Canvas Test</title>
    <style>
        body { font-family: Arial; margin: 20px; }
        canvas { border: 1px solid red; margin: 10px 0; display: block; width: 100%; height: 100px; }
        button { padding: 10px; background: #4CAF50; color: white; border: none; border-radius: 4px; margin: 5px; }
    </style>
</head>
<body>
    <h1>Canvas Test</h1>
    <div id="debug" style="background:#f5f5f5; padding:10px; margin-bottom:20px; font-family:monospace;"></div>
    
    <canvas id="testCanvas"></canvas>
    
    <div>
        <button onclick="testCanvas()">Test Canvas</button>
        <button onclick="clearDebug()">Clear Debug Log</button>
    </div>
    
    <script>
        function log(msg) {
            console.log(msg);
            document.getElementById("debug").innerHTML += msg + "<br>";
        }
        
        function clearDebug() {
            document.getElementById("debug").innerHTML = "";
        }
        
        function testCanvas() {
            const canvas = document.getElementById("testCanvas");
            
            try {
                // Log initial state
                log("Initial canvas size: " + canvas.width + "x" + canvas.height);
                log("Canvas client size: " + canvas.clientWidth + "x" + canvas.clientHeight);
                
                // Set canvas size to match display size
                canvas.width = canvas.clientWidth;
                canvas.height = canvas.clientHeight;
                
                log("Resized canvas to: " + canvas.width + "x" + canvas.height);
                
                // Get context and draw
                const ctx = canvas.getContext("2d");
                
                // Clear canvas
                ctx.fillStyle = "#222";
                ctx.fillRect(0, 0, canvas.width, canvas.height);
                
                // Draw gradient
                const gradient = ctx.createLinearGradient(0, 0, canvas.width, 0);
                gradient.addColorStop(0, "red");
                gradient.addColorStop(0.5, "green");
                gradient.addColorStop(1, "blue");
                
                ctx.fillStyle = gradient;
                ctx.fillRect(20, 20, canvas.width - 40, canvas.height - 40);
                
                // Draw text
                ctx.fillStyle = "white";
                ctx.font = "20px Arial";
                ctx.textAlign = "center";
                ctx.fillText("Canvas is working!", canvas.width/2, canvas.height/2);
                
                log("Canvas rendering successful");
            } catch (error) {
                log("Error: " + error.message);
            }
        }
        
        // Initial test with slight delay
        window.onload = function() {
            log("Page loaded");
            setTimeout(testCanvas, 100);
        };
    </script>
</body>
</html>
EOF

# Create a canvas initialization script
echo "Creating canvas initialization script..."
cat > $TEMP_DIR/fix.js << 'EOF'
// Canvas initialization fix
document.addEventListener("DOMContentLoaded", function() {
    console.log("Canvas fix script loaded");
    
    // Function to fix a canvas
    function fixCanvas(canvasId) {
        const canvas = document.getElementById(canvasId);
        if (!canvas) {
            console.warn("Canvas not found:", canvasId);
            return false;
        }
        
        try {
            console.log(canvasId + " before fix:", canvas.width, "x", canvas.height);
            
            // Set canvas dimensions to match display size
            canvas.width = canvas.clientWidth || 400;
            canvas.height = canvas.clientHeight || 100;
            
            console.log(canvasId + " after fix:", canvas.width, "x", canvas.height);
            
            // Test draw to confirm it works
            const ctx = canvas.getContext("2d");
            ctx.fillStyle = canvasId === "audioVisualizer" ? "#000" : "#222";
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            
            return true;
        } catch (e) {
            console.error("Error fixing " + canvasId + ":", e);
            return false;
        }
    }
    
    // Fix both canvases
    setTimeout(function() {
        fixCanvas("debugVisualizer");
        fixCanvas("audioVisualizer");
        console.log("Canvas fix complete");
    }, 100);
});
EOF

# Create a modified version of index.html with the fix script included
echo "Creating fixed index.html..."
cat > $TEMP_DIR/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Audio Event Detection Demo - FIXED</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            line-height: 1.6;
        }
        
        h1 {
            color: #333;
            border-bottom: 2px solid #4CAF50;
            padding-bottom: 10px;
        }

        .description {
            background-color: #f5f5f5;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        
        .controls {
            margin: 20px 0;
            display: flex;
            gap: 10px;
        }
        
        button {
            padding: 10px 15px;
            background-color: #4CAF50;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            transition: background-color 0.3s;
        }
        
        button:hover {
            background-color: #45a049;
        }

        button:disabled {
            background-color: #cccccc;
            cursor: not-allowed;
        }
        
        #status {
            margin: 15px 0;
            padding: 10px;
            background-color: #e7f3fe;
            border-left: 4px solid #2196F3;
        }
        
        #eventLog {
            height: 300px;
            overflow-y: auto;
            border: 1px solid #ddd;
            border-radius: 4px;
            padding: 10px;
            margin-top: 20px;
            background-color: #fafafa;
        }
        
        .event-item {
            padding: 10px;
            margin-bottom: 8px;
            border-left: 4px solid #4CAF50;
            background-color: #f9f9f9;
            border-radius: 2px;
        }

        .event-item.doorbell {
            border-left-color: #2196F3;
        }

        .event-item.knocking {
            border-left-color: #FF9800;
        }

        .confidence-bar {
            height: 10px;
            background-color: #e0e0e0;
            border-radius: 5px;
            margin-top: 5px;
            overflow: hidden;
        }

        .confidence-level {
            height: 100%;
            background-color: #4CAF50;
        }

        .visualizer-container {
            margin: 20px 0;
            border: 1px solid #ddd;
            border-radius: 4px;
            padding: 10px;
            background-color: #fafafa;
        }

        #audioVisualizer {
            width: 100%;
            height: 100px;
            background-color: #000;
            border-radius: 4px;
            display: block; /* Important for proper sizing */
        }
        
        #debugVisualizer {
            width: 100%;
            height: 100px;
            background-color: #222;
            border-radius: 4px;
            display: block; /* Important for proper sizing */
        }

        .settings {
            margin-top: 20px;
            padding: 15px;
            border: 1px solid #ddd;
            border-radius: 4px;
            background-color: #fafafa;
        }

        .settings h2 {
            margin-top: 0;
            font-size: 1.2em;
        }

        .setting-item {
            margin-bottom: 10px;
        }

        .setting-item label {
            display: block;
            margin-bottom: 5px;
        }

        .setting-item input {
            width: 100%;
            padding: 8px;
            border: 1px solid #ddd;
            border-radius: 4px;
        }
    </style>
</head>
<body>
    <h1>Audio Event Detection Demo - FIXED</h1>
    <div class="visualizer-container">
       <h2>Debug Visualizer</h2>
      <canvas id="debugVisualizer" width="400" height="100"></canvas>
    </div>
    
    <div class="description">
        <p>This demo uses your device's microphone to detect specific audio events like doorbells and knocking sounds. 
           Click "Start Detection" to begin, and the system will automatically identify and log detected sounds.</p>
    </div>

    <div class="controls">
        <button id="startDetection">Start Detection</button>
        <button id="stopDetection" disabled>Stop Detection</button>
        <button id="clearLog">Clear Log</button>
        <button id="testVisualizersBtn">Test Visualizers</button>
    </div>
    
    <div id="status">Status: Ready</div>
    
    <div class="visualizer-container">
        <h2>Audio Visualizer</h2>
        <canvas id="audioVisualizer" width="400" height="100"></canvas>
    </div>

    <h2>Event Log</h2>
    <div id="eventLog">
        <div class="event-item">Waiting for events...</div>
    </div>
    
    <div class="settings">
        <h2>Settings</h2>
        <div class="setting-item">
            <label for="energyThreshold">Energy Threshold (0-1)</label>
            <input type="range" id="energyThreshold" min="0.05" max="0.5" step="0.01" value="0.15">
            <span id="energyThresholdValue">0.15</span>
        </div>
        <div class="setting-item">
            <label for="eventThreshold">Event Confidence Threshold (0-1)</label>
            <input type="range" id="eventThreshold" min="0.3" max="0.9" step="0.05" value="0.6">
            <span id="eventThresholdValue">0.6</span>
        </div>
        <div class="setting-item">
            <label for="minEventDuration">Minimum Event Duration (ms)</label>
            <input type="number" id="minEventDuration" min="100" max="1000" step="50" value="300">
        </div>
    </div>
    
    <!-- Add our canvas fix script before loading the main app scripts -->
    <script src="fix.js"></script>
    <script src="audio-event-detector.js"></script>
    <script>
        document.addEventListener('DOMContentLoaded', () => {
            let detector = null;
            const startButton = document.getElementById('startDetection');
            const stopButton = document.getElementById('stopDetection');
            const clearLogButton = document.getElementById('clearLog');
            const statusElement = document.getElementById('status');
            const eventLogElement = document.getElementById('eventLog');
            const visualizerCanvas = document.getElementById('audioVisualizer');
            const visualizerContext = visualizerCanvas.getContext('2d');
            const debugCanvas = document.getElementById('debugVisualizer');
            const debugContext = debugCanvas.getContext('2d');

            // Settings elements
            const energyThresholdInput = document.getElementById('energyThreshold');
            const eventThresholdInput = document.getElementById('eventThreshold');
            const minEventDurationInput = document.getElementById('minEventDuration');
            const energyThresholdValue = document.getElementById('energyThresholdValue');
            const eventThresholdValue = document.getElementById('eventThresholdValue');

            // Update settings display
            energyThresholdInput.addEventListener('input', () => {
                energyThresholdValue.textContent = energyThresholdInput.value;
            });

            eventThresholdInput.addEventListener('input', () => {
                eventThresholdValue.textContent = eventThresholdInput.value;
            });
            
            // Test visualizers
            document.getElementById('testVisualizersBtn').addEventListener('click', () => {
                console.log("Testing visualizers");
                
                // Test debug visualizer
                if (debugContext) {
                    // Clear
                    debugContext.fillStyle = '#222';
                    debugContext.fillRect(0, 0, debugCanvas.width, debugCanvas.height);
                    
                    // Draw a sine wave
                    debugContext.strokeStyle = '#4CAF50';
                    debugContext.lineWidth = 2;
                    debugContext.beginPath();
                    
                    for (let x = 0; x < debugCanvas.width; x++) {
                        const y = debugCanvas.height/2 + Math.sin(x/20) * 30;
                        
                        if (x === 0) {
                            debugContext.moveTo(x, y);
                        } else {
                            debugContext.lineTo(x, y);
                        }
                    }
                    
                    debugContext.stroke();
                }
                
                // Test audio visualizer
                if (visualizerContext) {
                    // Clear
                    visualizerContext.fillStyle = '#000';
                    visualizerContext.fillRect(0, 0, visualizerCanvas.width, visualizerCanvas.height);
                    
                    // Draw bars
                    const barWidth = visualizerCanvas.width / 32;
                    
                    for (let i = 0; i < 32; i++) {
                        const barHeight = visualizerCanvas.height * (0.2 + 0.6 * Math.sin(i/32 * Math.PI));
                        
                        // Create gradient
                        const gradient = visualizerContext.createLinearGradient(0, visualizerCanvas.height, 0, visualizerCanvas.height - barHeight);
                        gradient.addColorStop(0, '#4CAF50');
                        gradient.addColorStop(0.5, '#FFEB3B');
                        gradient.addColorStop(1, '#F44336');
                        
                        visualizerContext.fillStyle = gradient;
                        visualizerContext.fillRect(i * barWidth, visualizerCanvas.height - barHeight, barWidth - 1, barHeight);
                    }
                }
                
                statusElement.textContent = 'Status: Visualizer test complete';
            });

            // Initialize the detector
            startButton.addEventListener('click', async () => {
                // Get current settings
                const settings = {
                    energyThreshold: parseFloat(energyThresholdInput.value),
                    eventThreshold: parseFloat(eventThresholdInput.value),
                    minEventDuration: parseInt(minEventDurationInput.value),
                    debugVisualizer: true,  // Enable debug visualizer
                    onEvent: (detections, buffer) => {
                        // Remove "waiting" message if it's the first event
                        if (eventLogElement.firstChild.textContent === 'Waiting for events...') {
                            eventLogElement.innerHTML = '';
                        }
                        
                        // Add events to the log
                        detections.forEach(event => {
                            const eventItem = document.createElement('div');
                            eventItem.className = `event-item ${event.type.toLowerCase()}`;
                            
                            const confidencePercent = Math.round(event.confidence * 100);
                            
                            eventItem.innerHTML = `
                                <strong>${event.type}</strong><br>
                                Confidence: ${confidencePercent}%
                                <div class="confidence-bar">
                                    <div class="confidence-level" style="width: ${confidencePercent}%"></div>
                                </div>
                                Time: ${event.timestamp.toLocaleTimeString()}<br>
                                Duration: ${event.duration}ms
                            `;
                            
                            eventLogElement.insertBefore(eventItem, eventLogElement.firstChild);
                        });
                    }
                };

                // Create and initialize detector
                detector = new AudioEventDetector(settings);
                const initialized = await detector.initialize();
                
                if (!initialized) {
                    statusElement.textContent = 'Status: Failed to initialize (microphone access denied?)';
                    statusElement.style.borderLeftColor = '#F44336';
                    return;
                }
                
                // Add event detection models
                detector.addEventModel('doorbell', createDoorbellDetector());
                detector.addEventModel('knocking', createKnockingDetector());
                
                // Start detection
                detector.start();
                
                // Update UI
                statusElement.textContent = 'Status: Detecting audio events';
                statusElement.style.borderLeftColor = '#4CAF50';
                startButton.disabled = true;
                stopButton.disabled = false;
            });
            
            // Stop detection
            stopButton.addEventListener('click', () => {
                if (detector) {
                    detector.stop();
                    statusElement.textContent = 'Status: Detection stopped';
                    statusElement.style.borderLeftColor = '#FF9800';
                    startButton.disabled = false;
                    stopButton.disabled = true;
                }
            });
            
            // Clear log
            clearLogButton.addEventListener('click', () => {
                eventLogElement.innerHTML = '<div class="event-item">Waiting for events...</div>';
            });
        });
    </script>
</body>
</html>
EOF

# Create an index page for the tests
echo "Creating test index page..."
cat > $TEMP_DIR/test-index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Audio Detection Test Pages</title>
    <style>
        body { font-family: Arial; margin: 20px; max-width: 800px; margin: 0 auto; padding: 20px; }
        .test-card {
            border: 1px solid #ddd;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
            background: #f9f9f9;
        }
        h2 { margin-top: 0; color: #333; }
        a.button {
            display: inline-block;
            padding: 10px 15px;
            background: #4CAF50;
            color: white;
            text-decoration: none;
            border-radius: 4px;
            margin: 10px 0;
        }
    </style>
</head>
<body>
    <h1>Audio Detection Test Pages</h1>
    <p>Use these pages to test and troubleshoot canvas visualization issues.</p>
    
    <div class="test-card">
        <h2>1. Simple Canvas Test</h2>
        <p>A basic test to check if canvas rendering works in your browser.</p>
        <a href="canvas-test.html" class="button">Open Canvas Test</a>
    </div>
    
    <div class="test-card">
        <h2>2. Fixed Audio Detection App</h2>
        <p>The full application with canvas sizing fixes applied.</p>
        <a href="index.html" class="button">Open Fixed App</a>
    </div>
</body>
</html>
EOF

# Create a ConfigMap from these files
echo "Creating ConfigMap from files..."
kubectl delete configmap audio-detection-files 2>/dev/null || true
kubectl create configmap audio-detection-files \
  --from-file=$TEMP_DIR/canvas-test.html \
  --from-file=$TEMP_DIR/fix.js \
  --from-file=$TEMP_DIR/index.html \
  --from-file=$TEMP_DIR/test-index.html

# Update the deployment to use this ConfigMap
echo "Updating deployment to use ConfigMap..."
cat > deploy-patch.yaml << EOF
spec:
  template:
    spec:
      containers:
      - name: audio-detection
        volumeMounts:
        - name: app-files
          mountPath: /usr/share/nginx/html
      volumes:
      - name: app-files
        configMap:
          name: audio-detection-files
EOF

kubectl patch deployment $DEPLOYMENT_NAME --patch "$(cat deploy-patch.yaml)" --type=strategic

# Get the original audio-event-detector.js file
echo "Retrieving audio-event-detector.js..."
# This is tricky since we can't directly read from the pod. We'll need to create a temporary pod.
kubectl run temp-pod --image=busybox --restart=Never --rm -i -- sleep 5
kubectl cp audio-detection-app-86c7bfbcdf-jkwr7:/usr/share/nginx/html/audio-event-detector.js $TEMP_DIR/audio-event-detector.js 2>/dev/null || echo "Could not copy the JavaScript file, will need to be added manually"

# Add the audio-event-detector.js to the ConfigMap
if [ -f "$TEMP_DIR/audio-event-detector.js" ]; then
  echo "Adding audio-event-detector.js to ConfigMap..."
  kubectl create configmap audio-detector-js --from-file=$TEMP_DIR/audio-event-detector.js
  
  # Patch the deployment to include this file as well
  cat > js-patch.yaml << EOF
spec:
  template:
    spec:
      containers:
      - name: audio-detection
        volumeMounts:
        - name: js-file
          mountPath: /usr/share/nginx/html/audio-event-detector.js
          subPath: audio-event-detector.js
      volumes:
      - name: js-file
        configMap:
          name: audio-detector-js
EOF

  kubectl patch deployment $DEPLOYMENT_NAME --patch "$(cat js-patch.yaml)" --type=strategic
else
  echo "Warning: Could not retrieve audio-event-detector.js. You will need to add it to the ConfigMap manually."
fi

# Wait for the rollout to complete
echo "Waiting for deployment to roll out..."
kubectl rollout status deployment/$DEPLOYMENT_NAME

# Get pod info
POD_NAME=$(kubectl get pods -l app=audio-detection --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')

echo ""
echo "==================================================="
echo "Deployment updated successfully!"
echo "==================================================="
echo ""
echo "Access the test pages:"
echo "kubectl port-forward $POD_NAME 8080:80"
echo "Then open: http://localhost:8080/test-index.html"
echo ""
echo "==================================================="

# Clean up
rm -f deploy-patch.yaml js-patch.yaml
# Uncomment to remove temp files: rm -rf $TEMP_DIR
