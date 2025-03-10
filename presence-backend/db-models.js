// src/fingerprint-service/models.js
const mongoose = require('mongoose');
const Schema = mongoose.Schema;

// Schema for audio fingerprints
const fingerprintSchema = new Schema({
  // The fingerprint data (signature, features, etc.)
  data: {
    type: Schema.Types.Mixed,
    required: true
  },
  
  // Reference to the context this fingerprint belongs to
  contextId: {
    type: Schema.Types.ObjectId,
    ref: 'Context',
    required: true
  },
  
  // Metadata
  createdAt: {
    type: Date,
    default: Date.now
  }
});

// Add indexes for faster queries
fingerprintSchema.index({ contextId: 1 });
fingerprintSchema.index({ createdAt: -1 });

// Schema for contexts (detected events, shows, locations)
const contextSchema = new Schema({
  // Context name (e.g., "CNN News", "Taylor Swift Concert")
  name: {
    type: String,
    required: true,
    trim: true
  },
  
  // Context type (broadcast, concert, podcast, etc.)
  type: {
    type: String,
    enum: ['broadcast', 'concert', 'podcast', 'sports_event', 'movie', 'live_event', 'unknown'],
    default: 'unknown'
  },
  
  // Number of users who have matched this context
  usersCount: {
    type: Number,
    default: 0
  },
  
  // Location data (optional)
  location: {
    type: {
      latitude: Number,
      longitude: Number,
      name: String
    },
    required: false
  },
  
  // Additional metadata about the context
  metadata: {
    type: Schema.Types.Mixed,
    default: {}
  },
  
  // Associated chat room ID (if any)
  chatRoomId: {
    type: String,
    required: false
  },
  
  // Timestamps
  createdAt: {
    type: Date,
    default: Date.now
  },
  
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

// Add indexes for faster queries
contextSchema.index({ createdAt: -1 });
contextSchema.index({ type: 1 });
contextSchema.index({ usersCount: -1 });

// Pre-save hook to update the updatedAt field
contextSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  next();
});

// Create models
const FingerprintModel = mongoose.model('Fingerprint', fingerprintSchema);
const ContextModel = mongoose.model('Context', contextSchema);

module.exports = {
  FingerprintModel,
  ContextModel
};
