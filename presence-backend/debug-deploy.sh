#!/bin/bash
# Script to update your Kubernetes deployment with debug files

# Step 1: Create a directory for our files
echo "Creating temporary directory..."
mkdir -p ./audio-debug
cd ./audio-debug

# Step 2: Create the visualization test file
echo "Creating visualization test file..."
cat > visualization-test.html << 'EOL'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Audio Visualization Test</title>
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
        
        canvas {
            width: 100%;
            background-color: #000;
            margin-bottom: 20px;
            border-radius: 4px;
        }
        
        .visualizer-container {
            margin: 20px 0;
            border: 1px solid #ddd;
            border-radius: 4px;
            padding: 10px;
            background-color: #fafafa;
        }
        
        .info-panel {
            margin-top: 20px;
            padding: 10px;
            background-color: #fffde7;
            border-left: 4px solid #ffc107;
        }
        
        pre {
            background-color: #f5f5f5;
            padding: 10px;
            border-radius: 4px;
            overflow-x: auto;
        }
    </style>
</head>
<body>
    <h1>Audio Visualization Test</h1>
    
    <div class="description">
        <p>This page tests the audio visualization components to ensure they're rendering properly. 
           If you see animations in both visualizers, the rendering is working correctly.</p>
    </div>

    <div class="controls">
        <button id="testReal">Test with Microphone</button>
        <button id="testFake">Test with Fake Data</button>
        <button id="stopTest">Stop Test</button>
    </div>
    
    <div id="status">Status: Ready for testing</div>
    
    <div class="visualizer-container">
        <h2>Debug Visualizer</h2>
        <canvas id="debugVisualizer" height="100"></canvas>
    </div>
    
    <div class="visualizer-container">
        <h2>Audio Visualizer</h2>
        <canvas id="audioVisualizer" height="100"></canvas>
    </div>
    
    <div class="info-panel">
        <h2>Debug Information</h2>
        <div id="debug"></div>
    </div>
    
    <script>
        document.addEventListener('DOMContentLoaded', () => {
            const testRealButton = document.getElementById('testReal');
            const testFakeButton = document.getElementById('testFake');
            const stopTestButton = document.getElementById('stopTest');
            const statusElement = document.getElementById('status');
            const debugElement = document.getElementById('debug');
            
            // Make sure canvases have correct dimensions
            const debugCanvas = document.getElementById('debugVisualizer');
            const audioCanvas = document.getElementById('audioVisualizer');
            
            // Resize canvases to match their display size
            function resizeCanvas(canvas) {
                canvas.width = canvas.clientWidth;
                canvas.height = canvas.clientHeight;
            }
            
            resizeCanvas(debugCanvas);
            resizeCanvas(audioCanvas);
            window.addEventListener('resize', () => {
                resizeCanvas(debugCanvas);
                resizeCanvas(audioCanvas);
            });
            
            // Test with real microphone
            testRealButton.addEventListener('click', async () => {
                statusElement.textContent = 'Status: Testing with real microphone...';
                debugElement.innerHTML = '<p>Requesting microphone access...</p>';
                
                try {
                    // Check if browser supports getUserMedia
                    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
                        throw new Error("Your browser doesn't support getUserMedia API");
                    }
                    
                    // Request microphone access
                    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
                    
                    // Create audio context
                    const audioContext = new (window.AudioContext || window.webkitAudioContext)();
                    const sourceNode = audioContext.createMediaStreamSource(stream);
                    
                    // Create analyzer nodes (one for each visualizer)
                    const debugAnalyser = audioContext.createAnalyser();
                    debugAnalyser.fftSize = 2048;
                    sourceNode.connect(debugAnalyser);
                    
                    const audioAnalyser = audioContext.createAnalyser();
                    audioAnalyser.fftSize = 1024;
                    sourceNode.connect(audioAnalyser);
                    
                    // Get canvases
                    const debugCtx = debugCanvas.getContext('2d');
                    const audioCtx = audioCanvas.getContext('2d');
                    
                    // Create data arrays
                    const debugData = new Uint8Array(debugAnalyser.frequencyBinCount);
                    const audioData = new Uint8Array(audioAnalyser.frequencyBinCount);
                    
                    // Update status
                    statusElement.textContent = 'Status: Microphone connected, visualizing audio';
                    debugElement.innerHTML = '<p>Microphone access granted. Visualizing real audio data.</p>';
                    
                    // Disable start buttons, enable stop button
                    testRealButton.disabled = true;
                    testFakeButton.disabled = true;
                    stopTestButton.disabled = false;
                    
                    // Draw function for debug visualizer
                    function drawDebug() {
                        if (!testRealButton.disabled) return;
                        
                        debugAnalyser.getByteTimeDomainData(debugData);
                        
                        debugCtx.fillStyle = '#222';
                        debugCtx.fillRect(0, 0, debugCanvas.width, debugCanvas.height);
                        
                        debugCtx.lineWidth = 2;
                        debugCtx.strokeStyle = '#4CAF50';
                        debugCtx.beginPath();
                        
                        const sliceWidth = debugCanvas.width / debugData.length;
                        let x = 0;
                        
                        for (let i = 0; i < debugData.length; i++) {
                            const v = debugData[i] / 128.0;
                            const y = v * debugCanvas.height / 2;
                            
                            if (i === 0) {
                                debugCtx.moveTo(x, y);
                            } else {
                                debugCtx.lineTo(x, y);
                            }
                            
                            x += sliceWidth;
                        }
                        
                        debugCtx.lineTo(debugCanvas.width, debugCanvas.height / 2);
                        debugCtx.stroke();
                        
                        requestAnimationFrame(drawDebug);
                    }
                    
                    // Draw function for audio visualizer
                    function drawAudio() {
                        if (!testRealButton.disabled) return;
                        
                        audioAnalyser.getByteFrequencyData(audioData);
                        
                        audioCtx.fillStyle = '#000';
                        audioCtx.fillRect(0, 0, audioCanvas.width, audioCanvas.height);
                        
                        const barWidth = audioCanvas.width / audioData.length;
                        let x = 0;
                        
                        for (let i = 0; i < audioData.length; i++) {
                            const barHeight = (audioData[i] / 255) * audioCanvas.height;
                            
                            // Create gradient
                            const gradient = audioCtx.createLinearGradient(0, audioCanvas.height, 0, audioCanvas.height - barHeight);
                            gradient.addColorStop(0, '#4CAF50');
                            gradient.addColorStop(0.5, '#FFEB3B');
                            gradient.addColorStop(1, '#F44336');
                            
                            audioCtx.fillStyle = gradient;
                            audioCtx.fillRect(x, audioCanvas.height - barHeight, barWidth - 1, barHeight);
                            
                            x += barWidth;
                        }
                        
                        requestAnimationFrame(drawAudio);
                    }
                    
                    // Start drawing
                    drawDebug();
                    drawAudio();
                    
                    // Store cleanup function
                    window.stopVisualizers = () => {
                        stream.getTracks().forEach(track => track.stop());
                        audioContext.close();
                        testRealButton.disabled = false;
                        testFakeButton.disabled = false;
                        stopTestButton.disabled = true;
                        statusElement.textContent = 'Status: Test stopped';
                    };
                    
                } catch (error) {
                    console.error('Error:', error);
                    statusElement.textContent = `Status: Error - ${error.message}`;
                    debugElement.innerHTML = `<p>Error accessing microphone: ${error.message}</p>
                                            <pre>${error.stack || 'No stack trace available'}</pre>
                                            <p>Using fake data might work better for testing visualizers.</p>`;
                    
                    testRealButton.disabled = false;
                    testFakeButton.disabled = false;
                }
            });
            
            // Test with fake data
            testFakeButton.addEventListener('click', () => {
                statusElement.textContent = 'Status: Testing with fake audio data...';
                
                // Disable start buttons, enable stop button
                testRealButton.disabled = true;
                testFakeButton.disabled = true;
                stopTestButton.disabled = false;
                
                // Get canvases contexts
                const debugCtx = debugCanvas.getContext('2d');
                const audioCtx = audioCanvas.getContext('2d');
                
                // Create fake data
                const debugDataSize = 1024;
                const audioDataSize = 128;
                let time = 0;
                
                // Draw function for debug visualizer (fake waveform)
                function drawDebug() {
                    if (!testRealButton.disabled) return;
                    
                    debugCtx.fillStyle = '#222';
                    debugCtx.fillRect(0, 0, debugCanvas.width, debugCanvas.height);
                    
                    debugCtx.lineWidth = 2;
                    debugCtx.strokeStyle = '#4CAF50';
                    debugCtx.beginPath();
                    
                    const sliceWidth = debugCanvas.width / debugDataSize;
                    let x = 0;
                    
                    for (let i = 0; i < debugDataSize; i++) {
                        // Create a wave pattern with variation
                        const v = 0.5 + 
                                 0.2 * Math.sin(i / 10 + time) + 
                                 0.1 * Math.sin(i / 5 + time * 0.7);
                        
                        const y = v * debugCanvas.height;
                        
                        if (i === 0) {
                            debugCtx.moveTo(x, y);
                        } else {
                            debugCtx.lineTo(x, y);
                        }
                        
                        x += sliceWidth;
                    }
                    
                    debugCtx.stroke();
                    
                    // Draw a threshold line
                    debugCtx.strokeStyle = '#FF9800';
                    debugCtx.beginPath();
                    debugCtx.moveTo(0, debugCanvas.height * 0.7);
                    debugCtx.lineTo(debugCanvas.width, debugCanvas.height * 0.7);
                    debugCtx.stroke();
                    
                    // Add some text
                    debugCtx.fillStyle = '#FFF';
                    debugCtx.font = '12px Arial';
                    debugCtx.fillText('Energy: 0.42', 10, 20);
                    
                    time += 0.05;
                    requestAnimationFrame(drawDebug);
                }
                
                // Draw function for audio visualizer (fake spectrum)
                function drawAudio() {
                    if (!testRealButton.disabled) return;
                    
                    audioCtx.fillStyle = '#000';
                    audioCtx.fillRect(0, 0, audioCanvas.width, audioCanvas.height);
                    
                    const barWidth = audioCanvas.width / audioDataSize;
                    let x = 0;
                    
                    for (let i = 0; i < audioDataSize; i++) {
                        // Create a spectrum-like pattern
                        const barHeight = audioCanvas.height * (
                            0.1 + 0.4 * Math.sin(i / audioDataSize * Math.PI + time) * Math.sin(time * 0.2)
                        );
                        
                        // Create gradient
                        const gradient = audioCtx.createLinearGradient(0, audioCanvas.height, 0, audioCanvas.height - barHeight);
                        gradient.addColorStop(0, '#4CAF50');
                        gradient.addColorStop(0.5, '#FFEB3B');
                        gradient.addColorStop(1, '#F44336');
                        
                        audioCtx.fillStyle = gradient;
                        audioCtx.fillRect(x, audioCanvas.height - barHeight, barWidth - 1, barHeight);
                        
                        x += barWidth;
                    }
                    
                    time += 0.1;
                    requestAnimationFrame(drawAudio);
                }
                
                // Start drawing
                drawDebug();
                drawAudio();
                
                // Store cleanup function
                window.stopVisualizers = () => {
                    testRealButton.disabled = false;
                    testFakeButton.disabled = false;
                    stopTestButton.disabled = true;
                    statusElement.textContent = 'Status: Test stopped';
                };
                
                debugElement.innerHTML = '<p>Using fake data for visualization testing. If you see animations in both visualizers, the rendering is working correctly.</p>';
            });
            
            // Stop test
            stopTestButton.addEventListener('click', () => {
                if (window.stopVisualizers) {
                    window.stopVisualizers();
                }
            });
            
            // Initially disable stop button
            stopTestButton.disabled = true;
        });
    </script>
</body>
</html>
EOL

# Step 3: Create a fixed version of the audio detector with improved error handling
echo "Creating improved audio detector..."
cat > fixed-audio-detector.js << 'EOL'
/**
 * AudioEventDetector - A class for real-time audio event detection
 * Detects specific sound patterns like doorbells and knocking
 * 
 * FIXED VERSION WITH ENHANCED VISUALIZATION AND DEBUGGING
 */
class AudioEventDetector {
    constructor(options = {}) {
        // Configuration parameters
        this.options = {
            energyThreshold: 0.15,        // Threshold for audio energy to be considered an event
            eventThreshold: 0.6,          // Minimum confidence for event detection
            minEventDuration: 300,        // Minimum duration (ms) for an event to be valid
            debugVisualizer: false,       // Whether to show debug visualizer
            onEvent: null,                // Callback for detected events
            ...options
        };

        console.log("Audio Event Detector initialized with options:", this.options);

        // Audio context and processing nodes
        this.audioContext = null;
        this.analyserNode = null;
        this.sourceNode = null;
        this.stream = null;
        
        // Audio processing properties
        this.sampleRate = 0;
        this.fftSize = 2048;
        this.frequencyBinCount = 0;
        this.frequencyData = null;
        this.timeData = null;
        
        // Event detection
        this.eventModels = {};
        this.detectedEvents = [];
        this.isRecording = false;
        this.isInitialized = false;
        
        // State tracking
        this.energyHistory = [];
        this.energyHistorySize = 50;
        this.eventStartTime = null;
        this.currentEventType = null;
        this.lastEventTime = 0;
        this.cooldownPeriod = 1000; // 1 second cooldown between events
        
        // Debug visualization
        this.debugCanvas = null;
        this.debugContext = null;
        this.visualizerCanvas = null;
        this.visualizerContext = null;
        
        // Inject test data for visualizer (to ensure it can render)
        this._useTestData = false;
    }

    /**
     * Initialize the audio context and request microphone access
     */
    async initialize() {
        try {
            console.log("Initializing audio context and requesting microphone access...");
            
            // Set up audio context
            this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
            this.sampleRate = this.audioContext.sampleRate;
            console.log("Audio context created, sample rate:", this.sampleRate);
            
            // Request microphone access - with detailed error handling
            try {
                this.stream = await navigator.mediaDevices.getUserMedia({ 
                    audio: {
                        echoCancellation: true,
                        noiseSuppression: true,
                        autoGainControl: true
                    },
                    video: false 
                });
                console.log("Microphone access granted");
            } catch (micError) {
                console.error("Microphone access error:", micError.name, micError.message);
                
                if (micError.name === 'NotAllowedError') {
                    console.log("Permission denied - using test data instead");
                    this._useTestData = true;
                } else {
                    // Rethrow for other errors
                    throw micError;
                }
            }
            
            if (!this._useTestData) {
                // Create source node from microphone
                this.sourceNode = this.audioContext.createMediaStreamSource(this.stream);
            
                // Create analyzer node for frequency data
                this.analyserNode = this.audioContext.createAnalyser();
                this.analyserNode.fftSize = this.fftSize;
                this.analyserNode.smoothingTimeConstant = 0.5;
                
                // Connect the source to the analyzer
                this.sourceNode.connect(this.analyserNode);
                
                // Set up frequency data arrays
                this.frequencyBinCount = this.analyserNode.frequencyBinCount;
                this.frequencyData = new Uint8Array(this.frequencyBinCount);
                this.timeData = new Uint8Array(this.fftSize);
            } else {
                console.log("Using test data for visualization and detection");
                // Create fake data for testing
                this.frequencyBinCount = 1024;
                this.frequencyData = new Uint8Array(this.frequencyBinCount);
                this.timeData = new Uint8Array(this.fftSize);
                
                // Fill with random initial data
                this._generateTestData();
            }
            
            // Initialize debug visualizer if enabled
            if (this.options.debugVisualizer) {
                this.debugCanvas = document.getElementById('debugVisualizer');
                if (this.debugCanvas) {
                    console.log("Debug visualizer canvas found");
                    this.debugContext = this.debugCanvas.getContext('2d');
                    
                    // Ensure proper size
                    this.debugCanvas.width = this.debugCanvas.clientWidth;
                    this.debugCanvas.height = this.debugCanvas.clientHeight;
                } else {
                    console.warn("Debug visualizer canvas not found");
                }
            }
            
            // Initialize audio visualizer
            this.visualizerCanvas = document.getElementById('audioVisualizer');
            if (this.visualizerCanvas) {
                console.log("Audio visualizer canvas found");
                this.visualizerContext = this.visualizerCanvas.getContext('2d');
                
                // Ensure proper size
                this.visualizerCanvas.width = this.visualizerCanvas.clientWidth;
                this.visualizerCanvas.height = this.visualizerCanvas.clientHeight;
            } else {
                console.warn("Audio visualizer canvas not found");
            }
            
            this.isInitialized = true;
            return true;
        } catch (error) {
            console.error('AudioEventDetector initialization failed:', error);
            return false;
        }
    }

    /**
     * Generate test data for visualization when microphone is not available
     */
    _generateTestData() {
        // For frequency data (spectrum)
        for (let i = 0; i < this.frequencyData.length; i++) {
            // Create a curve with higher values in the mid-range
            const normalizedPosition = i / this.frequencyData.length;
            const value = Math.sin(normalizedPosition * Math.PI) * 127 + 
                          Math.random() * 50 + 60;
            this.frequencyData[i] = Math.min(255, Math.max(0, value));
        }
        
        // For time data (waveform)
        for (let i = 0; i < this.timeData.length; i++) {
            // Create a sine wave with some noise
            const value = Math.sin(i / 20) * 40 + 128 + (Math.random() * 10);
            this.timeData[i] = Math.min(255, Math.max(0, value));
        }
        
        // Add some variation over time for the test data
        if (this._testTime === undefined) {
            this._testTime = 0;
        }
        this._testTime += 0.05;
    }

    /**
     * Add an event detection model
     * @param {string} eventType - Type of event (e.g., 'doorbell', 'knocking')
     * @param {function} modelFn - Function that evaluates audio data and returns confidence
     */
    addEventModel(eventType, modelFn) {
        if (typeof modelFn === 'function') {
            this.eventModels[eventType] = modelFn;
            console.log(`Added event model for ${eventType}`);
        }
    }

    /**
     * Start audio event detection
     */
    start() {
        if (!this.isInitialized) {
            console.error('AudioEventDetector not initialized');
            return false;
        }
        
        console.log("Starting audio event detection");
        this.isRecording = true;
        this.processAudio();
        return true;
    }

    /**
     * Stop audio event detection
     */
    stop() {
        console.log("Stopping audio event detection");
        this.isRecording = false;
        // Clear any in-progress events
        this.eventStartTime = null;
        this.currentEventType = null;
    }

    /**
     * Process audio data and detect events
     */
    processAudio() {
        if (!this.isRecording) return;
        
        if (!this._useTestData) {
            // Get frequency domain data
            this.analyserNode.getByteFrequencyData(this.frequencyData);
            // Get time domain data
            this.analyserNode.getByteTimeDomainData(this.timeData);
        } else {
            // Update test data
            this._generateTestData();
        }
        
        // Calculate audio energy (magnitude)
        const energy = this.calculateEnergy(this.timeData);
        this.trackEnergy(energy);
        
        // Check if energy exceeds threshold
        if (energy > this.options.energyThreshold) {
            // If we're not already tracking an event, start a new one
            if (!this.eventStartTime) {
                this.eventStartTime = Date.now();
                this.bestEventType = null;
                this.bestConfidence = 0;
            }
            
            // Evaluate all event models to find the best match
            Object.entries(this.eventModels).forEach(([eventType, modelFn]) => {
                const confidence = modelFn(this.frequencyData, this.timeData, this);
                
                if (confidence > this.bestConfidence && confidence >= this.options.eventThreshold) {
                    this.bestEventType = eventType;
                    this.bestConfidence = confidence;
                }
            });
        } else {
            // If energy drops below threshold and we were tracking an event
            if (this.eventStartTime) {
                const now = Date.now();
                const duration = now - this.eventStartTime;
                
                // Check if the event meets minimum duration and confidence requirements
                if (this.bestEventType && 
                    duration >= this.options.minEventDuration && 
                    now - this.lastEventTime > this.cooldownPeriod) {
                    
                    // Create event object
                    const eventObj = {
                        type: this.bestEventType,
                        confidence: this.bestConfidence,
                        timestamp: new Date(),
                        duration: duration
                    };
                    
                    console.log("Event detected:", eventObj);
                    
                    // Add to detected events
                    this.detectedEvents.push(eventObj);
                    this.lastEventTime = now;
                    
                    // Call event callback
                    if (typeof this.options.onEvent === 'function') {
                        this.options.onEvent([eventObj], this.frequencyData.slice());
                    }
                }
                
                // Reset event tracking
                this.eventStartTime = null;
                this.bestEventType = null;
                this.bestConfidence = 0;
            }
        }
        
        // Draw visualizations
        this.drawVisualizations();
        
        // Continue processing
        requestAnimationFrame(() => this.processAudio());
    }

    /**
     * Calculate audio energy from time domain data
     */
    calculateEnergy(timeData) {
        let sum = 0;
        const length = timeData.length;
        
        // Calculate sum of squared differences from the center value (128)
        for (let i = 0; i < length; i++) {
            const value = (timeData[i] - 128) / 128.0;
            sum += value * value;
        }
        
        return Math.sqrt(sum / length);
    }

    /**
     * Track energy levels over time
     */
    trackEnergy(energy) {
        this.energyHistory.push(energy);
        if (this.energyHistory.length > this.energyHistorySize) {
            this.energyHistory.shift();
        }
    }

    /**
     * Get the average energy level
     */
    getAverageEnergy() {
        if (this.energyHistory.length === 0) return 0;
        
        const sum = this.energyHistory.reduce((a, b) => a + b, 0);
        return sum / this.energyHistory.length;
    }

    /**
     * Draw visualizations (both debug and audio)
     */
    drawVisualizations() {
        // Draw debug visualization if enabled
        if (this.debugContext) {
            this.drawDebugVisualizer();
        }
        
        // Draw audio spectrum visualization
        if (this.visualizerContext) {
            this.drawAudioVisualizer();
        }
    }

    /**
     * Draw debug visualization
     */
    drawDebugVisualizer() {
        const canvas = this.debugCanvas;
        const ctx = this.debugContext;
        const width = canvas.width;
        const height = canvas.height;
        
        // Clear canvas with dark background
        ctx.fillStyle = '#222';
        ctx.fillRect(0, 0, width, height);
        
        // Draw energy threshold line
        ctx.strokeStyle = '#FF9800';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(0, height - (this.options.energyThreshold * height));
        ctx.lineTo(width, height - (this.options.energyThreshold * height));
        ctx.stroke();
        
        // Label the threshold line
        ctx.fillStyle = '#FF9800';
        ctx.font = '10px Arial';
        ctx.fillText(`Threshold: ${this.options.energyThreshold.toFixed(2)}`, 5, height - (this.options.energyThreshold * height) - 5);
        
        // Draw energy history
        ctx.strokeStyle = '#4CAF50';
        ctx.lineWidth = 2;
        ctx.beginPath();
        
        const step = width / (this.energyHistorySize - 1);
        
        for (let i = 0; i < this.energyHistory.length; i++) {
            const x = i * step;
            const y = height - (this.energyHistory[i] * height);
            
            if (i === 0) {
                ctx.moveTo(x, y);
            } else {
                ctx.lineTo(x, y);
            }
        }
        
        ctx.stroke();
        
        // Display current energy value
        const currentEnergy = this.energyHistory.length > 0 ? 
            this.energyHistory[this.energyHistory.length - 1] : 0;
        
        ctx.fillStyle = '#FFF';
        ctx.font = '12px Arial';
        ctx.fillText(`Energy: ${currentEnergy.toFixed(3)}`, 5, 15);
        
        // Draw event status
        if (this.eventStartTime) {
            ctx.fillStyle = 'rgba(244, 67, 54, 0.3)';
            ctx.fillRect(0, 0, width, height);
            
            if (this.bestEventType) {
                ctx.fillStyle = '#FFF';
                ctx.font = '14px Arial';
                ctx.fillText(`${this.bestEventType} (${Math.round(this.bestConfidence * 100)}%)`, 5, 35);
            }
        }
    }

    /**
     * Draw audio spectrum visualization
     */
    drawAudioVisualizer() {
        const canvas = this.visualizerCanvas;
        const ctx = this.visualizerContext;
        const width = canvas.width;
        const height = canvas.height;
        
        // Clear canvas with dark background
        ctx.fillStyle = '#000';
        ctx.fillRect(0, 0, width, height);
        
        // Draw frequency bars
        const barWidth = width / this.frequencyData.length;
        
        for (let i = 0; i < this.frequencyData.length; i++) {
            const barHeight = (this.frequencyData[i] / 255) * height;
            
            // Create gradient
            const gradient = ctx.createLinearGradient(0, height, 0, height - barHeight);
            gradient.addColorStop(0, '#4CAF50');
            gradient.addColorStop(0.5, '#FFEB3B');
            gradient.addColorStop(1, '#F44336');
            
            ctx.fillStyle = gradient;
            ctx.fillRect(i * barWidth, height - barHeight, barWidth - 1, barHeight);
        }
        
        // Add a visual indicator when events are detected
        if (this.eventStartTime) {
            ctx.strokeStyle = '#FFFFFF';
            ctx.lineWidth = 2;
            ctx.strokeRect(0, 0, width, height);
            
            if (this.bestEventType) {
                ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
                ctx.font = 'bold 16px Arial';
                ctx.textAlign = 'center';
                ctx.fillText(`${this.bestEventType} detected`, width / 2, height / 2);
            }
        }
    }
}

/**
 * Create a doorbell detector model
 * Doorbell sounds typically have strong frequency components in the 500-2000 Hz range
 * and have a periodic pattern
 */
function createDoorbellDetector() {
    // Frequency ranges for doorbell detection (in Hz)
    const doorbellRanges = [
        { min: 500, max: 800, weight: 0.4 },    // Lower component
        { min: 1000, max: 2000, weight: 0.6 }   // Higher component
    ];
    
    // Map frequency bin indices
    const mapFrequencyRanges = (ranges, sampleRate, binCount) => {
        return ranges.map(range => {
            const minBin = Math.floor(range.min * binCount / (sampleRate / 2));
            const maxBin = Math.floor(range.max * binCount / (sampleRate / 2));
            return { ...range, minBin, maxBin };
        });
    };
    
    // Ring buffer to detect periodicity
    const historySize = 8;
    const energyHistory = Array(historySize).fill(0);
    let historyIndex = 0;
    
    // Previous frame data for comparison
    let prevFrameData = null;
    
    return (frequencyData, timeData, detector) => {
        const binCount = frequencyData.length;
        const sampleRate = detector.sampleRate || 44100; // Default if not set
        
        // Map frequency ranges to bin indices
        const ranges = mapFrequencyRanges(doorbellRanges, sampleRate, binCount);
        
        // Check energy levels in doorbell frequency ranges
        let totalEnergy = 0;
        let weightedEnergy = 0;
        
        ranges.forEach(range => {
            let rangeEnergy = 0;
            
            for (let i = range.minBin; i <= range.maxBin && i < binCount; i++) {
                rangeEnergy += frequencyData[i] / 255.0;
            }
            
            const binCount = Math.min(range.maxBin, binCount - 1) - range.minBin + 1;
            if (binCount > 0) {
                rangeEnergy /= binCount;
                weightedEnergy += rangeEnergy * range.weight;
                totalEnergy += rangeEnergy;
            }
        });
        
        if (ranges.length > 0) {
            totalEnergy /= ranges.length;
        }
        
        // Store energy in history buffer
        energyHistory[historyIndex] = totalEnergy;
        historyIndex = (historyIndex + 1) % historySize;
        
        // Calculate periodicity by looking for repeating patterns
        let periodicityScore = 0;
        
        // Look for every 2-3 frame pattern, typical of doorbells
        for (let offset = 2; offset <= 3; offset++) {
            let patternScore = 0;
            
            for (let i = 0; i < historySize; i++) {
                const j = (i + offset) % historySize;
                
                // High values followed by low values is characteristic of doorbells
                if (energyHistory[i] > 0.3 && energyHistory[j] > 0.3) {
                    patternScore += 0.1;
                }
            }
            
            periodicityScore = Math.max(periodicityScore, patternScore);
        }
        
        // Calculate frame-to-frame difference to detect ringing
        let frameChangeScore = 0;
        
        if (prevFrameData) {
            let diffSum = 0;
            
            for (let i = 0; i < timeData.length; i++) {
                diffSum += Math.abs(timeData[i] - prevFrameData[i]) / 255.0;
            }
            
            const avgDiff = diffSum / timeData.length;
            
            // Moderate changes are characteristic of ringing sounds
            if (avgDiff > 0.05 && avgDiff < 0.3) {
                frameChangeScore = 0.3;
            }
        }
        
        // Store current frame for next comparison
        prevFrameData = timeData.slice();
        
        // Final confidence score (weighted average of components)
        const confidence = weightedEnergy * 0.5 + periodicityScore * 0.3 + frameChangeScore * 0.2;
        
        return Math.min(confidence, 1.0);
    };
}

/**
 * Create a knocking detector model
 * Knocking sounds typically have strong transients and low-frequency components
 */
function createKnockingDetector() {
    // Frequency ranges for knock detection (in Hz)
    const knockRanges = [
        { min: 50, max: 200, weight: 0.6 },    // Low frequencies (thud)
        { min: 200, max: 800, weight: 0.4 }    // Mid frequencies (impact)
    ];
    
    // Map frequency bin indices
    const mapFrequencyRanges = (ranges, sampleRate, binCount) => {
        return ranges.map(range => {
            const minBin = Math.floor(range.min * binCount / (sampleRate / 2));
            const maxBin = Math.floor(range.max * binCount / (sampleRate / 2));
            return { ...range, minBin, maxBin };
        });
    };
    
    // Ring buffer to detect knock patterns
    const historySize = 10;
    const energyHistory = Array(historySize).fill(0);
    let historyIndex = 0;
    
    // State tracking
    let lastKnockTime = 0;
    let knockCount = 0;
    
    return (frequencyData, timeData, detector) => {
        const binCount = frequencyData.length;
        const sampleRate = detector.sampleRate || 44100; // Default if not set
        
        // Map frequency ranges to bin indices
        const ranges = mapFrequencyRanges(knockRanges, sampleRate, binCount);
        
        // Check energy levels in knock frequency ranges
        let totalEnergy = 0;
        let weightedEnergy = 0;
        
        ranges.forEach(range => {
            let rangeEnergy = 0;
            
            for (let i = range.minBin; i <= range.maxBin && i < binCount; i++) {
                rangeEnergy += frequencyData[i] / 255.0;
            }
            
            const binCount = Math.min(range.maxBin, binCount - 1) - range.minBin + 1;
            if (binCount > 0) {
                rangeEnergy /= binCount;
                weightedEnergy += rangeEnergy * range.weight;
                totalEnergy += rangeEnergy;
            }
        });
        
        if (ranges.length > 0) {
            totalEnergy /= ranges.length;
        }
        
        // Store energy in history buffer
        const currentEnergy = totalEnergy;
        const prevEnergy = energyHistory[historyIndex];
        energyHistory[historyIndex] = currentEnergy;
        historyIndex = (historyIndex + 1) % historySize;
        
        // Check for sharp transient (rapid energy increase)
        const isTransient = currentEnergy > (prevEnergy * 2.0 || 0) && currentEnergy > 0.3;
        
        // Track knocks
        const now = Date.now();
        
        if (isTransient) {
            // If this is a new knock (not right after the last one)
            if (now - lastKnockTime > 200) {
                knockCount++;
                lastKnockTime = now;
            }
        }
        
        // Reset knock count if it's been too long since the last knock
        if (now - lastKnockTime > 2000) {
            knockCount = 0;
        }
        
        // Calculate knock pattern score
        // Higher score for 2-4 knocks in sequence
        let patternScore = 0;
        
        if (knockCount >= 2 && knockCount <= 4) {
            patternScore = 0.3;
        }
        
        // Calculate transient sharpness
        // Analyze how quickly the energy rises (sharp rise is characteristic of knocks)
        let transientScore = 0;
        
        if (isTransient) {
            transientScore = 0.5;
        }
        
        // Final confidence score (weighted average of components)
        const confidence = weightedEnergy * 0.4 + transientScore * 0.4 + patternScore * 0.2;
        
        return Math.min(confidence, 1.0);
    };
}
EOL

# Step 4: Create a simple debug page that works 100% locally
echo "Creating a simple debug page..."
cat > debug.html << 'EOL'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Canvas Debug Test</title>
    <style>
        body { font-family: Arial; margin: 20px; }
        canvas { border: 1px solid #333; margin: 10px 0; }
        button { padding: 10px; margin: 5px; }
    </style>
</head>
<body>
    <h1>Canvas Rendering Test</h1>
    <p>This is a minimal test to see if canvas rendering works on this server.</p>
    
    <canvas id="testCanvas" width="400" height="200"></canvas>
    
    <div>
        <button id="testButton">Draw Test Pattern</button>
        <button id="animateButton">Animate Test</button>
        <button id="stopButton">Stop Animation</button>
    </div>
    
    <div id="status">Click a button to start the test</div>
    
    <script>
        // Get elements
        const canvas = document.getElementById('testCanvas');
        const ctx = canvas.getContext('2d');
        const testButton = document.getElementById('testButton');
        const animateButton = document.getElementById('animateButton');
        const stopButton = document.getElementById('stopButton');
        const statusElement = document.getElementById('status');
        
        // Animation variables
        let animating = false;
        let animationTime = 0;
        
        // Draw a test pattern
        function drawTestPattern() {
            // Clear canvas
            ctx.fillStyle = '#222';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            
            // Draw gradient rectangle
            const gradient = ctx.createLinearGradient(0, 0, canvas.width, 0);
            gradient.addColorStop(0, 'red');
            gradient.addColorStop(0.5, 'green');
            gradient.addColorStop(1, 'blue');
            
            ctx.fillStyle = gradient;
            ctx.fillRect(50, 50, canvas.width - 100, canvas.height - 100);
            
            // Draw text
            ctx.fillStyle = 'white';
            ctx.font = '20px Arial';
            ctx.textAlign = 'center';
            ctx.fillText('Canvas Rendering Works!', canvas.width / 2, canvas.height / 2);
            
            statusElement.textContent = 'Test pattern drawn successfully!';
        }
        
        // Animate the canvas
        function animate() {
            if (!animating) return;
            
            // Clear canvas
            ctx.fillStyle = '#222';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            
            // Draw animated pattern
            for (let i = 0; i < 5; i++) {
                const x = Math.sin(animationTime + i) * 50 + canvas.width / 2;
                const y = Math.cos(animationTime + i) * 50 + canvas.height / 2;
                const radius = 20 + Math.sin(animationTime * 2) * 10;
                
                ctx.beginPath();
                ctx.arc(x, y, radius, 0, Math.PI * 2);
                ctx.fillStyle = `hsl(${(animationTime * 50 + i * 50) % 360}, 100%, 50%)`;
                ctx.fill();
            }
            
            // Update time
            animationTime += 0.05;
            
            // Continue animation
            requestAnimationFrame(animate);
        }
        
        // Add event listeners
        testButton.addEventListener('click', drawTestPattern);
        
        animateButton.addEventListener('click', () => {
            animating = true;
            animationTime = 0;
            animate();
            statusElement.textContent = 'Animation running - canvas is working!';
        });
        
        stopButton.addEventListener('click', () => {
            animating = false;
            statusElement.textContent = 'Animation stopped';
        });
    </script>
</body>
</html>
EOL

# Step 5: Update Kubernetes deployment with these files
echo "Creating ConfigMap with debug files..."
kubectl delete configmap audio-detection-files 2>/dev/null || true
kubectl create configmap audio-detection-files --from-file=visualization-test.html --from-file=debug.html --from-file=fixed-audio-detector.js

# Step 6: Update the deployment to include all files
echo "Updating deployment..."
cat > deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: audio-detection-app
  labels:
    app: audio-detection
spec:
  replicas: 1
  selector:
    matchLabels:
      app: audio-detection
  template:
    metadata:
      labels:
        app: audio-detection
    spec:
      containers:
      - name: audio-detection
        image: nginx:alpine
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        volumeMounts:
        - name: app-files
          mountPath: /usr/share/nginx/html
      volumes:
      - name: app-files
        configMap:
          name: audio-detection-files
---
apiVersion: v1
kind: Service
metadata:
  name: audio-detection-service
spec:
  selector:
    app: audio-detection
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: audio-detection-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
  - host: audio-detection.talkstudio.space
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: audio-detection-service
            port:
              number: 80
EOF

# Apply new configuration
echo "Applying updated configuration..."
kubectl apply -f deployment.yaml

# Wait for deployment to roll out
echo "Waiting for deployment to roll out..."
kubectl rollout status deployment/audio-detection-app

# Get pod name for port-forwarding
POD_NAME=$(kubectl get pods -l app=audio-detection -o jsonpath='{.items[0].metadata.name}')

echo ""
echo "===================================================="
echo "Setup complete! To test your deployment:"
echo ""
echo "1. Access the debug page first:"
echo "   kubectl port-forward $POD_NAME 8080:80"
echo "   Then open: http://localhost:8080/debug.html"
echo ""
echo "2. If that works, try the visualization test page:"
echo "   http://localhost:8080/visualization-test.html"
echo ""
echo "3. Use the fixed audio detector in your main app:"
echo "   Import the file as: /fixed-audio-detector.js"
echo "===================================================="
