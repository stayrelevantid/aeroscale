output "project_id" {
  value       = var.project_id
  description = "GCP Project ID"
}

output "region" {
  value       = var.region
  description = "GCP Region"
}

output "zone" {
  value       = var.zone
  description = "GCP Zone"
}

output "gke_cluster_name" {
  value       = google_container_cluster.aeroscale_gke.name
  description = "GKE Cluster Name"
}

output "gke_cluster_endpoint" {
  value       = google_container_cluster.aeroscale_gke.endpoint
  description = "GKE Cluster Endpoint"
}

output "pubsub_topic_name" {
  value       = google_pubsub_topic.aeroscale_topic.name
  description = "Pub/Sub Topic Name"
}

output "pubsub_subscription_name" {
  value       = google_pubsub_subscription.aeroscale_subscription.name
  description = "Pub/Sub Subscription Name"
}

output "worker_service_account_email" {
  value       = google_service_account.aeroscale_worker.email
  description = "Worker GSA Email"
}

output "ksa_namespace" {
  value       = "aeroscale"
  description = "Kubernetes Service Account Namespace"
}

output "ksa_name" {
  value       = "aeroscale-worker-sa"
  description = "Kubernetes Service Account Name"
}

output "artifact_registry_repo" {
  value       = google_artifact_registry_repository.aeroscale_docker.name
  description = "Artifact Registry Repository Name"
}

output "artifact_registry_url" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/aeroscale-docker"
  description = "Artifact Registry Docker Repository URL"
}