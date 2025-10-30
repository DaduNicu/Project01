# Tutorial: Automating Deployment and Integration of a Web Service in GKE

This tutorial walks through setting up a complete CI/CD pipeline for deploying a containerized web service to Google Kubernetes Engine (GKE) using Terraform, Helm, and GitHub Actions.

## What You'll Build

By the end of this tutorial, you'll have:
- GKE cluster provisioned with Terraform
- Dockerized Flask application
- Automated CI/CD pipeline with GitHub Actions
- Helm-based deployments to dev and prod environments
- Monitoring with Prometheus
- Secure secrets management

## Prerequisites

- GCP account with billing enabled
- GitHub repository
- Local tools: `gcloud`, `terraform`, `kubectl`, `helm`, `docker`

## Part 1: Setup GCP Project

### 1.1 Create GCP Project

```bash
export PROJECT_ID="your-unique-project-id"
gcloud projects create $PROJECT_ID
gcloud config set project $PROJECT_ID

# Enable billing (must be done via console)
```

### 1.2 Enable Required APIs

```bash
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com
```

This takes 1-2 minutes.

## Part 2: Infrastructure with Terraform

### 2.1 Configure Terraform

Navigate to terraform directory:

```bash
cd infra/terraform
```

Create `terraform.tfvars`:

```hcl
project_id = "your-project-id"
region     = "us-central1"
```

### 2.2 Initialize and Apply

```bash
terraform init
terraform plan
terraform apply
```

Type `yes` when prompted. This creates:
- VPC network with 2 subnets
- GKE Autopilot cluster
- Artifact Registry repository
- Service accounts with IAM roles

Takes ~10-15 minutes for GKE cluster.

### 2.3 Configure kubectl

```bash
gcloud container clusters get-credentials gcp-devops-challenge \
  --region us-central1 \
  --project $PROJECT_ID

kubectl get nodes
```

You should see GKE nodes listed.

## Part 3: Build and Push Docker Image

### 3.1 Authenticate Docker

```bash
gcloud auth configure-docker us-central1-docker.pkg.dev
```

### 3.2 Build Image

```bash
cd ../../app
docker build -t us-central1-docker.pkg.dev/$PROJECT_ID/gcp-devops-challenge/app:v1 .
```

### 3.3 Test Locally

```bash
docker run -p 8080:8080 us-central1-docker.pkg.dev/$PROJECT_ID/gcp-devops-challenge/app:v1
```

In another terminal:
```bash
curl http://localhost:8080/healthz
```

Should return: `{"status":"healthy","sys_env":"helloworld",...}`

### 3.4 Push to Registry

```bash
docker push us-central1-docker.pkg.dev/$PROJECT_ID/gcp-devops-challenge/app:v1
```

## Part 4: Deploy with Helm

### 4.1 Update Helm Values

Edit `charts/app/values.yaml`, replace `PROJECT_ID`:

```yaml
image:
  repository: us-central1-docker.pkg.dev/YOUR_PROJECT_ID/gcp-devops-challenge/app
  tag: "v1"
```

### 4.2 Install to Dev

```bash
cd ../charts
helm install app app \
  -f app/values.dev.yaml \
  --namespace dev --create-namespace
```

### 4.3 Verify Deployment

```bash
kubectl get pods -n dev
kubectl get svc -n dev
```

Wait for pods to be `Running`:

```bash
kubectl wait --for=condition=ready pod -l app=app -n dev --timeout=120s
```

### 4.4 Test the Service

```bash
kubectl port-forward -n dev svc/app 8080:80
```

Visit http://localhost:8080/healthz

## Part 5: Setup CI/CD with GitHub Actions

### 5.1 Create Service Account Key

```bash
gcloud iam service-accounts keys create cicd-key.json \
  --iam-account=gcp-devops-challenge-cicd-sa@$PROJECT_ID.iam.gserviceaccount.com
```

### 5.2 Add GitHub Secrets

Go to your GitHub repo → Settings → Secrets and variables → Actions

Add secrets:
- `GCP_SA_KEY`: Content of `cicd-key.json` (base64 encoded)
- `GCP_PROJECT_ID`: Your project ID

```bash
cat cicd-key.json | base64
```

### 5.3 Push Code to GitHub

```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/your-username/your-repo.git
git push -u origin main
```

### 5.4 Test CI/CD

Create a new branch and PR:

```bash
git checkout -b test-ci
echo "# Test" >> README.md
git add README.md
git commit -m "Test CI"
git push origin test-ci
```

Open PR on GitHub. You should see PR checks running:
- Lint and tests
- Docker build and scan
- Terraform validate
- Helm lint

Once checks pass, merge PR. This triggers deployment to dev.

## Part 6: Secrets Management

### 6.1 Install External Secrets Operator

```bash
cd ../../infra/k8s/external-secrets
./install.sh
```

### 6.2 Create Secrets in GCP

```bash
echo -n "helloworld" | gcloud secrets create sys-env \
  --data-file=- \
  --replication-policy=automatic
```

### 6.3 Grant Access

```bash
gcloud secrets add-iam-policy-binding sys-env \
  --member="serviceAccount:gcp-devops-challenge-cicd-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### 6.4 Apply SecretStore

Update `secret-store.yaml` with your project ID, then:

```bash
kubectl apply -f secret-store.yaml
```

### 6.5 Update Helm Chart

Uncomment External Secret in `charts/app/templates/externalsecret.yaml` and redeploy:

```bash
helm upgrade app ../charts/app -f ../charts/app/values.dev.yaml -n dev
```

## Part 7: Monitoring

### 7.1 Install Prometheus

```bash
cd ../monitoring
./install-prometheus.sh
```

Takes 2-3 minutes.

### 7.2 Access Grafana

```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

Open http://localhost:3000
- Username: `admin`
- Password: `prom-operator`

### 7.3 View Metrics

Go to Explore → Select Prometheus → Query:

```promql
rate(flask_http_request_total[5m])
```

You'll see request rates for your app.

### 7.4 Apply ServiceMonitor

```bash
kubectl apply -f servicemonitor.yaml
```

This configures Prometheus to scrape app metrics.

## Part 8: Deploy to Production

### 8.1 Manual Approval

Production deployments require manual approval via GitHub Environments.

Go to repo Settings → Environments → Create "prod" environment → Add protection rules:
- Required reviewers: Add yourself

### 8.2 Trigger Production Deploy

Go to Actions → Deploy workflow → Run workflow → Select "prod"

Approve the deployment when prompted.

### 8.3 Verify Production

```bash
kubectl get pods -n prod
kubectl port-forward -n prod svc/app 8080:80
curl http://localhost:8080/healthz
```

## Part 9: Test Rollback

### 9.1 Simulate Bad Deployment

Edit `app/src/main.py` to break healthcheck:

```python
@app.route('/healthz', methods=['GET'])
def healthz():
    return jsonify({'status': 'unhealthy'}), 500  # broken!
```

Commit and push. Deployment will fail health checks.

### 9.2 Manual Rollback

```bash
helm history app -n prod
helm rollback app -n prod
```

The app rolls back to previous version.

### 9.3 Verify

```bash
kubectl get pods -n prod
curl http://localhost:8080/healthz  # should be healthy again
```

## Part 10: Testing HPA

### 10.1 Check HPA Status

```bash
kubectl get hpa -n dev
```

Should show current CPU usage and replica count.

### 10.2 Generate Load

```bash
kubectl run load-generator --rm -i --tty --image=busybox -- /bin/sh

# Inside the pod:
while true; do wget -q -O- http://app.dev/healthz; done
```

### 10.3 Watch Scaling

In another terminal:

```bash
kubectl get hpa -n dev -w
```

You'll see replicas increase as CPU rises above 70%.

## Troubleshooting

### Pods Not Starting

```bash
kubectl describe pod <pod-name> -n dev
kubectl logs <pod-name> -n dev
```

Common issues:
- Image pull errors: Check Artifact Registry permissions
- CrashLoopBackOff: Check app logs
- Pending: Check resource requests

### Terraform Errors

```bash
# Refresh state
terraform refresh

# Detailed logging
export TF_LOG=DEBUG
terraform apply
```

### GitHub Actions Failing

Check:
- Secrets are set correctly
- Service account has required permissions
- GKE cluster is running

## Cleanup

### Delete Applications

```bash
helm uninstall app -n dev
helm uninstall app -n prod
```

### Destroy Infrastructure

```bash
cd infra/terraform
terraform destroy
```

**Important**: Delete any LoadBalancer services first, or `terraform destroy` may hang.

## Next Steps

- Add custom domain and SSL certificate
- Implement canary deployments with Argo Rollouts
- Add more comprehensive monitoring dashboards
- Set up alerting rules
- Implement log aggregation with Loki
- Add API gateway (Kong, Istio)

## Common Issues

**Q: Terraform times out creating GKE cluster**
A: Autopilot takes 10-15 min. Be patient or check GCP Console for errors.

**Q: Can't push to Artifact Registry**
A: Run `gcloud auth configure-docker us-central1-docker.pkg.dev`

**Q: HPA not scaling**
A: Ensure metrics-server is running. GKE Autopilot has it by default.

**Q: External Secrets not syncing**
A: Check ServiceAccount annotations and IAM bindings.

## Conclusion

You now have a production-ready CI/CD pipeline for Kubernetes deployments on GCP. The setup includes:

✅ Infrastructure as Code with Terraform  
✅ Containerized application with best practices  
✅ Automated testing and security scanning  
✅ Multi-environment deployments with Helm  
✅ Secrets management with External Secrets  
✅ Monitoring with Prometheus and Grafana  
✅ Automated rollbacks on failure  

For questions or issues, refer to OPERATIONS.md and SECURITY.md.

