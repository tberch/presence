const mongoose = require('mongoose');
const Schema = mongoose.Schema;

// Schema for notifications
const notificationSchema = new Schema({
  // User who will receive this notification
  userId: {
    type: String,
    required: true,
    index: true
  },
  
  // Notification type (e.g., context_joined, message_received)
  type: {
    type: String,
    required: true
  },
  
  // Notification title
  title: {
    type: String,
    required: true
  },
  
  // Notification body
  body: {
    type: String,
    default: ''
  },
  
  // Additional data
  data: {
    type: Schema.Types.Mixed,
    default: {}
  },
  
  // Whether the notification has been read
  read: {
    type: Boolean,
    default: false
  }
}, { timestamps: true });

// Schema for device tokens (for push notifications)
const deviceTokenSchema = new Schema({
  // User who owns this device
  userId: {
    type: String,
    required: true,
    index: true
  },
  
  // Device identifier
  deviceId: {
    type: String,
    required: true
  },
  
  // Push notification token
  token: {
    type: String,
    required: true
  },
  
  // Platform (ios, android, web)
  platform: {
    type: String,
    enum: ['ios', 'android', 'web'],
    required: true
  }
}, { timestamps: true });

// Add indexes for faster queries
notificationSchema.index({ userId: 1, read: 1 });
notificationSchema.index({ createdAt: -1 });

deviceTokenSchema.index({ userId: 1, deviceId: 1 }, { unique: true });
deviceTokenSchema.index({ token: 1 });

// Create models
const NotificationModel = mongoose.model('Notification', notificationSchema);
const DeviceTokenModel = mongoose.model('DeviceToken', deviceTokenSchema);

module.exports = {
  NotificationModel,
  DeviceTokenModel
};
