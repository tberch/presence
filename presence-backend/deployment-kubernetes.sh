cat > deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: audio-event-detector
  labels:
    app: audio-event-detector
spec:
  replicas: 2
  selector:
    matchLabels:
      app: audio-event-detector
  template:
    metadata:
      labels:
        app: audio-event-detector
    spec:
      containers:
      - name: audio-event-detector
        image: your-registry/audio-event-detector:v1
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: "0.5"
            memory: "512Mi"
          requests:
            cpu: "0.2"
            memory: "256Mi"
EOF
