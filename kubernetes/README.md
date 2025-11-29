# Konecta ERP - Kubernetes Infrastructure

This directory contains the complete Kubernetes infrastructure for deploying Konecta ERP on Google Kubernetes Engine (GKE).

## 📁 Directory Structure

```
infrastructure/
├── kubernetes/          # Kubernetes manifests
│   ├── base/           # Base manifests for all services
│   └── overlays/       # Environment-specific overlays
│       ├── dev/        # Development environment
│       ├── staging/    # Staging environment
│       └── prod/       # Production environment
├── helm/               # Helm charts
│   └── consul/         # Consul configuration
├── terraform/          # Infrastructure as Code
│   ├── gke/           # GKE cluster
│   ├── artifact-registry/  # Docker registry
│   ├── networking/    # Load balancer, firewall
│   └── secrets/       # Secret Manager
└── ci-cd/             # CI/CD pipelines
    ├── cloudbuild.yaml
    └── github-actions/
```

## 🚀 Quick Start

### Prerequisites

- GCP account with billing enabled
- `gcloud` CLI installed and authenticated
- `kubectl` installed
- `terraform` >= 1.5.0
- `helm` >= 3.0

### 1. Deploy Infrastructure with Terraform

```bash
# Navigate to GKE terraform directory
cd infrastructure/terraform/gke

# Copy and edit terraform.tfvars
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your GCP project ID and settings

# Initialize and apply
terraform init
terraform apply

# Get kubectl credentials
gcloud container clusters get-credentials konecta-erp-cluster \
  --region us-central1 \
  --project erp-system-478020
```

### 2. Deploy Artifact Registry

```bash
cd ../artifact-registry
cp ../gke/terraform.tfvars .
terraform init
terraform apply
```

### 3. Install Consul with Helm

```bash
# Add Hashicorp Helm repository
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Install Consul
helm install consul hashicorp/consul \
  -f infrastructure/helm/consul/custom-values.yaml \
  --namespace default

# Wait for Consul to be ready
kubectl wait --for=condition=ready pod -l app=consul --timeout=5m
```

### 4. Build and Push Docker Images

```bash
# Set your Artifact Registry URL
export ARTIFACT_REGISTRY_URL="us-central1-docker.pkg.dev/erp-system-478020/konecta-erp"

# Configure Docker
gcloud auth configure-docker us-central1-docker.pkg.dev

# Build and push all images (example for one service)
cd konecta_erp
docker build -t ${ARTIFACT_REGISTRY_URL}/authentication-service:latest \
  -f backend/AuthenticationService/Dockerfile .
docker push ${ARTIFACT_REGISTRY_URL}/authentication-service:latest

docker build -t ${ARTIFACT_REGISTRY_URL}/hr-service:latest \
  -f backend/HrService/Dockerfile .
docker push ${ARTIFACT_REGISTRY_URL}/hr-service:latest

docker build -t ${ARTIFACT_REGISTRY_URL}/inventory-service:latest \
  -f backend/InventoryService/Dockerfile .
docker push ${ARTIFACT_REGISTRY_URL}/inventory-service:latest

docker build -t ${ARTIFACT_REGISTRY_URL}/finance-service:latest \
  -f backend/FinanceService/Dockerfile .
docker push ${ARTIFACT_REGISTRY_URL}/finance-service:latest

docker build -t ${ARTIFACT_REGISTRY_URL}/user-management-service:latest \
  -f backend/UserManagementService/Dockerfile .
docker push ${ARTIFACT_REGISTRY_URL}/user-management-service:latest

docker build -t ${ARTIFACT_REGISTRY_URL}/reporting-service:latest \
  -f backend/ReportingService/Dockerfile backend/ReportingService/
docker push ${ARTIFACT_REGISTRY_URL}/reporting-service:latest

docker build -t ${ARTIFACT_REGISTRY_URL}/config-server:latest \
  -f backend/config/Dockerfile backend/config
docker push ${ARTIFACT_REGISTRY_URL}/config-server:latest

docker build -t ${ARTIFACT_REGISTRY_URL}/api-gateway:latest \
  -f backend/ApiGateWay/Dockerfile backend/ApiGateWay/
docker push ${ARTIFACT_REGISTRY_URL}/api-gateway:latest

docker build -t ${ARTIFACT_REGISTRY_URL}/frontend:latest \
  -f frontend/Dockerfile frontend
docker push ${ARTIFACT_REGISTRY_URL}/frontend:latest



docker build -t ${ARTIFACT_REGISTRY_URL}/authentication-service:dev-latest \
  -f backend/AuthenticationService/Dockerfile .
docker push ${ARTIFACT_REGISTRY_URL}/authentication-service:dev-latest

docker build -t ${ARTIFACT_REGISTRY_URL}/hr-service:dev-latest \
  -f backend/HrService/Dockerfile .
docker push ${ARTIFACT_REGISTRY_URL}/hr-service:dev-latest

docker build -t ${ARTIFACT_REGISTRY_URL}/inventory-service:dev-latest \
  -f backend/InventoryService/Dockerfile .
docker push ${ARTIFACT_REGISTRY_URL}/inventory-service:dev-latest

docker build -t ${ARTIFACT_REGISTRY_URL}/finance-service:dev-latest \
  -f backend/FinanceService/Dockerfile .
docker push ${ARTIFACT_REGISTRY_URL}/finance-service:dev-latest

docker build -t ${ARTIFACT_REGISTRY_URL}/user-management-service:dev-latest \
  -f backend/UserManagementService/Dockerfile .
docker push ${ARTIFACT_REGISTRY_URL}/user-management-service:dev-latest

docker build -t ${ARTIFACT_REGISTRY_URL}/reporting-service:dev-latest \
  -f backend/ReportingService/Dockerfile backend/ReportingService/
docker push ${ARTIFACT_REGISTRY_URL}/reporting-service:dev-latest

docker build -t ${ARTIFACT_REGISTRY_URL}/config-server:dev-latest \
  -f backend/config/Dockerfile backend/config
docker push ${ARTIFACT_REGISTRY_URL}/config-server:dev-latest

docker build -t ${ARTIFACT_REGISTRY_URL}/api-gateway:dev-latest \
  -f backend/ApiGateWay/Dockerfile backend/ApiGateWay/
docker push ${ARTIFACT_REGISTRY_URL}/api-gateway:dev-latest

docker build -t ${ARTIFACT_REGISTRY_URL}/frontend:dev-latest \
  -f frontend/Dockerfile frontend
docker push ${ARTIFACT_REGISTRY_URL}/frontend:dev-latest


# Repeat for all services or use the CI/CD pipeline
```

### 5. Deploy Application to Kubernetes

```bash
# Update image URLs in manifests
export ARTIFACT_REGISTRY_URL="us-central1-docker.pkg.dev/erp-system-478020/konecta-erp"

# For dev environment
kubectl apply -k infrastructure/kubernetes/overlays/dev/

# Wait for deployments
kubectl rollout status deployment/api-gateway
kubectl rollout status deployment/authentication-service
kubectl rollout status deployment/frontend

# Check status
kubectl get pods
kubectl get svc
kubectl get ingress
```

### 6. Access the Application

```bash
# Get the Ingress IP
kubectl get ingress konecta-erp-ingress

# Access the application
# Frontend: http://<INGRESS_IP>
# API Gateway: http://<INGRESS_IP>/api
# Consul UI: kubectl port-forward svc/consul-ui 8500:80
```

## 🔧 Configuration

### Environment Variables

Each environment (dev/staging/prod) has different configurations:

**Dev:**

- 1 replica per service
- Lower resource limits (256Mi RAM, 100m CPU)
- MailHog enabled for email testing

**Staging:**

- 2 replicas per service
- Moderate resources (512Mi RAM, 250m CPU)
- MailHog enabled

**Production:**

- 3+ replicas per service
- Higher resources (1-2Gi RAM, 500m-1000m CPU)
- MailHog disabled (use real SMTP)
- Versioned image tags (not latest)

### Secrets Management

Secrets are currently base64-encoded in Kubernetes Secrets. For production:

1. **Option 1: Google Secret Manager** (Recommended)

   ```bash
   cd infrastructure/terraform/secrets
   terraform init
   terraform apply
   ```

2. **Option 2: Sealed Secrets**
   ```bash
   kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
   ```

### Scaling

**Manual Scaling:**

```bash
kubectl scale deployment api-gateway --replicas=5
```

**Auto-scaling:**
HPAs are configured for all services. Adjust in overlays:

```yaml
spec:
  minReplicas: 2
  maxReplicas: 10
```

## 📊 Monitoring

### View Logs

```bash
# All pods
kubectl logs -l app=api-gateway --tail=100 -f

# Specific pod
kubectl logs <pod-name> -f
```

### Check Resource Usage

```bash
kubectl top nodes
kubectl top pods
```

### Consul UI

```bash
kubectl port-forward svc/consul-ui 8500:80
# Access at http://localhost:8500
```

### Prometheus and Grafana

**Prometheus** collects metrics from all services and Kubernetes components.

**Grafana** provides visualization dashboards for monitoring.

#### Access Prometheus (Dev Environment)

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Access at http://localhost:9090

# Check targets status
# Navigate to Status > Targets to see all monitored services
```

#### Access Grafana (Dev Environment)

```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Access at http://localhost:3000

# Default credentials:
# Username: admin
# Password: admin
# (You'll be prompted to change on first login)
```

#### Access Monitoring (Staging/Prod)

For staging and production environments, Prometheus and Grafana are exposed via LoadBalancer:

```bash
# Get external IPs
kubectl get svc -n monitoring

# Access Prometheus at http://<PROMETHEUS_EXTERNAL_IP>:9090
# Access Grafana at http://<GRAFANA_EXTERNAL_IP>:3000
```

#### Pre-configured Dashboards

Grafana comes with pre-configured dashboards:

1. **Kubernetes Cluster Overview** - Node CPU/memory, pod counts, container restarts
2. **Konecta ERP Services** - Service availability, HTTP request rates, error rates, response times

#### Adding Metrics to Your Services

To enable Prometheus scraping for your .NET services, add these annotations to your deployment pods:

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "80"
    prometheus.io/path: "/metrics"
```

For .NET applications, use the `prometheus-net` library to expose metrics.

## 🔄 Updates and Rollbacks

### Rolling Update

```bash
# Update image
kubectl set image deployment/api-gateway \
  api-gateway=${ARTIFACT_REGISTRY_URL}/api-gateway:v1.1.0

# Check rollout status
kubectl rollout status deployment/api-gateway
```

### Rollback

```bash
kubectl rollout undo deployment/api-gateway
kubectl rollout undo deployment/api-gateway --to-revision=2
```

## 🐛 Troubleshooting

### Pods not starting

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Database connection issues

```bash
# Check SQL Server is running
kubectl get pods -l app=sqlserver

# Check seed job completed
kubectl get jobs

# Test connection
kubectl exec -it sqlserver-0 -- /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P 'pa55w0rd!' -C -Q "SELECT 1"
```

### Service discovery issues

```bash
# Check Consul
kubectl get pods -l app=consul
kubectl logs -l app=consul

# Check DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup api-gateway
```

### Ingress not working

```bash
# Check ingress status
kubectl describe ingress konecta-erp-ingress

# Check backend health
kubectl get ingress konecta-erp-ingress -o yaml
```

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Kustomize Documentation](https://kustomize.io/)
- [Consul on Kubernetes](https://developer.hashicorp.com/consul/docs/k8s)

## 🔐 Security Best Practices

1. **Use Workload Identity** for GCP service authentication
2. **Enable Binary Authorization** for image verification
3. **Use Network Policies** to restrict pod-to-pod communication
4. **Rotate secrets regularly** using Secret Manager
5. **Enable audit logging** for compliance
6. **Use private GKE clusters** for production
7. **Implement RBAC** for user access control

## 📝 License

Copyright © 2024 Konecta ERP
