#!/bin/bash
# Script to remove the debug visualizer from the audio detection app

# Use the specific pod
RUNNING_POD="audio-detection-app-86c7bfbcdf-jkwr7"
echo "Using pod: $RUNNING_POD"

# Get the current index.html from the container
echo "Retrieving current index.html..."
kubectl exec $RUNNING_POD -- cat /usr/share/nginx/html/index.html > current-index.html

# Create a modified version without the debug visualizer
echo "Creating modified index.html without debug visualizer..."
cat > modified-index.html << 'EOF'
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
    <script>
    // Canvas initialization script
    document.addEventListener('DOMContentLoaded', function() {
        // Wait for layout to complete
        setTimeout(function() {
            // Fix the audio visualizer
            var audioCanvas = document.getElementById('audioVisualizer');
            if (audioCanvas) {
                audioCanvas.width = audioCanvas.clientWidth;
                audioCanvas.height = audioCanvas.clientHeight;
                console.log('Audio visualizer sized to: ' + audioCanvas.width + '×' + audioCanvas.height);
            }
        }, 100);
    });
    </script>
</head>
<body>
    <h1>Audio Event Detection Demo</h1>
    
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
                
                // Test audio visualizer
                if (visualizerContext) {
                    // Clear
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

# Create ConfigMap with the modified HTML
echo "Creating ConfigMap with modified index.html..."
kubectl delete configmap modified-index-html 2>/dev/null || true
kubectl create configmap modified-index-html --from-file=index.html=modified-index.html

# Create a patch for the deployment
echo "Creating patch to mount the modified index.html..."
cat > deployment-patch.yaml << EOF
spec:
  template:
    spec:
      volumes:
      - name: modified-index
        configMap:
          name: modified-index-html
      containers:
      - name: audio-detection
        volumeMounts:
        - name: modified-index
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
EOF

# Apply the patch
echo "Applying patch to deployment..."
kubectl patch deployment audio-detection-app --patch "$(cat deployment-patch.yaml)" --type=strategic

# Wait for rollout
echo "Waiting for deployment rollout..."
kubectl rollout status deployment/audio-detection-app

# Get the new pod name
NEW_POD=$(kubectl get pods -l app=audio-detection --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')

echo ""
echo "====================================================="
echo "Debug visualizer has been removed!"
echo "====================================================="
echo ""
echo "Access your app after setting up port-forwarding:"
echo "kubectl port-forward $NEW_POD 8080:80"
echo ""
echo "Then visit: http://localhost:8080/"
echo ""
echo "Changes made:"
echo "- Removed the debug visualizer at the top"
echo "- Kept only the audio visualizer"
echo "- Added canvas sizing fix directly in the HTML"
echo "- Kept the test visualizer button"
echo "====================================================="

# Clean up
rm -f current-index.html modified-index.html deployment-patch.yaml
