const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const mongoose = require('mongoose');
const { NotificationModel, DeviceTokenModel } = require('./models');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

const port = process.env.PORT || 3005;

// Connect to MongoDB (or use in-memory fallback if unavailable)
let dbConnected = false;
const connectToMongoDB = async () => {
  try {
    const mongoHost = process.env.MONGODB_HOST || 'mongodb';
    const mongoPort = process.env.MONGODB_PORT || '27017';
    const mongoDb = process.env.MONGODB_DB || 'presence';
    const mongoUser = process.env.MONGODB_USER || 'presence.admin';
    const mongoPassword = process.env.MONGODB_PASSWORD || 'changeme';
    
    const mongoUrl = `mongodb://${mongoUser}:${mongoPassword}@${mongoHost}:${mongoPort}/${mongoDb}?authSource=admin`;
    
    await mongoose.connect(mongoUrl);
    console.log('Connected to MongoDB');
    dbConnected = true;
  } catch (error) {
    console.error('Failed to connect to MongoDB, using in-memory storage:', error.message);
    // We'll continue without MongoDB and use in-memory storage
  }
};

// In-memory storage for development/testing
const inMemoryNotifications = [];
const inMemoryDeviceTokens = [];
const inMemoryClients = new Map(); // userId -> socket.id

// Express middleware
app.use(express.json());

// Logging middleware
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  if (req.body && Object.keys(req.body).length > 0) {
    console.log('Body:', JSON.stringify(req.body).substring(0, 100) + '...');
  }
  next();
});

// Root path handler
app.get('/', (req, res) => {
  res.json({
    service: 'Notification Service',
    message: 'Manages notifications and push messaging',
    version: '1.0.0',
    endpoints: [
      '/health - Service health check',
      '/status - Service status information',
      '/notifications - List or create notifications',
      '/notifications/:id - Get a specific notification',
      '/devices/register - Register a device for push notifications',
      'WebSocket - Real-time notifications'
    ]
  });
});

// Health endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Status endpoint
app.get('/status', (req, res) => {
  res.json({
    service: 'notification-service',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    database: dbConnected ? 'connected' : 'in-memory',
    connections: Object.keys(io.sockets.sockets).length
  });
});

// Get notifications for a user
app.get('/notifications', async (req, res) => {
  try {
    const userId = req.query.user_id;
    const limit = parseInt(req.query.limit) || 20;
    const skip = parseInt(req.query.skip) || 0;
    
    if (!userId) {
      return res.status(400).json({ error: 'User ID is required' });
    }
    
    let notifications;
    
    if (dbConnected) {
      // Get from MongoDB
      notifications = await NotificationModel.find({ userId })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit);
      
      notifications = notifications.map(notification => ({
        id: notification._id.toString(),
        user_id: notification.userId,
        type: notification.type,
        title: notification.title,
        body: notification.body,
        data: notification.data,
        read: notification.read,
        created_at: notification.createdAt
      }));
    } else {
      // Get from in-memory storage
      notifications = inMemoryNotifications
        .filter(n => n.userId === userId)
        .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
        .slice(skip, skip + limit)
        .map(notification => ({
          id: notification.id,
          user_id: notification.userId,
          type: notification.type,
          title: notification.title,
          body: notification.body,
          data: notification.data,
          read: notification.read,
          created_at: notification.createdAt
        }));
    }
    
    // Get total count for pagination
    let total;
    if (dbConnected) {
      total = await NotificationModel.countDocuments({ userId });
    } else {
      total = inMemoryNotifications.filter(n => n.userId === userId).length;
    }
    
    res.json({
      notifications,
      pagination: {
        total,
        limit,
        skip,
        has_more: skip + limit < total
      }
    });
  } catch (error) {
    console.error('Error fetching notifications:', error);
    res.status(500).json({ 
      error: 'Error fetching notifications',
      details: error.message 
    });
  }
});

// Get a specific notification
app.get('/notifications/:id', async (req, res) => {
  try {
    const notificationId = req.params.id;
    let notification;
    
    if (dbConnected) {
      // Get from MongoDB
      notification = await NotificationModel.findById(notificationId);
      
      if (!notification) {
        return res.status(404).json({ error: 'Notification not found' });
      }
      
      notification = {
        id: notification._id.toString(),
        user_id: notification.userId,
        type: notification.type,
        title: notification.title,
        body: notification.body,
        data: notification.data,
        read: notification.read,
        created_at: notification.createdAt
      };
    } else {
      // Get from in-memory storage
      notification = inMemoryNotifications.find(n => n.id === notificationId);
      
      if (!notification) {
        return res.status(404).json({ error: 'Notification not found' });
      }
    }
    
    res.json(notification);
  } catch (error) {
    console.error(`Error getting notification ${req.params.id}:`, error);
    res.status(500).json({ error: 'Failed to retrieve notification' });
  }
});

// Mark notification as read
app.put('/notifications/:id/read', async (req, res) => {
  try {
    const notificationId = req.params.id;
    
    if (dbConnected) {
      // Update in MongoDB
      const notification = await NotificationModel.findByIdAndUpdate(
        notificationId,
        { read: true },
        { new: true }
      );
      
      if (!notification) {
        return res.status(404).json({ error: 'Notification not found' });
      }
      
      res.json({
        id: notification._id.toString(),
        read: notification.read
      });
    } else {
      // Update in-memory
      const notification = inMemoryNotifications.find(n => n.id === notificationId);
      
      if (!notification) {
        return res.status(404).json({ error: 'Notification not found' });
      }
      
      notification.read = true;
      
      res.json({
        id: notification.id,
        read: notification.read
      });
    }
  } catch (error) {
    console.error(`Error marking notification ${req.params.id} as read:`, error);
    res.status(500).json({ error: 'Failed to update notification' });
  }
});

// Create a new notification
app.post('/notifications', async (req, res) => {
  try {
    const { user_id, type, title, body, data } = req.body;
    
    if (!user_id || !type || !title) {
      return res.status(400).json({ error: 'User ID, type, and title are required' });
    }
    
    let newNotification;
    
    if (dbConnected) {
      // Create in MongoDB
      newNotification = await NotificationModel.create({
        userId: user_id,
        type,
        title,
        body: body || '',
        data: data || {},
        read: false
      });
      
      newNotification = {
        id: newNotification._id.toString(),
        user_id: newNotification.userId,
        type: newNotification.type,
        title: newNotification.title,
        body: newNotification.body,
        data: newNotification.data,
        read: newNotification.read,
        created_at: newNotification.createdAt
      };
    } else {
      // Create in-memory
      newNotification = {
        id: `notif_${Date.now()}`,
        userId: user_id,
        type,
        title,
        body: body || '',
        data: data || {},
        read: false,
        createdAt: new Date()
      };
      
      inMemoryNotifications.push(newNotification);
    }
    
    // Send push notification
    await sendPushNotification(user_id, {
      type,
      title,
      body: body || '',
      data: data || {}
    });
    
    // Send real-time notification
    sendRealtimeNotification(user_id, newNotification);
    
    res.status(201).json(newNotification);
  } catch (error) {
    console.error('Error creating notification:', error);
    res.status(500).json({ error: 'Failed to create notification' });
  }
});

// Register a device for push notifications
app.post('/devices/register', async (req, res) => {
  try {
    const { user_id, device_id, token, platform } = req.body;
    
    if (!user_id || !device_id || !token || !platform) {
      return res.status(400).json({ error: 'User ID, device ID, token, and platform are required' });
    }
    
    let deviceToken;
    
    if (dbConnected) {
      // Check if token already exists
      deviceToken = await DeviceTokenModel.findOne({
        userId: user_id,
        deviceId: device_id
      });
      
      if (deviceToken) {
        // Update existing token
        deviceToken = await DeviceTokenModel.findByIdAndUpdate(
          deviceToken._id,
          {
            token,
            platform,
            updatedAt: new Date()
          },
          { new: true }
        );
      } else {
        // Create new token
        deviceToken = await DeviceTokenModel.create({
          userId: user_id,
          deviceId: device_id,
          token,
          platform
        });
      }
      
      deviceToken = {
        id: deviceToken._id.toString(),
        user_id: deviceToken.userId,
        device_id: deviceToken.deviceId,
        platform: deviceToken.platform,
        updated_at: deviceToken.updatedAt
      };
    } else {
      // Check if token already exists in memory
      deviceToken = inMemoryDeviceTokens.find(t => t.userId === user_id && t.deviceId === device_id);
      
      if (deviceToken) {
        // Update existing token
        deviceToken.token = token;
        deviceToken.platform = platform;
        deviceToken.updatedAt = new Date();
      } else {
        // Create new token
        deviceToken = {
          id: `token_${Date.now()}`,
          userId: user_id,
          deviceId: device_id,
          token,
          platform,
          createdAt: new Date(),
          updatedAt: new Date()
        };
        
        inMemoryDeviceTokens.push(deviceToken);
      }
    }
    
    res.json({
      success: true,
      device: {
        id: deviceToken.id,
        user_id: deviceToken.user_id,
        device_id: deviceToken.device_id,
        platform: deviceToken.platform,
        updated_at: deviceToken.updated_at
      }
    });
  } catch (error) {
    console.error('Error registering device token:', error);
    res.status(500).json({ error: 'Failed to register device token' });
  }
});

// Send push notification
async function sendPushNotification(userId, notification) {
  console.log(`Sending push notification to user ${userId}:`, notification);
  
  try {
    // Get device tokens for the user
    let deviceTokens;
    if (dbConnected) {
      deviceTokens = await DeviceTokenModel.find({ userId });
    } else {
      deviceTokens = inMemoryDeviceTokens.filter(t => t.userId === userId);
    }
    
    if (deviceTokens.length === 0) {
      console.log(`No device tokens found for user ${userId}`);
      return;
    }
    
    // In a real implementation, this would send to Firebase, APNS, etc.
    // Here we'll just simulate the sending
    console.log(`Would send to ${deviceTokens.length} devices:`);
    
    for (const token of deviceTokens) {
      console.log(`- Platform: ${token.platform}, Token: ${token.token.substring(0, 10)}...`);
      
      // Simulate sending based on platform
      if (token.platform === 'ios') {
        // Simulate iOS push notification
        simulateAPNSPush(token.token, notification);
      } else if (token.platform === 'android') {
        // Simulate Android push notification
        simulateFCMPush(token.token, notification);
      } else if (token.platform === 'web') {
        // Simulate web push notification
        simulateWebPush(token.token, notification);
      }
    }
    
    console.log('Push notifications sent (simulated)');
  } catch (error) {
    console.error('Error sending push notification:', error);
  }
}

// Simulate iOS push notification
function simulateAPNSPush(token, notification) {
  console.log(`[APNS Simulation] Sending to iOS device: ${notification.title}`);
  // In a real app, this would use the 'apn' library or a service like Firebase
}

// Simulate Android push notification
function simulateFCMPush(token, notification) {
  console.log(`[FCM Simulation] Sending to Android device: ${notification.title}`);
  // In a real app, this would use the Firebase Admin SDK
}

// Simulate web push notification
function simulateWebPush(token, notification) {
  console.log(`[Web Push Simulation] Sending to browser: ${notification.title}`);
  // In a real app, this would use the web-push library
}

// Send real-time notification
function sendRealtimeNotification(userId, notification) {
  // Check if user has any connected clients
  const socketId = inMemoryClients.get(userId);
  
  if (socketId) {
    io.to(socketId).emit('notification', notification);
    console.log(`Real-time notification sent to user ${userId}`);
  } else {
    console.log(`No connected client for user ${userId}`);
  }
}

// Set up Socket.IO for real-time notifications
io.on('connection', (socket) => {
  console.log('New client connected');
  
  // Client authenticates with user ID
  socket.on('authenticate', (data) => {
    const { userId } = data;
    
    if (!userId) {
      return socket.emit('error', { message: 'User ID is required' });
    }
    
    // Store mapping from user ID to socket ID
    inMemoryClients.set(userId, socket.id);
    socket.userId = userId;
    
    console.log(`User ${userId} authenticated`);
    socket.emit('authenticated', { success: true });
    
    // Send any unread notifications
    sendUnreadNotifications(userId, socket);
  });
  
  // Handle disconnect
  socket.on('disconnect', () => {
    if (socket.userId) {
      inMemoryClients.delete(socket.userId);
      console.log(`User ${socket.userId} disconnected`);
    }
    
    console.log('Client disconnected');
  });
});

// Send unread notifications to a client
async function sendUnreadNotifications(userId, socket) {
  try {
    let unreadNotifications;
    
    if (dbConnected) {
      unreadNotifications = await NotificationModel.find({
        userId,
        read: false
      }).sort({ createdAt: -1 }).limit(10);
      
      unreadNotifications = unreadNotifications.map(notification => ({
        id: notification._id.toString(),
        user_id: notification.userId,
        type: notification.type,
        title: notification.title,
        body: notification.body,
        data: notification.data,
        read: notification.read,
        created_at: notification.createdAt
      }));
    } else {
      unreadNotifications = inMemoryNotifications
        .filter(n => n.userId === userId && !n.read)
        .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
        .slice(0, 10);
    }
    
    if (unreadNotifications.length > 0) {
      socket.emit('unread_notifications', { notifications: unreadNotifications });
      console.log(`Sent ${unreadNotifications.length} unread notifications to user ${userId}`);
    }
  } catch (error) {
    console.error('Error sending unread notifications:', error);
  }
}

// Start the server
async function startServer() {
  // Connect to MongoDB (if available)
  await connectToMongoDB();
  
  // Start the server
  server.listen(port, () => {
    console.log(`Notification service listening on port ${port}`);
    if (!dbConnected) {
      console.log('Warning: Running with in-memory storage (no MongoDB connection)');
    }
  });
}

startServer();
