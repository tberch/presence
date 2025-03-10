#!/bin/bash
# Script to build and deploy a local Docker image for the Audio Event Detection app

# Set variables
IMAGE_NAME="audio-event-detector"
IMAGE_TAG="latest"
NAMESPACE="default"

echo "===== Building local Docker image ====="
# Create a temporary directory
mkdir -p ./docker-build
cd ./docker-build

# Copy required files
echo "Copying application files..."
cp ../index.html .
cp ../audio-event-detector.js .

# Create Dockerfile
echo "Creating Dockerfile..."
cat > Dockerfile << EOF
FROM nginx:alpine

# Copy web files to nginx html directory
COPY index.html /usr/share/nginx/html/
COPY audio-event-detector.js /usr/share/nginx/html/

# Expose port 80
EXPOSE 80

# Use nginx's default command to start nginx
CMD ["nginx", "-g", "daemon off;"]
EOF

# Build Docker image
echo "Building Docker image..."
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .

# Check for Docker Desktop Kubernetes
if kubectl config current-context | grep -q "docker-desktop"; then
  echo "Using Docker Desktop Kubernetes - no need to push to registry"
else
  # If using a remote cluster, enable these lines
  # echo "Pushing Docker image to registry..."
  # docker tag ${IMAGE_NAME}:${IMAGE_TAG} your-registry/${IMAGE_NAME}:${IMAGE_TAG}
  # docker push your-registry/${IMAGE_NAME}:${IMAGE_TAG}
  echo "Note: For remote clusters, you'll need to push to a registry"
fi

# Go back to original directory
cd ..

echo "===== Updating Kubernetes deployment ====="
# Update kubernetes deployment file to use local image
cat > kubernetes-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: audio-detection-app
  labels:
    app: audio-detection
spec:
  replicas: 1
  selector:
    matchLabels:
      app: audio-detection
  template:
    metadata:
      labels:
        app: audio-detection
    spec:
      containers:
      - name: audio-detection
        image: ${IMAGE_NAME}:${IMAGE_TAG}
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: "0.5"
            memory: "512Mi"
          requests:
            cpu: "0.2"
            memory: "256Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: audio-detection-service
spec:
  selector:
    app: audio-detection
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: audio-detection-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
  - host: audio-detection.talkstudio.space  # Replace with your domain
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: audio-detection-service
            port:
              number: 80
EOF

# Apply Kubernetes configurations
echo "Applying Kubernetes configurations..."
kubectl delete deployment audio-detection-app 2>/dev/null || true
kubectl apply -f kubernetes-deployment.yaml -n ${NAMESPACE}

# Wait for deployment to be ready
echo "Waiting for deployment to be ready..."
kubectl rollout status deployment/audio-detection-app -n ${NAMESPACE}

# Get service information
echo "Deployment complete! Here's how to access your application:"
echo "Service: "
kubectl get service audio-detection-service -n ${NAMESPACE}
echo "Ingress: "
kubectl get ingress audio-detection-ingress -n ${NAMESPACE}

echo "Setting up port-forward for testing:"
POD_NAME=$(kubectl get pods -l app=audio-detection -o jsonpath='{.items[0].metadata.name}')
echo "kubectl port-forward ${POD_NAME} 8080:80"
echo "Then visit http://localhost:8080 in your browser"
