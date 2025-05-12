# Output the cluster endpoint and certificate
output "kubernetes_cluster_endpoint" {
  value       = google_container_cluster.ecommerce_cluster.endpoint
  description = "GKE Cluster Endpoint"
}

output "kubernetes_cluster_name" {
  value       = google_container_cluster.ecommerce_cluster.name
  description = "GKE Cluster Name"
}

output "ecommerce_cluster" {
  value       = google_container_cluster.ecommerce_cluster
  description = "GKE Cluster object"
}

output "kubernetes_cluster_ca_certificate" {
  value       = base64decode(google_container_cluster.ecommerce_cluster.master_auth[0].cluster_ca_certificate)
  sensitive   = true
  description = "GKE Cluster CA Certificate"
}