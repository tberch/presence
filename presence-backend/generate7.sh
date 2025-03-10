#!/bin/bash
# Comprehensive Ingress troubleshooting script

echo "======== CHECKING INGRESS RESOURCES ========"
kubectl get ingress -n presence
kubectl describe ingress -n presence

echo ""
echo "======== CHECKING FINGERPRINT SERVICE ========"
kubectl get svc fingerprint-service -n presence
kubectl get pods -l app=fingerprint-service -n presence
echo "Checking if fingerprint service responds internally:"
kubectl exec -n presence $(kubectl get pods -n presence -l app=fingerprint-service -o jsonpath='{.items[0].metadata.name}') -- curl -s localhost:3000/health || echo "Failed to connect to service internally"

echo ""
echo "======== CREATING SIMPLIFIED INGRESS ========"
cat > k8s/ingress/simplified.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: simplified-ingress
  namespace: presence
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
  - http:
      paths:
      - path: /test
        pathType: Prefix
        backend:
          service:
            name: fingerprint-service
            port:
              number: 3000
EOF

kubectl apply -f k8s/ingress/simplified.yaml

echo ""
echo "======== INGRESS CONTROLLER LOGS ========"
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50

echo ""
echo "======== CREATING TEST SERVICE FOR VALIDATION ========"
# Create a simple echo service to test Ingress
cat > k8s/deployments/echo-server.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo-server
  namespace: presence
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo-server
  template:
    metadata:
      labels:
        app: echo-server
    spec:
      containers:
      - name: echo-server
        image: ealen/echo-server:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: echo-server
  namespace: presence
spec:
  selector:
    app: echo-server
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: echo-ingress
  namespace: presence
  annotations:
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
  - http:
      paths:
      - path: /echo
        pathType: Prefix
        backend:
          service:
            name: echo-server
            port:
              number: 80
EOF

kubectl apply -f k8s/deployments/echo-server.yaml

echo ""
echo "======== TESTING OPTIONS ========"
echo "Wait 30 seconds for resources to be ready, then try:"
echo "1. Access the simplified ingress at: http://localhost/test/health"
echo "2. Access the echo server at: http://localhost/echo"
echo "3. Check the NodePort services:"

# Get NodePort services and their ports
kubectl get svc -n presence | grep NodePort

echo ""
echo "If the NodePort services work but Ingress doesn't, check the Ingress controller configuration"
