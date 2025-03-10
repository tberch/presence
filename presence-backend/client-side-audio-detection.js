// Client-Side Audio Event Detection System

class AudioEventDetector {
  constructor(options = {}) {
    // Configuration options
    this.options = {
      sampleRate: options.sampleRate || 44100,
      fftSize: options.fftSize || 2048,
      bufferLen: options.bufferLen || 4096,
      minDecibels: options.minDecibels || -90,
      maxDecibels: options.maxDecibels || -10,
      smoothingTimeConstant: options.smoothingTimeConstant || 0.85,
      eventThreshold: options.eventThreshold || 0.7,
      energyThreshold: options.energyThreshold || 0.2,
      minEventDuration: options.minEventDuration || 300, // ms
      eventCooldown: options.eventCooldown || 1000, // ms
      onEvent: options.onEvent || this._defaultEventHandler
    };

    // Internal state
    this.audioContext = null;
    this.analyser = null;
    this.microphone = null;
    this.isRecording = false;
    this.eventInProgress = false;
    this.lastEventTime = 0;
    this.eventStartTime = 0;
    this.eventBuffer = [];
    this.models = new Map();

    // Arrays for analysis
    this.frequencyData = null;
    this.timeData = null;
  }

  /**
   * Initialize the audio context and request microphone access
   */
  async initialize() {
    try {
      // Create audio context
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)({
        sampleRate: this.options.sampleRate
      });

      // Request microphone access
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      this.microphone = this.audioContext.createMediaStreamSource(stream);

      // Set up analyzer node
      this.analyser = this.audioContext.createAnalyser();
      this.analyser.fftSize = this.options.fftSize;
      this.analyser.minDecibels = this.options.minDecibels;
      this.analyser.maxDecibels = this.options.maxDecibels;
      this.analyser.smoothingTimeConstant = this.options.smoothingTimeConstant;

      // Connect microphone to analyzer
      this.microphone.connect(this.analyser);

      // Create data arrays
      this.frequencyData = new Uint8Array(this.analyser.frequencyBinCount);
      this.timeData = new Uint8Array(this.options.bufferLen);

      console.log('Audio Event Detector initialized successfully');
      return true;
    } catch (error) {
      console.error('Failed to initialize Audio Event Detector:', error);
      return false;
    }
  }

  /**
   * Start listening for audio events
   */
  start() {
    if (this.isRecording || !this.analyser) return false;
    
    this.isRecording = true;
    this._analyzeAudio();
    console.log('Audio Event Detection started');
    return true;
  }

  /**
   * Stop listening for audio events
   */
  stop() {
    this.isRecording = false;
    console.log('Audio Event Detection stopped');
    return true;
  }

  /**
   * Add a model for specific event detection
   * @param {string} eventName - Name of the event to detect
   * @param {Function} detectionFunction - Function that analyzes audio data and returns confidence
   */
  addEventModel(eventName, detectionFunction) {
    this.models.set(eventName, detectionFunction);
    console.log(`Added detection model for "${eventName}"`);
  }

  /**
   * Remove a specific event detection model
   * @param {string} eventName - Name of the event model to remove
   */
  removeEventModel(eventName) {
    const removed = this.models.delete(eventName);
    if (removed) {
      console.log(`Removed detection model for "${eventName}"`);
    }
    return removed;
  }

  /**
   * Main audio analysis loop
   * @private
   */
  _analyzeAudio() {
    if (!this.isRecording) return;

    // Get current audio data
    this.analyser.getByteFrequencyData(this.frequencyData);
    this.analyser.getByteTimeDomainData(this.timeData);

    // Calculate audio energy (simplified RMS)
    const energy = this._calculateEnergy(this.timeData);

    // Check if we have enough energy to consider this an event
    if (energy > this.options.energyThreshold) {
      this._processAudioEvent(energy);
    } else if (this.eventInProgress) {
      // End the event if energy drops below threshold
      const eventDuration = Date.now() - this.eventStartTime;
      if (eventDuration >= this.options.minEventDuration) {
        this._finalizeEvent(eventDuration);
      } else {
        // Discard events that are too short
        this.eventInProgress = false;
        this.eventBuffer = [];
      }
    }

    // Continue the analysis loop
    requestAnimationFrame(() => this._analyzeAudio());
  }

  /**
   * Process potential audio event
   * @param {number} energy - Current audio energy level
   * @private
   */
  _processAudioEvent(energy) {
    const now = Date.now();

    // Check if we're in cooldown period
    if (now - this.lastEventTime < this.options.eventCooldown) {
      return;
    }

    // Start tracking a new event
    if (!this.eventInProgress) {
      this.eventInProgress = true;
      this.eventStartTime = now;
      this.eventBuffer = [];
    }

    // Add current frame to event buffer
    this.eventBuffer.push({
      time: now - this.eventStartTime,
      frequencyData: [...this.frequencyData],
      timeData: [...this.timeData],
      energy
    });
  }

  /**
   * Finalize and report a detected event
   * @param {number} duration - Event duration in ms
   * @private
   */
  _finalizeEvent(duration) {
    this.eventInProgress = false;
    this.lastEventTime = Date.now();

    // Run event through classification models
    const detections = [];
    
    for (const [eventName, detectionFn] of this.models.entries()) {
      try {
        const confidence = detectionFn(this.eventBuffer);
        
        if (confidence >= this.options.eventThreshold) {
          detections.push({
            type: eventName,
            confidence,
            timestamp: new Date(),
            duration
          });
        }
      } catch (error) {
        console.error(`Error in detection model "${eventName}":`, error);
      }
    }

    // If we have detections, trigger the callback
    if (detections.length > 0) {
      this.options.onEvent(detections, this.eventBuffer);
    }

    // Clear the buffer
    this.eventBuffer = [];
  }

  /**
   * Calculate energy from audio time domain data
   * @param {Uint8Array} timeData - Audio time domain data
   * @returns {number} - Energy level between 0-1
   * @private
   */
  _calculateEnergy(timeData) {
    let sum = 0;
    
    // Convert 8-bit values to -1.0 to 1.0 range and calculate RMS
    for (let i = 0; i < timeData.length; i++) {
      const amplitude = (timeData[i] / 128.0) - 1.0;
      sum += amplitude * amplitude;
    }
    
    const rms = Math.sqrt(sum / timeData.length);
    return rms;
  }

  /**
   * Default event handler
   * @param {Array} detections - Array of detected events
   * @private
   */
  _defaultEventHandler(detections) {
    console.log('Audio events detected:', detections);
  }

  /**
   * Get frequency domain features (MFCCs, spectral centroid, etc.)
   * @param {Uint8Array} frequencyData - Frequency domain data
   * @returns {Object} - Object containing various audio features
   */
  extractFeatures(frequencyData = this.frequencyData) {
    // This is a simplified version - a real implementation would include
    // proper MFCC calculation, spectral centroid, etc.
    
    const features = {
      // Average energy in different frequency bands
      lowEnergy: this._getBandEnergy(frequencyData, 0, 200),
      midEnergy: this._getBandEnergy(frequencyData, 200, 2000),
      highEnergy: this._getBandEnergy(frequencyData, 2000, 20000),
      
      // Simplified spectral centroid
      spectralCentroid: this._calculateSpectralCentroid(frequencyData),
      
      // Simplified spectral rolloff
      spectralRolloff: this._calculateSpectralRolloff(frequencyData, 0.85)
    };
    
    return features;
  }

  /**
   * Calculate energy in a specific frequency band
   * @param {Uint8Array} frequencyData - Frequency domain data
   * @param {number} minFreq - Minimum frequency in Hz
   * @param {number} maxFreq - Maximum frequency in Hz
   * @returns {number} - Energy in the specified band (0-1)
   * @private
   */
  _getBandEnergy(frequencyData, minFreq, maxFreq) {
    const binSize = this.options.sampleRate / this.options.fftSize;
    const minBin = Math.floor(minFreq / binSize);
    const maxBin = Math.min(Math.ceil(maxFreq / binSize), frequencyData.length - 1);
    
    let sum = 0;
    for (let i = minBin; i <= maxBin; i++) {
      sum += frequencyData[i];
    }
    
    return sum / ((maxBin - minBin + 1) * 255); // Normalize to 0-1
  }

  /**
   * Calculate the spectral centroid
   * @param {Uint8Array} frequencyData - Frequency domain data
   * @returns {number} - Spectral centroid in Hz
   * @private
   */
  _calculateSpectralCentroid(frequencyData) {
    const binSize = this.options.sampleRate / this.options.fftSize;
    let numerator = 0;
    let denominator = 0;
    
    for (let i = 0; i < frequencyData.length; i++) {
      const amplitude = frequencyData[i];
      const frequency = i * binSize;
      
      numerator += frequency * amplitude;
      denominator += amplitude;
    }
    
    return denominator === 0 ? 0 : numerator / denominator;
  }

  /**
   * Calculate the spectral rolloff
   * @param {Uint8Array} frequencyData - Frequency domain data
   * @param {number} percentile - Percentile for rolloff (0-1)
   * @returns {number} - Frequency at which the percentile is reached
   * @private
   */
  _calculateSpectralRolloff(frequencyData, percentile) {
    const binSize = this.options.sampleRate / this.options.fftSize;
    const totalEnergy = frequencyData.reduce((sum, value) => sum + value, 0);
    const rolloffThreshold = totalEnergy * percentile;
    
    let cumulativeEnergy = 0;
    for (let i = 0; i < frequencyData.length; i++) {
      cumulativeEnergy += frequencyData[i];
      if (cumulativeEnergy >= rolloffThreshold) {
        return i * binSize;
      }
    }
    
    return this.options.sampleRate / 2; // Nyquist frequency
  }
}

// Example of a detection model for a door bell sound
function createDoorbellDetector(referencePatterns) {
  return function(eventBuffer) {
    // This is a simplified example - a real detector would use
    // more sophisticated signal processing and machine learning

    // Extract features from the event buffer
    const features = eventBuffer.map(frame => {
      // Calculate the spectral centroid and band energies
      const binSize = 44100 / 2048; // Example values
      
      let midSum = 0;
      let highSum = 0;
      
      for (let i = 10; i < 50; i++) { // Approx 200-1000Hz
        midSum += frame.frequencyData[i];
      }
      
      for (let i = 50; i < 100; i++) { // Approx 1000-2000Hz
        highSum += frame.frequencyData[i];
      }
      
      return {
        midEnergy: midSum / (40 * 255),
        highEnergy: highSum / (50 * 255),
        ratio: midSum / (highSum || 1)
      };
    });
    
    // Look for a pattern typical of doorbells (simplified)
    // - High energy in mid frequencies
    // - Specific ratio between mid and high frequencies
    // - Duration pattern
    
    const avgMidEnergy = features.reduce((sum, f) => sum + f.midEnergy, 0) / features.length;
    const avgRatio = features.reduce((sum, f) => sum + f.ratio, 0) / features.length;
    
    // Simple doorbell heuristic - this should be replaced with a proper
    // machine learning model in a production system
    const doorBellConfidence = 
      (avgMidEnergy > 0.4 ? 0.6 : 0) +
      (avgRatio > 1.5 && avgRatio < 3.5 ? 0.4 : 0);
    
    return doorBellConfidence;
  };
}

// Example of a detection model for a knocking sound
function createKnockingDetector() {
  return function(eventBuffer) {
    // Extract temporal features to detect knocking rhythm
    let peaks = [];
    let lastPeakTime = -1;
    const peakThreshold = 0.5; // Threshold for detecting energy peaks
    
    // Find energy peaks in the buffer
    for (let i = 0; i < eventBuffer.length; i++) {
      const frame = eventBuffer[i];
      
      // Check if this is a local maximum in energy
      if (frame.energy > peakThreshold) {
        const isLocalMax = (i === 0 || eventBuffer[i-1].energy < frame.energy) &&
                           (i === eventBuffer.length-1 || eventBuffer[i+1].energy < frame.energy);
        
        if (isLocalMax) {
          // Only count if it's been at least 100ms since the last peak
          if (lastPeakTime === -1 || frame.time - lastPeakTime > 100) {
            peaks.push(frame.time);
            lastPeakTime = frame.time;
          }
        }
      }
    }
    
    // Knocking typically has 2-5 peaks with similar intervals
    if (peaks.length >= 2 && peaks.length <= 5) {
      // Calculate intervals between peaks
      const intervals = [];
      for (let i = 1; i < peaks.length; i++) {
        intervals.push(peaks[i] - peaks[i-1]);
      }
      
      // Check if intervals are similar (typical of knocking)
      const avgInterval = intervals.reduce((sum, val) => sum + val, 0) / intervals.length;
      const intervalConsistency = intervals.every(interval => 
        Math.abs(interval - avgInterval) < 0.3 * avgInterval
      );
      
      // More knocking heuristics
      const isKnockingDuration = eventBuffer[eventBuffer.length-1].time < 2000; // Less than 2 seconds
      const lowFrequencyDominant = eventBuffer.every(frame => {
        const lowFreqSum = frame.frequencyData.slice(0, 20).reduce((sum, val) => sum + val, 0);
        const totalSum = frame.frequencyData.reduce((sum, val) => sum + val, 0);
        return lowFreqSum > 0.5 * totalSum;
      });
      
      // Calculate confidence based on heuristics
      let confidence = 0;
      if (intervalConsistency) confidence += 0.4;
      if (isKnockingDuration) confidence += 0.3;
      if (lowFrequencyDominant) confidence += 0.3;
      
      return confidence;
    }
    
    return 0; // Not knocking
  };
}

// Example usage:
async function setupAudioEventDetection() {
  const detector = new AudioEventDetector({
    // Custom options
    energyThreshold: 0.15,
    eventThreshold: 0.6,
    // Custom event handler
    onEvent: (detections, buffer) => {
      console.log('Detected audio events:', detections);
      // Update UI, trigger actions, etc.
      
      // Example: display notifications based on event type
      detections.forEach(event => {
        new Notification(`Sound detected: ${event.type}`, {
          body: `Confidence: ${Math.round(event.confidence * 100)}%`,
          icon: `/icons/${event.type}.png`
        });
        
        // Could also send to a server, trigger smart home actions, etc.
      });
    }
  });
  
  // Initialize detector
  const initialized = await detector.initialize();
  if (!initialized) {
    console.error('Failed to initialize audio detection');
    return;
  }
  
  // Add event detection models
  detector.addEventModel('doorbell', createDoorbellDetector());
  detector.addEventModel('knocking', createKnockingDetector());
  
  // Start detection
  detector.start();
  
  // UI controls
  document.getElementById('startDetection').addEventListener('click', () => detector.start());
  document.getElementById('stopDetection').addEventListener('click', () => detector.stop());
  
  return detector;
}

// Example HTML to use with this code:
/*
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
        }
        
        .controls {
            margin: 20px 0;
        }
        
        button {
            padding: 10px 15px;
            margin-right: 10px;
            background-color: #4CAF50;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
        }
        
        button:hover {
            background-color: #45a049;
        }
        
        #eventLog {
            height: 300px;
            overflow-y: auto;
            border: 1px solid #ddd;
            padding: 10px;
            margin-top: 20px;
        }
        
        .event-item {
            padding: 8px;
            margin-bottom: 5px;
            border-left: 4px solid #4CAF50;
            background-color: #f9f9f9;
        }
    </style>
</head>
<body>
    <h1>Audio Event Detection</h1>
    
    <div class="controls">
        <button id="startDetection">Start Detection</button>
        <button id="stopDetection">Stop Detection</button>
    </div>
    
    <div id="status">Status: Ready</div>
    
    <div id="eventLog">
        <div class="event-item">Waiting for events...</div>
    </div>
    
    <script src="audio-event-detector.js"></script>
    <script>
        document.addEventListener('DOMContentLoaded', () => {
            // Initialize the detector
            setupAudioEventDetection().then(detector => {
                // Update status
                document.getElementById('status').textContent = 'Status: Initialized';
                
                // Custom event handler to update UI
                const originalOnEvent = detector.options.onEvent;
                detector.options.onEvent = (detections, buffer) => {
                    // Call the original handler
                    originalOnEvent(detections, buffer);
                    
                    // Update UI
                    const eventLog = document.getElementById('eventLog');
                    
                    detections.forEach(event => {
                        const eventItem = document.createElement('div');
                        eventItem.className = 'event-item';
                        eventItem.innerHTML = `
                            <strong>${event.type}</strong> (${Math.round(event.confidence * 100)}%)<br>
                            Time: ${event.timestamp.toLocaleTimeString()}<br>
                            Duration: ${event.duration}ms
                        `;
                        
                        eventLog.insertBefore(eventItem, eventLog.firstChild);
                    });
                };
            });
        });
    </script>
</body>
</html>
*/
