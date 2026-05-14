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
  source     = "./modules/vpc"
  project_id = var.project_id
  region     = var.region
  depends_on = [google_project_service.apis]
}

module "gke" {
  source       = "./modules/gke"
  project_id   = var.project_id
  region       = var.region
  zone         = var.zone
  cluster_name = var.cluster_name
  machine_type = var.machine_type
  node_count   = var.node_count
  network      = module.vpc.network_name
  subnetwork   = module.vpc.private_subnet_name
  depends_on   = [module.vpc]
}

module "cloudsql" {
  source      = "./modules/cloudsql"
  project_id  = var.project_id
  region      = var.region
  db_password = var.db_password
  depends_on  = [google_project_service.apis]
}

module "artifact_registry" {
  source     = "./modules/artifact-registry"
  project_id = var.project_id
  region     = var.region
  depends_on = [google_project_service.apis]
}