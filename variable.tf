# variables.tf
variable "project_id" {
  description = "Your GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "github_repository" {
  description = "Your GitHub repo (format: username/repo-name)"
  type        = string
}