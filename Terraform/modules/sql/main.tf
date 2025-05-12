# This reserves a private IP range for Cloud SQL to use
resource "google_compute_global_address" "private_ip_address" {
  name          = "ecommerce-private-ip-range"

  # Used for VPC Service Controls
  purpose       = "VPC_PEERING"                           
  address_type  = "INTERNAL"                              
  prefix_length = 24               

  # The starting address of the range                       
  address       = var.db_cidr                             
  network       = var.private_network 
}

# This creates the actual VPC peering connection to Google services
# Without this, Cloud SQL cannot use private IP in our VPC
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.private_network                

  # Google's service networking API
  service                 = "servicenetworking.googleapis.com"   

  # Use our reserved range
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name] 
}

# Generate a secure random password for the database
resource "random_password" "db_password" {

  # 16 characters long
  length           = 16    

  # Include special characters
  special          = true    

  # Allowed special characters
  override_special = "!#$%&*()-_=+[]{}<>:?" 
}

# Create a Secret in Secret Manager to store the database password
resource "google_secret_manager_secret" "db_password" {
  secret_id = var.db_password_secret_name

  # Set automatic replication (Google manages the replication)
  replication {
    auto {
      # Auto replication, no parameters needed
    }
  }

  # Add labels for better organization
  labels = {
    environment = var.environment
    app         = "ecommerce"
    managed-by  = "terraform"
  }
}

# Store the actual password value in the Secret Manager secret
resource "google_secret_manager_secret_version" "db_password_version" {

  # Reference the secret we just created
  secret      = google_secret_manager_secret.db_password.id 

  # Store the generated password
  secret_data = random_password.db_password.result          
}

# Database instance configuration
resource "google_sql_database_instance" "ecommerce_db" {
  name             = var.instance_name # Name of the database instance
  database_version = var.db_version           
  region           = var.region          

  # Prevents accidental deletion of the database instance
  # To delete the instance, you must set this to false first
  deletion_protection = var.deletion_protection_enabled

  # Ensure VPC peering is established before creating the database
  depends_on = [
    google_service_networking_connection.private_vpc_connection
  ]

  settings {
    tier = var.vm_tier
    availability_type = var.availability_type
    edition = var.edition

    # Storage configuration
    disk_size       = var.disk_size   
    disk_type       = var.disk_type 
    disk_autoresize = false   

    # Backup configuration
    backup_configuration {
      enabled    = var.backup_enabled

      # 10:00 PM start time for backups
      start_time = "22:00" 

      # Multi-region in the United States
      location   = "us"    

      backup_retention_settings {

        # Keep 7 days of backups
        retained_backups = 7 
      }
      point_in_time_recovery_enabled = true 
      transaction_log_retention_days = 7   
    }

    # Maintenance window settings
    maintenance_window {

      # Saturday (0=Sunday, 1=Monday, ..., 6=Saturday)
      day          = 6        

      # 12:00 AM (midnight)
      hour         = 0 

      # Use stable updates (not preview)
      ###############################################################################################################
      update_track = "stable" 
    }

    # Query insights for performance monitoring
    insights_config {
      query_insights_enabled = false
    }


    # IP configuration - Private IP only, no public IP
    ip_configuration {
      ipv4_enabled       = var.public_ip_enabled 
      private_network    = var.private_network
      allocated_ip_range = google_compute_global_address.private_ip_address.name
    }

    # Database flags for PostgreSQL configuration
    database_flags {
      name  = "max_connections"
      value = var.max_connections
    }

    # Always active (not on-demand)
    activation_policy = "ALWAYS"

    # Primary zone specification
    location_preference {
      zone = "${var.region}-a" 
    }

    # Labels for resource organization and billing analysis
    user_labels = {
      environment = var.environment
      project     = "ecommerce-prod-459415"
      app         = "db"
    }
  }
}

# Create the ecommerce database
resource "google_sql_database" "ecommerce_database" {
  name     = var.db_name
  instance = var.instance_name

  depends_on = [google_sql_database_instance.ecommerce_db]
}
# Gives the postgres default user a password so we will have a way to have permissions on the table he just created
resource "google_sql_user" "postgres_user" {
  name     = var.db_user
  instance = var.instance_name
  password = random_password.db_password.result

  depends_on = [google_sql_database_instance.ecommerce_db]
}
