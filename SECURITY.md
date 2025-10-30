# Security

## Overview

This project implements multiple layers of security following DevSecOps best practices.

## IAM & Access Control

### Service Accounts

**GKE Node SA** (`gcp-devops-challenge-node-sa`)
- Permissions: logging.logWriter, monitoring.metricWriter, monitoring.viewer
- Purpose: Node-level operations, log/metric shipping
- Scope: Minimal required permissions

**CI/CD SA** (`gcp-devops-challenge-cicd-sa`)
- Permissions: artifactregistry.writer, container.developer
- Purpose: GitHub Actions pipeline
- Scope: Deploy apps, push images only

### Workload Identity

Workload Identity enabled for pod-level authentication to GCP services.

```bash
# Bind K8s SA to GCP SA
kubectl annotate serviceaccount external-secrets-sa \
  -n dev \
  iam.gke.io/gcp-service-account=gcp-devops-challenge-cicd-sa@PROJECT_ID.iam.gserviceaccount.com
```

### Least Privilege

All service accounts follow principle of least privilege:
- No Owner/Editor roles
- Specific resource-level permissions only
- Time-limited credentials preferred

## Secrets Management

### CI/CD Secrets (Vault)

HashiCorp Vault deployed in GKE for CI secrets:
- GitHub tokens
- Service account keys
- API credentials

**Note**: Dev mode used for challenge. Production should use:
- HA Vault deployment
- Auto-unseal with GCP KMS
- Regular backups

### Application Secrets (GCP Secret Manager)

External Secrets Operator syncs secrets from GCP Secret Manager:
- Automatic rotation
- Audit logging
- Version control

```bash
# Create secret
echo -n "helloworld" | gcloud secrets create sys-env --data-file=-

# Grant access
gcloud secrets add-iam-policy-binding sys-env \
  --member="serviceAccount:gcp-devops-challenge-cicd-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### Secret Rotation

1. Update secret in GCP Secret Manager
2. External Secrets Operator refreshes every 1h
3. Or force refresh: restart deployment

## Container Security

### Image Scanning

Trivy scans all images for vulnerabilities:
- Runs on every PR
- Fails on HIGH/CRITICAL CVEs
- SBOM generated with Syft

### Dockerfile Best Practices

- Multi-stage builds (smaller attack surface)
- Non-root user (UID 1000)
- Minimal base image (python:3.11-slim)
- No secrets in layers
- HEALTHCHECK defined

### Runtime Security

Pod security:
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: false  # flask needs write for temp files
```

## Infrastructure Security

### Network

- VPC with private subnets
- Firewall rules limiting access
- GKE cluster can be made private (modify main.tf)

### IaC Scanning

Checkov scans Terraform for misconfigurations:
- Encryption settings
- Public access
- IAM overpermissions
- Compliance checks

### Terraform State

- Stored in GCS bucket
- Versioning enabled
- Encrypted at rest
- Access controlled via IAM

## Supply Chain Security

### SBOM

Software Bill of Materials generated for each image:
- SPDX format
- Uploaded as artifact
- Tracks all dependencies

### Image Signing (Optional)

Can be added with cosign:
```bash
cosign sign --key cosign.key \
  us-central1-docker.pkg.dev/PROJECT_ID/gcp-devops-challenge/app:$SHA
```

### Provenance

Build provenance tracked via:
- Git SHA in image tags
- GitHub Actions logs
- Artifact registry metadata

## Monitoring & Incident Response

### Logging

All logs sent to GCP Cloud Logging:
- Structured JSON format
- Retained for audit
- Searchable and exportable

### Alerting

Prometheus can be configured for alerts:
- High error rates
- Pod restarts
- Resource exhaustion

### Audit Logs

GCP audit logs track:
- IAM changes
- Secret access
- Kubernetes API calls

```bash
gcloud logging read "protoPayload.serviceName=iam.googleapis.com" --limit 10
```

## Compliance

### Standards Followed

- CIS GKE Benchmark (partial)
- OWASP Container Security
- Least privilege access
- Defense in depth

### Regular Tasks

- [ ] Review IAM permissions quarterly
- [ ] Update base images monthly
- [ ] Rotate service account keys (if using keys)
- [ ] Review audit logs weekly
- [ ] Update dependencies (dependabot)

## Threat Model

### Attack Vectors

1. **Compromised CI/CD**
   - Mitigation: OIDC auth, limited SA permissions, audit logs

2. **Container breakout**
   - Mitigation: Non-root user, readonly filesystem where possible

3. **Supply chain attack**
   - Mitigation: SBOM, image scanning, signed images

4. **Credential theft**
   - Mitigation: Short-lived tokens, Workload Identity, Vault

5. **DoS attack**
   - Mitigation: HPA, rate limiting (can add), GCP DDoS protection

## Hardening Recommendations

For production:

1. **Enable Private GKE Cluster**
```hcl
private_cluster_config {
  enable_private_nodes    = true
  enable_private_endpoint = false
  master_ipv4_cidr_block = "172.16.0.0/28"
}
```

2. **Add Network Policies**
```yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: app-network-policy
spec:
  podSelector:
    matchLabels:
      app: app
  policyTypes:
  - Ingress
  - Egress
```

3. **Use Workload Identity Federation** instead of SA keys

4. **Enable Binary Authorization** to only run signed images

5. **Add WAF** (Cloud Armor) in front of ingress

## Incident Response

If security incident:

1. **Isolate** - Scale down affected pods
2. **Investigate** - Check logs, audit trails
3. **Remediate** - Apply fixes, rotate credentials
4. **Document** - Write postmortem
5. **Improve** - Update security controls

## Contacts

- Security team: security@example.com
- On-call: oncall@example.com

