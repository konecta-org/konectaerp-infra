output "ingress_ip_address" {
  description = "Static IP address for Ingress"
  value       = google_compute_global_address.ingress_ip.address
}

output "ingress_ip_name" {
  description = "Name of the static IP address"
  value       = google_compute_global_address.ingress_ip.name
}
