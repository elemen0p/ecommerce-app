# Variable definitions - These will be set from terraform.tfvars
# Project ID variable - required for all GCP resources
variable "project_id" {
  description = "The GCP project ID where all resources will be created"
  type        = string
  # No default - this must be provided in terraform.tfvars
}

# Primary region variable
variable "region1" {
  description = "Primary GCP region for resource deployment (e.g., for the first subnet)"
  type        = string
  default     = "us-central1" # Iowa - a strategic central US location
}

# Secondary region variable
variable "region2" {
  description = "Secondary GCP region for resource deployment (e.g., for the second subnet)"
  type        = string
  default     = "us-east1" # South Carolina - provides East Coast presence
}

variable "frontend_image_tag" {
  description = "The tag for the frontend image"
  type        = string
  default     = "latest"
}

variable "backend_image_tag" {
  description = "The tag for the backend image"
  type        = string
  default     = "latest"
}

variable "my_ip" {
  description = "My local IP address for GKE master access"
  type        = string
}

variable "subnet1_name" {
  type        = string
  description = "Subnet in the primary region"
}

variable "subnet1_range" {
  type        = string
  default     = "10.0.0.0/24"
  description = "IP address range for this subnet in CIDR notation"
}

variable "subnet2_name" {
  type        = string
  description = "Subnet in the secondary region"
}

variable "subnet2_range" {
  type        = string
  default     = "10.0.1.0/24"
  description = "IP address range for this subnet in CIDR notation"
}
