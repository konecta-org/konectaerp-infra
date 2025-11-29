# Deploying Prometheus and Grafana to Konecta ERP Cluster

This guide walks you through deploying the monitoring stack to your existing GKE cluster.

## Prerequisites

- GKE cluster is already running
- `kubectl` is configured to access your cluster
- You have cluster-admin permissions

## Deployment Steps

### 1. Verify Cluster Access

```bash
# Verify you're connected to the right cluster
kubectl cluster-info
kubectl get nodes
```

### 2. Deploy Monitoring Stack (Dev Environment)

```bash
# Navigate to the project root
cd /home/sherif/projects/konectaerp

# Apply the dev overlay (includes Prometheus and Grafana)
kubectl apply -k infrastructure/kubernetes/overlays/dev/

# Wait for monitoring pods to be ready
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=5m
kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=5m
```

### 3. Verify Deployment

```bash
# Check monitoring namespace
kubectl get all -n monitoring

# Expected output should show:
# - prometheus pod (Running)
# - grafana pod (Running)
# - prometheus service
# - grafana service
# - prometheus and grafana PVCs (Bound)

# Check PVCs
kubectl get pvc -n monitoring

# Check logs
kubectl logs -n monitoring -l app=prometheus --tail=50
kubectl logs -n monitoring -l app=grafana --tail=50
```

### 4. Access Prometheus

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Open in browser: http://localhost:9090
# Navigate to Status > Targets to verify scrape targets
```

### 5. Access Grafana

```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Open in browser: http://localhost:3000
# Login with: admin / admin
# You'll be prompted to change the password

# Verify:
# 1. Datasource is configured (Configuration > Data Sources)
# 2. Dashboards are loaded (Dashboards > Browse)
```

### 6. Test Metrics Collection

In Prometheus UI (http://localhost:9090):

```promql
# Check if services are up
up

# Check Kubernetes nodes
kube_node_info

# Check pod metrics
kube_pod_info

# Check container CPU usage
rate(container_cpu_usage_seconds_total[5m])
```

## Deploying to Staging/Production

For staging or production environments:

```bash
# Staging
kubectl apply -k infrastructure/kubernetes/overlays/staging/

# Production
kubectl apply -k infrastructure/kubernetes/overlays/prod/

# Get LoadBalancer IPs
kubectl get svc -n monitoring

# Wait for EXTERNAL-IP to be assigned
# Access Prometheus at http://<PROMETHEUS_EXTERNAL_IP>:9090
# Access Grafana at http://<GRAFANA_EXTERNAL_IP>:3000
```

## Troubleshooting

### Pods Not Starting

```bash
# Describe the pod
kubectl describe pod -n monitoring <pod-name>

# Check events
kubectl get events -n monitoring --sort-by='.lastTimestamp'

# Common issues:
# - PVC not binding: Check storage class exists
# - Image pull errors: Check internet connectivity
# - Resource limits: Check node capacity
```

### PVC Not Binding

```bash
# Check storage classes
kubectl get storageclass

# If standard-rwo doesn't exist, update the PVC to use an available storage class
# For GKE, common storage classes are:
# - standard (default)
# - standard-rwo
# - premium-rwo
```

### Prometheus Not Scraping Targets

```bash
# Check Prometheus logs
kubectl logs -n monitoring -l app=prometheus

# Verify RBAC permissions
kubectl get clusterrolebinding prometheus

# Test service discovery
kubectl get endpoints -n monitoring
```

### Grafana Can't Connect to Prometheus

```bash
# Verify Prometheus service
kubectl get svc -n monitoring prometheus

# Test connectivity from Grafana pod
kubectl exec -n monitoring -it <grafana-pod> -- wget -O- http://prometheus.monitoring.svc.cluster.local:9090/api/v1/status/config
```

### Prometheus or Grafana Permission Issues

If you see errors like:

- Prometheus: `Error opening query log file: open /prometheus/queries.active: permission denied`
- Grafana: `mkdir: can't create directory '/var/lib/grafana/plugins': Permission denied`

**Solution**: Both deployments have been updated with proper security contexts and init containers. Redeploy:

```bash
# Delete existing monitoring resources
kubectl delete deployment prometheus grafana -n monitoring
kubectl delete pvc prometheus-storage grafana-storage -n monitoring

# Reapply the configuration
kubectl apply -k infrastructure/kubernetes/overlays/dev/

# Wait for both to be ready
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=5m
kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=5m

# Verify no permission errors
kubectl logs -n monitoring -l app=prometheus --tail=20
kubectl logs -n monitoring -l app=grafana --tail=20
```

**What was fixed:**

- **Prometheus**: Added `securityContext` with `fsGroup: 65534` (nobody user) and init container
- **Grafana**: Added `securityContext` with `fsGroup: 472` (grafana user) and init container
- Both use init containers to set proper ownership before the main containers start

See [MONITORING_PERMISSION_FIX.md](file:///home/sherif/projects/konectaerp/infrastructure/kubernetes/MONITORING_PERMISSION_FIX.md) for detailed explanation.

## Customization

### Adding Custom Dashboards

1. Create dashboard JSON in Grafana UI
2. Export the JSON
3. Add to `configmap-dashboards.yaml`
4. Redeploy: `kubectl apply -k infrastructure/kubernetes/overlays/dev/`

### Adjusting Retention Period

Edit `infrastructure/kubernetes/base/prometheus/deployment.yaml`:

```yaml
args:
  - "--storage.tsdb.retention.time=30d" # Change from 15d to 30d
```

### Changing Grafana Password

```bash
# Access Grafana pod
kubectl exec -n monitoring -it <grafana-pod> -- grafana-cli admin reset-admin-password <new-password>
```

## Next Steps

1. **Configure Alerting**: Set up Alertmanager for notifications
2. **Add Service Metrics**: Instrument your .NET services with prometheus-net
3. **Create Custom Dashboards**: Build dashboards specific to your business metrics
4. **Set Up Grafana Users**: Create user accounts for your team
5. **Enable HTTPS**: Configure TLS for Grafana and Prometheus

## Cleanup

To remove the monitoring stack:

```bash
# Delete monitoring resources
kubectl delete namespace monitoring

# Or remove from kustomization and reapply
# Remove prometheus and grafana from base/kustomization.yaml
kubectl apply -k infrastructure/kubernetes/overlays/dev/
```
