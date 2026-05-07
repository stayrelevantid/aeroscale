resource "google_container_cluster" "aeroscale_gke" {
  name     = "aeroscale-gke"
  location = var.region

  network    = google_compute_network.aeroscale_vpc.id
  subnetwork = google_compute_subnetwork.aeroscale_subnet.id

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "10.0.16.0/28"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.aeroscale_subnet.secondary_ip_range[0].range_name
    services_secondary_range_name = google_compute_subnetwork.aeroscale_subnet.secondary_ip_range[1].range_name
  }

  deletion_protection = false

  remove_default_node_pool = true
  initial_node_count       = 1

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    service_account = google_service_account.aeroscale_worker.email
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

resource "google_container_node_pool" "aeroscale_nodes" {
  name     = "aeroscale-node-pool"
  cluster  = google_container_cluster.aeroscale_gke.name
  location = var.region

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  node_count = 1

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    service_account = google_service_account.aeroscale_worker.email
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  management {
    auto_upgrade = true
    auto_repair  = true
  }
}