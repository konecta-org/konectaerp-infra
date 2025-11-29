terraform {
  # required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.12.0"
    }
    # google-beta = {
    #   source  = "hashicorp/google-beta"
    #   version = "~> 5.0"
    # }
  }

  backend "gcs" {
    # Configure this with your GCS bucket for state storage
    bucket = "konecta-erp-system"
    prefix = "terraform/gke"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# provider "google-beta" {
#   project = var.project_id
#   region  = var.region
# }
