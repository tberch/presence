// Canvas Fix for Audio Detection App
// Copy this ENTIRE code block and paste it into your browser console
// after loading the app at http://localhost:8080/

(function() {
  console.log("Applying canvas visualization fix...");
  
  // Step 1: Fix canvas sizes
  function fixCanvasSizes() {
    // Fix debug visualizer
    const debugCanvas = document.getElementById('debugVisualizer');
    if (debugCanvas) {
      console.log("Debug canvas before: " + debugCanvas.width + "x" + debugCanvas.height);
      debugCanvas.width = debugCanvas.clientWidth;
      debugCanvas.height = debugCanvas.clientHeight;
      console.log("Debug canvas after: " + debugCanvas.width + "x" + debugCanvas.height);
    } else {
      console.warn("Debug visualizer canvas not found");
    }
    
    // Fix audio visualizer
    const audioCanvas = document.getElementById('audioVisualizer');
    if (audioCanvas) {
      console.log("Audio canvas before: " + audioCanvas.width + "x" + audioCanvas.height);
      audioCanvas.width = audioCanvas.clientWidth;
      audioCanvas.height = audioCanvas.clientHeight;
      console.log("Audio canvas after: " + audioCanvas.width + "x" + audioCanvas.height);
    } else {
      console.warn("Audio visualizer canvas not found");
    }
  }
  
  // Step 2: Create a test function
  function testVisualizers() {
    // Test debug visualizer
    const debugCanvas = document.getElementById('debugVisualizer');
    if (debugCanvas) {
      const ctx = debugCanvas.getContext('2d');
      
      // Clear canvas
      ctx.fillStyle = '#222';
      ctx.fillRect(0, 0, debugCanvas.width, debugCanvas.height);
      
      // Draw a sine wave
      ctx.strokeStyle = '#4CAF50';
      ctx.lineWidth = 2;
      ctx.beginPath();
      
      for (let x = 0; x < debugCanvas.width; x++) {
        const y = debugCanvas.height/2 + Math.sin(x/20) * 30;
        
        if (x === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      }
      
      ctx.stroke();
      console.log("Debug visualizer test pattern drawn");
    }
    
    // Test audio visualizer
    const audioCanvas = document.getElementById('audioVisualizer');
    if (audioCanvas) {
      const ctx = audioCanvas.getContext('2d');
      
      // Clear canvas
      ctx.fillStyle = '#000';
      ctx.fillRect(0, 0, audioCanvas.width, audioCanvas.height);
      
      // Draw bars
      const barCount = 32;
      const barWidth = audioCanvas.width / barCount;
      
      for (let i = 0; i < barCount; i++) {
        const barHeight = audioCanvas.height * (0.2 + 0.6 * Math.sin(i/barCount * Math.PI));
        
        // Create gradient
        const gradient = ctx.createLinearGradient(0, audioCanvas.height, 0, audioCanvas.height - barHeight);
        gradient.addColorStop(0, '#4CAF50');
        gradient.addColorStop(0.5, '#FFEB3B');
        gradient.addColorStop(1, '#F44336');
        
        ctx.fillStyle = gradient;
        ctx.fillRect(i * barWidth, audioCanvas.height - barHeight, barWidth - 1, barHeight);
      }
      
      console.log("Audio visualizer test pattern drawn");
    }
  }
  
  // Step 3: Create a test button
  function addTestButton() {
    // Check if the button already exists
    if (document.getElementById('testVisualizersBtn')) {
      console.log("Test button already exists");
      return;
    }
    
    // Find the controls container
    const controlsDiv = document.querySelector('.controls');
    if (!controlsDiv) {
      console.warn("Controls div not found, creating a floating button");
      
      // Create a floating button
      const btn = document.createElement('button');
      btn.id = 'testVisualizersBtn';
      btn.textContent = 'Test Visualizers';
      btn.style.position = 'fixed';
      btn.style.top = '10px';
      btn.style.right = '10px';
      btn.style.zIndex = '9999';
      btn.style.padding = '10px 15px';
      btn.style.backgroundColor = '#4CAF50';
      btn.style.color = 'white';
      btn.style.border = 'none';
      btn.style.borderRadius = '4px';
      btn.style.cursor = 'pointer';
      btn.addEventListener('click', testVisualizers);
      
      document.body.appendChild(btn);
      console.log("Floating test button added");
    } else {
      // Add button to controls
      const btn = document.createElement('button');
      btn.id = 'testVisualizersBtn';
      btn.textContent = 'Test Visualizers';
      btn.addEventListener('click', testVisualizers);
      
      controlsDiv.appendChild(btn);
      console.log("Test button added to controls");
    }
  }
  
  // Step 4: Patch the AudioEventDetector to fix canvases during initialization
  function patchAudioDetector() {
    if (typeof AudioEventDetector !== 'function') {
      console.warn("AudioEventDetector not found, cannot patch it");
      return;
    }
    
    console.log("Patching AudioEventDetector...");
    
    // Store original
    const originalInitialize = AudioEventDetector.prototype.initialize;
    
    // Override initialize
    AudioEventDetector.prototype.initialize = async function() {
      console.log("Patched initialize method called");
      
      // Call original initialize
      const result = await originalInitialize.apply(this);
      
      // Fix canvases after initialization
      setTimeout(() => {
        fixCanvasSizes();
        
        // Fix visualizer drawing methods
        if (this.drawDebugVisualizer) {
          const originalDrawDebug = this.drawDebugVisualizer;
          this.drawDebugVisualizer = function() {
            // Make sure canvas is sized properly before drawing
            const canvas = document.getElementById('debugVisualizer');
            if (canvas && (canvas.width !== canvas.clientWidth || canvas.height !== canvas.clientHeight)) {
              canvas.width = canvas.clientWidth;
              canvas.height = canvas.clientHeight;
            }
            
            // Call original
            originalDrawDebug.apply(this);
          };
        }
        
        if (this.drawAudioVisualizer) {
          const originalDrawAudio = this.drawAudioVisualizer;
          this.drawAudioVisualizer = function() {
            // Make sure canvas is sized properly before drawing
            const canvas = document.getElementById('audioVisualizer');
            if (canvas && (canvas.width !== canvas.clientWidth || canvas.height !== canvas.clientHeight)) {
              canvas.width = canvas.clientWidth;
              canvas.height = canvas.clientHeight;
            }
            
            // Call original
            originalDrawAudio.apply(this);
          };
        }
        
        console.log("Visualization methods patched");
      }, 200);
      
      return result;
    };
    
    console.log("AudioEventDetector patched");
  }
  
  // Apply all fixes
  fixCanvasSizes();
  addTestButton();
  patchAudioDetector();
  testVisualizers();
  
  console.log("Canvas visualization fix applied! Try clicking the 'Test Visualizers' button.");
  console.log("If you restart the detector, the fix will automatically apply to new visualizations.");
})();
