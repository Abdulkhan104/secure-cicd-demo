output "workload_identity_provider" {
  description = "Workload Identity Provider ID for GitHub Actions"
  value       = "projects/${var.project_id}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github.workload_identity_pool_provider_id}"
}

output "github_service_account_email" {
  description = "Service account email for GitHub Actions"
  value       = google_service_account.github_actions.email
}

output "gke_cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.private_cluster.name
}

output "artifact_registry_repo" {
  description = "Artifact Registry repository ID"
  value       = google_artifact_registry_repository.app.id
}

output "gke_workload_identity_pool" {
  description = "Workload Identity pool for GKE"
  value       = "${var.project_id}.svc.id.goog"
}

output "app_service_account_email" {
  description = "App service account for Workload Identity binding"
  value       = google_service_account.app.email
}
