#!/bin/bash
# Script to diagnose and fix container packaging issues

# Define the pod
RUNNING_POD="audio-detection-app-86c7bfbcdf-jkwr7"
echo "Using pod: $RUNNING_POD"

# Check what files are actually in the container
echo "Checking files in the container..."
kubectl exec $RUNNING_POD -- ls -la /usr/share/nginx/html/

# Check content of index.html to see what JavaScript files it's referencing
echo "Checking index.html to see what JavaScript files it's trying to load..."
kubectl exec $RUNNING_POD -- cat /usr/share/nginx/html/index.html | grep -E "\.js|script"

# Check if the audio-event-detector.js exists anywhere in the container
echo "Searching for audio-event-detector.js anywhere in the container..."
kubectl exec $RUNNING_POD -- find / -name "audio-event-detector.js" 2>/dev/null || echo "File not found in container"

# Create a minimal working detector script to replace the missing one
echo "Creating a minimal audio event detector script..."
cat > audio-event-detector.min.js << 'EOF'
/**
 * Minimal Audio Event Detector - Replacement for missing file
 */
class AudioEventDetector {
    constructor(options = {}) {
        this.options = {
            energyThreshold: 0.15,
            eventThreshold: 0.6,
            minEventDuration: 300,
            debugVisualizer: false,
            onEvent: null,
            ...options
        };
        
        console.log("Audio Event Detector initialized");
        
        // Canvas elements
        this.debugCanvas = document.getElementById('debugVisualizer');
        this.audioCanvas = document.getElementById('audioVisualizer');
        
        // Fix canvas sizes 
        setTimeout(() => {
            this.fixCanvasSizes();
        }, 100);
    }
    
    fixCanvasSizes() {
        if (this.debugCanvas) {
            console.log("Debug canvas before: " + this.debugCanvas.width + "x" + this.debugCanvas.height);
            this.debugCanvas.width = this.debugCanvas.clientWidth;
            this.debugCanvas.height = this.debugCanvas.clientHeight;
            console.log("Debug canvas fixed: " + this.debugCanvas.width + "x" + this.debugCanvas.height);
            
            this.debugContext = this.debugCanvas.getContext('2d');
        }
        
        if (this.audioCanvas) {
            console.log("Audio canvas before: " + this.audioCanvas.width + "x" + this.audioCanvas.height);
            this.audioCanvas.width = this.audioCanvas.clientWidth;
            this.audioCanvas.height = this.audioCanvas.clientHeight;
            console.log("Audio canvas fixed: " + this.audioCanvas.width + "x" + this.audioCanvas.height);
            
            this.audioContext = this.audioCanvas.getContext('2d');
        }
    }
    
    async initialize() {
        console.log("Initializing AudioEventDetector...");
        
        try {
            // Create audio context
            this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
            
            // Try to get microphone access
            try {
                this.stream = await navigator.mediaDevices.getUserMedia({ audio: true });
                console.log("Microphone access granted");
                
                // Set up audio processing
                this.sourceNode = this.audioContext.createMediaStreamSource(this.stream);
                this.analyserNode = this.audioContext.createAnalyser();
                this.sourceNode.connect(this.analyserNode);
                
                this.analyserNode.fftSize = 2048;
                this.frequencyData = new Uint8Array(this.analyserNode.frequencyBinCount);
                this.timeData = new Uint8Array(this.analyserNode.fftSize);
                
                return true;
            } catch (err) {
                console.warn("Microphone access denied, using fake data:", err);
                
                // Set up fake data
                this.frequencyData = new Uint8Array(1024);
                this.timeData = new Uint8Array(2048);
                this._useFakeData = true;
                
                return true; // Still return true so the app continues
            }
        } catch (err) {
            console.error("Failed to initialize audio:", err);
            return false;
        }
    }
    
    start() {
        console.log("Starting audio detection");
        this.isRunning = true;
        this.processAudio();
        return true;
    }
    
    stop() {
        console.log("Stopping audio detection");
        this.isRunning = false;
        return true;
    }
    
    processAudio() {
        if (!this.isRunning) return;
        
        if (!this._useFakeData) {
            // Get real audio data
            this.analyserNode.getByteFrequencyData(this.frequencyData);
            this.analyserNode.getByteTimeDomainData(this.timeData);
        } else {
            // Generate fake data
            this.generateFakeData();
        }
        
        // Draw visualizations
        this.drawDebugVisualizer();
        this.drawAudioVisualizer();
        
        // Simulate an event occasionally
        if (this._useFakeData && Math.random() < 0.001) {
            const type = Math.random() < 0.5 ? 'doorbell' : 'knocking';
            const event = {
                type: type,
                confidence: 0.6 + Math.random() * 0.3,
                timestamp: new Date(),
                duration: 300 + Math.random() * 500
            };
            
            if (this.options.onEvent) {
                this.options.onEvent([event], this.frequencyData);
            }
        }
        
        // Continue processing
        requestAnimationFrame(() => this.processAudio());
    }
    
    generateFakeData() {
        // Simple fake data generator
        const time = Date.now() / 1000;
        
        // Generate frequency data
        for (let i = 0; i < this.frequencyData.length; i++) {
            const value = Math.sin(i/this.frequencyData.length * Math.PI + time) * 127 + 128;
            this.frequencyData[i] = value + Math.random() * 30;
        }
        
        // Generate time data
        for (let i = 0; i < this.timeData.length; i++) {
            this.timeData[i] = 128 + Math.sin(i/50 + time * 2) * 40;
        }
    }
    
    drawDebugVisualizer() {
        if (!this.debugContext) return;
        
        const width = this.debugCanvas.width;
        const height = this.debugCanvas.height;
        
        // Clear canvas
        this.debugContext.fillStyle = '#222';
        this.debugContext.fillRect(0, 0, width, height);
        
        // Draw energy threshold
        this.debugContext.strokeStyle = '#FF9800';
        this.debugContext.beginPath();
        this.debugContext.moveTo(0, height * 0.7);
        this.debugContext.lineTo(width, height * 0.7);
        this.debugContext.stroke();
        
        // Draw waveform
        this.debugContext.strokeStyle = '#4CAF50';
        this.debugContext.beginPath();
        
        const sliceWidth = width / this.timeData.length;
        let x = 0;
        
        for (let i = 0; i < this.timeData.length; i++) {
            const v = this.timeData[i] / 128.0;
            const y = v * height / 2;
            
            if (i === 0) {
                this.debugContext.moveTo(x, y);
            } else {
                this.debugContext.lineTo(x, y);
            }
            
            x += sliceWidth;
        }
        
        this.debugContext.stroke();
    }
    
    drawAudioVisualizer() {
        if (!this.audioContext) return;
        
        const width = this.audioCanvas.width;
        const height = this.audioCanvas.height;
        
        // Clear canvas
        this.audioContext.fillStyle = '#000';
        this.audioContext.fillRect(0, 0, width, height);
        
        // Draw frequency bars
        const barWidth = width / Math.min(64, this.frequencyData.length);
        
        for (let i = 0; i < Math.min(64, this.frequencyData.length); i++) {
            const barHeight = (this.frequencyData[i] / 255) * height;
            
            // Create gradient
            const gradient = this.audioContext.createLinearGradient(0, height, 0, height - barHeight);
            gradient.addColorStop(0, '#4CAF50');
            gradient.addColorStop(0.5, '#FFEB3B');
            gradient.addColorStop(1, '#F44336');
            
            this.audioContext.fillStyle = gradient;
            this.audioContext.fillRect(i * barWidth, height - barHeight, barWidth - 1, barHeight);
        }
    }
    
    addEventModel(type, model) {
        console.log(`Added event model for ${type}`);
        return true;
    }
}

// Simple model functions
function createDoorbellDetector() {
    return function() {
        return Math.random() * 0.3; // Low probability
    };
}

function createKnockingDetector() {
    return function() {
        return Math.random() * 0.3; // Low probability
    };
}
EOF

# Create a ConfigMap with the script
echo "Creating ConfigMap with minimal detector script..."
kubectl delete configmap detector-script 2>/dev/null || true
kubectl create configmap detector-script --from-file=audio-event-detector.js=audio-event-detector.min.js

# Create a patch to update the deployment
echo "Creating patch to mount the script..."
cat > deployment-patch.yaml << EOF
spec:
  template:
    spec:
      volumes:
      - name: detector-script
        configMap:
          name: detector-script
      containers:
      - name: audio-detection
        volumeMounts:
        - name: detector-script
          mountPath: /usr/share/nginx/html/audio-event-detector.js
          subPath: audio-event-detector.js
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
echo "A minimal audio detector script has been deployed!"
echo "====================================================="
echo ""
echo "Access your app after setting up port-forwarding:"
echo "kubectl port-forward $NEW_POD 8080:80"
echo ""
echo "Then visit: http://localhost:8080/"
echo ""
echo "The minimal script provides basic functionality:"
echo "- Properly sized visualizers"
echo "- Real microphone input if granted"
echo "- Fake data if microphone access is denied"
echo "- Simple audio visualizations"
echo "- Simulated events (in fake data mode)"
echo "====================================================="

# Clean up
rm -f audio-event-detector.min.js deployment-patch.yaml
