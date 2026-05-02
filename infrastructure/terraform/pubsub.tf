resource "google_pubsub_topic" "aeroscale_topic" {
  name = "aeroscale-event-queue"
}

resource "google_pubsub_subscription" "aeroscale_subscription" {
  name  = "aeroscale-event-subscription"
  topic = google_pubsub_topic.aeroscale_topic.name

  ack_deadline_seconds = 60

  message_retention_duration = "604800s"

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }
}