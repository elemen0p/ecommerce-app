# terraform.tfvars

# Replace with your actual GCP project ID
project_id = "ecommerce-prod-459415"

# Regions for deployment - already set to defaults in main.tf, but you can customize here
region1 = "us-central1"
region2 = "us-east1"

# Subnets details
subnet1_name  = "ecommerce-subnet-central1"
subnet1_range = "10.0.0.0/24"
subnet2_name  = "ecommerce-subnet-east1"
subnet2_range = "10.0.1.0/24"

# Authorize for master access
my_ip = "79.177.142.0/24"

frontend_image_tag = "latest"
backend_image_tag  = "latest"



