output "cloud_sql_ip" {
  description = "Cloud SQL public IP"
  value       = google_sql_database_instance.crewmeister.public_ip_address
}

output "instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.crewmeister.name
}