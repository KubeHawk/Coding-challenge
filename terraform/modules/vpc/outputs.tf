output "network_name" {
  value = google_compute_network.vpc.name
}

output "private_subnet_name" {
  value = google_compute_subnetwork.private.name
}