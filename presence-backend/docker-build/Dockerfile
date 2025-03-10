FROM nginx:alpine

# Copy web files to nginx html directory
COPY index.html /usr/share/nginx/html/
COPY audio-event-detector.js /usr/share/nginx/html/

# Expose port 80
EXPOSE 80

# Use nginx's default command to start nginx
CMD ["nginx", "-g", "daemon off;"]
