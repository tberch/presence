#!/bin/bash
# This script implements the User Service for authentication and user management

echo "===== 1. Creating User Service Directory Structure ====="
mkdir -p src/user-service

# Create the main User Service file
cat > src/user-service/index.js << 'EOF'
const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { UserModel, DeviceModel } = require('./models');

const app = express();
const port = process.env.PORT || 3003;

// JWT secret
const JWT_SECRET = process.env.JWT_SECRET || 'presence-jwt-secret-key';

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
const inMemoryUsers = [];
const inMemoryDevices = [];

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

// Authentication middleware
const authenticate = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    
    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      
      // Get user
      let user;
      if (dbConnected) {
        user = await UserModel.findById(decoded.userId);
      } else {
        user = inMemoryUsers.find(u => u.id === decoded.userId);
      }
      
      if (!user) {
        return res.status(401).json({ error: 'User not found' });
      }
      
      // Add user to request
      req.user = user;
      req.token = token;
      
      next();
    } catch (error) {
      res.status(401).json({ error: 'Invalid token' });
    }
  } catch (error) {
    res.status(500).json({ error: 'Authentication error' });
  }
};

// Root path handler
app.get('/', (req, res) => {
  res.json({
    service: 'User Service',
    message: 'Manages users, authentication, and devices',
    version: '1.0.0',
    endpoints: [
      '/health - Service health check',
      '/status - Service status information',
      '/users - List or create users',
      '/users/:id - Get a specific user',
      '/users/device/:deviceId - Get user by device ID',
      '/users/context-join - Record context join',
      '/auth/register - Register a new user',
      '/auth/login - Login and get token'
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
    service: 'user-service',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    database: dbConnected ? 'connected' : 'in-memory'
  });
});

// Get users (admin only)
app.get('/users', authenticate, async (req, res) => {
  try {
    // Check if user is admin
    if (!req.user.isAdmin) {
      return res.status(403).json({ error: 'Admin access required' });
    }
    
    let users;
    
    if (dbConnected) {
      // Get from MongoDB
      users = await UserModel.find().select('-password');
      
      users = users.map(user => ({
        id: user._id.toString(),
        username: user.username,
        email: user.email,
        isAdmin: user.isAdmin,
        created_at: user.createdAt
      }));
    } else {
      // Get from in-memory storage
      users = inMemoryUsers.map(user => ({
        id: user.id,
        username: user.username,
        email: user.email,
        isAdmin: user.isAdmin,
        created_at: user.createdAt
      }));
    }
    
    res.json({ users });
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ 
      error: 'Error fetching users',
      details: error.message 
    });
  }
});

// Get a specific user
app.get('/users/:id', async (req, res) => {
  try {
    const userId = req.params.id;
    let user;
    
    if (dbConnected) {
      // Get from MongoDB
      user = await UserModel.findById(userId).select('-password');
      
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }
      
      user = {
        id: user._id.toString(),
        username: user.username,
        email: user.email,
        profile: user.profile || {},
        created_at: user.createdAt
      };
    } else {
      // Get from in-memory storage
      user = inMemoryUsers.find(u => u.id === userId);
      
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }
      
      // Remove password
      const { password, ...userWithoutPassword } = user;
      user = userWithoutPassword;
    }
    
    res.json(user);
  } catch (error) {
    console.error(`Error getting user ${req.params.id}:`, error);
    res.status(500).json({ error: 'Failed to retrieve user' });
  }
});

// Get user batch by IDs
app.post('/users/batch', async (req, res) => {
  try {
    const { user_ids } = req.body;
    
    if (!user_ids || !Array.isArray(user_ids)) {
      return res.status(400).json({ error: 'User IDs array is required' });
    }
    
    let users;
    
    if (dbConnected) {
      // Get from MongoDB
      users = await UserModel.find({ _id: { $in: user_ids } }).select('-password');
      
      users = users.map(user => ({
        id: user._id.toString(),
        username: user.username,
        profile: user.profile || {}
      }));
    } else {
      // Get from in-memory storage
      users = inMemoryUsers
        .filter(u => user_ids.includes(u.id))
        .map(user => {
          const { password, ...userWithoutPassword } = user;
          return {
            ...userWithoutPassword,
            profile: user.profile || {}
          };
        });
    }
    
    res.json({ users });
  } catch (error) {
    console.error('Error getting users batch:', error);
    res.status(500).json({ error: 'Failed to retrieve users' });
  }
});

// Get user by device ID
app.get('/users/device/:deviceId', async (req, res) => {
  try {
    const deviceId = req.params.deviceId;
    let device, user;
    
    if (dbConnected) {
      // Get device from MongoDB
      device = await DeviceModel.findOne({ deviceId });
      
      if (!device) {
        return res.status(404).json({ error: 'Device not found' });
      }
      
      // Get associated user
      user = await UserModel.findById(device.userId).select('-password');
      
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }
      
      user = {
        id: user._id.toString(),
        username: user.username,
        profile: user.profile || {}
      };
    } else {
      // Get from in-memory storage
      device = inMemoryDevices.find(d => d.deviceId === deviceId);
      
      if (!device) {
        return res.status(404).json({ error: 'Device not found' });
      }
      
      user = inMemoryUsers.find(u => u.id === device.userId);
      
      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }
      
      // Remove sensitive data
      user = {
        id: user.id,
        username: user.username,
        profile: user.profile || {}
      };
    }
    
    res.json(user);
  } catch (error) {
    console.error(`Error getting user for device ${req.params.deviceId}:`, error);
    res.status(500).json({ error: 'Failed to retrieve user' });
  }
});

// Record context join
app.post('/users/context-join', async (req, res) => {
  try {
    const { device_id, context_id } = req.body;
    
    if (!device_id || !context_id) {
      return res.status(400).json({ error: 'Device ID and Context ID are required' });
    }
    
    // Find or create device
    let device, userId;
    
    if (dbConnected) {
      // Check if device exists
      device = await DeviceModel.findOne({ deviceId: device_id });
      
      if (device) {
        userId = device.userId;
      } else {
        // Create anonymous user
        const newUser = await UserModel.create({
          username: `anonymous-${device_id}`,
          password: await bcrypt.hash(Math.random().toString(), 10),
          isAnonymous: true
        });
        
        // Create device
        device = await DeviceModel.create({
          deviceId: device_id,
          userId: newUser._id,
          lastActive: new Date()
        });
        
        userId = newUser._id;
      }
    } else {
      // Check if device exists in memory
      device = inMemoryDevices.find(d => d.deviceId === device_id);
      
      if (device) {
        userId = device.userId;
      } else {
        // Create anonymous user
        const newUser = {
          id: `user_${Date.now()}`,
          username: `anonymous-${device_id}`,
          password: await bcrypt.hash(Math.random().toString(), 10),
          isAnonymous: true,
          createdAt: new Date()
        };
        
        inMemoryUsers.push(newUser);
        
        // Create device
        device = {
          id: `device_${Date.now()}`,
          deviceId: device_id,
          userId: newUser.id,
          lastActive: new Date()
        };
        
        inMemoryDevices.push(device);
        
        userId = newUser.id;
      }
    }
    
    // Update device last active time
    if (dbConnected) {
      await DeviceModel.findByIdAndUpdate(device._id, { lastActive: new Date() });
    } else {
      device.lastActive = new Date();
    }
    
    res.json({
      success: true,
      user_id: userId.toString(),
      context_id
    });
  } catch (error) {
    console.error('Error processing context join:', error);
    res.status(500).json({ error: 'Failed to process context join' });
  }
});

// Register a new user
app.post('/auth/register', async (req, res) => {
  try {
    const { username, email, password } = req.body;
    
    if (!username || !email || !password) {
      return res.status(400).json({ error: 'Username, email, and password are required' });
    }
    
    // Check if user already exists
    let existingUser;
    
    if (dbConnected) {
      existingUser = await UserModel.findOne({ $or: [{ username }, { email }] });
    } else {
      existingUser = inMemoryUsers.find(u => u.username === username || u.email === email);
    }
    
    if (existingUser) {
      return res.status(400).json({ error: 'Username or email already in use' });
    }
    
    // Create user
    const hashedPassword = await bcrypt.hash(password, 10);
    let newUser;
    
    if (dbConnected) {
      newUser = await UserModel.create({
        username,
        email,
        password: hashedPassword,
        isAdmin: false,
        isAnonymous: false
      });
      
      newUser = {
        id: newUser._id.toString(),
        username: newUser.username,
        email: newUser.email,
        created_at: newUser.createdAt
      };
    } else {
      newUser = {
        id: `user_${Date.now()}`,
        username,
        email,
        password: hashedPassword,
        isAdmin: false,
        isAnonymous: false,
        createdAt: new Date()
      };
      
      inMemoryUsers.push(newUser);
      
      // Remove password from response
      const { password, ...userWithoutPassword } = newUser;
      newUser = userWithoutPassword;
    }
    
    // Generate token
    const token = jwt.sign({ userId: newUser.id }, JWT_SECRET, { expiresIn: '7d' });
    
    res.status(201).json({
      user: newUser,
      token
    });
  } catch (error) {
    console.error('Error registering user:', error);
    res.status(500).json({ error: 'Failed to register user' });
  }
});

// Login
app.post('/auth/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password are required' });
    }
    
    // Find user
    let user, passwordMatch;
    
    if (dbConnected) {
      user = await UserModel.findOne({ username });
      
      if (!user) {
        return res.status(401).json({ error: 'Invalid credentials' });
      }
      
      // Check password
      passwordMatch = await bcrypt.compare(password, user.password);
    } else {
      user = inMemoryUsers.find(u => u.username === username);
      
      if (!user) {
        return res.status(401).json({ error: 'Invalid credentials' });
      }
      
      // Check password
      passwordMatch = await bcrypt.compare(password, user.password);
    }
    
    if (!passwordMatch) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    // Generate token
    const token = jwt.sign({ userId: user._id || user.id }, JWT_SECRET, { expiresIn: '7d' });
    
    // Prepare user data (remove password)
    let userData;
    
    if (dbConnected) {
      userData = {
        id: user._id.toString(),
        username: user.username,
        email: user.email,
        isAdmin: user.isAdmin,
        created_at: user.createdAt
      };
    } else {
      const { password, ...userWithoutPassword } = user;
      userData = userWithoutPassword;
    }
    
    res.json({
      user: userData,
      token
    });
  } catch (error) {
    console.error('Error logging in:', error);
    res.status(500).json({ error: 'Failed to login' });
  }
});

// Register device
app.post('/auth/register-device', authenticate, async (req, res) => {
  try {
    const { device_id } = req.body;
    
    if (!device_id) {
      return res.status(400).json({ error: 'Device ID is required' });
    }
    
    // Check if device already exists
    let device;
    
    if (dbConnected) {
      device = await DeviceModel.findOne({ deviceId: device_id });
      
      if (device) {
        // Update device user if it's an anonymous device
        const existingUser = await UserModel.findById(device.userId);
        
        if (existingUser && existingUser.isAnonymous) {
          // Update device to point to authenticated user
          await DeviceModel.findByIdAndUpdate(device._id, { userId: req.user._id });
          
          // Optionally, delete or mark the anonymous user
          // await UserModel.findByIdAndDelete(existingUser._id);
        } else if (device.userId.toString() !== req.user._id.toString()) {
          return res.status(400).json({ error: 'Device already registered to another user' });
        }
      } else {
        // Create new device
        device = await DeviceModel.create({
          deviceId: device_id,
          userId: req.user._id,
          lastActive: new Date()
        });
      }
      
      device = {
        id: device._id.toString(),
        device_id: device.deviceId,
        last_active: device.lastActive
      };
    } else {
      device = inMemoryDevices.find(d => d.deviceId === device_id);
      
      if (device) {
        // Check if it's an anonymous device
        const existingUser = inMemoryUsers.find(u => u.id === device.userId);
        
        if (existingUser && existingUser.isAnonymous) {
          // Update device to point to authenticated user
          device.userId = req.user.id;
          
          // Optionally, remove the anonymous user
          // const index = inMemoryUsers.findIndex(u => u.id === existingUser.id);
          // if (index !== -1) inMemoryUsers.splice(index, 1);
        } else if (device.userId !== req.user.id) {
          return res.status(400).json({ error: 'Device already registered to another user' });
        }
      } else {
        // Create new device
        device = {
          id: `device_${Date.now()}`,
          deviceId: device_id,
          userId: req.user.id,
          lastActive: new Date()
        };
        
        inMemoryDevices.push(device);
      }
    }
    
    res.json({ device });
  } catch (error) {
    console.error('Error registering device:', error);
    res.status(500).json({ error: 'Failed to register device' });
  }
});

// Get users for a context
app.get('/users/context/:contextId', async (req, res) => {
  try {
    const contextId = req.params.contextId;
    
    // This is a simplified implementation
    // In a real app, you would query a user-context association table
    
    // For demo, return some sample users
    const sampleUsers = [
      { id: 'user1', username: 'user1', profile: { avatar: 'avatar1.png' } },
      { id: 'user2', username: 'user2', profile: { avatar: 'avatar2.png' } },
      { id: 'user3', username: 'user3', profile: { avatar: 'avatar3.png' } }
    ];
    
    res.json({ users: sampleUsers, context_id: contextId });
  } catch (error) {
    console.error(`Error getting users for context ${req.params.contextId}:`, error);
    res.status(500).json({ error: 'Failed to retrieve users' });
  }
});

// Start the server
async function startServer() {
  // Connect to MongoDB (if available)
  await connectToMongoDB();
  
  // Start the server
  app.listen(port, () => {
    console.log(`User service listening on port ${port}`);
    if (!dbConnected) {
      console.log('Warning: Running with in-memory storage (no MongoDB connection)');
    }
  });
}

startServer();
EOF

# Create models file for the User Service
cat > src/user-service/models.js << 'EOF'
const mongoose = require('mongoose');
const Schema = mongoose.Schema;

// Schema for users
const userSchema = new Schema({
  // Username
  username: {
    type: String,
    required: true,
    unique: true,
    trim: true
  },
  
  // Email
  email: {
    type: String,
    required: false,
    unique: true,
    sparse: true, // Allow null/undefined values
    trim: true,
    lowercase: true
  },
  
  // Password (hashed)
  password: {
    type: String,
    required: true
  },
  
  // User profile information
  profile: {
    type: {
      displayName: String,
      avatar: String,
      bio: String
    },
    default: {}
  },
  
  // Is admin user
  isAdmin: {
    type: Boolean,
    default: false
  },
  
  // Is anonymous user (created automatically for devices)
  isAnonymous: {
    type: Boolean,
    default: false
  }
}, { timestamps: true });

// Schema for devices
const deviceSchema = new Schema({
  // Device identifier
  deviceId: {
    type: String,
    required: true,
    unique: true,
    trim: true
  },
  
  // User who owns this device
  userId: {
    type: Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  
  // Last active timestamp
  lastActive: {
    type: Date,
    default: Date.now
  },
  
  // Device metadata
  metadata: {
    type: Schema.Types.Mixed,
    default: {}
  }
}, { timestamps: true });

// Add indexes for faster queries
userSchema.index({ username: 1 });
userSchema.index({ email: 1 });
userSchema.index({ isAnonymous: 1 });

deviceSchema.index({ deviceId: 1 });
deviceSchema.index({ userId: 1 });
deviceSchema.index({ lastActive: -1 });

// Create models
const UserModel = mongoose.model('User', userSchema);
const DeviceModel = mongoose.model('Device', deviceSchema);

module.exports = {
  UserModel,
  DeviceModel
};
EOF

# Create package.json for the User Service
cat > src/user-service/package.json << 'EOF'
{
  "name": "user-service",
  "version": "1.0.0",
  "description": "User management service for Presence application",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mongoose": "^7.5.0",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

echo "===== 2. Creating Docker Configuration for User Service ====="
mkdir -p docker/user-service

cat > docker/user-service/Dockerfile << 'EOF'
FROM node:16-alpine

WORKDIR /app

# Copy package files
COPY src/user-service/package*.json ./
RUN npm install

# Copy source code
COPY src/user-service/ ./

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3003/health || exit 1

# Environment variables
ENV NODE_ENV=production
ENV PORT=3003

EXPOSE 3003

CMD ["node", "index.js"]
EOF

echo "===== 3. Creating Kubernetes Configuration for User Service ====="
mkdir -p k8s/services k8s/deployments

# Create Kubernetes Secret for JWT
cat > k8s/secrets/jwt-secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: jwt-secret
  namespace: presence
type: Opaque
data:
  jwt-secret: cHJlc2VuY2Utand0LXNlY3JldC1rZXk=  # presence-jwt-secret-key (base64 encoded)
EOF

# Create Kubernetes Service
cat > k8s/services/user-service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: presence
  labels:
    app: user-service
spec:
  selector:
    app: user-service
  ports:
    - port: 3003
      targetPort: 3003
      name: http
  type: ClusterIP
EOF

# Create Kubernetes Deployment
cat > k8s/deployments/user-service.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: presence
  labels:
    app: user-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
    spec:
      containers:
        - name: user-service
          image: presence/user-service:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3003
          env:
            - name: PORT
              value: "3003"
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
            - name: JWT_SECRET
              valueFrom:
                secretKeyRef:
                  name: jwt-secret
                  key: jwt-secret
          livenessProbe:
            httpGet:
              path: /health
              port: 3003
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: 3003
            initialDelaySeconds: 5
            periodSeconds: 5
EOF

# Create NodePort service for direct testing
cat > k8s/services/user-service-nodeport.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: user-service-nodeport
  namespace: presence
  labels:
    app: user-service
spec:
  selector:
    app: user-service
  ports:
    - port: 3003
      targetPort: 3003
      nodePort: 30003
      name: http
  type: NodePort
EOF

# Update Ingress for user service
cat > k8s/ingress/user-ingress.yaml << 'EOF'
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
EOF

echo "===== 4. Creating Build and Deploy Scripts ====="

# Create build script
cat > build-user-service.sh << 'EOF'
#!/bin/bash
set -e

echo "Building User Service..."
docker build -t presence/user-service -f docker/user-service/Dockerfile .
echo "User Service built successfully!"
EOF
chmod +x build-user-service.sh

# Create deploy script
cat > deploy-user-service.sh << 'EOF'
#!/bin/bash
set -e

echo "Deploying User Service to Kubernetes..."

# Apply JWT secret
kubectl apply -f k8s/secrets/jwt-secret.yaml

# Apply Kubernetes Service and Deployment
kubectl apply -f k8s/services/user-service.yaml
kubectl apply -f k8s/services/user-service-nodeport.yaml
kubectl apply -f k8s/deployments/user-service.yaml

# Wait for deployment to be ready
kubectl rollout status deployment/user-service -n presence

echo "Deploying updated ingress configuration..."
kubectl apply -f k8s/ingress/user-ingress.yaml

echo "User Service deployed successfully!"
EOF
chmod +x deploy-user-service.sh

# Create test script
cat > test-user-service.sh << 'EOF'
#!/bin/bash

echo "===== Testing User Service ====="
kubectl -n presence port-forward svc/user-service 3003:3003 &
US_PID=$!
sleep 3

echo "===== Testing Root Path ====="
curl http://localhost:3003/
echo -e "\n"

echo "===== Testing Health Endpoint ====="
curl http://localhost:3003/health
echo -e "\n"

echo "===== Registering a Test User ====="
REGISTER_RESPONSE=$(curl -X POST http://localhost:3003/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@talkstudio.space","password":"password123"}')
echo $REGISTER_RESPONSE
echo -e "\n"

# Extract token
TOKEN=$(echo $REGISTER_RESPONSE | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

echo "===== Logging in as Test User ====="
curl -X POST http://localhost:3003/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"password123"}'
echo -e "\n"

echo "===== Getting User Profile ====="
curl -H "Authorization: Bearer $TOKEN" http://localhost:3003/users/me
echo -e "\n"

echo "===== Testing Device Registration ====="
curl -X POST http://localhost:3003/auth/register-device \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"device_id":"test-device-123"}'
echo -e "\n"

echo "===== Testing User lookup by Device ID ====="
curl http://localhost:3003/users/device/test-device-123
echo -e "\n"

# Clean up
kill $US_PID

echo "===== User Service Test Complete ====="
EOF
chmod +x test-user-service.sh

echo "===== User Service Implementation Complete ====="
echo ""
echo "To build the User Service:"
echo "  ./build-user-service.sh"
echo ""
echo "To deploy the User Service to Kubernetes:"
echo "  ./deploy-user-service.sh"
echo ""
echo "To test the User Service:"
echo "  ./test-user-service.sh"
