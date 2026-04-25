terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}



# Vpc N/w - all Neteorking 
resource "google_compute_network" "main" {
  name                    = "secure-cicd-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  name          = "secure-cicd-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.main.id
}

# IP range for Cloud Build private pool 
resource "google_compute_global_address" "cloudbuild_range" {
  name          = "cloudbuild-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = google_compute_network.main.id
}

# Connect Cloud Build to your VPC
resource "google_service_networking_connection" "cloudbuild_peering" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.cloudbuild_range.name]
}

#  PRIVATE CLOUD BUILD POOL
resource "google_cloudbuild_worker_pool" "private_pool" {
  name     = "secure-pool"
  location = var.region

  worker_config {
    disk_size_gb   = 100
    machine_type   = "e2-standard-2"
    no_external_ip = true  # NO internet access!
  }

  network_config {
    peered_network = google_compute_network.main.id
  }

  depends_on = [google_service_networking_connection.cloudbuild_peering]
}

# ARTIFACT REGISTRY ->AR
resource "google_artifact_registry_repository" "app" {
  location      = var.region
  repository_id = "my-app-repo"
  format        = "DOCKER"
}

# PRIVATE GKE CLUSTER {Google Cloud Cluster}
resource "google_container_cluster" "private_cluster" {
  name     = "secure-cluster"
  location = var.region

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false  # Keep API accessible for now
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  network    = google_compute_network.main.id
  subnetwork = google_compute_subnetwork.main.id

  # Enable Workload Identity for apps
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Remove default node pool (we'll create our own)
  remove_default_node_pool = true
  initial_node_count       = 1
}

# Node pool for the cluster
resource "google_container_node_pool" "secure_nodes" {
  name     = "secure-node-pool"
  location = var.region
  cluster  = google_container_cluster.private_cluster.name

  node_config {
    machine_type = "e2-standard-2"

    metadata = {
      "google-compute-enable-workload-identity" = "true"
    }

    service_account = google_service_account.gke_node.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  node_count = 1
}

# Service account for GKE nodes -> Its an Limmeted acces throughot the user 
resource "google_service_account" "gke_node" {
  account_id = "gke-node-sa"
}

# WORKLOAD IDENTITY FEDERATION
# Service account that GitHub will use
resource "google_service_account" "github_actions" {
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions Service Account"
}

# Create Workload Identity Pool
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
}

# Configure GitHub as an identity provider
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  # SECURITY: Only allow YOUR repository
  attribute_condition = "assertion.repository == '${var.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Allow GitHub to use the service account
resource "google_service_account_iam_member" "github_auth" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

# IAM permission
# Cloud Build permission
resource "google_project_iam_member" "cloudbuild_permissions" {
  for_each = toset([
    "roles/cloudbuild.builds.builder",
    "roles/cloudbuild.workerPoolOwner",
    "roles/artifactregistry.writer",
    "roles/container.developer",
    "roles/secretmanager.secretAccessor"
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

#  SM secret manager
resource "google_secret_manager_secret" "api_key" {
  secret_id = "api-key"
  replication {
    # automatic = true
  }
}

# Add a test secret value in this
resource "google_secret_manager_secret_version" "api_key_v1" {
  secret      = google_secret_manager_secret.api_key.id
  secret_data = "test-api-key-12345"
}

# svc account for the deployed app
resource "google_service_account" "app" {
  account_id = "app-sa"
}

# allow applic to read secrets
resource "google_secret_manager_secret_iam_member" "app_secret_access" {
  secret_id = google_secret_manager_secret.api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app.email}"
}

