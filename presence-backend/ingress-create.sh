cat > ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: audio-event-detector
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  rules:
  - host: audio-detection.talkstudio.space
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: audio-event-detector
            port:
              number: 80
  tls:
  - hosts:
    - audio-detection.talkstudio.space
    secretName: audio-detection-tls
EOF
