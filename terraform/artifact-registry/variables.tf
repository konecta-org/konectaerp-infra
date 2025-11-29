variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the registry"
  type        = string
  default     = "us-central1"
}

variable "repository_id" {
  description = "Artifact Registry repository ID"
  type        = string
  default     = "konecta-erp"
}

variable "description" {
  description = "Repository description"
  type        = string
  default     = "Docker images for Konecta ERP"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}
