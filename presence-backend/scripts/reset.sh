#!/bin/bash
set -e

echo "Resetting Presence environment..."

# Confirm with the user
read -p "Are you sure you want to delete all Presence resources? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Operation cancelled."
    exit 1
fi

# Delete all resources in the presence namespace
kubectl delete namespace presence --ignore-not-found=true

echo "Reset complete!"
