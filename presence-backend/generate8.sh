#!/bin/bash
# Fix all ingress resources to use the correct IngressClass

# Fix the main API Gateway ingress
cat > k8s/ingress/api-gateway.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-gateway
  namespace: presence
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
    - host: presence.local
      http:
        paths:
          - path: /fingerprint(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: fingerprint-service
                port:
                  number: 3000
          - path: /context(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: context-service
                port:
                  number: 3001
          - path: /chat(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: chat-service
                port:
                  number: 3002
          - path: /user(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: user-service
                port:
                  number: 3003
          - path: /search(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: search-service
                port:
                  number: 3004
          - path: /notification(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: notification-service
                port:
                  number: 3005
EOF

# Fix the simplified ingress
cat > k8s/ingress/simplified.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: simplified-ingress
  namespace: presence
spec:
  ingressClassName: nginx
  rules:
    - host: presence.local
      http:
        paths:
          - path: /test
            pathType: Prefix
            backend:
              service:
                name: fingerprint-service
                port:
                  number: 3000
EOF

# Create a catch-all ingress for http://localhost access
cat > k8s/ingress/catch-all.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: catch-all-ingress
  namespace: presence
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: fingerprint-service
                port:
                  number: 3000
          - path: /fingerprint
            pathType: Prefix
            backend:
              service:
                name: fingerprint-service
                port:
                  number: 3000
          - path: /echo
            pathType: Prefix
            backend:
              service:
                name: echo-server
                port:
                  number: 80
EOF

# Apply all the fixed ingress resources
kubectl apply -f k8s/ingress/api-gateway.yaml
kubectl apply -f k8s/ingress/simplified.yaml
kubectl apply -f k8s/ingress/catch-all.yaml

# Delete any old ingresses that might conflict
kubectl delete ingress echo-ingress -n presence

echo "Ingress resources updated with correct IngressClass"
echo "Now you should be able to access:"
echo "1. http://localhost/fingerprint/health - Main API Gateway"
echo "2. http://localhost/test/health - Simplified test path"
echo "3. http://localhost/echo - Echo server test"
echo "4. http://presence.local/fingerprint/health - If your hosts file is configured"

# Check ingress status
echo "Checking ingress status..."
kubectl get ingress -n presence
