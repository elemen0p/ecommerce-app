resource "google_container_cluster" "ecommerce_cluster" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id


  node_locations = [
    "${var.region}-a",
    "${var.region}-b",
    "${var.region}-c"
  ]

  
  # WIF is the best practice when trying to secure access the cloud services from running worloads in k8s
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Network configuration
  network    = var.private_network
  subnetwork = var.primary_subnet

  # Enable network policy with Calico (container network interface)
  network_policy {
    enabled  = var.network_policy_enabled
    provider = "CALICO" # Standard network policy engine for Kubernetes
  }

  # IP allocation policy (--enable-ip-alias flag)
  ip_allocation_policy {
    # We're creating the IP ranges automatically since they weren't specified
    # If you want to specify them, uncomment and set these:
    # cluster_ipv4_cidr_block  = "10.4.0.0/14" ==> nodes ip
    # services_ipv4_cidr_block = "10.0.0.0/20" ==> pods ip
  }

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # Allow access from internet to master
    master_ipv4_cidr_block  = var.master_cidr
  }

  # Master authorized networks (Cloud shell by default)
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.authorize_endpoint_cidr 
      display_name = var.authorize_display_name
    }
  }

# Remove default node pool and use separately managed node pool
  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-node-pool"
  cluster    = google_container_cluster.ecommerce_cluster.name
  location   = var.region
  project    = var.project_id

  #ignore these fields - tells tf to not manage them. gcp fill default values for configs not mentioned here and tf think that i want to remove this configs since they not here
  lifecycle {
    ignore_changes = [
      node_config[0].resource_labels,
      node_config[0].kubelet_config
    ]
  }

  initial_node_count       = 1
  
  # Autoscaling per zone 
  autoscaling {
    min_node_count = var.min_node_count 
    max_node_count = var.max_node_count 
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    service_account = var.gcp_service_account

    # Standard GKE scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append"
    ]
    
    # Controls how Kubernetes workloads running on nodes can access metadata about the node or project
    # This is the Most secure default. Makes metadata available through a local endpoint
    # Required for Workload Identity to work with GCP services securely.
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    tags = ["kubernetes-node"]

    labels = {
      environment = var.environment
      app         = "ecommerce"
      purpose     = "kubernetes-pool"
    }
  }

  management {

    # Automatically restarts or recreates unhealthy nodes
    auto_repair  = true

    # Keeps nodes up-to-date with Kubernetes and OS patches
    auto_upgrade = true
  }

  # Add this to ensure the cluster is fully created before creating the node pool
  depends_on = [
    google_container_cluster.ecommerce_cluster
  ]
}
