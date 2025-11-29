output "sqlserver_sa_password_secret_id" {
  description = "SQL Server SA password secret ID"
  value       = google_secret_manager_secret.sqlserver_sa_password.secret_id
}

output "rabbitmq_password_secret_id" {
  description = "RabbitMQ password secret ID"
  value       = google_secret_manager_secret.rabbitmq_password.secret_id
}

output "jwt_secret_id" {
  description = "JWT secret key ID"
  value       = google_secret_manager_secret.jwt_secret.secret_id
}

output "encryption_key_secret_id" {
  description = "Encryption key secret ID"
  value       = google_secret_manager_secret.encryption_key.secret_id
}
