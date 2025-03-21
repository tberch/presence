cat > k8s/deployments/fingerprint-service.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fingerprint-service
  namespace: presence
  labels:
    app: fingerprint-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fingerprint-service
  template:
    metadata:
      labels:
        app: fingerprint-service
    spec:
      containers:
        - name: fingerprint-service
          image: presence/fingerprint-service:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3000
          env:
            - name: SERVICE_NAME
              value: "fingerprint-service"
            - name: PORT
              value: "3000"
            - name: NODE_ENV
              valueFrom:
                configMapKeyRef:
                  name: service-config
                  key: NODE_ENV
            - name: MONGODB_HOST
              valueFrom:
                configMapKeyRef:
                  name: database-config
                  key: MONGODB_HOST
            - name: MONGODB_PORT
              valueFrom:
                configMapKeyRef:
                  name: database-config
                  key: MONGODB_PORT
            - name: MONGODB_DB
              valueFrom:
                configMapKeyRef:
                  name: database-config
                  key: MONGODB_DB
            - name: MONGODB_USER
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: mongodb-user
            - name: MONGODB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: mongodb-password
            - name: EVENT_SERVICE_URL
              value: "http://context-service:3001"
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 5
          resources:
            limits:
              cpu: "500m"
              memory: "512Mi"
            requests:
              cpu: "100m"
              memory: "128Mi"
EOF
