#!/bin/bash
# Direct script using the known running pod

# IMPORTANT: Hard-coded to use the running pod we found
RUNNING_POD="audio-detection-app-86c7bfbcdf-jkwr7"
echo "Using specific running pod: $RUNNING_POD"

# Create a ConfigMap with the canvas test page
echo "Creating canvas test page ConfigMap..."
cat << 'EOF' > canvas-test.html
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

echo "Creating canvas test ConfigMap..."
kubectl delete configmap canvas-test-page 2>/dev/null || true
kubectl create configmap canvas-test-page --from-file=canvas-test.html

# Create a config map with the init fix script
echo "Creating canvas init fix script..."
cat << 'EOF' > canvas-init.js
// Canvas initialization script for Audio Event Detector
console.log("Canvas initialization script loaded");

document.addEventListener("DOMContentLoaded", function() {
    console.log("DOM loaded, initializing canvases");
    
    // Function to fix canvas dimensions
    function fixCanvas(id) {
        const canvas = document.getElementById(id);
        if (!canvas) {
            console.warn("Canvas not found:", id);
            return false;
        }
        
        console.log(`Canvas ${id} before: width=${canvas.width}, height=${canvas.height}`);
        
        // Set dimensions based on displayed size
        canvas.width = canvas.clientWidth || 400;
        canvas.height = canvas.clientHeight || 100;
        
        console.log(`Canvas ${id} after: width=${canvas.width}, height=${canvas.height}`);
        
        // Test with a simple drawing
        try {
            const ctx = canvas.getContext('2d');
            ctx.fillStyle = id === 'audioVisualizer' ? '#000' : '#222';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            return true;
        } catch (e) {
            console.error(`Error initializing ${id}:`, e);
            return false;
        }
    }
    
    // Wait a moment for layout to stabilize, then fix canvases
    setTimeout(function() {
        const debugFixed = fixCanvas('debugVisualizer');
        const audioFixed = fixCanvas('audioVisualizer');
        console.log(`Canvas initialization complete. Debug: ${debugFixed}, Audio: ${audioFixed}`);
    }, 100);
});
EOF

echo "Creating canvas init script ConfigMap..."
kubectl delete configmap canvas-init-script 2>/dev/null || true  
kubectl create configmap canvas-init-script --from-file=canvas-init.js

# Create a job to apply these to the running pod
echo "Creating job to deploy files to the pod..."
cat << EOF > apply-fix-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: apply-canvas-fix
spec:
  ttlSecondsAfterFinished: 100
  template:
    spec:
      containers:
      - name: kubectl
        image: bitnami/kubectl
        command:
        - /bin/bash
        - -c
        - |
          # Create test page
          kubectl cp /canvas-test.html $RUNNING_POD:/tmp/canvas-test.html
          kubectl exec $RUNNING_POD -- cp /tmp/canvas-test.html /usr/share/nginx/html/canvas-test.html
          
          # Create init script
          kubectl cp /canvas-init.js $RUNNING_POD:/tmp/canvas-init.js
          kubectl exec $RUNNING_POD -- cp /tmp/canvas-init.js /usr/share/nginx/html/canvas-init.js
          
          # List files to verify
          kubectl exec $RUNNING_POD -- ls -la /usr/share/nginx/html/
          
          echo "Files deployed successfully!"
        volumeMounts:
        - name: canvas-test
          mountPath: /canvas-test.html
          subPath: canvas-test.html
        - name: canvas-init
          mountPath: /canvas-init.js
          subPath: canvas-init.js
      volumes:
      - name: canvas-test
        configMap:
          name: canvas-test-page
      - name: canvas-init
        configMap:
          name: canvas-init-script
      restartPolicy: Never
  backoffLimit: 1
EOF

echo "Creating a modified index.html that includes the fix script..."
cat << 'EOF' > modified-index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Audio Event Detection Demo</title>
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
            display: block;
        }
        
        #debugVisualizer {
            width: 100%;
            height: 100px;
            background-color: #222;
            border-radius: 4px;
            display: block;
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
    <h1>Audio Event Detection Demo</h1>
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
    
    <!-- Include canvas initialization script before the main app script -->
    <script src="canvas-init.js"></script>
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
            
            // Test visualizers button
            document.getElementById('testVisualizersBtn').addEventListener('click', () => {
                console.log("Testing visualizers");
                
                // Test debug visualizer
                if (debugContext) {
                    // Clear canvas
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
                    // Clear canvas
                    visualizerContext.fillStyle = '#000';
                    visualizerContext.fillRect(0, 0, visualizerCanvas.width, visualizerCanvas.height);
                    
                    // Draw bars
                    const barCount = 32;
                    const barWidth = visualizerCanvas.width / barCount;
                    
                    for (let i = 0; i < barCount; i++) {
                        const barHeight = visualizerCanvas.height * (0.2 + 0.6 * Math.sin(i/barCount * Math.PI));
                        
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

kubectl delete configmap modified-index 2>/dev/null || true
kubectl create configmap modified-index --from-file=index.html=modified-index.html

# Update the job to include the index.html update
cat << EOF >> apply-fix-job.yaml
          # Update index.html with the fixed version
          kubectl cp /index.html $RUNNING_POD:/tmp/index.html
          kubectl exec $RUNNING_POD -- cp /tmp/index.html /usr/share/nginx/html/index-fixed.html
EOF

echo "Applying job to deploy files..."
kubectl apply -f apply-fix-job.yaml

# Wait for job to complete
echo "Waiting for job to complete..."
kubectl wait --for=condition=complete job/apply-canvas-fix --timeout=30s

# Check job logs
echo "Job logs:"
kubectl logs job/apply-canvas-fix

echo ""
echo "======================================================"
echo "Canvas visualizer fix files have been deployed!"
echo "======================================================"
echo ""
echo "Now you can access the test pages:"
echo ""
echo "1. Set up port forwarding to the RUNNING pod:"
echo "   kubectl port-forward $RUNNING_POD 8080:80"
echo ""
echo "2. Access the test page in your browser:"
echo "   http://localhost:8080/canvas-test.html"
echo ""
echo "3. Try the fixed application:"
echo "   http://localhost:8080/index-fixed.html"
echo ""
echo "If the test page and fixed app work well, you can make the fix permanent"
echo "by updating your deployment to use the modified version."
echo "======================================================"

# Clean up
rm -f canvas-test.html canvas-init.js modified-index.html apply-fix-job.yaml
