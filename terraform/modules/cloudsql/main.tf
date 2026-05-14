resource "google_sql_database_instance" "crewmeister" {
  name             = "crewmeister-mysql"
  database_version = "MYSQL_8_0"
  region           = var.region

  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    disk_size         = 10
    disk_type         = "PD_SSD"

    backup_configuration {
      enabled = false
    }

    ip_configuration {
      authorized_networks {
        name  = "allow-gke-private-subnet"
        value = "10.0.32.0/19"
      }
    }
  }

  deletion_protection = false
}

resource "google_sql_database" "crewmeister" {
  name     = "challenge"
  instance = google_sql_database_instance.crewmeister.name
}

resource "google_sql_user" "crewmeister" {
  name     = "crewmeister"
  instance = google_sql_database_instance.crewmeister.name
  password = var.db_password
}