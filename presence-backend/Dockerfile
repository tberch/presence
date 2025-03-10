FROM nginx:alpine

# Create app directory
WORKDIR /usr/share/nginx/html

# Copy application files
COPY index.html .
COPY audio-event-detector.js .

# Expose port 80
EXPOSE 80

# Default command uses nginx's default entrypoint
