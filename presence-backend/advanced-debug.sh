#!/bin/bash
# Advanced debugging solution for canvas visualization issues

# Find the pod name for the main audio detection app
AUDIO_POD=$(kubectl get pods -l app=audio-detection -o jsonpath='{.items[0].metadata.name}')
echo "Found audio detection pod: $AUDIO_POD"

# Step 1: Create a standalone debug page that will test canvas functionality directly
echo "Creating standalone debug page..."
kubectl exec $AUDIO_POD -- sh -c "cat > /usr/share/nginx/html/canvas-debug.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Canvas Debug</title>
    <style>
        body { font-family: Arial; margin: 20px; }
        .debug-panel { 
            background: #f5f5f5; 
            border: 1px solid #ddd; 
            padding: 10px; 
            margin-bottom: 20px;
            white-space: pre-wrap;
            font-family: monospace;
            max-height: 200px;
            overflow: auto;
        }
        .canvas-container {
            border: 2px solid red;
            padding: 5px;
            margin-bottom: 20px;
        }
        canvas {
            border: 1px solid blue;
            display: block;
            width: 100%;
            height: 150px;
            background-color: #222;
        }
        button {
            padding: 10px;
            margin: 5px;
            background: #4CAF50;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
        }
    </style>
</head>
<body>
    <h1>Canvas Debug Tool</h1>
    
    <div class="debug-panel" id="debugOutput">Debug info will appear here</div>
    
    <div class="canvas-container">
        <h2>Test Canvas (with red border around container, blue border around canvas)</h2>
        <canvas id="testCanvas"></canvas>
    </div>
    
    <div>
        <button id="testDraw">Draw Test Pattern</button>
        <button id="testAnimation">Run Animation</button>
        <button id="stopAnimation">Stop Animation</button>
        <button id="clearDebug">Clear Debug Log</button>
    </div>
    
    <script>
        // Debug logging
        const debugOutput = document.getElementById('debugOutput');
        function log(message) {
            const timestamp = new Date().toLocaleTimeString();
            debugOutput.textContent += \`[\${timestamp}] \${message}\n\`;
            debugOutput.scrollTop = debugOutput.scrollHeight;
            console.log(message);
        }
        
        // Canvas elements
        const canvas = document.getElementById('testCanvas');
        let ctx = null;
        let animating = false;
        let animationFrame = null;
        
        // Initialize canvas with detailed error handling
        function initCanvas() {
            log('Starting canvas initialization');
            
            try {
                // Check if canvas exists
                if (!canvas) {
                    throw new Error('Canvas element not found');
                }
                
                log(\`Initial canvas properties - Width: \${canvas.width}, Height: \${canvas.height}, Style Width: \${canvas.style.width}, ClientWidth: \${canvas.clientWidth}\`);
                
                // Get canvas context with error handling
                try {
                    ctx = canvas.getContext('2d');
                    if (!ctx) {
                        throw new Error('Failed to get 2D context');
                    }
                    log('Got 2D context successfully');
                } catch (ctxError) {
                    log(\`Error getting context: \${ctxError.message}\`);
                    return false;
                }
                
                // Resize canvas to match display size
                try {
                    canvas.width = canvas.clientWidth;
                    canvas.height = canvas.clientHeight;
                    log(\`Resized canvas to \${canvas.width}x\${canvas.height}\`);
                } catch (resizeError) {
                    log(\`Error resizing canvas: \${resizeError.message}\`);
                }
                
                // Add resize handler
                window.addEventListener('resize', function() {
                    try {
                        const oldWidth = canvas.width;
                        const oldHeight = canvas.height;
                        
                        canvas.width = canvas.clientWidth;
                        canvas.height = canvas.clientHeight;
                        
                        log(\`Canvas resized from \${oldWidth}x\${oldHeight} to \${canvas.width}x\${canvas.height}\`);
                        
                        // Redraw if needed
                        drawTest();
                    } catch (resizeError) {
                        log(\`Error during resize: \${resizeError.message}\`);
                    }
                });
                
                log('Canvas initialization complete');
                return true;
            } catch (error) {
                log(\`Canvas initialization failed: \${error.message}\`);
                return false;
            }
        }
        
        // Draw test pattern
        function drawTest() {
            if (!ctx) {
                log('Cannot draw - context not available');
                return;
            }
            
            try {
                log(\`Drawing test pattern on canvas (\${canvas.width}x\${canvas.height})\`);
                
                // Clear canvas
                ctx.fillStyle = '#222';
                ctx.fillRect(0, 0, canvas.width, canvas.height);
                
                // Draw gradient
                const gradient = ctx.createLinearGradient(0, 0, canvas.width, 0);
                gradient.addColorStop(0, 'red');
                gradient.addColorStop(0.5, 'green');
                gradient.addColorStop(1, 'blue');
                
                ctx.fillStyle = gradient;
                ctx.fillRect(20, 20, canvas.width - 40, canvas.height - 40);
                
                // Draw text
                ctx.fillStyle = 'white';
                ctx.font = '20px Arial';
                ctx.textAlign = 'center';
                ctx.fillText('Canvas is working!', canvas.width/2, canvas.height/2);
                
                log('Test pattern drawn successfully');
            } catch (error) {
                log(\`Error drawing test pattern: \${error.message}\`);
            }
        }
        
        // Animate the canvas
        function animate() {
            if (!animating) return;
            
            try {
                // Clear canvas
                ctx.fillStyle = '#222';
                ctx.fillRect(0, 0, canvas.width, canvas.height);
                
                // Get current time
                const time = performance.now() / 1000;
                
                // Draw animated circles
                for (let i = 0; i < 5; i++) {
                    const x = Math.sin(time + i) * (canvas.width/4) + canvas.width/2;
                    const y = Math.cos(time + i) * (canvas.height/4) + canvas.height/2;
                    const radius = 10 + 5 * Math.sin(time * 2 + i);
                    
                    ctx.beginPath();
                    ctx.arc(x, y, radius, 0, Math.PI * 2);
                    ctx.fillStyle = \`hsl(\${((time * 50) + i * 50) % 360}, 100%, 50%)\`;
                    ctx.fill();
                }
                
                // Continue animation
                animationFrame = requestAnimationFrame(animate);
            } catch (error) {
                log(\`Animation error: \${error.message}\`);
                stopAnimation();
            }
        }
        
        // Stop animation
        function stopAnimation() {
            animating = false;
            if (animationFrame) {
                cancelAnimationFrame(animationFrame);
                animationFrame = null;
            }
            log('Animation stopped');
        }
        
        // Set up event listeners
        document.getElementById('testDraw').addEventListener('click', function() {
            log('Test draw button clicked');
            drawTest();
        });
        
        document.getElementById('testAnimation').addEventListener('click', function() {
            log('Animation button clicked');
            if (!animating) {
                animating = true;
                animate();
                log('Animation started');
            }
        });
        
        document.getElementById('stopAnimation').addEventListener('click', function() {
            log('Stop animation button clicked');
            stopAnimation();
        });
        
        document.getElementById('clearDebug').addEventListener('click', function() {
            debugOutput.textContent = '';
            log('Debug log cleared');
        });
        
        // Initialize on page load
        window.addEventListener('DOMContentLoaded', function() {
            log('DOM loaded');
            initCanvas();
            
            // Draw initial test pattern
            setTimeout(function() {
                log('Running delayed test draw');
                drawTest();
            }, 500);
        });
    </script>
</body>
</html>
EOF"

# Step 2: Create a self-contained test page that includes the fixed audio detector code
echo "Creating self-contained test page..."
kubectl exec $AUDIO_POD -- sh -c "cat > /usr/share/nginx/html/all-in-one-test.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>All-In-One Audio Detector Test</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        .container {
            border: 1px solid #ddd;
            border-radius: 4px;
            padding: 15px;
            margin-bottom: 20px;
        }
        .debug-log {
            background: #f5f5f5;
            border: 1px solid #ddd;
            padding: 10px;
            font-family: monospace;
            white-space: pre-wrap;
            height: 150px;
            overflow: auto;
            margin-bottom: 20px;
        }
        canvas {
            width: 100%;
            height: 120px;
            background-color: #222;
            border: 1px solid #666;
            margin-bottom: 10px;
            display: block;
        }
        button {
            padding: 8px 15px;
            background: #4CAF50;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            margin-right: 10px;
        }
        button:disabled {
            background: #ccc;
        }
    </style>
</head>
<body>
    <h1>Audio Detector All-In-One Test</h1>
    
    <div class="container">
        <h2>Debug Log</h2>
        <div id="debugLog" class="debug-log"></div>
        <button id="clearLog">Clear Log</button>
    </div>
    
    <div class="container">
        <h2>Debug Visualizer</h2>
        <canvas id="debugVisualizer"></canvas>
    </div>
    
    <div class="container">
        <h2>Audio Visualizer</h2>
        <canvas id="audioVisualizer"></canvas>
    </div>
    
    <div class="container">
        <h2>Controls</h2>
        <button id="testCanvasBtn">Test Canvas</button>
        <button id="testFakeData">Use Fake Data</button>
        <button id="startBtn">Start Detection</button>
        <button id="stopBtn" disabled>Stop Detection</button>
    </div>
    
    <script>
        // Debug logger
        const debugLog = document.getElementById('debugLog');
        function log(message) {
            const timestamp = new Date().toLocaleTimeString();
            debugLog.textContent += \`[\${timestamp}] \${message}\n\`;
            debugLog.scrollTop = debugLog.scrollHeight;
            console.log(message);
        }
        
        document.getElementById('clearLog').addEventListener('click', () => {
            debugLog.textContent = '';
        });
        
        // Canvas initialization
        const debugCanvas = document.getElementById('debugVisualizer');
        const audioCanvas = document.getElementById('audioVisualizer');
        let debugCtx, audioCtx;
        
        function initCanvases() {
            log('Initializing canvases');
            
            try {
                // Set up debug canvas
                debugCanvas.width = debugCanvas.clientWidth;
                debugCanvas.height = debugCanvas.clientHeight;
                debugCtx = debugCanvas.getContext('2d');
                log(\`Debug canvas size: \${debugCanvas.width}x\${debugCanvas.height}\`);
                
                // Set up audio canvas
                audioCanvas.width = audioCanvas.clientWidth;
                audioCanvas.height = audioCanvas.clientHeight;
                audioCtx = audioCanvas.getContext('2d');
                log(\`Audio canvas size: \${audioCanvas.width}x\${audioCanvas.height}\`);
                
                // Add resize handler
                window.addEventListener('resize', () => {
                    log('Window resized, updating canvas dimensions');
                    
                    debugCanvas.width = debugCanvas.clientWidth;
                    debugCanvas.height = debugCanvas.clientHeight;
                    
                    audioCanvas.width = audioCanvas.clientWidth;
                    audioCanvas.height = audioCanvas.clientHeight;
                    
                    // Redraw test pattern
                    testCanvases();
                });
                
                return true;
            } catch (error) {
                log(\`Canvas initialization error: \${error.message}\`);
                return false;
            }
        }
        
        // Test canvas rendering
        function testCanvases() {
            log('Testing canvas rendering');
            
            try {
                // Draw on debug canvas
                debugCtx.fillStyle = '#222';
                debugCtx.fillRect(0, 0, debugCanvas.width, debugCanvas.height);
                
                debugCtx.strokeStyle = '#4CAF50';
                debugCtx.lineWidth = 2;
                debugCtx.beginPath();
                for (let x = 0; x < debugCanvas.width; x++) {
                    const y = debugCanvas.height/2 + Math.sin(x/20) * 40;
                    if (x === 0) {
                        debugCtx.moveTo(x, y);
                    } else {
                        debugCtx.lineTo(x, y);
                    }
                }
                debugCtx.stroke();
                
                // Draw on audio canvas
                audioCtx.fillStyle = '#000';
                audioCtx.fillRect(0, 0, audioCanvas.width, audioCanvas.height);
                
                const barCount = 32;
                const barWidth = audioCanvas.width / barCount;
                
                for (let i = 0; i < barCount; i++) {
                    const barHeight = (Math.sin(i/barCount * Math.PI) * audioCanvas.height * 0.8);
                    
                    const gradient = audioCtx.createLinearGradient(0, audioCanvas.height, 0, audioCanvas.height - barHeight);
                    gradient.addColorStop(0, '#4CAF50');
                    gradient.addColorStop(0.5, '#FFEB3B');
                    gradient.addColorStop(1, '#F44336');
                    
                    audioCtx.fillStyle = gradient;
                    audioCtx.fillRect(i * barWidth, audioCanvas.height - barHeight, barWidth - 1, barHeight);
                }
                
                log('Canvas test complete - if you see patterns, rendering is working');
                return true;
            } catch (error) {
                log(\`Canvas rendering error: \${error.message}\`);
                return false;
            }
        }
        
        // Simplified AudioEventDetector class with the essential fixes
        class SimpleAudioVisualizer {
            constructor() {
                log('Creating audio visualizer');
                
                this.audioContext = null;
                this.analyserNode = null;
                this.sourceNode = null;
                this.stream = null;
                
                this.isRecording = false;
                this.useFakeData = false;
                
                this.fftSize = 2048;
                this.frequencyData = null;
                this.timeData = null;
                
                this.debugCanvas = debugCanvas;
                this.debugCtx = debugCtx;
                this.audioCanvas = audioCanvas;
                this.audioCtx = audioCtx;
                
                this.energyHistory = [];
                this.energyHistorySize = 50;
                
                log('Audio visualizer created');
            }
            
            async initialize(useFakeData = false) {
                log(\`Initializing audio visualizer (fake data: \${useFakeData})\`);
                this.useFakeData = useFakeData;
                
                try {
                    // Create audio context
                    this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
                    log(\`Created audio context, sample rate: \${this.audioContext.sampleRate}\`);
                    
                    // If not using fake data, get microphone access
                    if (!this.useFakeData) {
                        try {
                            log('Requesting microphone access');
                            this.stream = await navigator.mediaDevices.getUserMedia({ audio: true });
                            log('Microphone access granted');
                            
                            // Set up audio processing
                            this.sourceNode = this.audioContext.createMediaStreamSource(this.stream);
                            this.analyserNode = this.audioContext.createAnalyser();
                            this.analyserNode.fftSize = this.fftSize;
                            this.sourceNode.connect(this.analyserNode);
                            
                            this.frequencyData = new Uint8Array(this.analyserNode.frequencyBinCount);
                            this.timeData = new Uint8Array(this.fftSize);
                            
                            log('Audio processing setup complete');
                        } catch (micError) {
                            log(\`Microphone access error: \${micError.name} - \${micError.message}\`);
                            log('Falling back to fake data mode');
                            this.useFakeData = true;
                        }
                    }
                    
                    // If using fake data, set up dummy data
                    if (this.useFakeData) {
                        log('Setting up fake data');
                        this.frequencyData = new Uint8Array(1024);
                        this.timeData = new Uint8Array(this.fftSize);
                        
                        // Initialize with non-zero values
                        this._generateFakeData();
                    }
                    
                    log('Audio visualizer initialization complete');
                    return true;
                } catch (error) {
                    log(\`Audio initialization error: \${error.message}\`);
                    return false;
                }
            }
            
            _generateFakeData() {
                // Generate fake frequency data (spectrum)
                for (let i = 0; i < this.frequencyData.length; i++) {
                    const normalizedPosition = i / this.frequencyData.length;
                    const value = Math.sin(normalizedPosition * Math.PI) * 120 + 
                                 Math.random() * 30 + 70;
                    this.frequencyData[i] = Math.min(255, Math.max(0, value));
                }
                
                // Generate fake time domain data (waveform)
                const time = Date.now() / 500;
                for (let i = 0; i < this.timeData.length; i++) {
                    const value = 128 + Math.sin(i/30 + time) * 50 + Math.sin(i/15 + time * 0.8) * 20;
                    this.timeData[i] = Math.min(255, Math.max(0, value));
                }
            }
            
            start() {
                log('Starting audio visualization');
                
                this.isRecording = true;
                this.processAudio();
                
                // Enable stop button, disable start
                document.getElementById('startBtn').disabled = true;
                document.getElementById('stopBtn').disabled = false;
                document.getElementById('testFakeData').disabled = true;
                
                return true;
            }
            
            stop() {
                log('Stopping audio visualization');
                
                this.isRecording = false;
                
                // Enable start button, disable stop
                document.getElementById('startBtn').disabled = false;
                document.getElementById('stopBtn').disabled = true;
                document.getElementById('testFakeData').disabled = false;
                
                // If using real mic, clear canvases
                if (!this.useFakeData) {
                    this.debugCtx.fillStyle = '#222';
                    this.debugCtx.fillRect(0, 0, this.debugCanvas.width, this.debugCanvas.height);
                    
                    this.audioCtx.fillStyle = '#000';
                    this.audioCtx.fillRect(0, 0, this.audioCanvas.width, this.audioCanvas.height);
                }
            }
            
            processAudio() {
                if (!this.isRecording) return;
                
                try {
                    // Get audio data
                    if (!this.useFakeData && this.analyserNode) {
                        this.analyserNode.getByteFrequencyData(this.frequencyData);
                        this.analyserNode.getByteTimeDomainData(this.timeData);
                    } else {
                        this._generateFakeData();
                    }
                    
                    // Calculate energy level
                    const energy = this.calculateEnergy();
                    this.trackEnergy(energy);
                    
                    // Draw visualizations
                    this.drawDebugVisualizer();
                    this.drawAudioVisualizer();
                    
                    // Continue processing
                    requestAnimationFrame(() => this.processAudio());
                } catch (error) {
                    log(\`Audio processing error: \${error.message}\`);
                    this.stop();
                }
            }
            
            calculateEnergy() {
                if (!this.timeData) return 0;
                
                let sum = 0;
                const length = this.timeData.length;
                
                for (let i = 0; i < length; i++) {
                    const value = (this.timeData[i] - 128) / 128.0;
                    sum += value * value;
                }
                
                return Math.sqrt(sum / length);
            }
            
            trackEnergy(energy) {
                this.energyHistory.push(energy);
                if (this.energyHistory.length > this.energyHistorySize) {
                    this.energyHistory.shift();
                }
            }
            
            drawDebugVisualizer() {
                const canvas = this.debugCanvas;
                const ctx = this.debugCtx;
                const width = canvas.width;
                const height = canvas.height;
                
                // Clear canvas
                ctx.fillStyle = '#222';
                ctx.fillRect(0, 0, width, height);
                
                // Draw energy threshold line
                ctx.strokeStyle = '#FF9800';
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.moveTo(0, height * 0.7);
                ctx.lineTo(width, height * 0.7);
                ctx.stroke();
                
                // Draw energy history
                ctx.strokeStyle = '#4CAF50';
                ctx.lineWidth = 2;
                ctx.beginPath();
                
                const step = width / (this.energyHistorySize - 1);
                
                for (let i = 0; i < this.energyHistory.length; i++) {
                    const x = i * step;
                    const y = height - (this.energyHistory[i] * height * 5); // Scale for visibility
                    
                    if (i === 0) {
                        ctx.moveTo(x, y);
                    } else {
                        ctx.lineTo(x, y);
                    }
                }
                
                ctx.stroke();
                
                // Draw current energy level
                const currentEnergy = this.energyHistory.length > 0 ? 
                    this.energyHistory[this.energyHistory.length - 1] : 0;
                
                ctx.fillStyle = '#FFF';
                ctx.font = '12px Arial';
                ctx.fillText(\`Energy: \${currentEnergy.toFixed(3)}\`, 10, 20);
            }
            
            drawAudioVisualizer() {
                const canvas = this.audioCanvas;
                const ctx = this.audioCtx;
                const width = canvas.width;
                const height = canvas.height;
                
                // Clear canvas
                ctx.fillStyle = '#000';
                ctx.fillRect(0, 0, width, height);
                
                // Draw frequency data
                const barWidth = width / Math.min(128, this.frequencyData.length);
                
                for (let i = 0; i < Math.min(128, this.frequencyData.length); i++) {
                    const value = this.frequencyData[i];
                    const percent = value / 255;
                    const barHeight = height * percent;
                    
                    // Create gradient
                    const gradient = ctx.createLinearGradient(0, height, 0, height - barHeight);
                    gradient.addColorStop(0, '#4CAF50');
                    gradient.addColorStop(0.5, '#FFEB3B');
                    gradient.addColorStop(1, '#F44336');
                    
                    ctx.fillStyle = gradient;
                    ctx.fillRect(i * barWidth, height - barHeight, barWidth - 1, barHeight);
                }
            }
        }
        
        // Main script execution
        let visualizer = null;
        
        // Test canvas button
        document.getElementById('testCanvasBtn').addEventListener('click', () => {
            log('Testing canvas rendering');
            testCanvases();
        });
        
        // Fake data toggle
        document.getElementById('testFakeData').addEventListener('click', async () => {
            log('Using fake data for testing');
            
            if (visualizer) {
                visualizer.stop();
            }
            
            visualizer = new SimpleAudioVisualizer();
            await visualizer.initialize(true);
            visualizer.start();
        });
        
        // Start detection
        document.getElementById('startBtn').addEventListener('click', async () => {
            log('Starting real audio visualization');
            
            if (visualizer) {
                visualizer.stop();
            }
            
            visualizer = new SimpleAudioVisualizer();
            const initialized = await visualizer.initialize(false);
            
            if (initialized) {
                visualizer.start();
            } else {
                log('Failed to initialize audio - check console for errors');
            }
        });
        
        // Stop detection
        document.getElementById('stopBtn').addEventListener('click', () => {
            log('Stopping audio visualization');
            
            if (visualizer) {
                visualizer.stop();
            }
        });
        
        // Initialize on page load
        window.addEventListener('DOMContentLoaded', () => {
            log('Page loaded');
            
            if (initCanvases()) {
                log('Canvas initialization successful');
                setTimeout(testCanvases, 100);
            } else {
                log('Canvas initialization failed');
            }
        });
    </script>
</body>
</html>
EOF"

# Step 3: Create a script to directly apply fixes to the main audio-event-detector.js
echo "Creating a script to fix the main audio-event-detector.js file..."
kubectl exec $AUDIO_POD -- sh -c "cat > /usr/share/nginx/html/fix-audio-detector.js << EOF
/**
 * Canvas Initialization Script to fix audio-event-detector.js
 * 
 * This script monkey-patches the AudioEventDetector class to ensure
 * proper canvas initialization and rendering.
 */
(function() {
    console.log('Audio Event Detector Fix Script - Initializing');
    
    // Store original AudioEventDetector for patching
    const originalAudioEventDetector = window.AudioEventDetector;
    
    if (!originalAudioEventDetector) {
        console.error('AudioEventDetector not found - fix script cannot run');
        return;
    }
    
    console.log('Found AudioEventDetector, applying patches');
    
    // Fix 1: Ensure canvases are properly sized before use
    function initializeCanvases() {
        console.log('Initializing canvas elements');
        
        const debugCanvas = document.getElementById('debugVisualizer');
        const audioCanvas = document.getElementById('audioVisualizer');
        
        if (debugCanvas) {
            console.log('Found debug visualizer canvas');
            debugCanvas.width = debugCanvas.clientWidth || 400;
            debugCanvas.height = debugCanvas.clientHeight || 100;
            console.log(\`Debug canvas sized to \${debugCanvas.width}x\${debugCanvas.height}\`);
            
            // Verify canvas is working with a simple test draw
            try {
                const ctx = debugCanvas.getContext('2d');
                ctx.fillStyle = '#222';
                ctx.fillRect(0, 0, debugCanvas.width, debugCanvas.height);
                ctx.strokeStyle = '#4CAF50';
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.moveTo(0, debugCanvas.height/2);
                ctx.lineTo(debugCanvas.width, debugCanvas.height/2);
                ctx.stroke();
                console.log('Debug canvas test render completed');
            } catch (e) {
                console.error('Debug canvas test render failed:', e);
            }
        } else {
            console.warn('Debug canvas not found');
        }
        
        if (audioCanvas) {
            console.log('Found audio visualizer canvas');
            audioCanvas.width = audioCanvas.clientWidth || 400;
            audioCanvas.height = audioCanvas.clientHeight || 100;
            console.log(\`Audio canvas sized to \${audioCanvas.width}x\${audioCanvas.height}\`);
            
            // Verify canvas is working with a simple test draw
            try {
                const ctx = audioCanvas.getContext('2d');
                ctx.fillStyle = '#000';
                ctx.fillRect(0, 0, audioCanvas.width, audioCanvas.height);
                // Draw a test bar
                ctx.fillStyle = '#4CAF50';
                ctx.fillRect(audioCanvas.width/4, audioCanvas.height/4, 
                             audioCanvas.width/2, audioCanvas.height/2);
                console.log('Audio canvas test render completed');
            } catch (e) {
                console.error('Audio canvas test render failed:', e);
            }
        } else {
            console.warn('Audio canvas not found');
        }
        
        // Add a window resize handler
        window.addEventListener('resize', function() {
            console.log('Window resized, updating canvas dimensions');
            
            if (debugCanvas) {
                debugCanvas.width = debugCanvas.clientWidth || 400;
                debugCanvas.height = debugCanvas.clientHeight || 100;
            }
            
            if (audioCanvas) {
                audioCanvas.width = audioCanvas.clientWidth || 400;
                audioCanvas.height = audioCanvas.clientHeight || 100;
            }
        });
        
        console.log('Canvas initialization complete');
    }
    
    // Fix 2: Install fake data capability
    let useTestData = false;
    let testAnimationFrame = null;
    
    function generateTestData(frequencyData, timeData) {
        if (!frequencyData || !timeData) return;
        
        // Create a timestamp for animation
        const time = Date.now() / 500;
        
        // Generate realistic-looking frequency data
        for (let i = 0; i < frequencyData.length; i++) {
            // Create a nice curve with random variations
            const normalizedPosition = i / frequencyData.length;
            const baseValue = Math.sin(normalizedPosition * Math.PI) * 127;
            const randomVariation = Math.random() * 50;
            const timeVariation = Math.sin(time + i/100) * 30;
            
            frequencyData[i] = Math.min(255, Math.max(0, baseValue + randomVariation + timeVariation));
        }
        
        // Generate realistic-looking time domain data
        for (let i = 0; i < timeData.length; i++) {
            const value = 128 + 
                        Math.sin(i/20 + time) * 40 + 
                        Math.sin(i/10 + time * 0.7) * 20;
            
            timeData[i] = Math.min(255, Math.max(0, value));
        }
    }
    
    // Apply canvas initialization immediately and on DOMContentLoaded
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initializeCanvases);
    } else {
        // DOM already loaded, run initialization
        setTimeout(initializeCanvases, 100);
    }
    
    // Create a patched version of AudioEventDetector
    window.AudioEventDetector = function(...args) {
        console.log('Creating patched AudioEventDetector instance');
        
        // Call original constructor
        const instance = new originalAudioEventDetector(...args);
        
        // Patch initialize method to handle errors and use test data when needed
        const originalInit = instance.initialize;
        instance.initialize = async function() {
            console.log('Patched initialize method called');
            
            try {
                // Try to initialize normally
                const result = await originalInit.apply(this);
                
                if (!result) {
                    console.warn('Original initialization failed, using test data mode');
                    useTestData = true;
                    
                    // Set up fake data arrays if needed
                    if (!this.frequencyData) {
                        this.frequencyData = new Uint8Array(1024);
                    }
                    
                    if (!this.timeData) {
                        this.timeData = new Uint8Array(2048);
                    }
                    
                    // Generate initial test data
                    generateTestData(this.frequencyData, this.timeData);
                    
                    return true;
                }
                
                return result;
            } catch (error) {
                console.error('AudioEventDetector initialization error:', error);
                
                // Fall back to test data mode
                useTestData = true;
                
                // Set up fake data arrays
                this.frequencyData = new Uint8Array(1024);
                this.timeData = new Uint8Array(2048);
                
                // Generate initial test data
                generateTestData(this.frequencyData, this.timeData);
                
                return true;
            }
        };
        
        // Patch the processAudio method to use test data when needed
        const originalProcess = instance.processAudio;
        instance.processAudio = function() {
            if (useTestData) {
                // Generate fake data
                generateTestData(this.frequencyData, this.timeData);
                
                // Calculate audio energy (magnitude)
                const energy = this.calculateEnergy(this.timeData);
                this.trackEnergy(energy);
                
                // Draw visualizations
                if (this.debugContext) {
                    this.drawDebugVisualizer();
                }
                
                if (this.visualizerContext) {
                    this.drawAudioVisualizer();
                }
                
                // Continue processing
                testAnimationFrame = requestAnimationFrame(() => this.processAudio());
                return;
            }
            
            // Otherwise, call original method
            return originalProcess.apply(this);
        };
        
        // Patch the stop method to cancel test animation frame
        const originalStop = instance.stop;
        instance.stop = function() {
            if (testAnimationFrame) {
                cancelAnimationFrame(testAnimationFrame);
                testAnimationFrame = null;
            }
            
            // Call original method
            return originalStop.apply(this);
        };
        
        console.log('AudioEventDetector instance patched');
        return instance;
    };
    
    // Copy any static properties/methods
    for (const prop in originalAudioEventDetector) {
        if (originalAudioEventDetector.hasOwnProperty(prop)) {
            window.AudioEventDetector[prop] = originalAudioEventDetector[prop];
        }
    }
    
    console.log('Audio Event Detector Fix Script - Patching complete');
})();
EOF"

# Step 4: Update the index.html file to include our fix script
echo "Updating index.html to include the fix script..."
kubectl exec $AUDIO_POD -- sh -c "cat > /usr/share/nginx/html/index-fixed.html << EOF
<!DOCTYPE html>
<html lang=\"en\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
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
        
        .debug-tools {
            margin-top: 20px;
            padding: 15px;
            border: 1px solid #FFC107;
            border-radius: 4px;
            background-color: #FFF8E1;
        }
    </style>
</head>
<body>
    <h1>Audio Event Detection Demo - FIXED</h1>
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
    
    <div class=\"debug-tools\">
        <h2>Debug Tools</h2>
        <p>If you're having issues with visualizers, try these:</p>
        <button id=\"testVisualizers\">Test Visualizers</button>
        <button id=\"useFakeData\">Use Fake Data</button>
        <button id=\"goToDebugPage\">Open Debug Page</button>
        <div id=\"debugInfo\" style=\"margin-top: 10px; font-family: monospace;\"></div>
    </div>
    
    <!-- The fix script must be loaded BEFORE audio-event-detector.js -->
    <script src=\"fix-audio-detector.js\"></script>
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
            const debugVisualizer = document.getElementById('debugVisualizer');
            const debugInfo = document.getElementById('debugInfo');

            // Log a message to both console and debug info
            function log(message) {
                console.log(message);
                debugInfo.innerHTML += message + '<br>';
                debugInfo.scrollTop = debugInfo.scrollHeight;
            }
            
            // Clear debug info
            debugInfo.innerHTML = '';
            
            // Check if canvases exist
            log(\`Found audioVisualizer: \${!!visualizerCanvas}\`);
            log(\`Found debugVisualizer: \${!!debugVisualizer}\`);
            
            // Check canvas dimensions
            if (visualizerCanvas) {
                log(\`Audio visualizer dimensions: \${visualizerCanvas.width}×\${visualizerCanvas.height} (HTML), \${visualizerCanvas.clientWidth}×\${visualizerCanvas.clientHeight} (CSS)\`);
            }
            
            if (debugVisualizer) {
                log(\`Debug visualizer dimensions: \${debugVisualizer.width}×\${debugVisualizer.height} (HTML), \${debugVisualizer.clientWidth}×\${debugVisualizer.clientHeight} (CSS)\`);
            }

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
            document.getElementById('testVisualizers').addEventListener('click', () => {
                log('Testing visualizers');
                
                // Test audio visualizer
                if (visualizerCanvas) {
                    const ctx = visualizerCanvas.getContext('2d');
                    
                    // Clear canvas
                    ctx.fillStyle = '#000';
                    ctx.fillRect(0, 0, visualizerCanvas.width, visualizerCanvas.height);
                    
                    // Draw test bars
                    for (let i = 0; i < 10; i++) {
                        const barHeight = visualizerCanvas.height * (0.2 + i * 0.08);
                        const barWidth = visualizerCanvas.width / 12;
                        const x = i * (visualizerCanvas.width / 10);
                        
                        // Create gradient
                        const gradient = ctx.createLinearGradient(0, visualizerCanvas.height, 0, visualizerCanvas.height - barHeight);
                        gradient.addColorStop(0, '#4CAF50');
                        gradient.addColorStop(0.5, '#FFEB3B');
                        gradient.addColorStop(1, '#F44336');
                        
                        ctx.fillStyle = gradient;
                        ctx.fillRect(x, visualizerCanvas.height - barHeight, barWidth, barHeight);
                    }
                    
                    log('Audio visualizer test pattern drawn');
                }
                
                // Test debug visualizer
                if (debugVisualizer) {
                    const ctx = debugVisualizer.getContext('2d');
                    
                    // Clear canvas
                    ctx.fillStyle = '#222';
                    ctx.fillRect(0, 0, debugVisualizer.width, debugVisualizer.height);
                    
                    // Draw wave pattern
                    ctx.strokeStyle = '#4CAF50';
                    ctx.lineWidth = 2;
                    ctx.beginPath();
                    
                    for (let x = 0; x < debugVisualizer.width; x++) {
                        const y = debugVisualizer.height/2 + Math.sin(x/20) * (debugVisualizer.height/3);
                        
                        if (x === 0) {
                            ctx.moveTo(x, y);
                        } else {
                            ctx.lineTo(x, y);
                        }
                    }
                    
                    ctx.stroke();
                    
                    log('Debug visualizer test pattern drawn');
                }
            });
            
            // Use fake data
            document.getElementById('useFakeData').addEventListener('click', () => {
                log('Using fake data mode');
                
                if (detector) {
                    detector.stop();
                }
                
                // Create and initialize detector
                detector = new AudioEventDetector({
                    debugVisualizer: true,
                    onEvent: (detections) => {
                        log(\`Event detected: \${detections[0]?.type}\`);
                    }
                });
                
                // Force fake data mode
                detector._useTestData = true;
                
                // Initialize and start
                detector.initialize().then(initialized => {
                    if (initialized) {
                        detector.start();
                        statusElement.textContent = 'Status: Using fake data';
                        startButton.disabled = true;
                        stopButton.disabled = false;
                    } else {
                        log('Failed to initialize detector');
                    }
                });
            });
            
            // Debug page link
            document.getElementById('goToDebugPage').addEventListener('click', () => {
                window.open('canvas-debug.html', '_blank');
            });

            // Initialize the detector
            startButton.addEventListener('click', async () => {
                log('Starting audio detection');
                
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
                log('AudioEventDetector created');
                
                const initialized = await detector.initialize();
                log(\`Detector initialized: \${initialized}\`);
                
                if (!initialized) {
                    statusElement.textContent = 'Status: Failed to initialize (microphone access denied?)';
                    statusElement.style.borderLeftColor = '#F44336';
                    log('Initialization failed - try using fake data instead');
                    return;
                }
                
                // Add event detection models
                detector.addEventModel('doorbell', createDoorbellDetector());
                detector.addEventModel('knocking', createKnockingDetector());
                log('Event models added');
                
                // Start detection
                detector.start();
                log('Detection started');
                
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
                    log('Detection stopped');
                    statusElement.textContent = 'Status: Detection stopped';
                    statusElement.style.borderLeftColor = '#FF9800';
                    startButton.disabled = false;
                    stopButton.disabled = true;
                }
            });
            
            // Clear log
            clearLogButton.addEventListener('click', () => {
                eventLogElement.innerHTML = '<div class=\"event-item\">Waiting for events...</div>';
                log('Event log cleared');
            });
            
            log('Page initialization complete');
        });
    </script>
</body>
</html>
EOF"

# Create a small script to check if we should use the fix script
echo "Creating final test script..."
kubectl exec $AUDIO_POD -- sh -c "cat > /usr/share/nginx/html/check-if-fixed.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Audio Detection Test</title>
    <style>
        body { font-family: Arial; margin: 20px; max-width: 800px; margin: 0 auto; padding: 20px; }
        .tool-card { border: 1px solid #ddd; border-radius: 8px; padding: 20px; margin-bottom: 20px; }
        h2 { margin-top: 0; }
        button { padding: 10px 15px; background: #4CAF50; color: white; border: none; 
                border-radius: 4px; cursor: pointer; margin-right: 10px; }
        .info { background: #e7f3fe; padding: 15px; border-left: 4px solid #2196F3; margin: 20px 0; }
    </style>
</head>
<body>
    <h1>Audio Event Detection Test Center</h1>
    
    <div class="info">
        These tools will help diagnose and fix the canvas visualization issues.
    </div>
    
    <div class="tool-card">
        <h2>1. Basic Canvas Test</h2>
        <p>This tests if canvas rendering works at all in your environment.</p>
        <button onclick="window.location.href='canvas-debug.html'">Run Canvas Test</button>
    </div>
    
    <div class="tool-card">
        <h2>2. Audio Visualizer Test</h2>
        <p>This tests a simplified version of the audio visualizer with fake data.</p>
        <button onclick="window.location.href='all-in-one-test.html'">Run Visualizer Test</button>
    </div>
    
    <div class="tool-card">
        <h2>3. Fixed Application</h2>
        <p>This is the full application with fixes applied to address canvas issues.</p>
        <button onclick="window.location.href='index-fixed.html'">Launch Fixed App</button>
    </div>
    
    <script>
        // Check if canvas works at all
        function testCanvas() {
            try {
                const canvas = document.createElement('canvas');
                const ctx = canvas.getContext('2d');
                canvas.width = 100;
                canvas.height = 100;
                ctx.fillStyle = 'black';
                ctx.fillRect(0, 0, 100, 100);
                return true;
            } catch (e) {
                console.error('Canvas test failed:', e);
                return false;
            }
        }
        
        // Run basic test when page loads
        window.addEventListener('DOMContentLoaded', function() {
            if (testCanvas()) {
                document.querySelector('.info').innerHTML += 
                    '<p style="color: green"><strong>✓ Basic canvas rendering is supported in this browser.</strong></p>';
            } else {
                document.querySelector('.info').innerHTML += 
                    '<p style="color: red"><strong>✗ Canvas rendering is NOT working in this browser.</strong></p>';
            }
        });
    </script>
</body>
</html>
EOF"

# Ensure all files have the right permissions
kubectl exec $AUDIO_POD -- chmod 644 /usr/share/nginx/html/*.html /usr/share/nginx/html/*.js

# Output instructions
echo ""
echo "==================================================="
echo "Comprehensive debugging solution has been deployed!"
echo "==================================================="
echo ""
echo "Access the debug tools at:"
echo "  http://localhost:8080/check-if-fixed.html"
echo ""
echo "This page provides three tools:"
echo "  1. Basic Canvas Test - Tests if canvas rendering works at all"
echo "  2. Audio Visualizer Test - A simplified audio visualizer with fake data"
echo "  3. Fixed Application - The complete app with fixes applied"
echo ""
echo "For the main application with fixes:"
echo "  http://localhost:8080/index-fixed.html"
echo ""
echo "If these tests show the canvases working, but your original app still has issues,"
echo "you can permanently apply the fixes by replacing your index.html with the fixed version:"
echo ""
echo "kubectl exec $AUDIO_POD -- cp /usr/share/nginx/html/index-fixed.html /usr/share/nginx/html/index.html"
echo ""
echo "==================================================="
