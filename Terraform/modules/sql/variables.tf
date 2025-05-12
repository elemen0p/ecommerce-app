variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "db_cidr" {
  type        = string
  description = "DB network address we do vpc peering with"
}

variable "private_network" {
  type        = string
  description = "The VPC in which the db will be created"
}

variable "environment" {
  type        = string
  description = "prod/dev"
}

variable "db_password_secret_name" {
  type        = string
  description = "The name of the db password decret name in the gcp"
}

variable "instance_name" {
  type        = string
}

variable "db_version" {
  type        = string
  default     = "POSTGRES_17"
}

variable "db_name" {
  type        = string
  default     = "ecommerce"
}


variable "db_user" {
  type        = string
  default     = "postgres"
}

variable "deletion_protection_enabled" {
  type        = bool
  default     = true
}

variable "vm_tier" {
  type        = string
  default     = "db-custom-2-8192"
  description = "Machine type with 2 dedicated vCPUs and 8GB of RAM"
}

variable "availability_type" {
  type        = string
  default     = "REGIONAL"
  description = "Multi-zone high availability (REGIONAL = Primary + Standby)"
}

variable "edition" {
  type        = string
  default     = "ENTERPRISE"
}

variable "disk_size" {
  type        = number
  default     = 10
}

variable "disk_type" {
  type        = string
  default     = "PD_SSD"
  description = "SSD storage for better performance"
}

variable "disk_autoresize_enabled" {
  type        = bool
  default     = false
  description = "No automatic storage increases"
}

variable "backup_enabled" {
  type        = bool
  default     = true
}

variable "public_ip_enabled" {
  type        = bool
  default     = false
  description = "Disable public IP"
}

variable "max_connections" {
  type        = string
  default     = "100"
  description = "Maximum number of concurrent connections"
}