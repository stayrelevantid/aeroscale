resource "google_service_account" "aeroscale_worker" {
  account_id   = "aeroscale-worker"
  display_name = "AeroScale Worker Service Account"
}

resource "google_project_iam_member" "pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.aeroscale_worker.email}"
}

resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = google_service_account.aeroscale_worker.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[aeroscale/aeroscale-worker-sa]",
  ]
}