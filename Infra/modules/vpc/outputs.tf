output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.vpc.name
}

output "network_self_link" {
  description = "VPC network self link"
  value       = google_compute_network.vpc.self_link
}

output "subnet_name" {
  description = "Private subnet name"
  value       = google_compute_subnetwork.private.name
}

output "subnet_cidr" {
  description = "Private subnet CIDR"
  value       = google_compute_subnetwork.private.ip_cidr_range
}

output "pods_range_name" {
  description = "Pods secondary range name"
  value       = var.pods_range_name
}

output "services_range_name" {
  description = "Services secondary range name"
  value       = var.services_range_name
}