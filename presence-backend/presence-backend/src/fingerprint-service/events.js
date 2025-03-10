const axios = require('axios');

/**
 * Publish an event to notify other services
 * This uses HTTP calls to the event service
 */
const publishEvent = async (eventType, payload) => {
  try {
    // In Kubernetes, services can be accessed by their service name
    const eventServiceUrl = process.env.EVENT_SERVICE_URL || 'http://context-service:3001';
    
    await axios.post(`${eventServiceUrl}/events`, {
      type: eventType,
      source: 'fingerprint-service',
      timestamp: new Date().toISOString(),
      payload
    });
    
    console.log(`Event ${eventType} published successfully`);
    return true;
  } catch (error) {
    console.error(`Failed to publish event ${eventType}:`, error.message);
    return false;
  }
};

module.exports = {
  publishEvent
};
