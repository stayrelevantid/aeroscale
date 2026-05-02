resource "google_compute_network" "aeroscale_vpc" {
  name                    = "aeroscale-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "aeroscale_subnet" {
  name                     = "aeroscale-subnet"
  ip_cidr_range            = "10.0.0.0/20"
  region                   = var.region
  network                  = google_compute_network.aeroscale_vpc.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "aeroscale-pods"
    ip_cidr_range = "10.4.0.0/14"
  }

  secondary_ip_range {
    range_name    = "aeroscale-services"
    ip_cidr_range = "10.8.0.0/20"
  }
}

resource "google_compute_firewall" "allow_internal" {
  name    = "aeroscale-allow-internal"
  network = google_compute_network.aeroscale_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  source_ranges = ["10.0.0.0/20", "10.4.0.0/14", "10.8.0.0/20"]
}

resource "google_compute_router" "aeroscale_router" {
  name    = "aeroscale-router"
  region  = var.region
  network = google_compute_network.aeroscale_vpc.id
}

resource "google_compute_router_nat" "aeroscale_nat" {
  name                               = "aeroscale-nat"
  router                             = google_compute_router.aeroscale_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  min_ports_per_vm = 64
}

