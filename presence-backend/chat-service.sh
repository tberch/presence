#!/bin/bash
# This script implements the Chat Service for real-time communication

echo "===== 1. Creating Chat Service Directory Structure ====="
mkdir -p src/chat-service

# Create the main Chat Service file
cat > src/chat-service/index.js << 'EOF'
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const mongoose = require('mongoose');
const { ChatRoomModel, MessageModel } = require('./models');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

const port = process.env.PORT || 3002;

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
const inMemoryChatRooms = [];
const inMemoryMessages = [];

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
    service: 'Chat Service',
    message: 'Manages chat rooms and real-time messaging',
    version: '1.0.0',
    endpoints: [
      '/health - Service health check',
      '/status - Service status information',
      '/rooms - List or create chat rooms',
      '/rooms/:id - Get a specific chat room',
      '/rooms/:id/messages - Get messages for a chat room',
      'WebSocket - Real-time chat'
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
    service: 'chat-service',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    database: dbConnected ? 'connected' : 'in-memory',
    connections: Object.keys(io.sockets.sockets).length
  });
});

// Get all chat rooms
app.get('/rooms', async (req, res) => {
  try {
    let rooms;
    
    if (dbConnected) {
      // Get from MongoDB
      rooms = await ChatRoomModel.find()
        .sort({ createdAt: -1 })
        .limit(20);
      
      rooms = rooms.map(room => ({
        id: room._id.toString(),
        name: room.name,
        type: room.type,
        context_id: room.contextId,
        users_count: room.activeUsers.length,
        created_at: room.createdAt
      }));
    } else {
      // Get from in-memory storage
      rooms = inMemoryChatRooms.map(room => ({
        id: room.id,
        name: room.name,
        type: room.type,
        context_id: room.contextId,
        users_count: room.activeUsers.length,
        created_at: room.createdAt
      }));
    }
    
    res.json({ rooms });
  } catch (error) {
    console.error('Error fetching chat rooms:', error);
    res.status(500).json({ 
      error: 'Error fetching chat rooms',
      details: error.message 
    });
  }
});

// Get a specific chat room
app.get('/rooms/:id', async (req, res) => {
  try {
    const roomId = req.params.id;
    let room;
    
    if (dbConnected) {
      // Get from MongoDB
      room = await ChatRoomModel.findById(roomId);
      
      if (!room) {
        return res.status(404).json({ error: 'Chat room not found' });
      }
      
      room = {
        id: room._id.toString(),
        name: room.name,
        type: room.type,
        context_id: room.contextId,
        active_users: room.activeUsers,
        created_at: room.createdAt
      };
    } else {
      // Get from in-memory storage
      room = inMemoryChatRooms.find(r => r.id === roomId);
      
      if (!room) {
        return res.status(404).json({ error: 'Chat room not found' });
      }
    }
    
    res.json(room);
  } catch (error) {
    console.error(`Error getting chat room ${req.params.id}:`, error);
    res.status(500).json({ error: 'Failed to retrieve chat room' });
  }
});

// Get messages for a specific room
app.get('/rooms/:id/messages', async (req, res) => {
  try {
    const roomId = req.params.id;
    const limit = parseInt(req.query.limit) || 50;
    const before = req.query.before;
    
    let messages;
    
    if (dbConnected) {
      // Build query
      const query = { roomId };
      if (before) {
        query.createdAt = { $lt: new Date(before) };
      }
      
      // Get from MongoDB
      messages = await MessageModel.find(query)
        .sort({ createdAt: -1 })
        .limit(limit);
      
      messages = messages.map(msg => ({
        id: msg._id.toString(),
        room_id: msg.roomId,
        user_id: msg.userId,
        content: msg.content,
        created_at: msg.createdAt
      }));
    } else {
      // Get from in-memory storage
      messages = inMemoryMessages
        .filter(msg => msg.roomId === roomId)
        .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
        .slice(0, limit)
        .map(msg => ({
          id: msg.id,
          room_id: msg.roomId,
          user_id: msg.userId,
          content: msg.content,
          created_at: msg.createdAt
        }));
    }
    
    res.json({ messages });
  } catch (error) {
    console.error(`Error getting messages for room ${req.params.id}:`, error);
    res.status(500).json({ error: 'Failed to retrieve messages' });
  }
});

// Create a new chat room
app.post('/rooms', async (req, res) => {
  try {
    const { name, context_id, type } = req.body;
    
    if (!name) {
      return res.status(400).json({ error: 'Name is required' });
    }
    
    let newRoom;
    
    if (dbConnected) {
      // Create in MongoDB
      newRoom = await ChatRoomModel.create({
        name,
        contextId: context_id,
        type: type || 'context',
        activeUsers: []
      });
      
      newRoom = {
        id: newRoom._id.toString(),
        name: newRoom.name,
        type: newRoom.type,
        context_id: newRoom.contextId,
        created_at: newRoom.createdAt
      };
    } else {
      // Create in-memory
      newRoom = {
        id: `room_${Date.now()}`,
        name,
        contextId: context_id,
        type: type || 'context',
        activeUsers: [],
        createdAt: new Date()
      };
      
      inMemoryChatRooms.push(newRoom);
    }
    
    res.status(201).json(newRoom);
  } catch (error) {
    console.error('Error creating chat room:', error);
    res.status(500).json({ error: 'Failed to create chat room' });
  }
});

// Get chat rooms for a specific context
app.get('/rooms/context/:contextId', async (req, res) => {
  try {
    const contextId = req.params.contextId;
    let rooms;
    
    if (dbConnected) {
      // Get from MongoDB
      rooms = await ChatRoomModel.find({ contextId });
      
      rooms = rooms.map(room => ({
        id: room._id.toString(),
        name: room.name,
        type: room.type,
        context_id: room.contextId,
        users_count: room.activeUsers.length,
        created_at: room.createdAt
      }));
    } else {
      // Get from in-memory storage
      rooms = inMemoryChatRooms
        .filter(r => r.contextId === contextId)
        .map(room => ({
          id: room.id,
          name: room.name,
          type: room.type,
          context_id: room.contextId,
          users_count: room.activeUsers.length,
          created_at: room.createdAt
        }));
    }
    
    res.json({ rooms });
  } catch (error) {
    console.error(`Error getting rooms for context ${req.params.contextId}:`, error);
    res.status(500).json({ error: 'Failed to retrieve chat rooms' });
  }
});

// Set up Socket.IO for real-time chat
io.on('connection', (socket) => {
  console.log('New client connected');
  
  // Join a chat room
  socket.on('joinRoom', async ({ roomId, userId, userName }) => {
    if (!roomId || !userId) {
      return socket.emit('error', { message: 'Room ID and User ID are required' });
    }
    
    // Add user to room
    socket.join(roomId);
    
    // Store user info in socket
    socket.userId = userId;
    socket.userName = userName || userId;
    socket.roomId = roomId;
    
    console.log(`User ${userId} joined room ${roomId}`);
    
    // Add user to active users list
    if (dbConnected) {
      try {
        await ChatRoomModel.findByIdAndUpdate(
          roomId,
          { $addToSet: { activeUsers: userId } }
        );
      } catch (error) {
        console.error('Error updating active users:', error);
      }
    } else {
      const room = inMemoryChatRooms.find(r => r.id === roomId);
      if (room && !room.activeUsers.includes(userId)) {
        room.activeUsers.push(userId);
      }
    }
    
    // Notify other users
    socket.to(roomId).emit('userJoined', {
      userId,
      userName: socket.userName,
      timestamp: new Date()
    });
    
    // Send recent messages
    let recentMessages;
    if (dbConnected) {
      try {
        recentMessages = await MessageModel.find({ roomId })
          .sort({ createdAt: -1 })
          .limit(50);
        
        recentMessages = recentMessages.map(msg => ({
          id: msg._id.toString(),
          userId: msg.userId,
          userName: msg.userName,
          content: msg.content,
          createdAt: msg.createdAt
        }));
      } catch (error) {
        console.error('Error fetching recent messages:', error);
        recentMessages = [];
      }
    } else {
      recentMessages = inMemoryMessages
        .filter(msg => msg.roomId === roomId)
        .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
        .slice(0, 50)
        .map(msg => ({
          id: msg.id,
          userId: msg.userId,
          userName: msg.userName,
          content: msg.content,
          createdAt: msg.createdAt
        }));
    }
    
    socket.emit('recentMessages', { messages: recentMessages.reverse() });
  });
  
  // Leave a chat room
  socket.on('leaveRoom', async () => {
    const { roomId, userId } = socket;
    
    if (!roomId || !userId) return;
    
    // Remove user from room
    socket.leave(roomId);
    
    console.log(`User ${userId} left room ${roomId}`);
    
    // Remove user from active users list
    if (dbConnected) {
      try {
        await ChatRoomModel.findByIdAndUpdate(
          roomId,
          { $pull: { activeUsers: userId } }
        );
      } catch (error) {
        console.error('Error updating active users:', error);
      }
    } else {
      const room = inMemoryChatRooms.find(r => r.id === roomId);
      if (room) {
        room.activeUsers = room.activeUsers.filter(id => id !== userId);
      }
    }
    
    // Notify other users
    socket.to(roomId).emit('userLeft', {
      userId,
      userName: socket.userName,
      timestamp: new Date()
    });
    
    // Clean up socket data
    delete socket.roomId;
    delete socket.userId;
    delete socket.userName;
  });
  
  // Handle new messages
  socket.on('sendMessage', async (message) => {
    const { roomId, userId, userName } = socket;
    
    if (!roomId || !userId || !message.content) {
      return socket.emit('error', { message: 'Invalid message' });
    }
    
    const timestamp = new Date();
    
    // Create message object
    const newMessage = {
      roomId,
      userId,
      userName: userName || userId,
      content: message.content,
      createdAt: timestamp
    };
    
    // Save message
    let savedMessage;
    if (dbConnected) {
      try {
        savedMessage = await MessageModel.create(newMessage);
        savedMessage = {
          id: savedMessage._id.toString(),
          userId: savedMessage.userId,
          userName: savedMessage.userName,
          content: savedMessage.content,
          createdAt: savedMessage.createdAt
        };
      } catch (error) {
        console.error('Error saving message:', error);
        return socket.emit('error', { message: 'Failed to save message' });
      }
    } else {
      newMessage.id = `msg_${Date.now()}`;
      inMemoryMessages.push(newMessage);
      savedMessage = { ...newMessage };
    }
    
    // Broadcast message to room
    io.to(roomId).emit('newMessage', savedMessage);
  });
  
  // Handle disconnect
  socket.on('disconnect', async () => {
    const { roomId, userId } = socket;
    
    if (roomId && userId) {
      // Remove user from active users list
      if (dbConnected) {
        try {
          await ChatRoomModel.findByIdAndUpdate(
            roomId,
            { $pull: { activeUsers: userId } }
          );
        } catch (error) {
          console.error('Error updating active users:', error);
        }
      } else {
        const room = inMemoryChatRooms.find(r => r.id === roomId);
        if (room) {
          room.activeUsers = room.activeUsers.filter(id => id !== userId);
        }
      }
      
      // Notify other users
      socket.to(roomId).emit('userLeft', {
        userId,
        userName: socket.userName,
        timestamp: new Date()
      });
    }
    
    console.log('Client disconnected');
  });
});

// Start the server
async function startServer() {
  // Connect to MongoDB (if available)
  await connectToMongoDB();
  
  // Start the server
  server.listen(port, () => {
    console.log(`Chat service listening on port ${port}`);
    if (!dbConnected) {
      console.log('Warning: Running with in-memory storage (no MongoDB connection)');
    }
  });
}

startServer();
EOF

# Create models file for the Chat Service
cat > src/chat-service/models.js << 'EOF'
const mongoose = require('mongoose');
const Schema = mongoose.Schema;

// Schema for chat rooms
const chatRoomSchema = new Schema({
  // Room name
  name: {
    type: String,
    required: true,
    trim: true
  },
  
  // Associated context ID (if this is a context-specific chat room)
  contextId: {
    type: String,
    required: false,
    index: true
  },
  
  // Type of chat room (context, direct, group, etc.)
  type: {
    type: String,
    enum: ['context', 'direct', 'group', 'channel'],
    default: 'context'
  },
  
  // Currently active users in the room
  activeUsers: {
    type: [String],
    default: []
  },
  
  // Additional metadata
  metadata: {
    type: Schema.Types.Mixed,
    default: {}
  }
}, { timestamps: true });

// Schema for chat messages
const messageSchema = new Schema({
  // Room this message belongs to
  roomId: {
    type: Schema.Types.ObjectId,
    ref: 'ChatRoom',
    required: true,
    index: true
  },
  
  // User who sent the message
  userId: {
    type: String,
    required: true,
    index: true
  },
  
  // User name (cached for display)
  userName: {
    type: String,
    required: false
  },
  
  // Message content
  content: {
    type: String,
    required: true
  },
  
  // Additional metadata (reactions, mentions, etc.)
  metadata: {
    type: Schema.Types.Mixed,
    default: {}
  }
}, { timestamps: true });

// Add indexes for faster queries
chatRoomSchema.index({ createdAt: -1 });
chatRoomSchema.index({ 'activeUsers': 1 });

messageSchema.index({ createdAt: -1 });
messageSchema.index({ roomId: 1, createdAt: -1 });

// Create models
const ChatRoomModel = mongoose.model('ChatRoom', chatRoomSchema);
const MessageModel = mongoose.model('Message', messageSchema);

module.exports = {
  ChatRoomModel,
  MessageModel
};
EOF

# Create package.json for the Chat Service
cat > src/chat-service/package.json << 'EOF'
{
  "name": "chat-service",
  "version": "1.0.0",
  "description": "Real-time chat service for Presence application",
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

echo "===== 2. Creating Docker Configuration for Chat Service ====="
mkdir -p docker/chat-service

cat > docker/chat-service/Dockerfile << 'EOF'
FROM node:16-alpine

WORKDIR /app

# Copy package files
COPY src/chat-service/package*.json ./
RUN npm install

# Copy source code
COPY src/chat-service/ ./

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3002/health || exit 1

# Environment variables
ENV NODE_ENV=production
ENV PORT=3002

EXPOSE 3002

CMD ["node", "index.js"]
EOF

echo "===== 3. Creating Kubernetes Configuration for Chat Service ====="
mkdir -p k8s/services k8s/deployments

# Create Kubernetes Service
cat > k8s/services/chat-service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: chat-service
  namespace: presence
  labels:
    app: chat-service
spec:
  selector:
    app: chat-service
  ports:
    - port: 3002
      targetPort: 3002
      name: http
  type: ClusterIP
EOF

# Create Kubernetes Deployment
cat > k8s/deployments/chat-service.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chat-service
  namespace: presence
  labels:
    app: chat-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: chat-service
  template:
    metadata:
      labels:
        app: chat-service
    spec:
      containers:
        - name: chat-service
          image: presence/chat-service:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3002
          env:
            - name: PORT
              value: "3002"
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
              port: 3002
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: 3002
            initialDelaySeconds: 5
            periodSeconds: 5
EOF

# Create NodePort service for direct testing
cat > k8s/services/chat-service-nodeport.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: chat-service-nodeport
  namespace: presence
  labels:
    app: chat-service
spec:
  selector:
    app: chat-service
  ports:
    - port: 3002
      targetPort: 3002
      nodePort: 30002
      name: http
  type: NodePort
EOF

# Update Ingress for chat service
cat > k8s/ingress/chat-ingress.yaml << 'EOF'
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
EOF

echo "===== 4. Creating Build and Deploy Scripts ====="

# Create build script
cat > build-chat-service.sh << 'EOF'
#!/bin/bash
set -e

echo "Building Chat Service..."
docker build -t presence/chat-service -f docker/chat-service/Dockerfile .
echo "Chat Service built successfully!"
EOF
chmod +x build-chat-service.sh

# Create deploy script
cat > deploy-chat-service.sh << 'EOF'
#!/bin/bash
set -e

echo "Deploying Chat Service to Kubernetes..."

# Apply Kubernetes Service and Deployment
kubectl apply -f k8s/services/chat-service.yaml
kubectl apply -f k8s/services/chat-service-nodeport.yaml
kubectl apply -f k8s/deployments/chat-service.yaml

# Wait for deployment to be ready
kubectl rollout status deployment/chat-service -n presence

echo "Deploying updated ingress configuration..."
kubectl apply -f k8s/ingress/chat-ingress.yaml

echo "Chat Service deployed successfully!"
EOF
chmod +x deploy-chat-service.sh

# Create test script
cat > test-chat-service.sh << 'EOF'
#!/bin/bash

echo "===== Testing Chat Service ====="
kubectl -n presence port-forward svc/chat-service 3002:3002 &
CS_PID=$!
sleep 3

echo "===== Testing Root Path ====="
curl http://localhost:3002/
echo -e "\n"

echo "===== Testing Health Endpoint ====="
curl http://localhost:3002/health
echo -e "\n"

echo "===== Creating a New Chat Room ====="
curl -X POST http://localhost:3002/rooms \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Chat Room","type":"context","context_id":"test-context-123"}'
echo -e "\n"

echo "===== Getting All Chat Rooms ====="
curl http://localhost:3002/rooms
echo -e "\n"

echo "===== Testing Socket.IO Connection ====="
echo "To test WebSocket functionality, use a WebSocket client to connect to:"
echo "ws://localhost:3002"
echo "WebSocket testing requires a client that supports Socket.IO protocol."
echo "For a quick test, you can use tools like 'wscat' or browser-based Socket.IO testers."

# Clean up
kill $CS_PID

echo "===== Chat Service Test Complete ====="
EOF
chmod +x test-chat-service.sh

echo "===== Chat Service Implementation Complete ====="
echo ""
echo "To build the Chat Service:"
echo "  ./build-chat-service.sh"
echo ""
echo "To deploy the Chat Service to Kubernetes:"
echo "  ./deploy-chat-service.sh"
echo ""
echo "To test the Chat Service:"
echo "  ./test-chat-service.sh"
