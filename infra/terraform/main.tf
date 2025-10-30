# GCP Provider Configuration
provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.network_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
  project       = var.project_id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

# Firewall rule for health checks
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${var.network_name}-allow-health-checks"
  network = google_compute_network.vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["gke-node"]
}

# Service Account for GKE nodes
resource "google_service_account" "gke_node" {
  account_id   = "${var.cluster_name}-node-sa"
  display_name = "GKE Node Service Account"
  project      = var.project_id
}

# IAM bindings for GKE node service account
resource "google_project_iam_member" "gke_node_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

resource "google_project_iam_member" "gke_node_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

resource "google_project_iam_member" "gke_node_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

# Service Account for CI/CD
resource "google_service_account" "cicd" {
  account_id   = "${var.cluster_name}-cicd-sa"
  display_name = "CI/CD Service Account"
  project      = var.project_id
}

# IAM bindings for CI/CD service account
resource "google_project_iam_member" "cicd_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_project_iam_member" "cicd_gke_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# Allow CI/CD SA to act as GKE node SA
resource "google_service_account_iam_member" "cicd_workload_identity" {
  service_account_id = google_service_account.gke_node.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${google_service_account.cicd.email}"
}

# Artifact Registry Repository
resource "google_artifact_registry_repository" "docker" {
  location      = var.region
  repository_id = var.artifact_registry_name
  description   = "Docker repository for GCP DevOps Challenge"
  format        = "DOCKER"
  project       = var.project_id
}

# Grant GKE node SA permission to read from Artifact Registry
resource "google_artifact_registry_repository_iam_member" "gke_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.docker.location
  repository = google_artifact_registry_repository.docker.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.gke_node.email}"
}

# GKE Cluster - Autopilot mode
resource "google_container_cluster" "primary" {
  count = var.enable_autopilot ? 1 : 0

  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # Autopilot mode
  enable_autopilot = true

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Release channel
  release_channel {
    channel = "REGULAR"
  }

  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  # Logging and monitoring
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }
}

# GKE Cluster - Standard mode (alternative to Autopilot)
resource "google_container_cluster" "standard" {
  count = var.enable_autopilot ? 0 : 1

  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # Remove default node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Release channel
  release_channel {
    channel = "REGULAR"
  }

  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }
}

# Node Pool for Standard mode
resource "google_container_node_pool" "primary_nodes" {
  count = var.enable_autopilot ? 0 : 1

  name       = "${var.cluster_name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.standard[0].name
  node_count = var.node_count
  project    = var.project_id

  node_config {
    preemptible  = var.preemptible_nodes
    machine_type = var.node_machine_type

    service_account = google_service_account.gke_node.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      environment = var.environment
    }

    tags = ["gke-node"]

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

