# GCP DevOps Challenge

This project demonstrates a complete end-to-end CI/CD pipeline that deploys a Python Flask application to Google Kubernetes Engine (GKE). We're using industry-standard tools like Terraform for infrastructure, Helm for deployment management, and GitHub Actions for automation.

## Architecture Overview

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│   GitHub    │─────▶│ CI/CD Runner │─────▶│  GKE Cluster│
│  Repository │      │   (Actions)  │      │             │
└─────────────┘      └──────────────┘      └─────────────┘
                            │                      │
                            ▼                      ▼
                     ┌──────────────┐      ┌─────────────┐
                     │  Artifact    │      │   Vault +   │
                     │   Registry   │      │  Secrets    │
                     └──────────────┘      └─────────────┘
```

## Getting Started

### What You'll Need

Before diving in, make sure you have:
- A GCP project with billing enabled (free tier works great!)
- The `gcloud` CLI installed and authenticated
- Local installations of `terraform`, `kubectl`, and `helm`
- A GitHub repository for your code

### Step 1: Build Your Infrastructure

First, let's get your GKE cluster up and running:

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# Open terraform.tfvars and add your GCP project ID

terraform init
terraform apply
```

This will create your VPC, GKE Autopilot cluster, Artifact Registry, and all the necessary IAM roles. It takes about 10 minutes.

### Step 2: Connect to Your Cluster

Once Terraform finishes, connect kubectl to your new cluster:

```bash
gcloud container clusters get-credentials gcp-devops-challenge \
  --region us-central1 --project YOUR_PROJECT_ID
```

### Step 3: Configure GitHub Secrets

For the CI/CD pipeline to work, we need to give GitHub access to your GCP project:

```bash
# Create a service account key
gcloud iam service-accounts keys create cicd-key.json \
  --iam-account=gcp-devops-challenge-cicd-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Encode it for GitHub
cat cicd-key.json | base64
```

Head over to your GitHub repo → Settings → Secrets and add:
- `GCP_SA_KEY` (paste the base64 output)
- `GCP_PROJECT_ID` (your project ID)
- `GCP_REGION` (us-central1)

### Step 4: Try a Manual Deployment (Optional)

Want to see everything work before setting up automation? Here's how to deploy manually:

```bash
# Build the Docker image for linux/amd64 (important for GKE)
cd app
docker build --platform linux/amd64 \
  -t us-central1-docker.pkg.dev/YOUR_PROJECT_ID/gcp-devops-challenge/app:v1 .
docker push us-central1-docker.pkg.dev/YOUR_PROJECT_ID/gcp-devops-challenge/app:v1

# Deploy to dev environment using Helm
cd ../charts
helm install app app -n dev --create-namespace \
  --set image.repository=us-central1-docker.pkg.dev/YOUR_PROJECT_ID/gcp-devops-challenge/app \
  --set image.tag=v1
```

Wait a minute or two for the pods to come up, then test it:

```bash
kubectl port-forward -n dev svc/app 8080:80
curl http://localhost:8080/healthz
# Should return: {"service":"gcp-devops-challenge","status":"healthy","sys_env":"helloworld"}
```

## How the CI/CD Pipeline Works

Once you push code to GitHub, the automation kicks in:

**On Pull Requests:**
- Lints and tests your Python code
- Builds the Docker image and scans it with Trivy for vulnerabilities
- Validates your Terraform code and runs a plan
- Lints your Helm charts
- Scans infrastructure code with Checkov for security issues

If anything fails, the PR can't be merged. This catches problems early!

**When You Merge to Main:**
- Builds and pushes your Docker image (tagged with git SHA and `:main`)
- Generates an SBOM (Software Bill of Materials) for security tracking
- Applies any Terraform changes to keep infrastructure in sync
- Deploys the new version to the dev environment
- Runs smoke tests against the `/healthz` endpoint

**Deploying to Production:**
- Requires manual approval (set this up in GitHub Environments)
- Uses the prod Helm values with higher resource limits and replicas
- Implements rolling updates with zero downtime
- Automatically rolls back if health checks fail

## Project Structure

```
├── app/                    # Flask application
│   ├── src/
│   ├── tests/
│   └── Dockerfile
├── charts/app/            # Helm chart
│   ├── templates/
│   ├── values.yaml
│   ├── values.dev.yaml
│   └── values.prod.yaml
├── infra/
│   ├── terraform/         # GKE cluster & infra
│   ├── ansible/           # CI runner setup
│   ├── vault/             # Vault deployment
│   └── k8s/               # K8s manifests
└── .github/workflows/     # CI/CD pipelines
```

## Observability & Monitoring

We've included Prometheus and Grafana for monitoring your application:

```bash
# Install the monitoring stack
cd infra/k8s/monitoring
./install-prometheus.sh

# Access Grafana dashboard
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Open http://localhost:3000 in your browser
# Username: admin, Password: prom-operator
```

The Flask app exposes Prometheus metrics at `/metrics`, so you can track request rates, latency, and custom application metrics. Logs are automatically sent to Google Cloud Logging.

## Cleaning Up

When you're done experimenting, tear everything down to avoid charges:

```bash
cd infra/terraform
terraform destroy
```

**Note:** If terraform destroy hangs, delete any LoadBalancer services first:
```bash
kubectl delete svc --all -n dev
kubectl delete svc --all -n prod
```

## Documentation

- **[OPERATIONS.md](OPERATIONS.md)** - Day-to-day operations: deploying, rolling back, troubleshooting
- **[SECURITY.md](SECURITY.md)** - Security design, IAM, secrets management, and supply chain controls
- **[Tutorial.md](Tutorial.md)** - Step-by-step tutorial for deploying to GKE

## What's the Cost?

Running this setup on GCP free tier or with minimal usage:

- **GKE Autopilot**: ~$70-100/month (scales based on actual pod usage)
- **Artifact Registry**: ~$0.10/GB storage
- **Networking & Load Balancers**: ~$10-20/month

**Total**: Expect around $80-120/month for both dev and prod environments running 24/7. You can significantly reduce costs by stopping the cluster when not in use.

## Why GKE Autopilot?

We chose GKE Autopilot over standard GKE because:
- **Lower cost**: You only pay for pods, not nodes
- **Less management**: Google handles node provisioning, scaling, and security
- **Built-in best practices**: Security policies and resource limits enforced automatically

Perfect for this use case where we want to focus on the application, not cluster administration.

