# Example terraform.tfvars file
# Copy this to terraform.tfvars and update with your values

project_id  = "erp-system-478020"
region      = "us-central1"
environment = "dev"

# Cluster configuration
cluster_name = "konecta-erp-cluster"
network_name = "konecta-erp-network"

# Network configuration
subnet_cidr            = "10.0.0.0/24"
pods_cidr_range        = "10.1.0.0/16"
services_cidr_range    = "10.2.0.0/16"
master_ipv4_cidr_block = "172.16.0.0/28"

# Security
enable_private_nodes    = true
enable_private_endpoint = false

# Authorized networks (add your IP for kubectl access)
authorized_networks = [
  {
    cidr_block   = "0.0.0.0/0"
    display_name = "All (update this for production)"
  }
]
