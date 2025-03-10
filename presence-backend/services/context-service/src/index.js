// src/context-service/index.js
const express = require('express');
const bodyParser = require('body-parser');
const mongoose = require('mongoose');
const axios = require('axios');
const { ContextModel, UserContextModel } = require('./models');

const app = express();
const port = process.env.PORT || 3001;

// Connect to MongoDB
async function connectToMongoDB() {
  try {
    const mongoHost = process.env.MONGODB_HOST || 'mongodb';
    const mongoPort = process.env.MONGODB_PORT || '27017';
    const mongoDb = process.env.MONGODB_DB || 'presence';
    const mongoUser = process.env.MONGODB_USER || 'presence.admin';
    const mongoPass = process.env.MONGODB_PASSWORD || 'changeme';
    
    const mongoUrl = `mongodb://${mongoUser}:${mongoPass}@${mongoHost}:${mongoPort}/${mongoDb}?authSource=admin`;
    
    await mongoose.connect(mongoUrl, {
      useNewUrlParser: true,
      useUnifiedTopology: true
    });
    
    console.log('Connected to MongoDB');
    return true;
  } catch (error) {
    console.error('Failed to connect to MongoDB:', error);
    return false;
  }
}

// Middleware
app.use(bodyParser.json());
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
    service: 'Context Service',
    message: 'Manages contexts and associated metadata',
    version: '1.0.0',
    endpoints: [
      '/health - Service health check',
      '/contexts - Get or create contexts',
      '/contexts/:id - Get a specific context',
      '/events - Receive events from other services'
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
    service: 'context-service',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    database: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected'
  });
});

// Get all contexts
app.get('/contexts', async (req, res) => {
  try {
    // Query parameters
    const limit = parseInt(req.query.limit) || 20;
    const skip = parseInt(req.query.skip) || 0;
    const sort = req.query.sort || '-usersCount'; // Default sort by users count
    
    // Find contexts
    const contexts = await ContextModel.find()
      .sort(sort)
      .skip(skip)
      .limit(limit);
    
    // Format response
    const result = contexts.map(ctx => ({
      id: ctx._id.toString(),
      name: ctx.name,
      type: ctx.type,
      users_count: ctx.usersCount,
      created_at: ctx.createdAt,
      updated_at: ctx.updatedAt,
      metadata: ctx.metadata || {}
    }));
    
    // Get total count for pagination
    const total = await ContextModel.countDocuments();
    
    res.json({
      contexts: result,
      pagination: {
        total,
        limit,
        skip,
        has_more: skip + limit < total
      }
    });
  } catch (error) {
    console.error('Error getting contexts:', error);
    res.status(500).json({ error: 'Failed to retrieve contexts' });
  }
});

// Get a specific context
app.get('/contexts/:id', async (req, res) => {
  try {
    const contextId = req.params.id;
    
    // Find the context
    const context = await ContextModel.findById(contextId);
    
    if (!context) {
      return res.status(404).json({ error: 'Context not found' });
    }
    
    // Get active users for this context
    let activeUsers = [];
    try {
      const userContexts = await UserContextModel.find({ contextId })
        .sort('-joinedAt')
        .limit(100);
      
      // Get user details from user service
      if (userContexts.length > 0) {
        try {
          const userService = process.env.USER_SERVICE_URL || 'http://user-service:3003';
          const userIds = userContexts.map(uc => uc.userId);
          
          const userResponse = await axios.post(`${userService}/users/batch`, {
            user_ids: userIds
          });
          
          if (userResponse.data && userResponse.data.users) {
            activeUsers = userResponse.data.users;
          }
        } catch (userError) {
          console.error('Error fetching user details:', userError.message);
          // Continue without user details
        }
      }
    } catch (userError) {
      console.error('Error fetching active users:', userError.message);
      // Continue without active users
    }
    
    // Get chat room details if available
    let chatRoom = null;
    if (context.chatRoomId) {
      try {
        const chatService = process.env.CHAT_SERVICE_URL || 'http://chat-service:3002';
        const roomResponse = await axios.get(`${chatService}/rooms/${context.chatRoomId}`);
        
        if (roomResponse.data) {
          chatRoom = roomResponse.data;
        }
      } catch (chatError) {
        console.error('Error fetching chat room:', chatError.message);
        // Continue without chat room details
      }
    }
    
    // Format response
    const result = {
      id: context._id.toString(),
      name: context.name,
      type: context.type,
      users_count: context.usersCount,
      active_users: activeUsers,
      location: context.location || null,
      chat_room: chatRoom,
      created_at: context.createdAt,
      updated_at: context.updatedAt,
      metadata: context.metadata || {}
    };
    
    res.json(result);
  } catch (error) {
    console.error(`Error getting context ${req.params.id}:`, error);
    res.status(500).json({ error: 'Failed to retrieve context' });
  }
});

// Create a new context
app.post('/contexts', async (req, res) => {
  try {
    const { name, type, location, metadata } = req.body;
    
    if (!name) {
      return res.status(400).json({ error: 'Name is required' });
    }
    
    // Create context
    const context = await ContextModel.create({
      name,
      type: type || 'unknown',
      location: location || null,
      metadata: metadata || {},
      usersCount: 0,
      createdAt: new Date(),
      updatedAt: new Date()
    });
    
    // Create a chat room for this context
    try {
      const chatService = process.env.CHAT_SERVICE_URL || 'http://chat-service:3002';
      const roomResponse = await axios.post(`${chatService}/rooms`, {
        name: `${name} Chat`,
        context_id: context._id.toString(),
        type: 'context'
      });
      
      if (roomResponse.data && roomResponse.data.id) {
        // Update context with chat room ID
        context.chatRoomId = roomResponse.data.id;
        await context.save();
      }
    } catch (chatError) {
      console.error('Failed to create chat room:', chatError.message);
      // Continue without chat room
    }
    
    // Format response
    const result = {
      id: context._id.toString(),
      name: context.name,
      type: context.type,
      chat_room_id: context.chatRoomId,
      created_at: context.createdAt
    };
    
    res.status(201).json(result);
  } catch (error) {
    console.error('Error creating context:', error);
    res.status(500).json({ error: 'Failed to create context' });
  }
});

// Handle events from other services
app.post('/events', async (req, res) => {
  try {
    const { type, source, timestamp, payload } = req.body;
    
    console.log(`Received event ${type} from ${source}`);
    
    // Process event based on type
    switch (type) {
      case 'fingerprint.matched':
        await handleFingerprintMatched(payload);
        break;
        
      case 'user.joined_context':
        await handleUserJoinedContext(payload);
        break;
        
      case 'user.left_context':
        await handleUserLeftContext(payload);
        break;
        
      default:
        console.log(`Ignoring unknown event type: ${type}`);
    }
    
    res.json({ status: 'ok' });
  } catch (error) {
    console.error('Error processing event:', error);
    res.status(500).json({ error: 'Failed to process event' });
  }
});

// Handle fingerprint matched event
async function handleFingerprintMatched(payload) {
  try {
    const { context_id, device_id, confidence, location } = payload;
    
    if (!context_id || !device_id) {
      console.error('Missing required fields in fingerprint.matched event');
      return;
    }
    
    // Update context stats
    await ContextModel.findByIdAndUpdate(
      context_id,
      {
        $inc: { usersCount: 1 },
        $set: { updatedAt: new Date() }
      }
    );
    
    // Get user ID from device ID (if user service is available)
    let userId = null;
    try {
      const userService = process.env.USER_SERVICE_URL || 'http://user-service:3003';
      const userResponse = await axios.get(`${userService}/users/device/${device_id}`);
      
      if (userResponse.data && userResponse.data.id) {
        userId = userResponse.data.id;
      }
    } catch (userError) {
      console.error('Error getting user from device ID:', userError.message);
      // Continue without user ID
    }
    
    // If we couldn't get a user ID, use the device ID as a fallback
    userId = userId || `anonymous-${device_id}`;
    
    // Record the user-context association
    await UserContextModel.findOneAndUpdate(
      { userId, contextId: context_id },
      {
        $set: {
          lastActiveAt: new Date(),
          confidence: confidence || null,
          location: location || null
        },
        $setOnInsert: {
          joinedAt: new Date()
        }
      },
      { upsert: true, new: true }
    );
    
    // Notify other services (e.g., notification service)
    try {
      const notificationService = process.env.NOTIFICATION_SERVICE_URL || 'http://notification-service:3005';
      await axios.post(`${notificationService}/notifications`, {
        user_id: userId,
        type: 'context_joined',
        title: 'You joined a new context',
        body: 'Tap to see what other people are saying',
        data: {
          context_id
        }
      });
    } catch (notifError) {
      console.error('Failed to send notification:', notifError.message);
      // Continue without notification
    }
    
    console.log(`User ${userId} joined context ${context_id}`);
  } catch (error) {
    console.error('Error handling fingerprint.matched event:', error);
    throw error;
  }
}

// Handle user joined context event
async function handleUserJoinedContext(payload) {
  // Similar to fingerprint.matched but initiated by the user service
  const { user_id, context_id } = payload;
  
  if (!user_id || !context_id) {
    console.error('Missing required fields in user.joined_context event');
    return;
  }
  
  try {
    // Update context stats
    await ContextModel.findByIdAndUpdate(
      context_id,
      {
        $inc: { usersCount: 1 },
        $set: { updatedAt: new Date() }
      }
    );
    
    // Record the user-context association
    await UserContextModel.findOneAndUpdate(
      { userId: user_id, contextId: context_id },
      {
        $set: {
          lastActiveAt: new Date()
        },
        $setOnInsert: {
          joinedAt: new Date()
        }
      },
      { upsert: true, new: true }
    );
    
    console.log(`User ${user_id} joined context ${context_id} (via user service)`);
  } catch (error) {
    console.error('Error handling user.joined_context event:', error);
    throw error;
  }
}

// Handle user left context event
async function handleUserLeftContext(payload) {
  const { user_id, context_id } = payload;
  
  if (!user_id || !context_id) {
    console.error('Missing required fields in user.left_context event');
    return;
  }
  
  try {
    // Update context stats
    await ContextModel.findByIdAndUpdate(
      context_id,
      {
        $inc: { usersCount: -1 },
        $set: { updatedAt: new Date() }
      }
    );
    
    // Remove user-context association
    await UserContextModel.findOneAndDelete({ 
      userId: user_id, 
      contextId: context_id 
    });
    
    console.log(`User ${user_id} left context ${context_id}`);
  } catch (error) {
    console.error('Error handling user.left_context event:', error);
    throw error;
  }
}

// Start server
async function startServer() {
  // Connect to MongoDB first
  const dbConnected = await connectToMongoDB();
  
  // Start the server even if DB connection fails
  app.listen(port, () => {
    console.log(`Context service listening on port ${port}`);
    if (!dbConnected) {
      console.warn('Warning: Running without database connection');
    }
  });
}

startServer();
