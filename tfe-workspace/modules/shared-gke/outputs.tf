output "cluster_name" {
  value = google_container_cluster.this.name
}

output "cluster_endpoint" {
  value     = google_container_cluster.this.endpoint
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive = true
}

output "location" {
  value = google_container_cluster.this.location
}

output "namespace" {
  value = kubernetes_namespace_v1.tenant.metadata[0].name
}

output "get_credentials_command" {
  value = "gcloud container clusters get-credentials ${google_container_cluster.this.name} --region ${google_container_cluster.this.location} --project ${var.project_id}"
}
