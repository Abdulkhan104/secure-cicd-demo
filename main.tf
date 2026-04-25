terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# VPC NETWORK WITH GKE SECONDARY RANGES
resource "google_compute_network" "main" {
  name                    = "secure-cicd-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  name          = "secure-cicd-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.main.id

  # Secondary ranges required for GKE
  secondary_ip_range {
    range_name    = "pods-range"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "10.2.0.0/20"
  }
}

# IP range for Cloud Build private pool peering
resource "google_compute_global_address" "cloudbuild_range" {
  name          = "cloudbuild-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = google_compute_network.main.id
}

# VPC Peering connection for Cloud Build
resource "google_service_networking_connection" "cloudbuild_peering" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.cloudbuild_range.name]
}

# PRIVATE CLOUD BUILD POOL (NO INTERNET)
resource "google_cloudbuild_worker_pool" "private_pool" {
  name     = "secure-pool"
  location = var.region

  worker_config {
    machine_type   = "e2-standard-2"
    disk_size_gb   = 100
    no_external_ip = true # NO public internet access!
  }

  network_config {
    peered_network = google_compute_network.main.id
  }

  depends_on = [google_service_networking_connection.cloudbuild_peering]
}

# ARTIFACT REGISTRY (Private Docker Registry)
resource "google_artifact_registry_repository" "app" {
  location      = var.region
  repository_id = "my-app-repo"
  format        = "DOCKER"
}

# PRIVATE GKE CLUSTER
# resource "google_container_cluster" "private_cluster" {
#   name     = "secure-cluster"
#   location = var.region

#   deletion_protection = false
#   initial_node_count = 1
  
#   # CRITICAL: Force standard disk to avoid SSD quota
#   node_config {
#     machine_type = "e2-micro"
#     disk_type    = "pd-standard"
#     disk_size_gb = 12
#     image_type   = "COS_CONTAINERD"
#   }

# #   private_cluster_config {
# #     enable_private_nodes    = true
# #     enable_private_endpoint = false
# #     master_ipv4_cidr_block  = "172.16.0.0/28"
# #   }

#   ip_allocation_policy {
#     cluster_secondary_range_name  = "pods-range"
#     services_secondary_range_name = "services-range"
#   }

#   network    = google_compute_network.main.id
#   subnetwork = google_compute_subnetwork.main.id

#   workload_identity_config {
#     workload_pool = "${var.project_id}.svc.id.goog"
#   }

# #   remove_default_node_pool = true
# }  ---//remove wala

resource "google_container_cluster" "private_cluster" {
  name               = "secure-cluster"
  location           = var.region
  initial_node_count = 1
  
  node_config {
    machine_type = "e2-micro"
    disk_type    = "pd-standard"
    disk_size_gb = 12
    image_type   = "COS_CONTAINERD"
    
    # Add Workload Identity metadata
    metadata = {
      "google-compute-enable-workload-identity" = "true"
    }
    
    service_account = google_service_account.gke_node.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods-range"
    services_secondary_range_name = "services-range"
  }

  network    = google_compute_network.main.id
  subnetwork = google_compute_subnetwork.main.id

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  deletion_protection = false
}

# Node pool with Workload Identity support

# resource "google_container_node_pool" "secure_nodes" {
#   name     = "secure-node-pool"
#   location = var.region
#   cluster  = google_container_cluster.private_cluster.name

#   node_count = 1

#   node_config {
#     machine_type = "e2-micro"      # Smallest machine
#     disk_type    = "pd-standard"    # Standard disk (NOT SSD)
#     disk_size_gb = 12               # Smallest disk size

#     metadata = {
#       "google-compute-enable-workload-identity" = "true"
#     }

#     service_account = google_service_account.gke_node.email
#     oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
#   }

#   depends_on = [google_container_cluster.private_cluster]
# }

# SERVICE ACCOUNTS
# Service account for GKE nodes (minimal permissions)
resource "google_service_account" "gke_node" {
  account_id = "gke-node-sa"
}

# Service account for GitHub Actions CI/CD
resource "google_service_account" "github_actions" {
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions Service Account"
}

# Service account for deployed applications
resource "google_service_account" "app" {
  account_id = "app-sa"
}

# WORKLOAD IDENTITY FEDERATION (GitHub → GCP)
# Create Workload Identity Pool
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool-v2"
  display_name              = "GitHub Actions Pool"
  description               = "OIDC federation for GitHub Actions"
}

# Configure GitHub as OIDC provider
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.actor"      = "assertion.actor"
  }

  # SECURITY: Only allow your specific GitHub repository
  attribute_condition = "assertion.repository == '${var.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Allow GitHub to impersonate the CI/CD service account
resource "google_service_account_iam_member" "github_auth" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

# IAM PERMISSIONS (LEAST PRIVILEGE)
# Grant minimum required permissions to GitHub Actions SA
resource "google_project_iam_member" "cloudbuild_permissions" {
  for_each = toset([
    "roles/cloudbuild.builds.builder",   # Submit Cloud Build jobs
    "roles/cloudbuild.workerPoolOwner",  # Use private worker pool
    "roles/artifactregistry.writer",     # Push to Artifact Registry
    "roles/container.developer",         # Deploy to GKE
    "roles/secretmanager.secretAccessor" # Read secrets
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# SECRET MANAGER
# Create a secret for API keys
resource "google_secret_manager_secret" "api_key" {
  secret_id = "api-key"

  replication {
    auto {} # Automatically replicate across regions
  }
}

# Add a test secret value
resource "google_secret_manager_secret_version" "api_key_v1" {
  secret      = google_secret_manager_secret.api_key.id
  secret_data = "test-api-key-12345"
}

# Allow the application SA to read the secret
resource "google_secret_manager_secret_iam_member" "app_secret_access" {
  secret_id = google_secret_manager_secret.api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app.email}"
}
