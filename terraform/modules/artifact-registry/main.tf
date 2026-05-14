resource "google_artifact_registry_repository" "crewmeister" {
  location      = var.region
  repository_id = "crewmeister"
  format        = "DOCKER"
  description   = "Crewmeister Docker images"
}