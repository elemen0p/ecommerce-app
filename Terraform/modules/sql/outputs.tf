# The connection name of the database (PROJECT:REGION:INSTANCE)
#output "database_connection_name" {
#  description = "The connection name of the database to be used in connection strings"
#  value       = google_sql_database_instance.ecommerce_db.connection_name
#}

output "ecommerce_db" {
  description = "The connection name of the database to be used in connection strings"
  value       = google_sql_database_instance.ecommerce_db
}

output "private_ip_address" {
 description = "The db private ip"
 value       = google_compute_global_address.private_ip_address
}

# Information about the database password in Secret Manager
output "database_password_secret" {
  description = "Secret Manager path to access the database password"
  value       = "projects/${var.project_id}/secrets/ecommerce-db-password/versions/latest"
}

# The database password - SENSITIVE OUTPUT!
# This will only be displayed once after initial deployment
output "db_password" {
  description = "The generated password for the database user (displayed only once)"
  value       = random_password.db_password
  sensitive   = true
}

output "db_password_secret" {
  description = "The generated password for the database user (displayed only once)"
  value       = var.db_password_secret_name
}

