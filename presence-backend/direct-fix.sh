#!/bin/bash
# Script to directly create and fix the visualization test page

# Step 1: See what's actually in the container
echo "Checking what's in the nginx container's html directory:"
kubectl exec audio-test-7665bf454d-sqmxj -- ls -la /usr/share/nginx/html

# Step 2: Create an index.html file with a simple test
echo "Creating a direct test file in the container..."
kubectl exec audio-test-7665bf454d-sqmxj -- sh -c 'cat > /usr/share/nginx/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Canvas Test</title>
    <style>
        body { font-family: Arial; margin: 20px; }
        canvas { border: 1px solid #333; margin: 10px 0; }
        button { padding: 10px; margin: 5px; }
    </style>
</head>
<body>
    <h1>Canvas Test</h1>
    <p>Testing if canvas rendering works on this server.</p>
    
    <canvas id="testCanvas" width="400" height="200"></canvas>
    
    <div>
        <button id="testButton">Draw Test Pattern</button>
    </div>
    
    <div id="status">Click a button to start the test</div>
    
    <script>
        // Get elements
        const canvas = document.getElementById("testCanvas");
        const ctx = canvas.getContext("2d");
        const testButton = document.getElementById("testButton");
        const statusElement = document.getElementById("status");
        
        // Draw a test pattern
        function drawTestPattern() {
            // Clear canvas
            ctx.fillStyle = "#222";
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            
            // Draw gradient rectangle
            const gradient = ctx.createLinearGradient(0, 0, canvas.width, 0);
            gradient.addColorStop(0, "red");
            gradient.addColorStop(0.5, "green");
            gradient.addColorStop(1, "blue");
            
            ctx.fillStyle = gradient;
            ctx.fillRect(50, 50, canvas.width - 100, canvas.height - 100);
            
            // Draw text
            ctx.fillStyle = "white";
            ctx.font = "20px Arial";
            ctx.textAlign = "center";
            ctx.fillText("Canvas Rendering Works!", canvas.width / 2, canvas.height / 2);
            
            statusElement.textContent = "Test pattern drawn successfully!";
        }
        
        // Add event listeners
        testButton.addEventListener("click", drawTestPattern);
    </script>
</body>
</html>
EOF'

# Step 3: Create the debug.html file directly in the container
echo "Creating the debug.html file directly in the container..."
kubectl exec audio-test-7665bf454d-sqmxj -- sh -c 'cat > /usr/share/nginx/html/debug.html << EOF
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
        const canvas = document.getElementById("testCanvas");
        const ctx = canvas.getContext("2d");
        const testButton = document.getElementById("testButton");
        const animateButton = document.getElementById("animateButton");
        const stopButton = document.getElementById("stopButton");
        const statusElement = document.getElementById("status");
        
        // Animation variables
        let animating = false;
        let animationTime = 0;
        
        // Draw a test pattern
        function drawTestPattern() {
            // Clear canvas
            ctx.fillStyle = "#222";
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            
            // Draw gradient rectangle
            const gradient = ctx.createLinearGradient(0, 0, canvas.width, 0);
            gradient.addColorStop(0, "red");
            gradient.addColorStop(0.5, "green");
            gradient.addColorStop(1, "blue");
            
            ctx.fillStyle = gradient;
            ctx.fillRect(50, 50, canvas.width - 100, canvas.height - 100);
            
            // Draw text
            ctx.fillStyle = "white";
            ctx.font = "20px Arial";
            ctx.textAlign = "center";
            ctx.fillText("Canvas Rendering Works!", canvas.width / 2, canvas.height / 2);
            
            statusElement.textContent = "Test pattern drawn successfully!";
        }
        
        // Animate the canvas
        function animate() {
            if (!animating) return;
            
            // Clear canvas
            ctx.fillStyle = "#222";
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            
            // Draw animated pattern
            for (let i = 0; i < 5; i++) {
                const x = Math.sin(animationTime + i) * 50 + canvas.width / 2;
                const y = Math.cos(animationTime + i) * 50 + canvas.height / 2;
                const radius = 20 + Math.sin(animationTime * 2) * 10;
                
                ctx.beginPath();
                ctx.arc(x, y, radius, 0, Math.PI * 2);
                ctx.fillStyle = "hsl(" + ((animationTime * 50 + i * 50) % 360) + ", 100%, 50%)";
                ctx.fill();
            }
            
            // Update time
            animationTime += 0.05;
            
            // Continue animation
            requestAnimationFrame(animate);
        }
        
        // Add event listeners
        testButton.addEventListener("click", drawTestPattern);
        
        animateButton.addEventListener("click", () => {
            animating = true;
            animationTime = 0;
            animate();
            statusElement.textContent = "Animation running - canvas is working!";
        });
        
        stopButton.addEventListener("click", () => {
            animating = false;
            statusElement.textContent = "Animation stopped";
        });
    </script>
</body>
</html>
EOF'

# Step 4: Create the visualization-test.html file directly in the container with a simplified version
echo "Creating the visualization-test.html file directly in the container..."
kubectl exec audio-test-7665bf454d-sqmxj -- sh -c 'cat > /usr/share/nginx/html/visualization-test.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Canvas Visualization Test</title>
    <style>
        body { font-family: Arial; margin: 20px; }
        .visualizer-container { 
            margin: 20px 0;
            border: 1px solid #ddd; 
            padding: 10px;
            background-color: #fafafa;
        }
        canvas { 
            width: 100%; 
            background-color: #000;
            height: 100px;
            margin-bottom: 10px;
            border-radius: 4px;
        }
        button { 
            padding: 10px; 
            margin: 5px; 
            background-color: #4CAF50;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
        }
        button:hover { background-color: #45a049; }
        button:disabled { background-color: #cccccc; cursor: not-allowed; }
        #status {
            margin: 15px 0;
            padding: 10px;
            background-color: #e7f3fe;
            border-left: 4px solid #2196F3;
        }
    </style>
</head>
<body>
    <h1>Canvas Visualization Test</h1>
    <p>This tests if the canvas elements can render animations properly.</p>
    
    <div class="controls">
        <button id="testFake">Test Animation</button>
        <button id="stopTest" disabled>Stop</button>
    </div>
    
    <div id="status">Click "Test Animation" to begin</div>
    
    <div class="visualizer-container">
        <h2>Debug Visualizer</h2>
        <canvas id="debugVisualizer"></canvas>
    </div>
    
    <div class="visualizer-container">
        <h2>Audio Visualizer</h2>
        <canvas id="audioVisualizer"></canvas>
    </div>
    
    <script>
        document.addEventListener("DOMContentLoaded", () => {
            const testButton = document.getElementById("testFake");
            const stopButton = document.getElementById("stopTest");
            const statusElement = document.getElementById("status");
            
            // Get canvases and resize them
            const debugCanvas = document.getElementById("debugVisualizer");
            const audioCanvas = document.getElementById("audioVisualizer");
            
            // Resize function
            function resizeCanvas(canvas) {
                canvas.width = canvas.clientWidth;
                canvas.height = canvas.clientHeight;
            }
            
            // Resize canvases initially and on window resize
            resizeCanvas(debugCanvas);
            resizeCanvas(audioCanvas);
            window.addEventListener("resize", () => {
                resizeCanvas(debugCanvas);
                resizeCanvas(audioCanvas);
            });
            
            // Get canvas contexts
            const debugCtx = debugCanvas.getContext("2d");
            const audioCtx = audioCanvas.getContext("2d");
            
            // Animation variables
            let animating = false;
            let time = 0;
            let animationFrame;
            
            // Draw debug visualization (waveform)
            function drawDebug() {
                if (!animating) return;
                
                const width = debugCanvas.width;
                const height = debugCanvas.height;
                
                // Clear canvas
                debugCtx.fillStyle = "#222";
                debugCtx.fillRect(0, 0, width, height);
                
                // Draw waveform
                debugCtx.strokeStyle = "#4CAF50";
                debugCtx.lineWidth = 2;
                debugCtx.beginPath();
                
                for (let x = 0; x < width; x++) {
                    const y = height/2 + Math.sin(x/20 + time) * height/3;
                    
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
                debugCtx.moveTo(0, height * 0.7);
                debugCtx.lineTo(width, height * 0.7);
                debugCtx.stroke();
                
                // Add text
                debugCtx.fillStyle = "#FFF";
                debugCtx.font = "12px Arial";
                debugCtx.fillText("Energy: 0.42", 10, 20);
            }
            
            // Draw audio visualization (bars)
            function drawAudio() {
                if (!animating) return;
                
                const width = audioCanvas.width;
                const height = audioCanvas.height;
                
                // Clear canvas
                audioCtx.fillStyle = "#000";
                audioCtx.fillRect(0, 0, width, height);
                
                // Draw frequency bars
                const barCount = 64;
                const barWidth = width / barCount;
                
                for (let i = 0; i < barCount; i++) {
                    // Generate bar height with variation
                    const barHeight = Math.sin(i/barCount * Math.PI) * height/2 * (0.5 + 0.5 * Math.sin(time + i/10));
                    
                    // Create gradient
                    const gradient = audioCtx.createLinearGradient(0, height, 0, height - barHeight);
                    gradient.addColorStop(0, "#4CAF50");
                    gradient.addColorStop(0.5, "#FFEB3B");
                    gradient.addColorStop(1, "#F44336");
                    
                    // Draw bar
                    audioCtx.fillStyle = gradient;
                    audioCtx.fillRect(i * barWidth, height - barHeight, barWidth - 1, barHeight);
                }
            }
            
            // Animation loop
            function animate() {
                if (!animating) return;
                
                // Update time
                time += 0.05;
                
                // Draw visualizations
                drawDebug();
                drawAudio();
                
                // Continue animation
                animationFrame = requestAnimationFrame(animate);
            }
            
            // Start animation
            testButton.addEventListener("click", () => {
                animating = true;
                time = 0;
                testButton.disabled = true;
                stopButton.disabled = false;
                statusElement.textContent = "Animation running - if you see moving patterns, canvas rendering is working!";
                
                // Start animation
                animate();
            });
            
            // Stop animation
            stopButton.addEventListener("click", () => {
                animating = false;
                testButton.disabled = false;
                stopButton.disabled = true;
                statusElement.textContent = "Animation stopped";
                
                if (animationFrame) {
                    cancelAnimationFrame(animationFrame);
                }
            });
        });
    </script>
</body>
</html>
EOF'

# Step 5: Verify the files are now in the container
echo "Verifying files are now in the container:"
kubectl exec audio-test-7665bf454d-sqmxj -- ls -la /usr/share/nginx/html

echo "Setup complete! Access the test pages at:"
echo "  - http://localhost:8080/ (Simple test)"
echo "  - http://localhost:8080/debug.html (Debug test)"
echo "  - http://localhost:8080/visualization-test.html (Visualization test)"
