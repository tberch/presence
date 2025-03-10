#!/bin/bash
# This script implements the Notification Service for sending push notifications

echo "===== 1. Creating Notification Service Directory Structure ====="
mkdir -p src/notification-service

# Create the main Notification Service file
cat > src/notification-service/index.js << 'EOF'
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
EOF

# Create models file for the Notification Service
cat > src/notification-service/models.js << 'EOF'
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
EOF

# Create package.json for the Notification Service
cat > src/notification-service/package.json << 'EOF'
{
  "name": "notification-service",
  "version": "1.0.0",
  "description": "Notification service for Presence application",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mongoose": "^7.5.0",
    "socket.io": "^4.6.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

echo "===== 2. Creating Docker Configuration for Notification Service ====="
mkdir -p docker/notification-service

cat > docker/notification-service/Dockerfile << 'EOF'
FROM node:16-alpine

WORKDIR /app

# Copy package files
COPY src/notification-service/package*.json ./
RUN npm install

# Copy source code
COPY src/notification-service/ ./

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3005/health || exit 1

# Environment variables
ENV NODE_ENV=production
ENV PORT=3005

EXPOSE 3005

CMD ["node", "index.js"]
EOF

echo "===== 3. Creating Kubernetes Configuration for Notification Service ====="
mkdir -p k8s/services k8s/deployments

# Create Kubernetes Service
cat > k8s/services/notification-service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: notification-service
  namespace: presence
  labels:
    app: notification-service
spec:
  selector:
    app: notification-service
  ports:
    - port: 3005
      targetPort: 3005
      name: http
  type: ClusterIP
EOF

# Create Kubernetes Deployment
cat > k8s/deployments/notification-service.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service
  namespace: presence
  labels:
    app: notification-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: notification-service
  template:
    metadata:
      labels:
        app: notification-service
    spec:
      containers:
        - name: notification-service
          image: presence/notification-service:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3005
          env:
            - name: PORT
              value: "3005"
            - name: NODE_ENV
              value: "production"
            - name: MONGODB_HOST
              valueFrom:
                configMapKeyRef:
                  name: database-config
                  key: MONGODB_HOST
            - name: MONGODB_PORT
              valueFrom:
                configMapKeyRef:
                  name: database-config
                  key: MONGODB_PORT
            - name: MONGODB_DB
              valueFrom:
                configMapKeyRef:
                  name: database-config
                  key: MONGODB_DB
            - name: MONGODB_USER
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: mongodb-user
            - name: MONGODB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: mongodb-password
          livenessProbe:
            httpGet:
              path: /health
              port: 3005
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: 3005
            initialDelaySeconds: 5
            periodSeconds: 5
EOF

# Create NodePort service for direct testing
cat > k8s/services/notification-service-nodeport.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: notification-service-nodeport
  namespace: presence
  labels:
    app: notification-service
spec:
  selector:
    app: notification-service
  ports:
    - port: 3005
      targetPort: 3005
      nodePort: 30005
      name: http
  type: NodePort
EOF

# Update Ingress for notification service
cat > k8s/ingress/notification-ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-gateway
  namespace: presence
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
    - host: presence.local
      http:
        paths:
          - path: /fingerprint(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: fingerprint-service
                port:
                  number: 3000
          - path: /context(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: context-service
                port:
                  number: 3001
          - path: /chat(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: chat-service
                port:
                  number: 3002
          - path: /user(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: user-service
                port:
                  number: 3003
          - path: /notification(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: notification-service
                port:
                  number: 3005
    - http:
        paths:
          - path: /fingerprint(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: fingerprint-service
                port:
                  number: 3000
          - path: /context(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: context-service
                port:
                  number: 3001
          - path: /chat(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: chat-service
                port:
                  number: 3002
          - path: /user(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: user-service
                port:
                  number: 3003
          - path: /notification(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: notification-service
                port:
                  number: 3005
EOF

echo "===== 4. Creating Build and Deploy Scripts ====="

# Create build script
cat > build-notification-service.sh << 'EOF'
#!/bin/bash
set -e

echo "Building Notification Service..."
docker build -t presence/notification-service -f docker/notification-service/Dockerfile .
echo "Notification Service built successfully!"
EOF
chmod +x build-notification-service.sh

# Create deploy script
cat > deploy-notification-service.sh << 'EOF'
#!/bin/bash
set -e

echo "Deploying Notification Service to Kubernetes..."

# Apply Kubernetes Service and Deployment
kubectl apply -f k8s/services/notification-service.yaml
kubectl apply -f k8s/services/notification-service-nodeport.yaml
kubectl apply -f k8s/deployments/notification-service.yaml

# Wait for deployment to be ready
kubectl rollout status deployment/notification-service -n presence

echo "Deploying updated ingress configuration..."
kubectl apply -f k8s/ingress/notification-ingress.yaml

echo "Notification Service deployed successfully!"
EOF
chmod +x deploy-notification-service.sh

# Create test script
cat > test-notification-service.sh << 'EOF'
#!/bin/bash

echo "===== Testing Notification Service ====="
kubectl -n presence port-forward svc/notification-service 3005:3005 &
NS_PID=$!
sleep 3

echo "===== Testing Root Path ====="
curl http://localhost:3005/
echo -e "\n"

echo "===== Testing Health Endpoint ====="
curl http://localhost:3005/health
echo -e "\n"

echo "===== Creating a Test Notification ====="
curl -X POST http://localhost:3005/notifications \
  -H "Content-Type: application/json" \
  -d '{"user_id":"test-user-123","type":"test","title":"Test Notification","body":"This is a test notification","data":{"action":"test"}}'
echo -e "\n"

echo "===== Getting Notifications ====="
curl "http://localhost:3005/notifications?user_id=test-user-123"
echo -e "\n"

echo "===== Registering a Test Device ====="
curl -X POST http://localhost:3005/devices/register \
  -H "Content-Type: application/json" \
  -d '{"user_id":"test-user-123","device_id":"test-device-123","token":"test-token-123","platform":"android"}'
echo -e "\n"

echo "===== Testing Socket.IO Connection ====="
echo "To test WebSocket functionality, use a WebSocket client to connect to:"
echo "ws://localhost:3005"
echo "WebSocket testing requires a client that supports Socket.IO protocol."
echo "For a quick test, you can use tools like 'wscat' or browser-based Socket.IO testers."

# Clean up
kill $NS_PID

echo "===== Notification Service Test Complete ====="
EOF
chmod +x test-notification-service.sh

echo "===== Notification Service Implementation Complete ====="
echo ""
echo "To build the Notification Service:"
echo "  ./build-notification-service.sh"
echo ""
echo "To deploy the Notification Service to Kubernetes:"
echo "  ./deploy-notification-service.sh"
echo ""
echo "To test the Notification Service:"
echo "  ./test-notification-service.sh"
