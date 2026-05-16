resource "google_sql_database_instance" "main" {
  name             = var.instance_name
  database_version = var.database_version
  region           = var.region

  settings {
    tier              = var.tier
    availability_type = var.availability_type
    disk_size         = var.disk_size
    disk_type         = var.disk_type
    user_labels       = var.labels

    backup_configuration {
      enabled = var.backup_enabled
    }

    ip_configuration {
      authorized_networks {
        name  = var.authorized_network_name
        value = var.authorized_network
      }
    }
  }

  deletion_protection = var.deletion_protection
}

resource "google_sql_database" "main" {
  name     = var.db_name
  instance = google_sql_database_instance.main.name
}

resource "google_sql_user" "main" {
  name     = var.db_user
  instance = google_sql_database_instance.main.name
  password = var.db_password
}