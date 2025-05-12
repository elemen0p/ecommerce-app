resource "helm_release" "helm_object" {
  name  = var.helm_name
  chart = var.helm_path
  values = var.helm_values
}
