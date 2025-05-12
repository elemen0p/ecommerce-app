# VPC Network Resource
# A Virtual Private Cloud network provides networking for your cloud resources
resource "google_compute_network" "vpc" {
  # Name of the VPC that will appear in the GCP console
  name = var.vpc_name

  description = var.vpc_description

  # Must explicitly define all subnets
  auto_create_subnetworks = var.auto_create_subnetworks_enabled

  # single-zone/multi=zone
  routing_mode = var.routing_mode
}

# Subnet in the primary region
resource "google_compute_subnetwork" "subnet1" {
  # Name of the subnet that will appear in the GCP console
  name = var.subnet1_name

  # IP address range for this subnet in CIDR notation
  ip_cidr_range = var.subnet1_range

  # Region where this subnet will be created
  region = var.region1

  # The VPC network this subnet belongs to
  network = google_compute_network.vpc.id
}

# Subnet in the secondary region
resource "google_compute_subnetwork" "subnet2" {
  name = var.subnet2_name

  ip_cidr_range = var.subnet2_range

  # Secondary region for geographic distribution
  region = var.region2

  # Same VPC network as the first subnet
  network = google_compute_network.vpc.id
}

# FIREWALL RULES
# Firewall rules control traffic to and from your VPC resources

# 1. Custom ingress rule to allow traffic between the two subnets
resource "google_compute_firewall" "allow_custom" {
  name    = "vpc-allow-custom"
  network = google_compute_network.vpc.name

  # Allow all protocols and ports
  allow {
    protocol = "all"
  }

  # This is an ingress rule (traffic coming into instances)
  direction = "INGRESS"

  # Only allow traffic from the two subnet IP ranges
  # This ensures internal communication between your application components
  source_ranges = [var.subnet1_range, var.subnet2_range]

  # Priority determines the order of firewall rule evaluation
  # Lower numbers have higher priority (65534 is just before the default rule)
  priority = 65534
}

# 2. ICMP ingress rule - allows ping and other ICMP traffic
resource "google_compute_firewall" "allow_icmp" {
  name    = "vpc-allow-icmp"
  network = google_compute_network.vpc.name

  # Allow ICMP protocol (ping, traceroute, etc.)
  allow {
    protocol = "icmp"
  }

  direction = "INGRESS"

  # Allow ICMP from anywhere on the internet
  # This helps with troubleshooting network connectivity
  source_ranges = ["0.0.0.0/0"]

  priority = 65534
}

# 3. TLS ingress rule - allows HTTPS traffic
resource "google_compute_firewall" "allow_tls" {
  name    = "vpc-allow-tls"
  network = google_compute_network.vpc.name
  # Allow TCP traffic specifically on port 443 (HTTPS/TLS)
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  # This is an ingress rule (traffic coming into instances)
  direction = "INGRESS"

  # Allow TLS connections from anywhere
  source_ranges = ["0.0.0.0/0"]

  priority = 1000

}

# 4. Deny all other ingress traffic - acts as a default deny rule
resource "google_compute_firewall" "deny_all_ingress" {
  name    = "vpc-deny-all-ingress"
  network = google_compute_network.vpc.name

  # Deny all protocols and ports
  deny {
    protocol = "all"
  }

  direction = "INGRESS"

  # Apply to all sources not explicitly allowed by previous rules
  source_ranges = ["0.0.0.0/0"]

  # Slightly lower priority than the default allow rule (65535)
  # This ensures it's the last rule evaluated, after all custom rules
  priority = 65535
}

# 5. Allow all egress traffic - permits outbound connections from your instances
resource "google_compute_firewall" "allow_all_egress" {
  name    = "vpc-allow-all-egress"
  network = google_compute_network.vpc.name

  # Allow all protocols and ports for outbound traffic
  allow {
    protocol = "all"
  }

  # This is an egress rule (traffic going out from instances)
  direction = "EGRESS"

  # Allow outbound connections to any destination
  # This ensures your applications can reach external services
  destination_ranges = ["0.0.0.0/0"]

  # Lowest priority for egress rules
  priority = 65535
}
