variable "vpc_name" {
  type        = string
}

variable "vpc_description" {
  type        = string
}

variable "auto_create_subnetworks_enabled" {
    type        = bool
    default     = false
    description = "false - we'll need to mention those explicitly"
}
 variable "routing_mode" {
    type = string
    default = "GLOBAL"
    description = "GLOBAL routing mode allows subnets in different regions to communicate internally, Alternative is REGIONAL, which restricts cross-region communication"
 }

 variable "subnet1_name" {
    type = string
    description = "Subnet in the primary region"
 }

 variable "subnet1_range" {
    type = string
    default = "10.0.0.0/24"
    description = "IP address range for this subnet in CIDR notation"
 }

 variable "subnet2_name" {
    type = string
    description = "Subnet in the secondary region"
 }

 variable "subnet2_range" {
    type = string
    default = "10.0.1.0/24"
    description = "IP address range for this subnet in CIDR notation"
 }

 variable "region1" {
  type        = string
  description = "GCP  primary region in the VPC"
}

variable "region2" {
  type        = string
  description = "GCP  secondary region in the VPC"
}
