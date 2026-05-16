output "cluster_name" {
  description = "GKE cluster name"
  value       = module.gke.cluster_name
}

output "cluster_zone" {
  description = "GKE cluster zone"
  value       = module.gke.cluster_zone
}

output "artifact_registry_url" {
  description = "Artifact Registry URL"
  value       = module.artifact_registry.registry_url
}

output "cloud_sql_ip" {
  description = "Cloud SQL public IP"
  value       = module.cloudsql.cloud_sql_ip
}