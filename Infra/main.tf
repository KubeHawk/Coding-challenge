terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "crewmeister-terraform-state-496312"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

locals {
  labels = {
    project     = "crewmeister"
    environment = "production"
    managed_by  = "terraform"
  }
}

resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "sqladmin.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
  ])
  service            = each.key
  disable_on_destroy = false
}

module "vpc" {
  source = "./modules/vpc"

  network_name        = "${var.cluster_name}-vpc"
  routing_mode        = "REGIONAL"
  region              = var.region
  subnet_name         = "${var.cluster_name}-private"
  subnet_cidr         = "10.0.32.0/19"
  pods_range_name     = "k8s-pods"
  pods_cidr           = "172.16.0.0/14"
  services_range_name = "k8s-services"
  services_cidr       = "172.20.0.0/18"
  router_name         = "${var.cluster_name}-router"
  nat_name            = "${var.cluster_name}-nat"
  nat_ip_name         = "${var.cluster_name}-nat-ip"
  labels              = local.labels

  depends_on = [google_project_service.apis]
}

module "gke" {
  source = "./modules/gke"

  cluster_name            = var.cluster_name
  project_id              = var.project_id
  zone                    = var.zone
  network                 = module.vpc.network_name
  subnetwork              = module.vpc.subnet_name
  pods_range_name         = module.vpc.pods_range_name
  services_range_name     = module.vpc.services_range_name
  master_cidr             = "192.168.0.0/28"
  enable_private_endpoint = false
  release_channel         = "REGULAR"
  node_pool_name          = "${var.cluster_name}-node-pool"
  machine_type            = var.machine_type
  node_count              = var.node_count
  disk_size_gb            = 20
  disk_type               = "pd-standard"
  deletion_protection     = false
  labels                  = local.labels

  depends_on = [module.vpc]
}

module "cloudsql" {
  source = "./modules/cloudsql"

  instance_name           = "${var.cluster_name}-mysql"
  database_version        = "MYSQL_8_0"
  region                  = var.region
  tier                    = "db-f1-micro"
  availability_type       = "ZONAL"
  disk_size               = 10
  disk_type               = "PD_SSD"
  backup_enabled          = false
  authorized_network      = module.vpc.subnet_cidr
  authorized_network_name = "allow-gke-subnet"
  deletion_protection     = false
  db_name                 = "challenge"
  db_user                 = "crewmeister"
  db_password             = var.db_password
  labels                  = local.labels

  depends_on = [google_project_service.apis]
}

module "artifact_registry" {
  source = "./modules/artifact-registry"

  location      = var.region
  repository_id = var.cluster_name
  description   = "Docker images for ${var.cluster_name}"
  format        = "DOCKER"
  mode          = "STANDARD_REPOSITORY"
  project       = var.project_id
  labels        = local.labels

  depends_on = [google_project_service.apis]
}

module "monitoring" {
  source = "./modules/monitoring"

  namespace = "monitoring"

  # Chart versions
  prometheus_stack_version = "58.2.2"
  elasticsearch_version    = "8.5.1"
  kibana_version           = "8.5.1"
  logstash_version         = "8.5.1"

  # Grafana
  grafana_admin_password = var.grafana_admin_password

  # Values files
  prometheus_stack_values_file = "${path.module}/../helm/monitoring/kube-prometheus-stack-values.yaml"
  elasticsearch_values_file    = "${path.module}/../helm/monitoring/elasticsearch-values.yaml"
  kibana_values_file           = "${path.module}/../helm/monitoring/kibana-values.yaml"
  logstash_values_file         = "${path.module}/../helm/monitoring/logstash-values.yaml"

  # Kibana setup
  kibana_service_name         = "kibana-kibana"
  kibana_data_view_title      = "crewmeister-logs-*"
  kibana_data_view_time_field = "@timestamp"

  # Labels
  labels = local.labels

  depends_on = [module.gke]
}