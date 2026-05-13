output "cluster_name" {
  description = "Kind cluster name"
  value       = kind_cluster.crewmeister.name
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file for the cluster"
  value       = kind_cluster.crewmeister.kubeconfig_path
}

output "app_url" {
  description = "URL to access the application"
  value       = "http://localhost:30080"
}

output "health_check_url" {
  description = "Actuator health endpoint"
  value       = "http://localhost:30080/actuator/health"
}
