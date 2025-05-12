variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "cluster_name" {
  type        = string
  description = "GKE cluster name"
}

variable "private_network" {
  type        = string
  description = "The specific VPC"
}

variable "primary_subnet" {
  type        = string
  description = "The subnet of the primary region in the VPC"
}

variable "network_policy_enabled" {
  type        = bool
  default     = true
  description = "Enable use in network policy in k8s"
}

variable "master_cidr" {
  type        = string
  default     = "172.16.0.0/28"
  description = "A subnet in the master VPC (automatically created)"
}

variable "authorize_endpoint_cidr" {
  type = string
  description = "This range is allowed to access the api server"
}

variable "authorize_display_name" {
  type = string
  description = "A display name of the allowed range"
}

variable "min_node_count" {
  type = number
  description = "Min num of nodes when auto scaling"
}

variable "disk_size_gb" {
  type        = number
  default     = 20
}

variable "gcp_service_account" {
  type        = string
  description = "The google cloud service account"
}

variable "max_node_count" {
  type = number
  description = "Max num of nodes when auto scaling"
}

variable "environment" {
  type        = string
  description = "prod/dev"
}

variable "machine_type" {
  type        = string
  default     = "e2-standard-2"
}
