#!/bin/bash
# Quick setup script for Vault in dev mode

set -e

echo "Deploying Vault..."
kubectl apply -f vault-deployment.yaml

echo "Waiting for Vault pod..."
kubectl wait --for=condition=ready pod -l app=vault -n vault --timeout=120s

echo "Vault is ready!"
echo "Access Vault UI via port-forward:"
echo "  kubectl port-forward -n vault svc/vault 8200:8200"
echo ""
echo "Root token: root"
echo "Vault addr: http://localhost:8200"
echo ""
echo "To configure secrets:"
echo "  export VAULT_ADDR=http://localhost:8200"
echo "  export VAULT_TOKEN=root"
echo "  vault kv put secret/cicd gcp_sa_key=@path/to/key.json"

