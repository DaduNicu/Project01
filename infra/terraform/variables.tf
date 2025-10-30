variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone_a" {
  description = "First availability zone"
  type        = string
  default     = "us-central1-a"
}

variable "zone_b" {
  description = "Second availability zone"
  type        = string
  default     = "us-central1-b"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "gcp-devops-challenge"
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
  default     = "dev"
}

variable "network_name" {
  description = "VPC network name"
  type        = string
  default     = "gke-network"
}

variable "subnet_cidr" {
  description = "CIDR range for the subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "pods_cidr" {
  description = "CIDR range for pods"
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_cidr" {
  description = "CIDR range for services"
  type        = string
  default     = "10.2.0.0/16"
}

variable "artifact_registry_name" {
  description = "Artifact Registry repository name"
  type        = string
  default     = "gcp-devops-challenge"
}

variable "enable_autopilot" {
  description = "Enable GKE Autopilot mode for cost savings"
  type        = bool
  default     = true
}

variable "node_machine_type" {
  description = "Machine type for GKE nodes (used if autopilot is disabled)"
  type        = string
  default     = "e2-medium"
}

variable "node_count" {
  description = "Number of nodes per zone (used if autopilot is disabled)"
  type        = number
  default     = 1
}

variable "preemptible_nodes" {
  description = "Use preemptible nodes for cost savings (used if autopilot is disabled)"
  type        = bool
  default     = true
}

