# Set environment variables
export DOCKER_REGISTRY=tberchenbriter
export IMAGE_TAG=presence-webapp
export POSTGRES_PASSWORD=postgres_temp_pass
export MONGODB_PASSWORD=mongodb_temp_pass
export JWT_SECRET=jwt_temp_pass

# Apply Kubernetes configs
kubectl apply -f k8s/
