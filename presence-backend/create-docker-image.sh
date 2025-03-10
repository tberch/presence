# Create a Dockerfile in your project directory
cat > Dockerfile << 'EOF'
FROM nginx:alpine

# Copy application files
COPY index.html /usr/share/nginx/html/
COPY audio-event-detector.js /usr/share/nginx/html/

# Expose port 80
EXPOSE 80
EOF

# Build the Docker image
docker build -t audio-event-detector:v1 .

# Tag the image for your registry
docker tag audio-event-detector:v1 tberchenbriter/audio-event-detector:v1

# Push to your registry
docker push tberchenbriter/audio-event-detector:v1
