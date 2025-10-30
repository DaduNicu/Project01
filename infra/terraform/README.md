# GKE Infrastructure with Terraform

This directory contains the Terraform configuration for provisioning a GKE Autopilot cluster and all necessary supporting infrastructure on Google Cloud Platform.

## Getting Started

First, make sure the required Google Cloud APIs are enabled:

```bash
gcloud services enable compute.googleapis.com \
  container.googleapis.com \
  artifactregistry.googleapis.com
```

Then configure your project:

```bash
cp terraform.tfvars.example terraform.tfvars
# Open terraform.tfvars and set your GCP project ID
```

Now you're ready to deploy:

```bash
terraform init
terraform plan    # Review what will be created
terraform apply   # Build the infrastructure (takes ~10 minutes)
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

