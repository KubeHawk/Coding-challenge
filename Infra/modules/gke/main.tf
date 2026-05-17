# Google Container Cluster
resource "google_container_cluster" "main" {
  name       = var.cluster_name
  location   = var.zone
  project    = var.project_id
  network    = var.network
  subnetwork = var.subnetwork

  remove_default_node_pool = true
  initial_node_count       = 1
  networking_mode          = "VPC_NATIVE"

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_cidr
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  release_channel {
    channel = var.release_channel
  }

  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  deletion_protection = var.deletion_protection
  resource_labels     = var.labels
}

# Google Container Node Pool
resource "google_container_node_pool" "main" {
  name       = var.node_pool_name
  location   = var.zone
  cluster    = google_container_cluster.main.name
  project    = var.project_id
  node_count = var.node_count

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    labels       = var.labels
  }
}