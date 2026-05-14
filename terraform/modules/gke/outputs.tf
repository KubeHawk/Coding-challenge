output "cluster_name" {
  value = google_container_cluster.crewmeister.name
}

output "cluster_zone" {
  value = google_container_cluster.crewmeister.location
}