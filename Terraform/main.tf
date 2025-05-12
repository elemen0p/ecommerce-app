#=============================================================================================
#=============================================================================================
#=============================================================================================
#                                     P--R--O--V--I--D--E--R--S
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.10.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region1
}

provider "google-beta" {
  project = var.project_id
  region  = var.region1
}

provider "random" {}

#=============================================================================================
#=============================================================================================
#=============================================================================================
#                                     N--E--T--W--o--R--K--I--N--G
# VPC Network creation, 2 subnet and some common fw rules
module "net" {
  source                          = "./modules/net"
  vpc_name                        = "ecommerce-vpc"
  vpc_description                 = "Secure overlay network for the e-commerce platform connecting multi-zone components. This VPC enables private communication between frontend, backend, database, and supporting services across multiple regions using private IP addressing."
  auto_create_subnetworks_enabled = false
  routing_mode                    = "GLOBAL"
  subnet1_name                    = var.subnet1_name
  subnet1_range                   = var.subnet1_range
  subnet2_name                    = var.subnet2_name
  subnet2_range                   = var.subnet2_range
  region1                         = var.region1
  region2                         = var.region2
}

#=============================================================================================
#=============================================================================================
#=============================================================================================
#                                     D--A--T--A--B--A--S--E
module "sql" {
  source                      = "./modules/sql"
  project_id                  = var.project_id
  db_cidr                     = "10.223.160.0"
  region                      = var.region1
  private_network             = module.net.vpc_id
  db_password_secret_name     = "ecommerce-db-password"
  instance_name               = "ecommerce-db-instance"
  db_version                  = "POSTGRES_17"
  db_name                     = "ecommerce"
  db_user                     = "postgres"
  deletion_protection_enabled = true
  vm_tier                     = "db-custom-2-8192"
  availability_type           = "REGIONAL"
  edition                     = "ENTERPRISE"
  disk_size                   = 10
  disk_type                   = "PD_SSD"
  disk_autoresize_enabled     = false
  backup_enabled              = true
  public_ip_enabled           = false
  max_connections             = "100"
  environment                 = "prod"
}

#=============================================================================================
#=============================================================================================
#=============================================================================================
#                                     C--O--M--P--U--T--E
##Creation of google cloud sa and IAM rules
resource "google_service_account" "ecommerce_sa" {
  account_id   = "ecommerce-sa"
  display_name = "E-commerce Application Service Account"
  description  = "Service account for the e-commerce application to access GCP resources"
}

resource "google_project_iam_member" "ecommerce_sa_roles" {
  for_each = toset([
    "roles/cloudsql.client",
    "roles/cloudsql.admin",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/artifactregistry.reader",
    "roles/secretmanager.secretAccessor",
    "roles/containerregistry.ServiceAgent",
    "roles/storage.objectViewer"
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.ecommerce_sa.email}"
}

# GKE Cluster and node pool creation
module "gke" {
  source                  = "./modules/gke"
  project_id              = var.project_id
  region                  = var.region1
  cluster_name            = "ecommerce-cluster"
  private_network         = module.net.vpc_name
  primary_subnet          = var.subnet1_name
  network_policy_enabled  = true
  master_cidr             = "172.16.0.0/28"
  authorize_endpoint_cidr = var.my_ip
  authorize_display_name  = "TF server IP"
  min_node_count          = 1
  max_node_count          = 3
  disk_size_gb            = 20
  gcp_service_account     = google_service_account.ecommerce_sa.email
  machine_type            = "e2-standard-2"
  environment             = "prod"
}

#=============================================================================================
#=============================================================================================
#=============================================================================================
#                                     S--E--C--R--E--T--S
##Creation of the cert and key
resource "tls_private_key" "frontend_tls" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "frontend_tls" {
  private_key_pem = tls_private_key.frontend_tls.private_key_pem

  subject {
    common_name = "ecommerce-frontend"
  }

  dns_names = ["ecommerce-frontend.example.com"]

  validity_period_hours = 8760 # 365 days

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "kubernetes_secret" "frontend_tls" {
  metadata {
    name = "frontend-tls"
  }

  data = {
    "tls.crt" = tls_self_signed_cert.frontend_tls.cert_pem
    "tls.key" = tls_private_key.frontend_tls.private_key_pem
  }

  type = "kubernetes.io/tls"
}

#create a secret named ecommerce-tls-cert in the secret manager
resource "google_secret_manager_secret" "tls_cert" {
  secret_id = "ecommerce-tls-cert"

  replication {
    auto {}
  }

  labels = {
    environment = "prod"
    app         = "ecommerce"
  }
}

#Store the cert in the secret manager
resource "google_secret_manager_secret_version" "tls_cert" {
  secret      = google_secret_manager_secret.tls_cert.id
  secret_data = tls_self_signed_cert.frontend_tls.cert_pem
}

#create a secret named ecommerce-tls-key in the secret manager
resource "google_secret_manager_secret" "tls_key" {
  secret_id = "ecommerce-tls-key"

  replication {
    auto {}
  }

  labels = {
    environment = "prod"
    app         = "ecommerce"
  }
}

#Store the key in the secret manager
resource "google_secret_manager_secret_version" "tls_key" {
  secret      = google_secret_manager_secret.tls_key.id
  secret_data = tls_private_key.frontend_tls.private_key_pem
}

# Create Kubernetes secrets of db credentials for application use
resource "kubernetes_secret" "db_credentials" {
  metadata {
    name = "db-credentials"
  }

  data = {
    username = "postgres"
    password = module.sql.db_password.result
  }

  depends_on = [module.gke.primary_nodes]
}


# Give the service account access to the secrets
resource "google_secret_manager_secret_iam_member" "db_password_access" {
  secret_id = module.sql.db_password_secret
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.ecommerce_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "tls_cert_access" {
  secret_id = google_secret_manager_secret.tls_cert.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.ecommerce_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "tls_key_access" {
  secret_id = google_secret_manager_secret.tls_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.ecommerce_sa.email}"
}

#=============================================================================================
#=============================================================================================
#=============================================================================================
#                                     H--E--L--M


#explicitly need to create the sa in order to bind it to gcp sa
resource "kubernetes_service_account" "ecommerce_ksa" {
  metadata {
    name = "ecommerce-ksa"
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.ecommerce_sa.email
    }
  }

  depends_on = [
    module.gke.primary_nodes
  ]
}

# Allow the Kubernetes Service Account to use the Google Service Account identity
resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = google_service_account.ecommerce_sa.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[default/ecommerce-ksa]",
  ]
}

# Configure Terraform providers to connect to GKE
provider "kubernetes" {
  host                   = "https://${module.gke.ecommerce_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ecommerce_cluster.master_auth[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.ecommerce_cluster.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.ecommerce_cluster.master_auth[0].cluster_ca_certificate)
  }
}

data "google_client_config" "default" {}


# Ecommerce helm chart release
module "helm" {
  source    = "./modules/helm"
  helm_name = "ecommerce"
  helm_path = "../helm/ecommerce/"
  helm_values = [
    templatefile("./helm-values.tpl.yml", {
      db_host             = module.sql.ecommerce_db.private_ip_address,
      db_port             = "5432",
      db_name             = "ecommerce",
      gcp_service_account = google_service_account.ecommerce_sa.email,
      frontend_image_repo = "gcr.io/ecommerce-prod-459415/ecommerce-frontend",
      frontend_image_tag  = "latest",
      backend_image_repo  = "gcr.io/ecommerce-prod-459415/ecommerce-backend",
      backend_image_tag   = "latest",
      db_ip_range         = module.sql.private_ip_address.address
      db_ip_prefix        = module.sql.private_ip_address.prefix_length
    })
  ]

  depends_on = [
    module.gke.primary_nodes,
    kubernetes_secret.db_credentials,
    kubernetes_secret.frontend_tls
  ]

}

