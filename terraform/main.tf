terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }

  backend "gcs" {
    bucket = "crewmeister-terraform-state-496312"
    prefix = "terraform/state"
  }
}

# ─── GCP Provider ─────────────────────────────────────────────────────────────
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# ─── GKE Cluster ──────────────────────────────────────────────────────────────
resource "google_container_cluster" "crewmeister" {
  name     = var.cluster_name
  location = var.zone

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = "default"
  subnetwork = "default"

  deletion_protection = false
}

# ─── Node Pool ────────────────────────────────────────────────────────────────
resource "google_container_node_pool" "crewmeister_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.crewmeister.name
  node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    disk_size_gb = 20
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# ─── Artifact Registry ────────────────────────────────────────────────────────
resource "google_artifact_registry_repository" "crewmeister" {
  location      = var.region
  repository_id = "crewmeister"
  format        = "DOCKER"
  description   = "Crewmeister Docker images"
}

# ─── Cloud SQL (MySQL) ────────────────────────────────────────────────────────
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
        name  = "allow-all"
        value = "0.0.0.0/0"
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

# ─── Kubernetes & Helm Providers ──────────────────────────────────────────────
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.crewmeister.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.crewmeister.master_auth[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.crewmeister.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.crewmeister.master_auth[0].cluster_ca_certificate)
  }
}

# ─── Namespace ────────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "crewmeister" {
  depends_on = [google_container_node_pool.crewmeister_nodes]

  metadata {
    name = var.namespace
  }
}

# ─── Helm Release ─────────────────────────────────────────────────────────────
resource "helm_release" "crewmeister" {
  depends_on = [
    kubernetes_namespace.crewmeister,
    google_sql_database_instance.crewmeister,
  ]

  name      = "crewmeister"
  chart     = "${path.module}/../../helm/crewmeister"
  namespace = var.namespace
  timeout   = 300
  atomic    = true
  wait      = true

  set {
    name  = "image.repository"
    value = "${var.region}-docker.pkg.dev/${var.project_id}/crewmeister/crewmeister-app"
  }

  set {
    name  = "image.tag"
    value = var.app_image_tag
  }

  set {
    name  = "image.pullPolicy"
    value = "Always"
  }

  set {
    name  = "mysql.enabled"
    value = "false"
  }

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "env.SPRING_DATASOURCE_URL"
    value = "jdbc:mysql://${google_sql_database_instance.crewmeister.public_ip_address}:3306/challenge?createDatabaseIfNotExist=true"
  }

  set {
    name  = "env.SPRING_DATASOURCE_WRITER_URL"
    value = "jdbc:mysql://${google_sql_database_instance.crewmeister.public_ip_address}:3306/challenge?createDatabaseIfNotExist=true"
  }

  set {
    name  = "env.SPRING_DATASOURCE_USERNAME"
    value = "crewmeister"
  }

  set_sensitive {
    name  = "env.SPRING_DATASOURCE_PASSWORD"
    value = var.db_password
  }
}