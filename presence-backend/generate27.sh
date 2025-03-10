# Create MongoDB StatefulSet
cat > k8s/databases/mongodb.yaml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
  namespace: presence
spec:
  serviceName: mongodb
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
        - name: mongodb
          image: mongo:5
          ports:
            - containerPort: 27017
          env:
            - name: MONGO_INITDB_DATABASE
              valueFrom:
                configMapKeyRef:
                  name: database-config
                  key: MONGODB_DB
            - name: MONGO_INITDB_ROOT_USERNAME
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: mongodb-user
            - name: MONGO_INITDB_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: mongodb-password
          volumeMounts:
            - name: mongodb-data
              mountPath: /data/db
          resources:
            limits:
              cpu: "1000m"
              memory: "1Gi"
            requests:
              cpu: "500m"
              memory: "512Mi"
  volumeClaimTemplates:
    - metadata:
        name: mongodb-data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb
  namespace: presence
spec:
  selector:
    app: mongodb
  ports:
    - port: 27017
      targetPort: 27017
  clusterIP: None
EOF

# Create MongoDB storage
cat > k8s/storage/mongodb-pv.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mongodb-pv
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data/mongodb"
EOF

cat > k8s/storage/mongodb-pvc.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb-pvc
  namespace: presence
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF