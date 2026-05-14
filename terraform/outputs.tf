output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.crewmeister.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.crewmeister.endpoint
  sensitive   = true
}

output "cloud_sql_ip" {
  description = "Cloud SQL public IP"
  value       = google_sql_database_instance.crewmeister.public_ip_address
}

output "artifact_registry_url" {
  description = "Artifact Registry URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/crewmeister"
}

output "app_url" {
  description = "Run this to get the app's public IP after deployment"
  value       = "kubectl get svc -n ${var.namespace} crewmeister-crewmeister -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
}
