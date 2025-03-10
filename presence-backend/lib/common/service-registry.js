const ServiceClient = require('./service-client');

class ServiceRegistry {
  constructor() {
    this.services = {};
    this.initializeServices();
  }
  
  /**
   * Initialize clients for all known services
   */
  initializeServices() {
    const serviceNames = [
      'fingerprint-service',
      'context-service',
      'chat-service',
      'user-service',
      'search-service',
      'notification-service'
    ];
    
    for (const serviceName of serviceNames) {
      this.services[serviceName] = new ServiceClient(serviceName);
    }
  }
  
  /**
   * Get a client for a specific service
   */
  getService(serviceName) {
    if (!this.services[serviceName]) {
      this.services[serviceName] = new ServiceClient(serviceName);
    }
    
    return this.services[serviceName];
  }
  
  /**
   * Check health of all services
   */
  async checkAllServices() {
    const results = {};
    
    for (const [serviceName, serviceClient] of Object.entries(this.services)) {
      results[serviceName] = await serviceClient.checkHealth();
    }
    
    return results;
  }
}

// Export a singleton instance
module.exports = new ServiceRegistry();
