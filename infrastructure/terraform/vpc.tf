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

