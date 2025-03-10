#!/bin/bash
set -e

echo "Generating secure secrets for Presence..."

# Generate random passwords
POSTGRES_PASSWORD=$(openssl rand -base64 16)
MONGODB_PASSWORD=$(openssl rand -base64 16)
REDIS_PASSWORD=$(openssl rand -base64 16)
JWT_SECRET=$(openssl rand -base64 32)

# Create secrets file
cat > k8s/secrets/db-credentials.yaml << EOT
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: presence
type: Opaque
data:
  postgres-user: $(echo -n "presence.admin" | base64)
  postgres-password: $(echo -n "$POSTGRES_PASSWORD" | base64)
  mongodb-user: $(echo -n "presence.admin" | base64)
  mongodb-password: $(echo -n "$MONGODB_PASSWORD" | base64)
  redis-password: $(echo -n "$REDIS_PASSWORD" | base64)
EOT

# Create JWT secret
cat > k8s/secrets/jwt-secret.yaml << EOT
apiVersion: v1
kind: Secret
metadata:
  name: jwt-secret
  namespace: presence
type: Opaque
data:
  jwt-secret: $(echo -n "$JWT_SECRET" | base64)
EOT

echo "Secrets generated successfully!"
echo "--------------------------------"
echo "IMPORTANT: Keep these values in a secure location"
echo "PostgreSQL Password: $POSTGRES_PASSWORD"
echo "MongoDB Password: $MONGODB_PASSWORD"
echo "Redis Password: $REDIS_PASSWORD"
echo "JWT Secret: $JWT_SECRET"
echo "--------------------------------"
