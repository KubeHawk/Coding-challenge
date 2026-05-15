output "registry_url" {
  description = "Artifact Registry URL"
  value       = "${var.location}-docker.pkg.dev/${var.project}/${var.repository_id}"
}

output "repository_id" {
  description = "Repository ID"
  value       = google_artifact_registry_repository.main.repository_id
}