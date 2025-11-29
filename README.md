# Konecta ERP - Infrastructure

Production-ready Kubernetes infrastructure for Konecta ERP on Google Cloud Platform (GKE).

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Google Cloud Platform                    │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              GKE Autopilot Cluster                      │ │
│  │                                                          │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐             │ │
│  │  │ Frontend │  │   API    │  │  Consul  │             │ │
│  │  │ (Angular)│  │ Gateway  │  │   (SD)   │             │ │
│  │  └────┬─────┘  └────┬─────┘  └──────────┘             │ │
│  │       │             │                                   │ │
│  │  ┌────┴─────────────┴────────────────────────┐         │ │
│  │  │         Microservices Layer               │         │ │
│  │  │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐    │         │ │
│  │  │  │ Auth │ │  HR  │ │ Inv. │ │ Fin. │    │         │ │
│  │  │  └──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘    │         │ │
│  │  └─────┼────────┼────────┼────────┼─────────┘         │ │
│  │        │        │        │        │                    │ │
│  │  ┌─────┴────────┴────────┴────────┴─────────┐         │ │
│  │  │         Data & Messaging Layer           │         │ │
│  │  │  ┌──────────┐  ┌──────────┐             │         │ │
│  │  │  │SQL Server│  │ RabbitMQ │             │         │ │
│  │  │  │(StatefulS│  │(StatefulS│             │         │ │
│  │  │  └──────────┘  └──────────┘             │         │ │
│  │  └──────────────────────────────────────────┘         │ │
│  │                                                          │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐           │
│  │  Artifact  │  │   Secret   │  │   Cloud    │           │
│  │  Registry  │  │  Manager   │  │    NAT     │           │
│  └────────────┘  └────────────┘  └────────────┘           │
└─────────────────────────────────────────────────────────────┘
```

## 📦 Components

### Infrastructure (Terraform)

- **GKE Autopilot Cluster**: Managed Kubernetes with auto-scaling
- **Artifact Registry**: Docker image storage with vulnerability scanning
- **Cloud NAT**: Outbound internet access for private nodes
- **Secret Manager**: Secure credential storage
- **Load Balancer**: Global HTTPS load balancing

### Application Services

- **Frontend**: Angular SPA (Nginx)
- **API Gateway**: Spring Boot gateway with routing
- **Authentication Service**: .NET Core identity & JWT
- **HR Service**: .NET Core employee management
- **Inventory Service**: .NET Core inventory tracking
- **Finance Service**: .NET Core financial operations
- **User Management Service**: .NET Core user administration
- **Reporting Service**: Spring Boot analytics

### Infrastructure Services

- **Consul**: Service discovery and configuration
- **SQL Server**: Primary database (StatefulSet)
- **RabbitMQ**: Message broker (StatefulSet)
- **MailHog**: Email testing (dev/staging only)

## 🚀 Quick Start

### 1. Prerequisites

```bash
# Install required tools
brew install google-cloud-sdk kubectl terraform helm

# Or on Linux
curl https://sdk.cloud.google.com | bash
```

### 2. Deploy Infrastructure

```bash
# Clone repository
git clone https://github.com/your-org/konectaerp.git
cd konectaerp/infrastructure

# Configure GCP
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Deploy GKE cluster
cd terraform/gke
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings
terraform init
terraform apply

# Deploy Artifact Registry
cd ../artifact-registry
terraform init
terraform apply
```

### 3. Deploy Application

```bash
# Get cluster credentials
gcloud container clusters get-credentials konecta-erp-cluster \
  --region us-central1

# Install Consul
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install consul hashicorp/consul \
  -f helm/consul/custom-values.yaml

# Deploy application (dev environment)
kubectl apply -k kubernetes/overlays/dev/

# Check status
kubectl get pods
kubectl get ingress
```

## 📁 Directory Structure

```
infrastructure/
├── kubernetes/
│   ├── base/                    # Base Kubernetes manifests
│   │   ├── sqlserver/          # SQL Server StatefulSet
│   │   ├── rabbitmq/           # RabbitMQ StatefulSet
│   │   ├── config-server/      # Spring Config Server
│   │   ├── api-gateway/        # API Gateway
│   │   ├── *-service/          # Microservices
│   │   ├── frontend/           # Angular frontend
│   │   └── networking/         # Ingress & certificates
│   └── overlays/               # Environment-specific configs
│       ├── dev/                # Development (1 replica, low resources)
│       ├── staging/            # Staging (2 replicas, medium resources)
│       └── prod/               # Production (3+ replicas, high resources)
├── helm/
│   └── consul/                 # Consul Helm values
├── terraform/
│   ├── gke/                    # GKE cluster
│   ├── artifact-registry/      # Docker registry
│   ├── networking/             # Load balancer, firewall
│   └── secrets/                # Secret Manager
└── ci-cd/
    ├── cloudbuild.yaml         # Cloud Build pipeline
    └── github-actions/         # GitHub Actions workflows
```

## 🌍 Environments

| Environment    | Replicas | Resources              | Domain              | Purpose                   |
| -------------- | -------- | ---------------------- | ------------------- | ------------------------- |
| **Dev**        | 1        | 256Mi / 100m CPU       | dev.konecta.local   | Development & testing     |
| **Staging**    | 2        | 512Mi / 250m CPU       | staging.konecta.com | Pre-production validation |
| **Production** | 3-20     | 1-2Gi / 500m-1000m CPU | konecta.com         | Live production           |

## 🔧 Configuration

### Scaling

**Horizontal Pod Autoscaler (HPA):**

- Automatically scales based on CPU/memory
- Min replicas: 2 (dev: 1, prod: 3)
- Max replicas: 10 (prod: 20)

**Vertical Pod Autoscaler (VPA):**

- Available but not enabled by default
- Can be enabled per deployment

### Resource Allocation

**Development:**

```yaml
resources:
  requests: { memory: "256Mi", cpu: "100m" }
  limits: { memory: "512Mi", cpu: "250m" }
```

**Production:**

```yaml
resources:
  requests: { memory: "1Gi", cpu: "500m" }
  limits: { memory: "2Gi", cpu: "1000m" }
```

## 📊 Monitoring & Observability

### Built-in Monitoring

- **GKE Monitoring**: Automatic metrics collection
- **Cloud Logging**: Centralized log aggregation
- **Prometheus**: Metrics scraping (via GKE)

### Access Logs

```bash
# Application logs
kubectl logs -l app=api-gateway --tail=100 -f

# Consul logs
kubectl logs -l app=consul

# Database logs
kubectl logs sqlserver-0
```

### Metrics

```bash
# Resource usage
kubectl top nodes
kubectl top pods

# HPA status
kubectl get hpa
```

## 🔐 Security

### Network Security

- Private GKE nodes
- Network policies enabled
- Cloud NAT for outbound traffic
- Ingress with TLS/SSL

### Authentication & Authorization

- Workload Identity for GCP services
- RBAC for Kubernetes access
- JWT authentication for APIs
- Service-to-service mTLS (optional with Consul Connect)

### Secrets Management

- Kubernetes Secrets (base64)
- Google Secret Manager integration
- Sealed Secrets support

## 🔄 CI/CD

### Automated Pipelines

**Cloud Build:**

- Triggered on git push
- Builds all Docker images in parallel
- Pushes to Artifact Registry
- Deploys to appropriate environment

**GitHub Actions:**

- Build workflow on PR
- Deploy workflow on merge
- Environment-based deployments

### Manual Deployment

```bash
# Build and push single service
docker build -t us-central1-docker.pkg.dev/PROJECT/konecta-erp/api-gateway:v1.0.0 \
  -f konecta_erp/backend/ApiGateWay/Dockerfile konecta_erp/backend/ApiGateWay
docker push us-central1-docker.pkg.dev/PROJECT/konecta-erp/api-gateway:v1.0.0

# Update deployment
kubectl set image deployment/api-gateway \
  api-gateway=us-central1-docker.pkg.dev/PROJECT/konecta-erp/api-gateway:v1.0.0
```

## 🐛 Troubleshooting

See detailed troubleshooting guides:

- [Kubernetes README](kubernetes/README.md)
- [CI/CD README](ci-cd/README.md)

## 📚 Documentation

- [Kubernetes Deployment Guide](kubernetes/README.md)
- [CI/CD Pipeline Guide](ci-cd/README.md)
- [Terraform Modules](terraform/)

## 🤝 Contributing

1. Create feature branch
2. Make changes
3. Test in dev environment
4. Create pull request
5. Deploy to staging for QA
6. Merge to main for production

## 📄 License

Copyright © 2024 Konecta ERP
