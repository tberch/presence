#!/bin/bash
# Script to fix canvas initialization and sizing in the main audio detection app

# Find the pod name for the main audio detection app
AUDIO_POD=$(kubectl get pods -l app=audio-detection -o jsonpath='{.items[0].metadata.name}')
echo "Found audio detection pod: $AUDIO_POD"

# Step 1: Back up the original index.html
echo "Creating backup of original index.html..."
kubectl exec $AUDIO_POD -- cp /usr/share/nginx/html/index.html /usr/share/nginx/html/index.html.bak

# Step 2: Add resizing script to the HTML file
echo "Adding canvas initialization and resizing code to index.html..."
kubectl exec $AUDIO_POD -- sh -c "cat > /usr/share/nginx/html/canvas-init.js << EOF
/**
 * Canvas Initialization Script
 * This ensures proper sizing and rendering of canvas elements
 */
(function() {
    // Run when DOM is fully loaded
    document.addEventListener('DOMContentLoaded', function() {
        // Get canvas elements
        const debugCanvas = document.getElementById('debugVisualizer');
        const audioCanvas = document.getElementById('audioVisualizer');
        
        if (!debugCanvas || !audioCanvas) {
            console.warn('Canvas elements not found. Debug:', !!debugCanvas, 'Audio:', !!audioCanvas);
            return;
        }
        
        console.log('Initializing canvas elements...');
        
        // Function to resize canvases to match their display size
        function resizeCanvases() {
            if (debugCanvas) {
                debugCanvas.width = debugCanvas.clientWidth;
                debugCanvas.height = debugCanvas.clientHeight || 100;
                console.log('Debug canvas resized to:', debugCanvas.width, 'x', debugCanvas.height);
            }
            
            if (audioCanvas) {
                audioCanvas.width = audioCanvas.clientWidth;
                audioCanvas.height = audioCanvas.clientHeight || 100;
                console.log('Audio canvas resized to:', audioCanvas.width, 'x', audioCanvas.height);
            }
        }
        
        // Resize canvases initially
        resizeCanvases();
        
        // Resize canvases when window is resized
        window.addEventListener('resize', resizeCanvases);
        
        // Test draw to ensure canvases are working
        function testCanvases() {
            if (debugCanvas) {
                const ctx = debugCanvas.getContext('2d');
                ctx.fillStyle = '#222';
                ctx.fillRect(0, 0, debugCanvas.width, debugCanvas.height);
                
                // Draw a test line
                ctx.strokeStyle = '#4CAF50';
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.moveTo(0, debugCanvas.height / 2);
                ctx.lineTo(debugCanvas.width, debugCanvas.height / 2);
                ctx.stroke();
                
                console.log('Debug canvas rendered test pattern');
            }
            
            if (audioCanvas) {
                const ctx = audioCanvas.getContext('2d');
                ctx.fillStyle = '#000';
                ctx.fillRect(0, 0, audioCanvas.width, audioCanvas.height);
                
                // Draw test bars
                for (let i = 0; i < 10; i++) {
                    const barHeight = audioCanvas.height * (0.2 + 0.1 * i);
                    const x = i * (audioCanvas.width / 10);
                    const width = audioCanvas.width / 12;
                    
                    // Create gradient
                    const gradient = ctx.createLinearGradient(0, audioCanvas.height, 0, audioCanvas.height - barHeight);
                    gradient.addColorStop(0, '#4CAF50');
                    gradient.addColorStop(0.5, '#FFEB3B');
                    gradient.addColorStop(1, '#F44336');
                    
                    ctx.fillStyle = gradient;
                    ctx.fillRect(x, audioCanvas.height - barHeight, width, barHeight);
                }
                
                console.log('Audio canvas rendered test pattern');
            }
        }
        
        // Run test draw after a short delay to ensure everything is ready
        setTimeout(testCanvases, 500);
        
        console.log('Canvas initialization complete');
    });
})();
EOF"

# Step 3: Modify the index.html to include the new script and fix canvas attributes
echo "Updating index.html with proper canvas settings..."
kubectl exec $AUDIO_POD -- sh -c "cat > /usr/share/nginx/html/index.html << EOF
<!DOCTYPE html>
<html lang=\"en\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
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

        /* Canvas elements need a specific display property */
        #audioVisualizer, #debugVisualizer {
            width: 100%;
            height: 100px;
            background-color: #000;
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
    <h1>Audio Event Detection Demo</h1>
    <div class=\"visualizer-container\">
       <h2>Debug Visualizer</h2>
      <canvas id=\"debugVisualizer\" width=\"400\" height=\"100\"></canvas>
    </div>
    
    <div class=\"description\">
        <p>This demo uses your device's microphone to detect specific audio events like doorbells and knocking sounds. 
           Click \"Start Detection\" to begin, and the system will automatically identify and log detected sounds.</p>
    </div>

    <div class=\"controls\">
        <button id=\"startDetection\">Start Detection</button>
        <button id=\"stopDetection\" disabled>Stop Detection</button>
        <button id=\"clearLog\">Clear Log</button>
    </div>
    
    <div id=\"status\">Status: Ready</div>
    
    <div class=\"visualizer-container\">
        <h2>Audio Visualizer</h2>
        <canvas id=\"audioVisualizer\" width=\"400\" height=\"100\"></canvas>
    </div>

    <h2>Event Log</h2>
    <div id=\"eventLog\">
        <div class=\"event-item\">Waiting for events...</div>
    </div>
    
    <div class=\"settings\">
        <h2>Settings</h2>
        <div class=\"setting-item\">
            <label for=\"energyThreshold\">Energy Threshold (0-1)</label>
            <input type=\"range\" id=\"energyThreshold\" min=\"0.05\" max=\"0.5\" step=\"0.01\" value=\"0.15\">
            <span id=\"energyThresholdValue\">0.15</span>
        </div>
        <div class=\"setting-item\">
            <label for=\"eventThreshold\">Event Confidence Threshold (0-1)</label>
            <input type=\"range\" id=\"eventThreshold\" min=\"0.3\" max=\"0.9\" step=\"0.05\" value=\"0.6\">
            <span id=\"eventThresholdValue\">0.6</span>
        </div>
        <div class=\"setting-item\">
            <label for=\"minEventDuration\">Minimum Event Duration (ms)</label>
            <input type=\"number\" id=\"minEventDuration\" min=\"100\" max=\"1000\" step=\"50\" value=\"300\">
        </div>
    </div>
    
    <!-- Add canvas initialization script first -->
    <script src=\"canvas-init.js\"></script>
    <!-- Then load the main audio detection script -->
    <script src=\"audio-event-detector.js\"></script>
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
                            eventItem.className = \`event-item \${event.type.toLowerCase()}\`;
                            
                            const confidencePercent = Math.round(event.confidence * 100);
                            
                            eventItem.innerHTML = \`
                                <strong>\${event.type}</strong><br>
                                Confidence: \${confidencePercent}%
                                <div class="confidence-bar">
                                    <div class="confidence-level" style="width: \${confidencePercent}%"></div>
                                </div>
                                Time: \${event.timestamp.toLocaleTimeString()}<br>
                                Duration: \${event.duration}ms
                            \`;
                            
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
EOF"

# Step 4: Verify the changes
echo "Verifying changes to index.html and canvas-init.js..."
echo "Files in /usr/share/nginx/html:"
kubectl exec $AUDIO_POD -- ls -la /usr/share/nginx/html

echo "Canvas initialization script created successfully!"
echo "Canvas elements now have proper initialization and resizing."
echo ""
echo "To test, access your app at: http://localhost:8080"
echo "If you encounter any issues, the original HTML is backed up at: index.html.bak"
