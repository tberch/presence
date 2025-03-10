// Canvas initialization fix
document.addEventListener("DOMContentLoaded", function() {
    console.log("Canvas fix script loaded");
    
    // Function to fix a canvas
    function fixCanvas(canvasId) {
        const canvas = document.getElementById(canvasId);
        if (!canvas) {
            console.warn("Canvas not found:", canvasId);
            return false;
        }
        
        try {
            console.log(canvasId + " before fix:", canvas.width, "x", canvas.height);
            
            // Set canvas dimensions to match display size
            canvas.width = canvas.clientWidth || 400;
            canvas.height = canvas.clientHeight || 100;
            
            console.log(canvasId + " after fix:", canvas.width, "x", canvas.height);
            
            // Test draw to confirm it works
            const ctx = canvas.getContext("2d");
            ctx.fillStyle = canvasId === "audioVisualizer" ? "#000" : "#222";
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            
            return true;
        } catch (e) {
            console.error("Error fixing " + canvasId + ":", e);
            return false;
        }
    }
    
    // Fix both canvases
    setTimeout(function() {
        fixCanvas("debugVisualizer");
        fixCanvas("audioVisualizer");
        console.log("Canvas fix complete");
    }, 100);
});
