# Update fingerprint service deployment
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
            - name: CONTEXT_SERVICE_URL
              valueFrom:
                configMapKeyRef:
                  name: service-config
                  key: CONTEXT_SERVICE_URL
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

# Create context service deployment
cat > k8s/deployments/context-service.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: context-service
  namespace: presence
  labels:
    app: context-service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: context-service
  template:
    metadata:
      labels:
        app: context-service
    spec:
      containers:
        - name: context-service
          image: presence/context-service:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3001
          env:
            - name: SERVICE_NAME
              value: "context-service"
            - name: PORT
              value: "3001"
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
            - name: FINGERPRINT_SERVICE_URL
              valueFrom:
                configMapKeyRef:
                  name: service-config
                  key: FINGERPRINT_SERVICE_URL
            - name: CHAT_SERVICE_URL
              valueFrom:
                configMapKeyRef:
                  name: service-config
                  key: CHAT_SERVICE_URL
            - name: USER_SERVICE_URL
              valueFrom:
                configMapKeyRef:
                  name: service-config
                  key: USER_SERVICE_URL
            - name: NOTIFICATION_SERVICE_URL
              valueFrom:
                configMapKeyRef:
                  name: service-config
                  key: NOTIFICATION_SERVICE_URL
          livenessProbe:
            httpGet:
              path: /health
              port: 3001
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: 3001
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

# Create context service K8s service
cat > k8s/services/context-service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: context-service
  namespace: presence
  labels:
    app: context-service
spec:
  selector:
    app: context-service
  ports:
    - port: 3001
      targetPort: 3001
      name: http
  type: ClusterIP
EOF

# Create context service NodePort for testing
cat > k8s/services/context-service-nodeport.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: context-service-nodeport
  namespace: presence
  labels:
    app: context-service
spec:
  selector:
    app: context-service
  ports:
    - port: 3001
      targetPort: 3001
      nodePort: 30001
      name: http
  type: NodePort
EOF
