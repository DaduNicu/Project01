# GKE Infrastructure with Terraform

This directory contains the Terraform configuration for provisioning a GKE Autopilot cluster and all necessary supporting infrastructure on Google Cloud Platform.

## Getting Started

### 1. Enable Required APIs

First, make sure the required Google Cloud APIs are enabled:

```bash
gcloud services enable compute.googleapis.com \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  cloudresourcemanager.googleapis.com
```

### 2. Set Up Remote State Storage

Create a GCS bucket for Terraform state (enables CI/CD and team collaboration):

```bash
gsutil mb -p <your-project-id> -l us-central1 gs://gcp-devops-challenge-terraform-state
```

The backend is already configured in `main.tf` to use this bucket.

### 3. Configure Your Project

```bash
cp terraform.tfvars.example terraform.tfvars
# Open terraform.tfvars and set your GCP project ID
```

### 4. Deploy Infrastructure

```bash
terraform init    # Initialize Terraform and connect to GCS backend
terraform plan    # Review what will be created
terraform apply   # Build the infrastructure (takes ~10 minutes)
```

### 5. Grant CI/CD Permissions (for GitHub Actions)

After infrastructure is created, grant the CI/CD service account necessary permissions:

```bash
gcloud projects add-iam-policy-binding <your-project-id> \
  --member="serviceAccount:gcp-devops-challenge-cicd-sa@<your-project-id>.iam.gserviceaccount.com" \
  --role="roles/editor"
```

Once Terraform finishes, connect kubectl to your new cluster:

```bash
gcloud container clusters get-credentials gcp-devops-challenge \
  --region us-central1 \
  --project <your-project-id>
```

## What Gets Created

This Terraform configuration sets up:

- **VPC Network**: Custom network spanning multiple zones (us-central1-a, us-central1-b)
- **GKE Autopilot Cluster**: Fully managed Kubernetes cluster with automatic scaling
- **Artifact Registry**: Private Docker registry for storing container images
- **Service Accounts**: 
  - One for GKE nodes (with logging and monitoring permissions)
  - One for CI/CD (with permissions to push images and deploy)
- **IAM Bindings**: Least-privilege roles for all service accounts

## Remote State Backend

This configuration uses **Google Cloud Storage (GCS)** as the backend for Terraform state. This enables:
- **Collaboration**: Multiple team members can work on the same infrastructure
- **CI/CD Integration**: GitHub Actions can read/write state during deployments
- **State Locking**: Prevents concurrent modifications
- **Versioning**: GCS keeps historical versions of your state file

The backend is configured in `main.tf`:
```hcl
terraform {
  backend "gcs" {
    bucket = "gcp-devops-challenge-terraform-state"
    prefix = "terraform/state"
  }
}
```

## Architecture Decisions

**Why Autopilot?** We chose GKE Autopilot over Standard GKE because it reduces operational overhead and costs. Google manages node provisioning, scaling, and security patches automatically. You only pay for the pods you run, not the underlying nodes.

**Cost Controls**: The configuration uses minimal resources and Autopilot's pay-per-pod model. See the main README for cost estimates.

## Outputs

After applying, Terraform provides these outputs:

- `cluster_name` - Name of your GKE cluster
- `region` - The GCP region
- `artifact_registry_url` - Where to push your Docker images
- `kubeconfig_command` - Command to configure kubectl

## Cleanup

When you're done, tear down everything:

```bash
terraform destroy
```

**Important**: If destroy hangs, it's usually because of LoadBalancer services. Delete them first:

```bash
kubectl delete svc --all --all-namespaces
terraform destroy
```

