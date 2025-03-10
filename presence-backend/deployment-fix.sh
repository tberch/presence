#!/bin/bash
# Script to fix microphone access issues in the Audio Event Detection app

echo "===== Audio Event Detection - Deployment Fix ====="

# Create a test directory
echo "Creating test directory..."
mkdir -p ./audio-test
cd ./audio-test

# Save the microphone test HTML file
echo "Creating microphone test file..."
cat > index.html << 'EOF'
<!-- Copy content from the microphone-test artifact -->
EOF

echo "Creating ConfigMap from test file..."
kubectl delete configmap audio-detection-files 2>/dev/null || true
kubectl create configmap audio-detection-files --from-file=index.html

# Update deployment to use the ConfigMap
echo "Updating Kubernetes deployment..."
cat > deployment.yaml << EOF
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
        image: nginx:alpine
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        volumeMounts:
        - name: app-files
          mountPath: /usr/share/nginx/html
      volumes:
      - name: app-files
        configMap:
          name: audio-detection-files
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
  type: LoadBalancer  # Changed to LoadBalancer for direct access
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
  - host: audio-detection.talkstudio.space
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

# Apply configuration
echo "Applying updated configuration..."
kubectl apply -f deployment.yaml

# Wait for deployment to be ready
echo "Waiting for deployment to be ready..."
kubectl rollout status deployment/audio-detection-app

# Get pod name
POD_NAME=$(kubectl get pods -l app=audio-detection -o jsonpath='{.items[0].metadata.name}')
echo "Pod name: $POD_NAME"

# Setup port-forward 
echo "-----------------------------------------------------"
echo "To test the microphone access, run the following command:"
echo "kubectl port-forward $POD_NAME 8080:80"
echo "Then open http://localhost:8080 in your browser"
echo "-----------------------------------------------------"

# Get service information
echo "Service information:"
kubectl get service audio-detection-service

echo "IMPORTANT NOTES ABOUT MICROPHONE ACCESS:"
echo "1. Microphone access works ONLY on localhost or via HTTPS"
echo "2. For testing on localhost, use the port-forward command above"
echo "3. For production, you must configure HTTPS with a valid certificate"
echo "4. Check browser console for detailed error messages"
echo "5. Mobile devices may need different testing approaches"
