#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_SCRIPTS_DIR="$SCRIPT_DIR/../db-scripts"

echo "Initializing databases for Presence..."

# PostgreSQL initialization
echo "Initializing PostgreSQL..."
kubectl exec -it -n presence $(kubectl get pods -n presence -l app=postgres -o jsonpath="{.items[0].metadata.name}") -- \
  psql -U presence.admin -d presence -f /dev/stdin < "$DB_SCRIPTS_DIR/postgres-init.sql"

# MongoDB initialization
echo "Initializing MongoDB..."
kubectl exec -it -n presence $(kubectl get pods -n presence -l app=mongodb -o jsonpath="{.items[0].metadata.name}") -- \
  sh -c "cat > /tmp/mongo-init.js && mongo -u presence.admin -p changeme --authenticationDatabase admin presence /tmp/mongo-init.js" \
  < "$DB_SCRIPTS_DIR/mongo-init.js"

echo "Database initialization complete!"
