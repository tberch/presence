cat > service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: audio-event-detector
spec:
  selector:
    app: audio-event-detector
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF
