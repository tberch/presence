// src/context-service/models.js
const mongoose = require('mongoose');
const Schema = mongoose.Schema;

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

// Schema for user-context associations
const userContextSchema = new Schema({
  // User who joined the context
  userId: {
    type: String,
    required: true
  },
  
  // Context the user joined
  contextId: {
    type: Schema.Types.ObjectId,
    ref: 'Context',
    required: true
  },
  
  // When the user first joined this context
  joinedAt: {
    type: Date,
    default: Date.now
  },
  
  // When the user was last active in this context
  lastActiveAt: {
    type: Date,
    default: Date.now
  },
  
  // Confidence score of the match
  confidence: {
    type: Number,
    required: false
  },
  
  // Location when the user joined (optional)
  location: {
    type: {
      latitude: Number,
      longitude: Number
    },
    required: false
  }
});

// Add indexes for faster queries
userContextSchema.index({ userId: 1 });
userContextSchema.index({ contextId: 1 });
userContextSchema.index({ lastActiveAt: -1 });
userContextSchema.index({ userId: 1, contextId: 1 }, { unique: true });

// Create models
const ContextModel = mongoose.model('Context', contextSchema);
const UserContextModel = mongoose.model('UserContext', userContextSchema);

module.exports = {
  ContextModel,
  UserContextModel
};
