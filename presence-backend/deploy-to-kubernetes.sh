# Apply all resources
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml

# Check status
kubectl get pods -l app=audio-event-detector
kubectl get svc audio-event-detector
kubectl get ingress audio-event-detector
