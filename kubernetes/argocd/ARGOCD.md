# ArgoCD for Konecta ERP

This guide explains how to use ArgoCD for GitOps-based continuous delivery of the Konecta ERP application.

## Overview

ArgoCD is configured using the **App of Apps** pattern, where a root application manages environment-specific applications for dev, staging, and production.

### Architecture

```
Root App (konecta-erp-root)
├── Dev Application (dev-konecta-erp) → develop branch → overlays/dev
├── Staging Application (staging-konecta-erp) → staging branch → overlays/staging
└── Prod Application (prod-konecta-erp) → main branch → overlays/prod
```

### Sync Policies

- **Dev**: Automated sync with self-heal and prune enabled
- **Staging**: Automated sync with self-heal and prune enabled
- **Production**: Manual sync (requires approval)

### Deployment Order (Sync Waves)

ArgoCD deploys resources in the following order:

1. **Wave 0**: Infrastructure (SQL Server, RabbitMQ, seed jobs)
2. **Wave 1**: Config Server
3. **Wave 2**: Application services (API Gateway, Auth, HR, Inventory, Finance, User Management, Reporting)
4. **Wave 3**: Frontend and Ingress

## Installation

### Option 1: GitHub Actions (Recommended)

1. Navigate to **Actions** → **Install ArgoCD** workflow
2. Click **Run workflow**
3. Select environment (dev/staging/prod)
4. Click **Run workflow**

The workflow will:

- Install ArgoCD in the cluster
- Configure environment-specific service exposure
- Provide access credentials in the workflow summary

### Option 2: Manual Installation

```bash
# Get cluster credentials
gcloud container clusters get-credentials konecta-erp-cluster \
  --region us-central1 \
  --project YOUR_PROJECT_ID

# Install ArgoCD for dev environment
kubectl apply -k kubernetes/overlays/dev

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

# Get admin password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

## Accessing ArgoCD UI

### Development Environment (NodePort)

```bash
# Port-forward to ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at https://localhost:8080
# Username: admin
# Password: (from installation step)
```

### Staging/Production (LoadBalancer)

```bash
# Get external IP
kubectl get svc argocd-server -n argocd

# Access at https://<EXTERNAL_IP>
# Username: admin
# Password: (from installation step)
```

> [!IMPORTANT]
> Change the default admin password after first login:
>
> ```bash
> argocd account update-password
> ```

## Configuring Repository Access

ArgoCD needs access to this repository to sync applications.

### HTTPS with Token (Recommended)

1. Create a GitHub Personal Access Token with `repo` scope
2. In ArgoCD UI: **Settings** → **Repositories** → **Connect Repo**
3. Enter:
   - **Repository URL**: `https://github.com/konecta-org/konectaerp-infra.git`
   - **Username**: your GitHub username
   - **Password**: your GitHub token
4. Click **Connect**

### SSH Key

1. Generate SSH key: `ssh-keygen -t ed25519 -C "argocd@konecta"`
2. Add public key to GitHub repository deploy keys
3. In ArgoCD UI: **Settings** → **Repositories** → **Connect Repo**
4. Enter:
   - **Repository URL**: `git@github.com:konecta-org/konectaerp-infra.git`
   - **SSH Private Key**: paste private key
5. Click **Connect**

## Deploying Applications

### Initial Setup

After installing ArgoCD and configuring repository access:

```bash
# Apply the root App of Apps
kubectl apply -f kubernetes/argocd/applications/root-app.yaml

# This will automatically create all environment applications
```

### Via GitHub Actions (Automated)

Push to the appropriate branch:

- `develop` → triggers dev deployment
- `staging` → triggers staging deployment
- `main` → triggers prod deployment (manual sync required in ArgoCD)

The GitHub Actions workflow will:

1. Check if ArgoCD is installed
2. If yes: Use ArgoCD CLI to sync the application
3. If no: Fall back to `kubectl apply`

### Via ArgoCD UI (Manual)

1. Navigate to the application (e.g., `dev-konecta-erp`)
2. Click **Sync**
3. Review changes
4. Click **Synchronize**

### Via ArgoCD CLI

```bash
# Install ArgoCD CLI
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd /usr/local/bin/argocd

# Login
argocd login <ARGOCD_SERVER> --username admin

# Sync application
argocd app sync dev-konecta-erp

# Wait for sync to complete
argocd app wait dev-konecta-erp
```

## Managing Applications

### View Application Status

```bash
# List all applications
argocd app list

# Get detailed status
argocd app get dev-konecta-erp

# View sync history
argocd app history dev-konecta-erp
```

### Rollback to Previous Version

#### Via UI

1. Navigate to application
2. Click **History**
3. Select previous revision
4. Click **Rollback**

#### Via CLI

```bash
# List history
argocd app history dev-konecta-erp

# Rollback to specific revision
argocd app rollback dev-konecta-erp <REVISION_ID>
```

### Refresh Application

Force ArgoCD to check for changes:

```bash
argocd app get dev-konecta-erp --refresh
```

### Delete Application

```bash
# Delete application (keeps resources in cluster)
argocd app delete dev-konecta-erp

# Delete application and all resources
argocd app delete dev-konecta-erp --cascade
```

## Troubleshooting

### Application Stuck in "Progressing"

```bash
# Check sync status
argocd app get dev-konecta-erp

# View logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Force sync
argocd app sync dev-konecta-erp --force
```

### Sync Fails with "OutOfSync"

This usually means manual changes were made to the cluster:

```bash
# View differences
argocd app diff dev-konecta-erp

# Option 1: Sync to match git (recommended)
argocd app sync dev-konecta-erp --prune

# Option 2: Ignore differences (not recommended)
# Edit application and add ignoreDifferences in spec
```

### Repository Connection Issues

```bash
# Test repository connection
argocd repo list

# Re-add repository
argocd repo add https://github.com/konecta-org/konectaerp-infra.git \
  --username <USERNAME> \
  --password <TOKEN>
```

### ArgoCD Server Not Accessible

```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Check service
kubectl get svc argocd-server -n argocd

# View logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Restart ArgoCD server
kubectl rollout restart deployment argocd-server -n argocd
```

## Best Practices

### 1. Use Specific Image Tags in Production

The prod overlay uses versioned tags (`v1.0.0`) instead of `latest`. Update these in `kubernetes/overlays/prod/kustomization.yaml`:

```yaml
images:
  - name: us-central1-docker.pkg.dev/PROJECT/konecta-erp/api-gateway
    newTag: v1.2.0 # Update this
```

### 2. Review Changes Before Syncing Production

Always review the diff in ArgoCD UI before syncing production:

1. Navigate to `prod-konecta-erp`
2. Click **App Diff**
3. Review all changes
4. Click **Sync** only if changes are expected

### 3. Use Sync Waves for Dependencies

Resources are already configured with sync waves. If adding new resources with dependencies, add the annotation:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"
```

### 4. Monitor Application Health

Set up notifications for sync failures:

1. In ArgoCD UI: **Settings** → **Notifications**
2. Configure Slack/email notifications
3. Subscribe to `on-sync-failed` events

### 5. Regular Backups

Backup ArgoCD configuration:

```bash
# Export all applications
argocd app list -o yaml > argocd-apps-backup.yaml

# Export all repositories
argocd repo list -o yaml > argocd-repos-backup.yaml
```

## ArgoCD Image Updater

ArgoCD Image Updater is a tool that automatically checks container registries for new image versions and updates ArgoCD applications accordingly. It's integrated into the Konecta ERP setup to enable automated deployments for dev and staging environments.

### How It Works

Image Updater runs as a controller in the `argocd` namespace and:

1. **Monitors** container registries for new image tags
2. **Evaluates** tags against configured update strategies
3. **Updates** Kustomize image tags in Git when new versions are found
4. **Commits** changes back to the repository
5. **Triggers** ArgoCD to sync the updated application

### Configuration Overview

Image Updater is configured via annotations on ArgoCD Application resources:

- **Dev environment**: Auto-updates to latest tags matching `dev-*` pattern
- **Staging environment**: Auto-updates to semantic version tags (e.g., `v1.2.3`)
- **Production environment**: No auto-updates (manual control)

### Verifying Installation

```bash
# Check Image Updater pod status
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-image-updater

# View Image Updater logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater --tail=50

# Check Image Updater version
kubectl get deployment argocd-image-updater -n argocd -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### Update Strategies

#### Latest Tag Strategy (Dev)

Updates to the most recent tag matching a pattern:

```yaml
annotations:
  argocd-image-updater.argoproj.io/myimage.update-strategy: latest
  argocd-image-updater.argoproj.io/myimage.allow-tags: regexp:^dev-.*
```

#### Semantic Versioning Strategy (Staging)

Updates to the highest semantic version:

```yaml
annotations:
  argocd-image-updater.argoproj.io/myimage.update-strategy: semver
  argocd-image-updater.argoproj.io/myimage.allow-tags: regexp:^v[0-9]+\.[0-9]+\.[0-9]+$
```

### Enabling/Disabling Auto-Updates

#### Enable for an Application

Add annotations to the Application manifest:

```yaml
metadata:
  annotations:
    argocd-image-updater.argoproj.io/image-list: |
      myimage=us-central1-docker.pkg.dev/PROJECT/REPO/IMAGE
    argocd-image-updater.argoproj.io/myimage.update-strategy: latest
    argocd-image-updater.argoproj.io/write-back-method: git
```

#### Disable for an Application

Remove all `argocd-image-updater.argoproj.io/*` annotations from the Application.

#### Temporarily Pause Updates

Add this annotation to pause without removing configuration:

```yaml
metadata:
  annotations:
    argocd-image-updater.argoproj.io/update-strategy: pause
```

### Git Write-Back Configuration

Image Updater commits changes back to Git. Ensure proper authentication:

#### Using HTTPS with Token

Image Updater uses the same repository credentials configured in ArgoCD. No additional setup needed if ArgoCD can already access the repository.

#### Commit Author Configuration

The commit author is configured in `image-updater-config.yaml`:

```yaml
data:
  git.user: argocd-image-updater
  git.email: argocd-image-updater@konecta-erp.local
```

### Registry Authentication

For GCP Artifact Registry, Image Updater uses Workload Identity or service account credentials.

#### Verify Registry Access

```bash
# Check if Image Updater can list images
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater | grep "registry"
```

#### Configure Additional Registries

Edit the `argocd-image-updater-config` ConfigMap:

```bash
kubectl edit configmap argocd-image-updater-config -n argocd
```

Add registry configuration:

```yaml
data:
  registries.conf: |
    registries:
    - name: gcr
      prefix: us-central1-docker.pkg.dev
      api_url: https://us-central1-docker.pkg.dev
      credentials: ext:/scripts/auth1.sh
      default: true
```

### Monitoring Image Updates

#### View Update History

Check Git commits for image updates:

```bash
# View recent commits on develop branch
git log --oneline develop | grep "image update"

# View specific commit details
git show <commit-hash>
```

#### Check Application Status

```bash
# List applications with their image versions
argocd app get dev-konecta-erp -o yaml | grep "newTag:"
```

#### Image Updater Logs

```bash
# Follow Image Updater logs in real-time
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater -f

# Search for specific image updates
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater | grep "api-gateway"
```

### Troubleshooting Image Updater

#### No Updates Happening

**Check 1: Verify annotations are correct**

```bash
kubectl get application dev-konecta-erp -n argocd -o yaml | grep "argocd-image-updater"
```

**Check 2: Verify Image Updater is running**

```bash
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-image-updater
```

**Check 3: Check logs for errors**

```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater --tail=100
```

#### Authentication Errors

If you see `401 Unauthorized` or `403 Forbidden` errors:

```bash
# Check if Workload Identity is configured
kubectl describe serviceaccount argocd-image-updater -n argocd

# Verify GCP permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:argocd-image-updater*"
```

#### Git Write-Back Failures

If Image Updater can't commit to Git:

```bash
# Check repository credentials
argocd repo list

# Verify repository has write access
# The token/credentials must have write permissions
```

**Solution**: Update repository credentials with a token that has write access:

```bash
argocd repo add https://github.com/konecta-org/konectaerp-infra.git \
  --username <USERNAME> \
  --password <TOKEN_WITH_WRITE_ACCESS>
```

#### Image Not Found Errors

If Image Updater reports images not found:

```bash
# Verify image exists in registry
gcloud artifacts docker images list \
  us-central1-docker.pkg.dev/PROJECT_ID/konecta-erp

# Check if tag pattern matches
gcloud artifacts docker tags list \
  us-central1-docker.pkg.dev/PROJECT_ID/konecta-erp/api-gateway
```

#### Incorrect Tag Selected

If Image Updater selects the wrong tag:

1. Review the `allow-tags` pattern in annotations
2. Check available tags match your pattern:

```bash
gcloud artifacts docker tags list \
  us-central1-docker.pkg.dev/PROJECT_ID/konecta-erp/IMAGE_NAME
```

3. Adjust the regex pattern if needed

### Advanced Configuration

#### Custom Update Interval

Default is 2 minutes. To change:

```bash
kubectl edit configmap argocd-image-updater-config -n argocd
```

Update the `interval` field:

```yaml
data:
  interval: 5m # Check every 5 minutes
```

#### Ignore Tags Pattern

Exclude specific tags from consideration:

```yaml
annotations:
  argocd-image-updater.argoproj.io/myimage.ignore-tags: regexp:^.*-rc.*
```

#### Force Update

Manually trigger an update check:

```bash
# Restart Image Updater to force immediate check
kubectl rollout restart deployment argocd-image-updater -n argocd
```

### Best Practices

1. **Use specific tag patterns**: Avoid overly broad patterns that might match unexpected tags
2. **Test in dev first**: Verify update strategies work correctly in dev before enabling in staging
3. **Monitor Git commits**: Regularly review automated commits to ensure expected behavior
4. **Set up notifications**: Configure alerts for failed updates
5. **Document tag conventions**: Ensure your CI/CD pipeline creates tags that match your patterns

## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
