const axios = require('axios');

/**
 * ServiceClient - A client for making requests to other microservices
 * Uses Kubernetes DNS for service discovery
 */
class ServiceClient {
  constructor(serviceName, options = {}) {
    this.serviceName = serviceName;
    this.port = options.port || this.getDefaultPort(serviceName);
    this.baseUrl = `http://${serviceName}:${this.port}`;
    this.timeout = options.timeout || 5000;
    
    // Create axios instance with default config
    this.client = axios.create({
      baseURL: this.baseUrl,
      timeout: this.timeout,
      headers: {
        'Content-Type': 'application/json',
        'X-Service-Name': process.env.SERVICE_NAME || 'unknown-service'
      }
    });
    
    // Add request interceptor for tracing
    this.client.interceptors.request.use(config => {
      // Add request ID for tracing
      config.headers['X-Request-ID'] = generateRequestId();
      return config;
    });
    
    // Add response interceptor for error handling
    this.client.interceptors.response.use(
      response => response,
      error => this.handleRequestError(error)
    );
  }
  
  /**
   * Get default port for known services
   */
  getDefaultPort(serviceName) {
    const portMap = {
      'fingerprint-service': 3000,
      'context-service': 3001,
      'chat-service': 3002,
      'user-service': 3003,
      'search-service': 3004,
      'notification-service': 3005
    };
    
    return portMap[serviceName] || 3000;
  }
  
  /**
   * Handle request errors with proper logging and retry logic
   */
  handleRequestError(error) {
    if (error.response) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx
      console.error(`Service ${this.serviceName} responded with error:`, {
        status: error.response.status,
        data: error.response.data,
        url: error.config.url
      });
    } else if (error.request) {
      // The request was made but no response was received
      console.error(`No response from service ${this.serviceName}:`, {
        url: error.config.url,
        timeout: this.timeout
      });
    } else {
      // Something happened in setting up the request that triggered an Error
      console.error(`Error making request to ${this.serviceName}:`, error.message);
    }
    
    return Promise.reject(error);
  }
  
  /**
   * Make a GET request to the service
   */
  async get(path, options = {}) {
    try {
      const response = await this.client.get(path, options);
      return response.data;
    } catch (error) {
      throw error;
    }
  }
  
  /**
   * Make a POST request to the service
   */
  async post(path, data, options = {}) {
    try {
      const response = await this.client.post(path, data, options);
      return response.data;
    } catch (error) {
      throw error;
    }
  }
  
  /**
   * Make a PUT request to the service
   */
  async put(path, data, options = {}) {
    try {
      const response = await this.client.put(path, data, options);
      return response.data;
    } catch (error) {
      throw error;
    }
  }
  
  /**
   * Make a DELETE request to the service
   */
  async delete(path, options = {}) {
    try {
      const response = await this.client.delete(path, options);
      return response.data;
    } catch (error) {
      throw error;
    }
  }
  
  /**
   * Check if the service is healthy
   */
  async checkHealth() {
    try {
      const response = await this.client.get('/health');
      return response.data.status === 'ok';
    } catch (error) {
      console.error(`Health check failed for ${this.serviceName}:`, error.message);
      return false;
    }
  }
}

/**
 * Generate a unique request ID for tracing
 */
function generateRequestId() {
  return `req_${Date.now()}_${Math.random().toString(36).substring(2, 15)}`;
}

module.exports = ServiceClient;
