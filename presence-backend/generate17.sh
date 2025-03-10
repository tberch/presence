#!/bin/bash
# This script fixes the ingress configuration issues

echo "===== 1. Checking Existing Ingress Configurations ====="
kubectl get ingress -n presence

echo "===== 2. Updating the api-gateway Ingress Instead of Creating a New One ====="
# Instead of creating a new ingress, let's update the existing api-gateway
cat > k8s/ingress/api-gateway-updated.yaml << 'EOF'
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
            pathType: ImplementationSpecific
            backend:
              service:
                name: fingerprint-service
                port:
                  number: 3000
          - path: /context(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: context-service
                port:
                  number: 3001
          - path: /chat(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: chat-service
                port:
                  number: 3002
          - path: /user(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: user-service
                port:
                  number: 3003
          - path: /search(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: search-service
                port:
                  number: 3004
          - path: /notification(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: notification-service
                port:
                  number: 3005
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: fingerprint-service
                port:
                  number: 3000
EOF

kubectl apply -f k8s/ingress/api-gateway-updated.yaml

echo "===== 3. Cleanup any conflicting ingress resources ====="
# List all other ingress resources that might conflict
INGRESS_TO_DELETE=$(kubectl get ingress -n presence | grep -v "api-gateway" | awk 'NR>1 {print $1}')

# Delete them if they exist
if [ ! -z "$INGRESS_TO_DELETE" ]; then
  echo "Deleting conflicting ingress resources: $INGRESS_TO_DELETE"
  kubectl delete ingress $INGRESS_TO_DELETE -n presence
else
  echo "No conflicting ingress resources found"
fi

echo "===== 4. Creating Test Script ====="
# Create a test script for the updated service
cat > test-fingerprint.sh << 'EOF'
#!/bin/bash

echo "===== Testing Direct Access (Port Forward) ====="
echo "Setting up port forwarding..."
kubectl -n presence port-forward svc/fingerprint-service 3000:3000 &
PF_PID=$!
sleep 3

echo "Testing POST to /fingerprint endpoint:"
curl -X POST http://localhost:3000/fingerprint \
  -H "Content-Type: application/json" \
  -d '{"audioData":"dGVzdCBhdWRpbyBkYXRhIGZvciBmaW5nZXJwcmludGluZw==","location":{"latitude":37.7749,"longitude":-122.4194},"device_id":"test-device-123"}'
echo -e "\n"

# Kill port-forwarding
kill $PF_PID

echo "===== Testing Ingress Access ====="
echo "Testing service via presence.local host header:"
curl -H "Host: presence.local" http://localhost/fingerprint/health
echo -e "\n"

echo "Testing service via direct localhost access:"
curl http://localhost/fingerprint/health
echo -e "\n"

echo "Testing POST to /fingerprint via ingress (localhost):"
curl -X POST http://localhost/fingerprint \
  -H "Content-Type: application/json" \
  -d '{"audioData":"dGVzdCBhdWRpbyBkYXRhIGZvciBmaW5nZXJwcmludGluZw==","location":{"latitude":37.7749,"longitude":-122.4194},"device_id":"test-device-123"}'
echo -e "\n"

echo "Testing POST to /fingerprint via ingress (presence.local):"
curl -X POST -H "Host: presence.local" http://localhost/fingerprint \
  -H "Content-Type: application/json" \
  -d '{"audioData":"dGVzdCBhdWRpbyBkYXRhIGZvciBmaW5nZXJwcmludGluZw==","location":{"latitude":37.7749,"longitude":-122.4194},"device_id":"test-device-123"}'
echo -e "\n"
EOF
chmod +x test-fingerprint.sh

echo "===== NEXT STEPS ====="
echo "1. Run the test script to verify both issues are fixed:"
echo "   ./test-fingerprint.sh"
echo ""
echo "2. If the test through ingress still fails, try these commands to debug:"
echo "   kubectl get ingress -n presence"
echo "   kubectl describe ingress api-gateway -n presence"
echo "   kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller"
