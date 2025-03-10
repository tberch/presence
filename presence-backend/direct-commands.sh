#!/bin/bash
# Direct command approach to fix canvas visualization

# Use the running pod
RUNNING_POD="audio-detection-app-86c7bfbcdf-jkwr7"
echo "Using pod: $RUNNING_POD"

# Create a simple one-file solution we can apply directly
echo "Creating a self-contained HTML test file..."
cat > canvas-test.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Canvas Test</title>
    <style>
        body { font-family: Arial; margin: 20px; }
        .container { border: 1px solid #ddd; padding: 15px; margin: 15px 0; border-radius: 4px; }
        canvas { border: 1px solid red; margin: 10px 0; display: block; width: 100%; height: 100px; }
        button { padding: 10px; background: #4CAF50; color: white; border: none; border-radius: 4px; margin: 5px; }
        #log { font-family: monospace; height: 150px; overflow: auto; background: #f5f5f5; padding: 10px; margin: 10px 0; }
    </style>
</head>
<body>
    <h1>Canvas Visualization Test</h1>
    <div id="log">Debug info will appear here...</div>
    
    <div class="container">
        <h2>Test Canvas</h2>
        <canvas id="testCanvas"></canvas>
        <div>
            <button onclick="testCanvas()">Test Canvas</button>
            <button onclick="animate()">Animate</button>
            <button onclick="stopAnimation()">Stop Animation</button>
        </div>
    </div>
    
    <script>
        const logElem = document.getElementById('log');
        let animationId = null;
        
        function log(msg) {
            console.log(msg);
            logElem.innerHTML += msg + '<br>';
            logElem.scrollTop = logElem.scrollHeight;
        }
        
        function clearLog() {
            logElem.innerHTML = '';
        }
        
        function testCanvas() {
            const canvas = document.getElementById('testCanvas');
            
            log('Canvas initial size: ' + canvas.width + 'x' + canvas.height);
            log('Canvas client size: ' + canvas.clientWidth + 'x' + canvas.clientHeight);
            
            // Set proper size
            canvas.width = canvas.clientWidth;
            canvas.height = canvas.clientHeight;
            
            log('Canvas resized to: ' + canvas.width + 'x' + canvas.height);
            
            // Get context and draw
            const ctx = canvas.getContext('2d');
            
            // Clear
            ctx.fillStyle = '#222';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            
            // Draw gradient
            const gradient = ctx.createLinearGradient(0, 0, canvas.width, 0);
            gradient.addColorStop(0, 'red');
            gradient.addColorStop(0.5, 'green');
            gradient.addColorStop(1, 'blue');
            
            ctx.fillStyle = gradient;
            ctx.fillRect(20, 20, canvas.width - 40, canvas.height - 40);
            
            // Text
            ctx.fillStyle = 'white';
            ctx.font = '20px Arial';
            ctx.textAlign = 'center';
            ctx.fillText('Canvas is working!', canvas.width/2, canvas.height/2);
            
            log('Canvas rendering complete');
        }
        
        function animate() {
            if (animationId) return;
            
            const canvas = document.getElementById('testCanvas');
            const ctx = canvas.getContext('2d');
            
            // Ensure canvas is sized
            if (canvas.width !== canvas.clientWidth) {
                canvas.width = canvas.clientWidth;
                canvas.height = canvas.clientHeight;
            }
            
            let time = 0;
            
            function draw() {
                // Clear
                ctx.fillStyle = '#222';
                ctx.fillRect(0, 0, canvas.width, canvas.height);
                
                // Draw animated pattern
                for (let i = 0; i < 5; i++) {
                    const x = canvas.width/2 + Math.cos(time + i) * (canvas.width/4);
                    const y = canvas.height/2 + Math.sin(time + i) * (canvas.height/4);
                    const radius = 10 + Math.sin(time * 2) * 5;
                    
                    ctx.beginPath();
                    ctx.arc(x, y, radius, 0, Math.PI * 2);
                    ctx.fillStyle = 'hsl(' + ((time * 50 + i * 50) % 360) + ', 100%, 50%)';
                    ctx.fill();
                }
                
                time += 0.05;
                animationId = requestAnimationFrame(draw);
            }
            
            draw();
            log('Animation started');
        }
        
        function stopAnimation() {
            if (animationId) {
                cancelAnimationFrame(animationId);
                animationId = null;
                log('Animation stopped');
            }
        }
        
        window.addEventListener('load', function() {
            log('Page loaded');
            setTimeout(testCanvas, 100);
        });
    </script>
</body>
</html>
EOF

# Let's create a JavaScript fix that can be included in the app
echo "Creating a canvas fix script..."
cat > canvas-fix.js << 'EOF'
// Canvas fix script - Add at the beginning of your HTML
console.log("Canvas fix loaded");
window.addEventListener('DOMContentLoaded', function() {
    console.log("Fixing canvas elements");
    
    // Give browser a moment to render
    setTimeout(function() {
        // Fix debug visualizer
        var debugCanvas = document.getElementById('debugVisualizer');
        if (debugCanvas) {
            console.log("Debug canvas before: " + debugCanvas.width + "x" + debugCanvas.height);
            debugCanvas.width = debugCanvas.clientWidth;
            debugCanvas.height = debugCanvas.clientHeight;
            console.log("Debug canvas after: " + debugCanvas.width + "x" + debugCanvas.height);
            
            // Draw something to verify it works
            var ctx = debugCanvas.getContext('2d');
            ctx.fillStyle = '#222';
            ctx.fillRect(0, 0, debugCanvas.width, debugCanvas.height);
        }
        
        // Fix audio visualizer
        var audioCanvas = document.getElementById('audioVisualizer');
        if (audioCanvas) {
            console.log("Audio canvas before: " + audioCanvas.width + "x" + audioCanvas.height);
            audioCanvas.width = audioCanvas.clientWidth;
            audioCanvas.height = audioCanvas.clientHeight;
            console.log("Audio canvas after: " + audioCanvas.width + "x" + audioCanvas.height);
            
            // Draw something to verify it works
            var ctx = audioCanvas.getContext('2d');
            ctx.fillStyle = '#000';
            ctx.fillRect(0, 0, audioCanvas.width, audioCanvas.height);
        }
        
        console.log("Canvas fix complete");
    }, 100);
});
EOF

# Try to create the files directly in the pod
echo "Trying to create files in pod with kubectl exec..."

# First check if we can write to temp dir
kubectl exec $RUNNING_POD -- ls -la /tmp

# Try to create files in temp
echo "Copying files to pod temp directory..."
kubectl cp canvas-test.html ${RUNNING_POD}:/tmp/canvas-test.html
kubectl cp canvas-fix.js ${RUNNING_POD}:/tmp/canvas-fix.js

# List files to make sure they arrived
echo "Checking files in temp..."
kubectl exec $RUNNING_POD -- ls -la /tmp

# Now try to create test files in nginx directory
echo "Trying to copy from temp to nginx html directory..."
kubectl exec $RUNNING_POD -- sh -c "cp /tmp/canvas-test.html /usr/share/nginx/html/ 2>/dev/null || echo 'Failed to copy - read-only filesystem'"
kubectl exec $RUNNING_POD -- sh -c "cp /tmp/canvas-fix.js /usr/share/nginx/html/ 2>/dev/null || echo 'Failed to copy - read-only filesystem'"

# Check if files exist in nginx directory
echo "Checking if files exist in nginx html directory..."
kubectl exec $RUNNING_POD -- ls -la /usr/share/nginx/html/

# If that didn't work, let's try using a ConfigMap volume
echo "Creating ConfigMaps for the files..."
kubectl delete configmap canvas-fix-files 2>/dev/null || true
kubectl create configmap canvas-fix-files --from-file=canvas-test.html --from-file=canvas-fix.js

# Create an inline HTML that includes our fix script
echo "Creating an inline HTML with the fix script..."
cat > inline-fix.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Inline Fix</title>
    <style>
        body { font-family: Arial; margin: 20px; max-width: 800px; margin: 0 auto; }
        .box { border: 1px solid #ddd; padding: 15px; margin: 15px 0; }
        .success { background: #e6ffe6; }
        .code { font-family: monospace; background: #f5f5f5; padding: 10px; overflow: auto; }
    </style>
</head>
<body>
    <h1>Canvas Fix Instructions</h1>
    
    <div class="box">
        <h2>Step 1: Test Canvas Rendering</h2>
        <p>First, check if canvas rendering works at all in your environment.</p>
        <a href="canvas-test.html" style="display:inline-block; padding:10px; background:#4CAF50; color:white; text-decoration:none; border-radius:4px;">Open Canvas Test</a>
    </div>
    
    <div class="box">
        <h2>Step 2: Add This Script</h2>
        <p>Add this script tag at the beginning of your HTML file, before loading audio-event-detector.js:</p>
        <div class="code">&lt;script&gt;
// Canvas fix script
window.addEventListener('DOMContentLoaded', function() {
    // Give browser a moment to render
    setTimeout(function() {
        // Fix debug visualizer
        var debugCanvas = document.getElementById('debugVisualizer');
        if (debugCanvas) {
            debugCanvas.width = debugCanvas.clientWidth;
            debugCanvas.height = debugCanvas.clientHeight;
        }
        
        // Fix audio visualizer
        var audioCanvas = document.getElementById('audioVisualizer');
        if (audioCanvas) {
            audioCanvas.width = audioCanvas.clientWidth;
            audioCanvas.height = audioCanvas.clientHeight;
        }
    }, 100);
});
&lt;/script&gt;</div>
    </div>
    
    <div class="box">
        <h2>Step 3: Add A Test Button</h2>
        <p>Add this button to your controls div:</p>
        <div class="code">&lt;button id="testVisualizers"&gt;Test Visualizers&lt;/button&gt;</div>
        <p>And add this script at the end of your JavaScript:</p>
        <div class="code">document.getElementById('testVisualizers').addEventListener('click', function() {
    // Test debug visualizer
    var debugCanvas = document.getElementById('debugVisualizer');
    var debugCtx = debugCanvas.getContext('2d');
    
    // Draw sine wave
    debugCtx.fillStyle = '#222';
    debugCtx.fillRect(0, 0, debugCanvas.width, debugCanvas.height);
    debugCtx.strokeStyle = '#4CAF50';
    debugCtx.lineWidth = 2;
    debugCtx.beginPath();
    
    for (var x = 0; x < debugCanvas.width; x++) {
        var y = debugCanvas.height/2 + Math.sin(x/20) * 30;
        if (x === 0) {
            debugCtx.moveTo(x, y);
        } else {
            debugCtx.lineTo(x, y);
        }
    }
    
    debugCtx.stroke();
    
    // Test audio visualizer
    var audioCanvas = document.getElementById('audioVisualizer');
    var audioCtx = audioCanvas.getContext('2d');
    
    audioCtx.fillStyle = '#000';
    audioCtx.fillRect(0, 0, audioCanvas.width, audioCanvas.height);
    
    // Draw bars
    var barCount = 32;
    var barWidth = audioCanvas.width / barCount;
    
    for (var i = 0; i < barCount; i++) {
        var barHeight = audioCanvas.height * (0.2 + 0.6 * Math.sin(i/barCount * Math.PI));
        
        // Create gradient
        var gradient = audioCtx.createLinearGradient(0, audioCanvas.height, 0, audioCanvas.height - barHeight);
        gradient.addColorStop(0, '#4CAF50');
        gradient.addColorStop(0.5, '#FFEB3B');
        gradient.addColorStop(1, '#F44336');
        
        audioCtx.fillStyle = gradient;
        audioCtx.fillRect(i * barWidth, audioCanvas.height - barHeight, barWidth - 1, barHeight);
    }
});</div>
    </div>
    
    <div class="box success">
        <h2>Alternative Solution</h2>
        <p>If you can't modify your files directly, you might need to create a new deployment with these fixes included.</p>
        <p>Consider creating a ConfigMap with the fixed HTML and JS files:</p>
        <div class="code">kubectl create configmap fixed-audio-detector --from-file=index.html --from-file=audio-event-detector.js</div>
        <p>Then update your deployment to use this ConfigMap as a volume.</p>
    </div>
</body>
</html>
EOF

kubectl delete configmap inline-fix 2>/dev/null || true
kubectl create configmap inline-fix --from-file=inline-fix.html

# Now update the deployment to mount these ConfigMaps
echo "Creating patch for deployment to add ConfigMap volumes..."
cat > deployment-patch.yaml << EOF
spec:
  template:
    spec:
      volumes:
      - name: canvas-fix-files
        configMap:
          name: canvas-fix-files
      - name: inline-fix
        configMap:
          name: inline-fix
      containers:
      - name: audio-detection
        volumeMounts:
        - name: canvas-fix-files
          mountPath: /usr/share/nginx/html/canvas-test.html
          subPath: canvas-test.html
        - name: canvas-fix-files
          mountPath: /usr/share/nginx/html/canvas-fix.js
          subPath: canvas-fix.js
        - name: inline-fix
          mountPath: /usr/share/nginx/html/fix.html
          subPath: inline-fix.html
EOF

echo "Patching deployment..."
kubectl patch deployment audio-detection-app --patch "$(cat deployment-patch.yaml)" --type=strategic

echo "Waiting for rollout to complete..."
kubectl rollout status deployment/audio-detection-app

# Get the new pod name
NEW_POD=$(kubectl get pods -l app=audio-detection --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')

echo ""
echo "====================================================="
echo "Canvas fix files have been added to your deployment!"
echo "====================================================="
echo ""
echo "Access these files after setting up port-forwarding:"
echo "kubectl port-forward $NEW_POD 8080:80"
echo ""
echo "Then visit:"
echo "1. Canvas Test: http://localhost:8080/canvas-test.html"
echo "2. Fix Instructions: http://localhost:8080/fix.html"
echo ""
echo "These files will help you diagnose and fix the visualization issues."
echo "====================================================="

# Clean up temporary files
rm -f canvas-test.html canvas-fix.js inline-fix.html deployment-patch.yaml
