# Operations Guide

## Deploy

### Dev Environment

```bash
helm upgrade --install app charts/app \
  -f charts/app/values.dev.yaml \
  --namespace dev --create-namespace \
  --wait
```

### Prod Environment

```bash
helm upgrade --install app charts/app \
  -f charts/app/values.prod.yaml \
  --namespace prod --create-namespace \
  --wait
```

## Rollback

### Check history

```bash
helm history app -n prod
```

### Rollback to previous version

```bash
helm rollback app -n prod
```

### Rollback to specific revision

```bash
helm rollback app 3 -n prod
```

## Troubleshooting

### Pod not starting

```bash
# Check pod status
kubectl get pods -n dev
kubectl describe pod <pod-name> -n dev

# Check logs
kubectl logs <pod-name> -n dev
kubectl logs <pod-name> -n dev --previous  # previous container
```

### Check deployment status

```bash
kubectl rollout status deployment/app -n dev
kubectl get events -n dev --sort-by='.lastTimestamp'
```

### Image pull errors

```bash
# Verify artifact registry permissions
gcloud artifacts repositories list

# Test docker auth
gcloud auth configure-docker us-central1-docker.pkg.dev
docker pull us-central1-docker.pkg.dev/PROJECT_ID/gcp-devops-challenge/app:main
```

### Service not accessible

```bash
# Check service
kubectl get svc -n dev
kubectl describe svc app -n dev

# Check endpoints
kubectl get endpoints app -n dev

# Port forward for testing
kubectl port-forward svc/app 8080:80 -n dev
curl http://localhost:8080/healthz
```

### HPA not scaling

```bash
# Check HPA status
kubectl get hpa -n dev
kubectl describe hpa app -n dev

# Check metrics server
kubectl top pods -n dev
kubectl top nodes

# Generate load (for testing)
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://app.dev/healthz; done"
```

### Ingress issues

```bash
# Check ingress
kubectl get ingress -n dev
kubectl describe ingress app -n dev

# Check GCE load balancer (GKE)
gcloud compute forwarding-rules list
gcloud compute backend-services list
```

## Monitoring

### Check Prometheus

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Visit http://localhost:9090

Useful queries:
- `rate(flask_http_request_total[5m])` - Request rate
- `flask_http_request_duration_seconds_bucket` - Latency
- `up{job="app-metrics"}` - App availability

### Check logs

```bash
# Stream logs
kubectl logs -f deployment/app -n dev

# Last 100 lines
kubectl logs deployment/app -n dev --tail=100

# All pods
kubectl logs -l app=app -n dev --all-containers
```

### GCP Cloud Logging

```bash
gcloud logging read "resource.type=k8s_container AND resource.labels.namespace_name=dev" --limit 50
```

## Secrets

### Update secrets in GCP Secret Manager

```bash
# Create/update secret
echo -n "new-value" | gcloud secrets create sys-env --data-file=- --replication-policy=automatic

# or update existing
echo -n "new-value" | gcloud secrets versions add sys-env --data-file=-
```

Pods will pick up new values within 1 hour (or restart them).

### Restart deployment to pick up secrets

```bash
kubectl rollout restart deployment/app -n dev
```

## Cleanup

### Delete application

```bash
helm uninstall app -n dev
helm uninstall app -n prod
```

### Delete infrastructure

```bash
cd infra/terraform
terraform destroy
```

If terraform destroy hangs on GKE cluster:
1. Delete all services with LoadBalancer type first
2. Delete all PVCs
3. Run terraform destroy again

```bash
kubectl delete svc --all -n dev
kubectl delete svc --all -n prod
kubectl delete pvc --all --all-namespaces
```

## Common kubectl Commands

```bash
# Get everything in namespace
kubectl get all -n dev

# Shell into pod
kubectl exec -it <pod-name> -n dev -- /bin/sh

# Copy files from pod
kubectl cp dev/<pod-name>:/path/to/file ./local-file

# Check resource usage
kubectl top pods -n dev
kubectl top nodes

# Describe node
kubectl describe node <node-name>

# Drain node (for maintenance)
kubectl drain <node-name> --ignore-daemonsets

# Cordon node (prevent new pods)
kubectl cordon <node-name>
```

## Emergency Procedures

### App down - quick restore

```bash
# Rollback to last known good version
helm rollback app -n prod

# Or scale down and up
kubectl scale deployment app --replicas=0 -n prod
kubectl scale deployment app --replicas=3 -n prod
```

### High CPU/Memory

```bash
# Scale up immediately
kubectl scale deployment app --replicas=10 -n prod

# Check HPA limits
kubectl edit hpa app -n prod
```

### Database connection issues

Check secrets are properly mounted:
```bash
kubectl exec -it <pod-name> -n prod -- env | grep SYS_ENV
```

