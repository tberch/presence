# Copy the enhanced fingerprint service files
cp enhanced-fingerprint-service.js services/fingerprint-service/src/index.js
cp fingerprinting-module.js services/fingerprint-service/src/fingerprinting.js
cp db-models.js services/fingerprint-service/src/models.js

# Create package.json for fingerprint service
cat > services/fingerprint-service/package.json << 'EOF'
{
  "name": "fingerprint-service",
  "version": "1.0.0",
  "description": "Audio fingerprinting service for Presence",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js"
  },
  "dependencies": {
    "axios": "^0.27.2",
    "body-parser": "^1.20.0",
    "express": "^4.18.1",
    "mongoose": "^6.3.3"
  },
  "devDependencies": {
    "nodemon": "^2.0.20"
  }
}
EOF
