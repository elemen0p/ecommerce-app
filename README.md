# Cloud-Native E-commerce Application

This repository contains a cloud-native e-commerce application built on Google Cloud Platform, featuring high availability and resiliency capabilities.

## Architecture Design
![ecommerce_architecture drawio (1)](https://github.com/user-attachments/assets/0b64363d-3da3-4c5a-8af0-a61ff6274ac1)

### High Availability (HA)
- Multi-zone database deployment
- Multi-zone GKE cluster with node auto-scaling
- Replicated workloads with topology constraints

### Disaster Recovery (DR)
Not fully implemented but an implementation strategy is described:
- VPC spanning two different regions
- Standby instance of the entire system in the secondary region
- A new Google Cloud Load Balancer routing traffic to public egress IP
- Quick failover capability using shell commands, Terraform, or Python scripts

## Infrastructure Implementation

The infrastructure is implemented using Terraform modules and GCP APIs:

### Terraform Modules

#### SQL Module
- Creates private address range for the database
- Enables VPC peering
- Generates and manages database passwords in GCP Secret Manager
- Creates database instances and users

#### Network Module
- Creates VPC with regional subnets
- Implements firewall rules

#### Helm Module
- Manages Helm chart releases

#### GKE Module
- Creates GKE cluster with network policies
- Enables auto-generated subnet creation for pod IPs
- Configures node pools with auto-scaling
- Implements Workload Identity Federation (maps K8s SA to GCP SA)

> **Important**: Before applying Terraform code, you need to enable required GCP APIs (Kubernetes Engine API, etc.)

## Application Components

This MVP application demonstrates the architecture design with functional APIs:

### Frontend
- package.json
- app.js
- index.html
- Dockerfile

### Backend
- package.json
- app.js
- Dockerfile

## Security and Availability

### Database
- Multi-zone deployment in private subnet
- VPC peering for secure access
- Primary instance in primary zone, standby in another zone
- Internal IP access only
- 7-day backup retention
- Passwords stored in GCP Secret Manager
- Deletion protection enabled

### GKE Cluster
- Multi-zone deployment
- Nodes using primary subnet IPs
- Pods using auto-created subnet IPs
- Control plane on dedicated VPC with peering
- API server access restricted to authorized IP ranges:
  ```
  gcloud container clusters update ecommerce-cluster \
    --region=us-central1 \
    --enable-master-authorized-networks \
    --master-authorized-networks=<authorized_ip_cidr>
  ```
- Network policies enabled
- Node pool auto-scaling (1-3 nodes per zone)
- Workload Identity with least privilege IAM roles:
  - roles/cloudsql.client
  - roles/cloudsql.admin
  - roles/logging.logWriter
  - roles/monitoring.metricWriter
  - roles/artifactregistry.reader
  - roles/secretmanager.secretAccessor
  - roles/containerregistry.ServiceAgent
  - roles/storage.objectViewer

### Network
- Multi-region VPC with regional subnets
- Firewall rules:
  - Allow all egress
  - Deny all ingress by default
  - Allow ingress ICMP
  - Allow ingress TLS
  - Allow all traffic between subnets

## Helm Chart Configuration

### Deployments
- Separate backend and frontend deployments
- 3 replicas each
- Pod distribution across zones using topologySpreadConstraints
- Configuration via secrets and config maps
- Pod anti-affinity to avoid scheduling on same nodes

### Services
- Frontend service: GCP Load Balancer (internal access)
- Backend service: ClusterIP service
- Ingress: TLS termination
  - NOTE: Using self-signed certificates for non-production environments

### Network Policies
- Frontend:
  - Allowed ingress: port 80
  - Allowed egress: backend-service, DNS resolution
- Backend:
  - Allowed ingress: frontend-service
  - Allowed egress: Database, DNS resolution

## Pending Implementations

### Horizontal Pod Autoscaler (HPA)
Template available but not fully tested:

```yaml
{{- if .Values.frontend.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ecommerce-frontend
  labels:
    app: ecommerce-frontend
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ecommerce-frontend
  minReplicas: {{ .Values.frontend.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.frontend.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.frontend.autoscaling.targetCPUUtilizationPercentage }}
{{- end }}
```

## Getting Started

1. Enable required GCP APIs
2. Configure GCP authentication
3. Apply Terraform root module
4. Access the application through the configured ingress endpoint
![image](https://github.com/user-attachments/assets/04658159-5cb6-4076-be88-e4352e721580)
