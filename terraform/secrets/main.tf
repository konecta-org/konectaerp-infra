# SQL Server SA Password
resource "google_secret_manager_secret" "sqlserver_sa_password" {
  secret_id = "sqlserver-sa-password-${var.environment}"
  project   = var.project_id

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    application = "konecta-erp"
  }

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "sqlserver_sa_password" {
  count = var.sqlserver_sa_password != "" ? 1 : 0

  secret      = google_secret_manager_secret.sqlserver_sa_password.id
  secret_data = var.sqlserver_sa_password
}

# RabbitMQ Password
resource "google_secret_manager_secret" "rabbitmq_password" {
  secret_id = "rabbitmq-password-${var.environment}"
  project   = var.project_id

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    application = "konecta-erp"
  }

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "rabbitmq_password" {
  count = var.rabbitmq_password != "" ? 1 : 0

  secret      = google_secret_manager_secret.rabbitmq_password.id
  secret_data = var.rabbitmq_password
}

# JWT Secret Key
resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "jwt-secret-key-${var.environment}"
  project   = var.project_id

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    application = "konecta-erp"
  }

  replication {
    auto {}
  }
}

# Encryption Key
resource "google_secret_manager_secret" "encryption_key" {
  secret_id = "encryption-key-${var.environment}"
  project   = var.project_id

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    application = "konecta-erp"
  }

  replication {
    auto {}
  }
}
