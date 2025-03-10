# Create a NodePort service
cat > k8s/services/fingerprint-service-nodeport.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: fingerprint-service-nodeport
  namespace: presence
  labels:
    app: fingerprint-service
spec:
  selector:
    app: fingerprint-service
  ports:
    - port: 3000
      targetPort: 3000
      nodePort: 30000
      name: http
  type: NodePort
EOF

# Apply it
kubectl apply -f k8s/services/fingerprint-service-nodeport.yaml
