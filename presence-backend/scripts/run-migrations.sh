#!/bin/bash
set -e

echo "Running database migrations for Presence..."

# Create migration job
cat << 'EOT' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  namespace: presence
spec:
  template:
    spec:
      containers:
        - name: migration
          image: presence/user-service:latest
          command: ["node", "dist/scripts/migrate.js"]
          env:
            - name: POSTGRES_HOST
              valueFrom:
                configMapKeyRef:
                  name: database-config
                  key: POSTGRES_HOST
            - name: POSTGRES_PORT
              valueFrom:
                configMapKeyRef:
                  name: database-config
                  key: POSTGRES_PORT
            - name: POSTGRES_DB
              valueFrom:
                configMapKeyRef:
                  name: database-config
                  key: POSTGRES_DB
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: postgres-user
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: postgres-password
      restartPolicy: Never
  backoffLimit: 4
EOT

# Wait for job to complete
echo "Waiting for migration job to complete..."
kubectl wait --for=condition=complete job/db-migration -n presence --timeout=60s

# Check for success
if kubectl get job db-migration -n presence -o jsonpath='{.status.succeeded}' | grep -q 1; then
  echo "Migrations completed successfully!"
else
  echo "Migration job failed. Check logs for details:"
  kubectl logs job/db-migration -n presence
  exit 1
fi

# Clean up job
kubectl delete job db-migration -n presence

echo "Migration process complete!"
