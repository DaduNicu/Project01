#!/bin/bash
# Install External Secrets Operator

set -e

echo "Installing External Secrets Operator..."
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm upgrade --install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace \
  --wait

echo "External Secrets Operator installed!"
echo ""
echo "Next steps:"
echo "1. Create GCP Secret Manager secret:"
echo "   echo -n 'helloworld' | gcloud secrets create sys-env --data-file=-"
echo ""
echo "2. Apply SecretStore:"
echo "   kubectl apply -f secret-store.yaml"

