output "webhook_url" {
  description = "Paste this into TFE notification Webhook URL (GCP-tfe-workspace -> Settings -> Notifications)"
  value       = google_cloudfunctions2_function.bridge.service_config[0].uri
}

output "tfe_webhook_secret_hint" {
  description = "Use the same value in TFE notification Token field (from terraform variable tfe_webhook_secret)"
  value       = "Set in TFE notification Token — must match var.tfe_webhook_secret"
}
