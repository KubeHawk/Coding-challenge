resource "google_artifact_registry_repository" "main" {
  location      = var.location
  repository_id = var.repository_id
  description   = var.description
  format        = var.format
  labels        = var.labels
  mode          = var.mode
  project       = var.project

  lifecycle {
    prevent_destroy = true
  }
}