#/bin/bash
# Login to Docker Hub
docker login

# Tag your image for Docker Hub (replace tberchenbriter)
docker tag audio-event-detector:v1 tberchenbriter/audio-event-detector:v1

# Push to Docker Hub
docker push tberchenbriter/audio-event-detector:v1
