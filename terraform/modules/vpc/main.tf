resource "google_compute_network" "vpc" {
  name                    = "crewmeister-vpc"
  routing_mode            = "REGIONAL"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "private" {
  name                     = "crewmeister-private"
  ip_cidr_range            = "10.0.32.0/19"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "k8s-pods"
    ip_cidr_range = "172.16.0.0/14"
  }

  secondary_ip_range {
    range_name    = "k8s-services"
    ip_cidr_range = "172.20.0.0/18"
  }
}

resource "google_compute_router" "router" {
  name    = "crewmeister-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_address" "nat" {
  name         = "crewmeister-nat-ip"
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
  region       = var.region
}

resource "google_compute_router_nat" "nat" {
  name   = "crewmeister-nat"
  region = var.region
  router = google_compute_router.router.name

  nat_ip_allocate_option             = "MANUAL_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  nat_ips                            = [google_compute_address.nat.self_link]

  subnetwork {
    name                    = google_compute_subnetwork.private.self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}