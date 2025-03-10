cat > k8s/ingress/simple-ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: simple-ingress
  namespace: presence
spec:
  rules:
  - host: presence.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: fingerprint-service
            port:
              number: 3000
EOF

# Apply it
kubectl apply -f k8s/ingress/simple-ingress.yaml
