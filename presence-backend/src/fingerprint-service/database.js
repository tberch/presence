const { MongoClient } = require('mongodb');

let client;
let db;

/**
 * Connect to the MongoDB database
 */
const connectToDb = async () => {
  try {
    // Get connection details from environment variables
    const mongoHost = process.env.MONGODB_HOST || 'mongodb';
    const mongoPort = process.env.MONGODB_PORT || '27017';
    const mongoDb = process.env.MONGODB_DB || 'presence';
    const mongoUser = process.env.MONGODB_USER || 'presence.admin';
    const mongoPassword = process.env.MONGODB_PASSWORD || 'changeme';
    
    const uri = `mongodb://${mongoUser}:${mongoPassword}@${mongoHost}:${mongoPort}/${mongoDb}?authSource=admin`;
    
    client = new MongoClient(uri);
    await client.connect();
    
    db = client.db(mongoDb);
    console.log('Connected to MongoDB');
    
    // Initialize collections if needed
    await db.collection('fingerprints').createIndex({ signature: 1 });
    await db.collection('contexts').createIndex({ created_at: -1 });
    
    return db;
  } catch (error) {
    console.error('Failed to connect to MongoDB:', error);
    throw error;
  }
};

/**
 * Close the database connection
 */
const closeDb = async () => {
  if (client) {
    await client.close();
    console.log('MongoDB connection closed');
  }
};

// Handle application shutdown
process.on('SIGINT', async () => {
  await closeDb();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  await closeDb();
  process.exit(0);
});

module.exports = {
  connectToDb,
  closeDb,
  getDb: () => db
};
