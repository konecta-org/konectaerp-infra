# Reserve static IP for Ingress
resource "google_compute_global_address" "ingress_ip" {
  name    = var.ingress_ip_name
  project = var.project_id

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    application = "konecta-erp"
  }
}

# Firewall rule for health checks
resource "google_compute_firewall" "allow_health_checks" {
  name    = "allow-health-checks-konecta-erp"
  network = "default" # Update if using custom network
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }

  source_ranges = [
    "35.191.0.0/16", # Google Cloud health check ranges
    "130.211.0.0/22"
  ]

  target_tags = ["gke-node"]

  description = "Allow health checks from Google Cloud Load Balancer"
}

# Firewall rule for internal communication
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal-konecta-erp"
  network = "default" # Update if using custom network
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]

  description = "Allow internal communication within VPC"
}
