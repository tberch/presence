#!/bin/bash
# Simple direct fix for audio detection canvas issues

# Target the running pod instead of the crashing one
RUNNING_POD=$(kubectl get pods -l app=audio-detection --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
echo "Using running pod: $RUNNING_POD"

# Create a simple test page directly in the running container
echo "Creating a simple test visualization page..."
kubectl exec $RUNNING_POD -- sh -c 'cat > /usr/share/nginx/html/visualizer-test.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Visualizer Test</title>
    <style>
        body { font-family: Arial; margin: 20px; max-width: 800px; margin: 0 auto; padding: 20px; }
        .visualizer-container { border: 1px solid #ddd; padding: 15px; margin-bottom: 20px; background: #f5f5f5; }
        canvas { width: 100%; height: 120px; background: #222; border: 1px solid red; display: block; }
        button { padding: 10px 15px; background: #4CAF50; color: white; border: none; border-radius: 4px; 
                cursor: pointer; margin-right: 10px; margin-bottom: 10px; }
        #log { font-family: monospace; background: #f0f0f0; border: 1px solid #ddd; padding: 10px; 
              height: 150px; overflow: auto; margin-bottom: 20px; white-space: pre-wrap; }
    </style>
</head>
<body>
    <h1>Canvas Visualizer Test</h1>
    
    <div id="log">Debug log will appear here...</div>
    
    <div class="visualizer-container">
        <h2>Debug Visualizer</h2>
        <canvas id="debugVisualizer"></canvas>
    </div>
    
    <div class="visualizer-container">
        <h2>Audio Visualizer</h2>
        <canvas id="audioVisualizer"></canvas>
    </div>
    
    <div>
        <button id="testCanvases">Test Canvas Rendering</button>
        <button id="startAnimation">Start Animation</button>
        <button id="stopAnimation">Stop Animation</button>
        <button id="clearLog">Clear Log</button>
    </div>
    
    <script>
        // Debug logger
        const logElement = document.getElementById("log");
        function log(message) {
            const time = new Date().toLocaleTimeString();
            logElement.textContent += \`[\${time}] \${message}\n\`;
            logElement.scrollTop = logElement.scrollHeight;
            console.log(message);
        }
        
        // Get canvas elements
        const debugCanvas = document.getElementById("debugVisualizer");
        const audioCanvas = document.getElementById("audioVisualizer");
        let debugCtx, audioCtx;
        let animating = false;
        let animationFrame;
        
        // Initialize canvases
        function initCanvases() {
            log("Initializing canvases");
            
            // Debug canvas
            try {
                debugCanvas.width = debugCanvas.clientWidth;
                debugCanvas.height = debugCanvas.clientHeight;
                log(\`Debug canvas size: \${debugCanvas.width}×\${debugCanvas.height}\`);
                
                debugCtx = debugCanvas.getContext("2d");
                log("Got debug canvas context");
            } catch (error) {
                log(\`Error initializing debug canvas: \${error.message}\`);
            }
            
            // Audio canvas
            try {
                audioCanvas.width = audioCanvas.clientWidth;
                audioCanvas.height = audioCanvas.clientHeight;
                log(\`Audio canvas size: \${audioCanvas.width}×\${audioCanvas.height}\`);
                
                audioCtx = audioCanvas.getContext("2d");
                log("Got audio canvas context");
            } catch (error) {
                log(\`Error initializing audio canvas: \${error.message}\`);
            }
        }
        
        // Draw test patterns
        function drawTestPatterns() {
            log("Drawing test patterns");
            
            // Draw on debug canvas
            try {
                debugCtx.fillStyle = "#222";
                debugCtx.fillRect(0, 0, debugCanvas.width, debugCanvas.height);
                
                // Draw sine wave
                debugCtx.strokeStyle = "#4CAF50";
                debugCtx.lineWidth = 2;
                debugCtx.beginPath();
                
                for (let x = 0; x < debugCanvas.width; x++) {
                    const y = debugCanvas.height/2 + Math.sin(x/20) * 30;
                    
                    if (x === 0) {
                        debugCtx.moveTo(x, y);
                    } else {
                        debugCtx.lineTo(x, y);
                    }
                }
                
                debugCtx.stroke();
                
                // Draw threshold line
                debugCtx.strokeStyle = "#FF9800";
                debugCtx.beginPath();
                debugCtx.moveTo(0, debugCanvas.height * 0.7);
                debugCtx.lineTo(debugCanvas.width, debugCanvas.height * 0.7);
                debugCtx.stroke();
                
                // Add text
                debugCtx.fillStyle = "#FFF";
                debugCtx.font = "12px Arial";
                debugCtx.fillText("Energy: 0.42", 10, 15);
                
                log("Debug canvas rendered successfully");
            } catch (error) {
                log(\`Error drawing on debug canvas: \${error.message}\`);
            }
            
            // Draw on audio canvas
            try {
                audioCtx.fillStyle = "#000";
                audioCtx.fillRect(0, 0, audioCanvas.width, audioCanvas.height);
                
                // Draw frequency bars
                const barCount = 32;
                const barWidth = audioCanvas.width / barCount;
                
                for (let i = 0; i < barCount; i++) {
                    const barHeight = (0.1 + 0.7 * Math.sin(i/barCount * Math.PI)) * audioCanvas.height;
                    
                    // Create gradient
                    const gradient = audioCtx.createLinearGradient(0, audioCanvas.height, 0, audioCanvas.height - barHeight);
                    gradient.addColorStop(0, "#4CAF50");
                    gradient.addColorStop(0.5, "#FFEB3B");
                    gradient.addColorStop(1, "#F44336");
                    
                    audioCtx.fillStyle = gradient;
                    audioCtx.fillRect(i * barWidth, audioCanvas.height - barHeight, barWidth - 1, barHeight);
                }
                
                log("Audio canvas rendered successfully");
            } catch (error) {
                log(\`Error drawing on audio canvas: \${error.message}\`);
            }
        }
        
        // Animate canvases
        function animate() {
            if (!animating) return;
            
            const time = performance.now() / 1000;
            
            // Animate debug canvas
            try {
                debugCtx.fillStyle = "#222";
                debugCtx.fillRect(0, 0, debugCanvas.width, debugCanvas.height);
                
                // Draw moving sine wave
                debugCtx.strokeStyle = "#4CAF50";
                debugCtx.lineWidth = 2;
                debugCtx.beginPath();
                
                for (let x = 0; x < debugCanvas.width; x++) {
                    const y = debugCanvas.height/2 + Math.sin(x/20 + time) * 30;
                    
                    if (x === 0) {
                        debugCtx.moveTo(x, y);
                    } else {
                        debugCtx.lineTo(x, y);
                    }
                }
                
                debugCtx.stroke();
                
                // Draw threshold line
                debugCtx.strokeStyle = "#FF9800";
                debugCtx.beginPath();
                debugCtx.moveTo(0, debugCanvas.height * 0.7);
                debugCtx.lineTo(debugCanvas.width, debugCanvas.height * 0.7);
                debugCtx.stroke();
                
                // Update text
                debugCtx.fillStyle = "#FFF";
                debugCtx.font = "12px Arial";
                debugCtx.fillText(\`Energy: \${(0.3 + 0.2 * Math.sin(time)).toFixed(2)}\`, 10, 15);
            } catch (error) {
                log(\`Animation error (debug): \${error.message}\`);
            }
            
            // Animate audio canvas
            try {
                audioCtx.fillStyle = "#000";
                audioCtx.fillRect(0, 0, audioCanvas.width, audioCanvas.height);
                
                // Draw frequency bars
                const barCount = 32;
                const barWidth = audioCanvas.width / barCount;
                
                for (let i = 0; i < barCount; i++) {
                    const barHeight = (0.1 + 0.7 * Math.sin(i/barCount * Math.PI + time)) * audioCanvas.height;
                    
                    // Create gradient
                    const gradient = audioCtx.createLinearGradient(0, audioCanvas.height, 0, audioCanvas.height - barHeight);
                    gradient.addColorStop(0, "#4CAF50");
                    gradient.addColorStop(0.5, "#FFEB3B");
                    gradient.addColorStop(1, "#F44336");
                    
                    audioCtx.fillStyle = gradient;
                    audioCtx.fillRect(i * barWidth, audioCanvas.height - barHeight, barWidth - 1, barHeight);
                }
            } catch (error) {
                log(\`Animation error (audio): \${error.message}\`);
            }
            
            animationFrame = requestAnimationFrame(animate);
        }
        
        // Start animation
        function startAnimation() {
            if (!animating) {
                animating = true;
                animate();
                log("Animation started");
            }
        }
        
        // Stop animation
        function stopAnimation() {
            animating = false;
            if (animationFrame) {
                cancelAnimationFrame(animationFrame);
                animationFrame = null;
            }
            log("Animation stopped");
        }
        
        // Set up button event listeners
        document.getElementById("testCanvases").addEventListener("click", () => {
            log("Running canvas test");
            drawTestPatterns();
        });
        
        document.getElementById("startAnimation").addEventListener("click", () => {
            startAnimation();
        });
        
        document.getElementById("stopAnimation").addEventListener("click", () => {
            stopAnimation();
        });
        
        document.getElementById("clearLog").addEventListener("click", () => {
            logElement.textContent = "";
            log("Log cleared");
        });
        
        // Initialize on page load
        window.addEventListener("DOMContentLoaded", () => {
            log("Page loaded");
            
            // Initialize canvases with a slight delay
            setTimeout(() => {
                initCanvases();
                drawTestPatterns();
            }, 100);
        });
    </script>
</body>
</html>
EOF'

# Create a direct fix for the audio-event-detector.js
echo "Creating a direct patch for audio-event-detector.js..."
kubectl exec $RUNNING_POD -- sh -c 'cat > /usr/share/nginx/html/canvas-patch.js << EOF
/**
 * Canvas Patch - Fix for Audio Event Detector visualization
 */
(function() {
    console.log("Canvas patch loading");
    
    // Run when DOM is fully loaded
    document.addEventListener("DOMContentLoaded", function() {
        console.log("DOM loaded, initializing canvases");
        
        // Get canvas elements
        const debugCanvas = document.getElementById("debugVisualizer");
        const audioCanvas = document.getElementById("audioVisualizer");
        
        // Initialize debug canvas
        if (debugCanvas) {
            try {
                // Set dimensions based on CSS size
                console.log("Debug canvas before fix - width:", debugCanvas.width, "height:", debugCanvas.height);
                debugCanvas.width = debugCanvas.clientWidth;
                debugCanvas.height = debugCanvas.clientHeight;
                console.log("Debug canvas fixed - width:", debugCanvas.width, "height:", debugCanvas.height);
                
                // Test draw to verify it works
                const ctx = debugCanvas.getContext("2d");
                ctx.fillStyle = "#222";
                ctx.fillRect(0, 0, debugCanvas.width, debugCanvas.height);
                ctx.strokeStyle = "#4CAF50";
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.moveTo(0, debugCanvas.height/2);
                ctx.lineTo(debugCanvas.width, debugCanvas.height/2);
                ctx.stroke();
                
                console.log("Debug canvas initialization successful");
            } catch (e) {
                console.error("Debug canvas initialization failed:", e);
            }
        } else {
            console.warn("Debug canvas not found");
        }
        
        // Initialize audio canvas
        if (audioCanvas) {
            try {
                // Set dimensions based on CSS size
                console.log("Audio canvas before fix - width:", audioCanvas.width, "height:", audioCanvas.height);
                audioCanvas.width = audioCanvas.clientWidth;
                audioCanvas.height = audioCanvas.clientHeight;
                console.log("Audio canvas fixed - width:", audioCanvas.width, "height:", audioCanvas.height);
                
                // Test draw to verify it works
                const ctx = audioCanvas.getContext("2d");
                ctx.fillStyle = "#000";
                ctx.fillRect(0, 0, audioCanvas.width, audioCanvas.height);
                
                console.log("Audio canvas initialization successful");
            } catch (e) {
                console.error("Audio canvas initialization failed:", e);
            }
        } else {
            console.warn("Audio canvas not found");
        }
        
        // Add resize handler
        window.addEventListener("resize", function() {
            console.log("Window resized, updating canvas dimensions");
            
            if (debugCanvas) {
                debugCanvas.width = debugCanvas.clientWidth;
                debugCanvas.height = debugCanvas.clientHeight;
            }
            
            if (audioCanvas) {
                audioCanvas.width = audioCanvas.clientWidth;
                audioCanvas.height = audioCanvas.clientHeight;
            }
        });
        
        console.log("Canvas patch applied successfully");
    });
})();
EOF'

# Create a modified index.html that includes the patch
echo "Creating patched index.html..."
kubectl exec $RUNNING_POD -- sh -c 'cat > /usr/share/nginx/html/index-patched.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Audio Event Detection Demo - PATCHED</title>
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
    <h1>Audio Event Detection Demo - PATCHED</h1>
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
    
    <!-- Canvas patch must be loaded before other scripts -->
    <script src="canvas-patch.js"></script>
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
EOF'

# Create an index to access all the debugging and test files
echo "Creating an index page for all debugging tools..."
kubectl exec $RUNNING_POD -- sh -c 'cat > /usr/share/nginx/html/debug-index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Audio Detection Debug Tools</title>
    <style>
        body { font-family: Arial; margin: 20px; max-width: 800px; margin: 0 auto; padding: 20px; }
        .tool-card { 
            border: 1px solid #ddd; 
            border-radius: 8px; 
            padding: 20px; 
            margin-bottom: 20px;
            background: linear-gradient(to bottom, #ffffff, #f5f5f5);
        }
        h2 { margin-top: 0; color: #333; }
        .description { color: #666; margin-bottom: 15px; }
        .btn {
            display: inline-block;
            padding: 10px 15px;
            background: #4CAF50;
            color: white;
            text-decoration: none;
            border-radius: 4px;
            margin-right: 10px;
        }
        .info {
            background: #e7f3fe;
            border-left: 4px solid #2196F3;
            padding: 15px;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <h1>Audio Detection Debug Tools</h1>
    
    <div class="info">
        These tools will help diagnose and fix canvas visualization issues.
    </div>
    
    <div class="tool-card">
        <h2>1. Simple Visualizer Test</h2>
        <div class="description">
            A standalone test page that shows if canvas visualization works in your environment.
            This includes debug logging and animated visualizations.
        </div>
        <a href="visualizer-test.html" class="btn">Open Test Page</a>
    </div>
    
    <div class="tool-card">
        <h2>2. Patched Application</h2>
        <div class="description">
            The full application with patches applied to fix canvas sizing issues.
            Includes a special "Test Visualizers" button to verify canvas rendering.
        </div>
        <a href="index-patched.html" class="btn">Open Patched App</a>
    </div>
    
    <div class="tool-card">
        <h2>3. Original Application</h2>
        <div class="description">
            The original application without any modifications.
        </div>
        <a href="index.html" class="btn">Open Original App</a>
    </div>
    
    <div class="tool-card">
        <h2>Apply Permanent Fix</h2>
        <div class="description">
            If the patched application works, you can permanently apply the fix by using these commands:
        </div>
        <pre style="background:#f0f0f0; padding:10px; overflow:auto; border-radius:4px;">
# Apply the canvas patch to your audio-event-detector.js
kubectl cp canvas-patch.js $RUNNING_POD:/usr/share/nginx/html/

# Replace the original index.html with the patched version
kubectl exec $RUNNING_POD -- cp /usr/share/nginx/html/index-patched.html /usr/share/nginx/html/index.html
        </pre>
    </div>
</body>
</html>
EOF'

# Output success message
echo ""
echo "=================================================================="
echo "Fix created successfully! Here's how to access the debugging tools:"
echo "=================================================================="
echo ""
echo "1. Set up port forwarding:"
echo "   kubectl port-forward $RUNNING_POD 8080:80"
echo ""
echo "2. Access the debug index page:"
echo "   http://localhost:8080/debug-index.html"
echo ""
echo "3. Try the different test tools to find what works best"
echo ""
echo "4. If the patched version works, make it permanent with:"
echo "   kubectl exec $RUNNING_POD -- cp /usr/share/nginx/html/index-patched.html /usr/share/nginx/html/index.html"
echo ""
echo "=================================================================="
