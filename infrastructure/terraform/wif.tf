resource "google_iam_workload_identity_pool" "aeroscale_github" {
  workload_identity_pool_id = "aeroscale-github"
  display_name              = "AeroScale GitHub Actions Pool"
  description               = "Workload Identity Pool for GitHub Actions CI/CD"
}

resource "google_iam_workload_identity_pool_provider" "aeroscale_github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.aeroscale_github.workload_identity_pool_id
  workload_identity_pool_provider_id = "aeroscale-github-provider"
  display_name                       = "AeroScale GitHub OIDC Provider"
  description                        = "OIDC identity provider for GitHub Actions"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  attribute_condition = "attribute.repository == \"stayrelevantid/aeroscale\""
}

resource "google_service_account_iam_member" "github_actions_wif" {
  service_account_id = google_service_account.aeroscale_worker.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.aeroscale_github.name}/attribute.repository/stayrelevantid/aeroscale"
}

resource "google_project_iam_member" "artifact_registry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.aeroscale_worker.email}"
}

resource "google_project_iam_member" "container_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.aeroscale_worker.email}"
}