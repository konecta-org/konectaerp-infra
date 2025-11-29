# Complete Fix: Prometheus & Grafana Permission Issues

If you encountered permission errors for Prometheus or Grafana:

**Prometheus Error:**

```
Error opening query log file: open /prometheus/queries.active: permission denied
```

**Grafana Error:**

```
mkdir: can't create directory '/var/lib/grafana/plugins': Permission denied
```

## Solution

Both deployments have been updated to fix these issues. Follow these steps:

### 1. Delete Existing Monitoring Resources

```bash
# Delete both deployments
kubectl delete deployment prometheus -n monitoring
kubectl delete deployment grafana -n monitoring

# Delete the PVCs (this removes volumes with wrong permissions)
kubectl delete pvc prometheus-storage -n monitoring
kubectl delete pvc grafana-storage -n monitoring
```

### 2. Redeploy with Fixed Configuration

```bash
# Reapply the configuration
kubectl apply -k infrastructure/kubernetes/overlays/dev/

# Wait for both to be ready
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=5m
kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=5m
```

### 3. Verify Everything is Working

```bash
# Check pod status
kubectl get pods -n monitoring

# Check Prometheus logs (should not show permission errors)
kubectl logs -n monitoring -l app=prometheus --tail=30

# Check Grafana logs (should not show permission errors)
kubectl logs -n monitoring -l app=grafana --tail=30

# Access Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open http://localhost:9090

# Access Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Open http://localhost:3000 (admin/admin)
```

## What Was Fixed

### Prometheus

- **Security Context**: Runs as `nobody` user (UID 65534) with proper fsGroup
- **Init Container**: Sets correct ownership of `/prometheus` directory
- **User**: Prometheus default user is 65534 (nobody)

```yaml
securityContext:
  fsGroup: 65534 # nobody group
  runAsUser: 65534 # nobody user
  runAsNonRoot: true

initContainers:
  - name: init-chown-data
    image: busybox:latest
    command: ["sh", "-c", "chown -R 65534:65534 /prometheus"]
    securityContext:
      runAsUser: 0 # Needs root to change ownership
```

### Grafana

- **Security Context**: Runs as Grafana user (UID 472) with proper fsGroup
- **Init Container**: Sets correct ownership of `/var/lib/grafana` directory
- **Explicit Paths**: Environment variables for all Grafana directories

```yaml
securityContext:
  fsGroup: 472 # Grafana group
  runAsUser: 472 # Grafana user
  runAsNonRoot: true

initContainers:
  - name: init-chown-data
    image: busybox:latest
    command: ["sh", "-c", "chown -R 472:472 /var/lib/grafana"]
    securityContext:
      runAsUser: 0 # Needs root to change ownership
```

## Why This Happens

When Kubernetes creates a PersistentVolume, it may be owned by root (UID 0). Prometheus and Grafana run as non-root users for security, so they can't write to these directories without proper permissions.

The init container runs as root to change the ownership to the correct user, then the main container runs as that non-root user with full access.

## Files Updated

- [`base/prometheus/deployment.yaml`](file:///home/sherif/projects/konectaerp/infrastructure/kubernetes/base/prometheus/deployment.yaml)
- [`base/grafana/deployment.yaml`](file:///home/sherif/projects/konectaerp/infrastructure/kubernetes/base/grafana/deployment.yaml)
- [`MONITORING.md`](file:///home/sherif/projects/konectaerp/infrastructure/kubernetes/MONITORING.md)

These fixes are now permanent parts of the deployment configuration and will work on any Kubernetes cluster.
