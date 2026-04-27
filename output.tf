output "workload_identity_provider" {
  value = "projects/${var.project_id}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github.workload_identity_pool_provider_id}"
}

output "github_service_account_email" {
  value = google_service_account.github_actions.email
}

output "gke_cluster_name" {
  value = google_container_cluster.private_cluster.name
}
