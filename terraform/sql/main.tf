resource "google_sql_database_instance" "sqlserver" {
  name             = "app-sql-${var.environment}"
  database_version = "SQLSERVER_2019_STANDARD"
  region           = var.region

  settings {
    tier = "db-custom-2-8192"
  }
}

output "sql_server_host" {
  value = google_sql_database_instance.sqlserver.private_ip_address
}

output "sql_server_port" {
  value = 1433
}

output "sql_server_db" {
  value = "appdb"
}
