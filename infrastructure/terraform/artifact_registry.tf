resource "google_artifact_registry_repository" "aeroscale_docker" {
  location      = var.region
  repository_id = "aeroscale-docker"
  format        = "DOCKER"
  description   = "AeroScale Worker Docker images"
}