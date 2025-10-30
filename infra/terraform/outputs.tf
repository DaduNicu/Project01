# Outputs for GCP Infrastructure

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "cluster_name" {
  description = "GKE cluster name"
  value       = var.enable_autopilot ? google_container_cluster.primary[0].name : google_container_cluster.standard[0].name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = var.enable_autopilot ? google_container_cluster.primary[0].endpoint : google_container_cluster.standard[0].endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = var.enable_autopilot ? google_container_cluster.primary[0].master_auth[0].cluster_ca_certificate : google_container_cluster.standard[0].master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "artifact_registry_url" {
  description = "Artifact Registry repository URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
}

output "gke_node_service_account" {
  description = "GKE node service account email"
  value       = google_service_account.gke_node.email
}

output "cicd_service_account" {
  description = "CI/CD service account email"
  value       = google_service_account.cicd.email
}

output "vpc_network_name" {
  description = "VPC network name"
  value       = google_compute_network.vpc.name
}

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${var.cluster_name} --region ${var.region} --project ${var.project_id}"
}

