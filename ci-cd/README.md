# CI/CD Pipelines for Konecta ERP

This directory contains CI/CD pipeline configurations for automated building and deployment of Konecta ERP to GKE.

## 🔧 Available Pipelines

### 1. Google Cloud Build (`cloudbuild.yaml`)

Cloud Build pipeline for GCP-native CI/CD.

**Features:**

- Parallel Docker image builds
- Automatic push to Artifact Registry
- Environment-based deployment (dev/staging/prod)
- Rollout verification

**Setup:**

```bash
# Enable Cloud Build API
gcloud services enable cloudbuild.googleapis.com

# Grant Cloud Build permissions
PROJECT_ID=$(gcloud config get-value project)
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
  --role=roles/container.developer

# Create trigger
gcloud builds triggers create github \
  --repo-name=konectaerp \
  --repo-owner=YOUR_GITHUB_ORG \
  --branch-pattern="^main$" \
  --build-config=infrastructure/ci-cd/cloudbuild.yaml \
  --substitutions=_ENV=prod,_REGION=us-central1,_CLUSTER_NAME=konecta-erp-cluster
```

**Manual Trigger:**

```bash
gcloud builds submit \
  --config=infrastructure/ci-cd/cloudbuild.yaml \
  --substitutions=_ENV=dev
```

### 2. GitHub Actions

Two workflows for build and deployment.

**Setup:**

1. **Configure Workload Identity Federation** (Recommended)

```bash
# Create Workload Identity Pool
gcloud iam workload-identity-pools create "github-pool" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# Create Workload Identity Provider
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Create Service Account
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions Service Account"

# Grant permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/container.developer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

# Allow GitHub to impersonate service account
gcloud iam service-accounts add-iam-policy-binding \
  github-actions@${PROJECT_ID}.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/attribute.repository/YOUR_ORG/konectaerp"
```

2. **Add GitHub Secrets**

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add the following secrets:

- `GCP_PROJECT_ID`: Your GCP project ID
- `WIF_PROVIDER`: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider`
- `WIF_SERVICE_ACCOUNT`: `github-actions@PROJECT_ID.iam.gserviceaccount.com`

3. **Workflows**

- **`build.yml`**: Builds and pushes Docker images on every push/PR
- **`deploy.yml`**: Deploys to GKE on push to main/staging/develop

## 🌍 Environment Strategy

| Branch    | Environment | Overlay   | Image Tag            |
| --------- | ----------- | --------- | -------------------- |
| `develop` | Development | `dev`     | `dev-latest`         |
| `staging` | Staging     | `staging` | `staging-latest`     |
| `main`    | Production  | `prod`    | `v1.0.0` (versioned) |

## 🔄 Workflow

### Development Flow

```
1. Developer pushes to feature branch
   ↓
2. Create PR to develop
   ↓
3. GitHub Actions builds images (build.yml)
   ↓
4. Merge to develop
   ↓
5. GitHub Actions deploys to dev environment (deploy.yml)
```

### Production Flow

```
1. Merge develop to staging
   ↓
2. GitHub Actions deploys to staging
   ↓
3. QA testing on staging
   ↓
4. Merge staging to main
   ↓
5. GitHub Actions deploys to production
```

## 📋 Pipeline Steps

### Build Pipeline

1. **Checkout code**
2. **Authenticate to GCP**
3. **Build Docker images** (parallel)
   - config-server
   - api-gateway
   - authentication-service
   - hr-service
   - inventory-service
   - finance-service
   - user-management-service
   - reporting-service
   - frontend
4. **Push to Artifact Registry**
5. **Tag with commit SHA and environment**

### Deploy Pipeline

1. **Checkout code**
2. **Authenticate to GCP**
3. **Get GKE credentials**
4. **Determine environment** (based on branch)
5. **Apply Kustomize overlay**
6. **Wait for rollout**
7. **Verify deployment**
8. **Output ingress IP**

## 🔍 Monitoring Pipelines

### Cloud Build

```bash
# List recent builds
gcloud builds list --limit=10

# View build logs
gcloud builds log <BUILD_ID>

# View build in console
https://console.cloud.google.com/cloud-build/builds
```

### GitHub Actions

View in GitHub:

- Repository → Actions tab
- Click on workflow run for details
- View logs for each job

## 🐛 Troubleshooting

### Build Failures

**Docker build fails:**

```bash
# Test locally
docker build -f konecta_erp/backend/AuthenticationService/Dockerfile konecta_erp
```

**Permission denied:**

```bash
# Check service account permissions
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:github-actions@*"
```

### Deployment Failures

**kubectl connection issues:**

```bash
# Verify cluster exists
gcloud container clusters list

# Get credentials manually
gcloud container clusters get-credentials konecta-erp-cluster \
  --region us-central1
```

**Rollout timeout:**

```bash
# Check pod status
kubectl get pods
kubectl describe pod <pod-name>

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

## 🔐 Security Best Practices

1. **Use Workload Identity Federation** instead of service account keys
2. **Scan images** for vulnerabilities (enabled in Artifact Registry)
3. **Use least privilege** for service accounts
4. **Rotate credentials** regularly
5. **Enable audit logging** for builds
6. **Use signed commits** for production deployments

## 📊 Metrics and Monitoring

### Cloud Build Metrics

- Build duration
- Success/failure rate
- Resource usage

### Deployment Metrics

- Deployment frequency
- Lead time for changes
- Mean time to recovery (MTTR)
- Change failure rate

## 🚀 Advanced Features

### Blue/Green Deployments

```yaml
# In kustomization.yaml
nameSuffix: -blue

# Deploy blue version
kubectl apply -k overlays/prod/

# Switch traffic
kubectl patch svc api-gateway -p '{"spec":{"selector":{"version":"blue"}}}'
```

### Canary Deployments

Use Flagger or Argo Rollouts for progressive delivery.

### Multi-Region Deployments

Deploy to multiple GKE clusters:

```bash
# Deploy to us-central1
gcloud container clusters get-credentials konecta-erp-us-central1 --region us-central1
kubectl apply -k overlays/prod/

# Deploy to europe-west1
gcloud container clusters get-credentials konecta-erp-europe-west1 --region europe-west1
kubectl apply -k overlays/prod/
```

## 📚 Additional Resources

- [Cloud Build Documentation](https://cloud.google.com/build/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [Kustomize Best Practices](https://kubectl.docs.kubernetes.io/guides/config_management/)
