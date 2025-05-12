variable "helm_name" {
  type        = string
}

variable "helm_path" {
  type        = string
  description = "Path to the helm chart"
}

variable "helm_values" {
  type        = list(any)
  description = "List of values for values.yaml"
}
