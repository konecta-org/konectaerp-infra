# Konecta ERP Monitoring – All-in-One Guide

This document consolidates **MONITORING.md**, **MONITORING_PERMISSION_FIX.md**, and **MONITORING_QUICKSTART.md** into a single reference file.

---

## 1. Overview

This monitoring stack deploys **Prometheus** and **Grafana** on a GKE Kubernetes cluster using **Kustomize** with environment-specific overlays (dev, staging, prod).

### What You Get
- Cluster & node metrics
- Pod & container metrics
- Microservices metrics
- Persistent storage for metrics & dashboards
- Secure non-root deployments
- Environment-specific scaling

---

## 2. Prerequisites

- Running GKE cluster
- `kubectl` configured
- Cluster-admin permissions
- Existing Konecta ERP Kubernetes structure

---

## 3. Deploy Monitoring

### Dev
```bash
kubectl apply -k infrastructure/kubernetes/overlays/dev/
```

### Staging
```bash
kubectl apply -k infrastructure/kubernetes/overlays/staging/
```

### Production
```bash
kubectl apply -k infrastructure/kubernetes/overlays/prod/
```

Verify:
```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
kubectl get pvc -n monitoring
```

---

## 4. Access Services

### Prometheus
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```
http://localhost:9090

Useful queries:
```promql
up
kube_node_info
kube_pod_info
rate(container_cpu_usage_seconds_total[5m])
```

### Grafana
```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000
```
http://localhost:3000  
Login: `admin / admin`

---

## 5. Environment Configuration

| Environment | Service Type | Prometheus Storage | Grafana Storage |
|------------|--------------|--------------------|-----------------|
| Dev        | NodePort     | 5Gi                | 2Gi             |
| Staging    | LoadBalancer | 15Gi               | 5Gi             |
| Production | LoadBalancer | 20Gi (2 replicas)  | 10Gi (2 replicas)|

---

## 6. Permissions & Security Fix (IMPORTANT)

### Common Errors
- Prometheus: permission denied on `/prometheus`
- Grafana: permission denied on `/var/lib/grafana`

### Solution Implemented
- Init containers run as root to `chown` volumes
- Main containers run as non-root users
- Correct `fsGroup` and `runAsUser`

#### Prometheus
- UID/GID: `65534` (nobody)

#### Grafana
- UID/GID: `472` (grafana)

If upgrading from an older deployment:
```bash
kubectl delete deployment prometheus grafana -n monitoring
kubectl delete pvc prometheus-storage grafana-storage -n monitoring
kubectl apply -k infrastructure/kubernetes/overlays/dev/
```

---

## 7. Directory Structure

```
infrastructure/kubernetes/
├── base/
│   ├── prometheus/
│   └── grafana/
├── overlays/
│   ├── dev/
│   ├── staging/
│   └── prod/
├── MONITORING.md
```

---

## 8. Customization

### Change Retention
```yaml
--storage.tsdb.retention.time=30d
```

### Add Dashboards
1. Export JSON from Grafana
2. Add to dashboard ConfigMap
3. Reapply overlay

### Reset Grafana Password
```bash
kubectl exec -n monitoring -it <grafana-pod> -- grafana-cli admin reset-admin-password NEWPASS
```

---

## 9. What Is Monitored

- Kubernetes nodes, pods, containers
- All Konecta ERP microservices
- RabbitMQ
- SQL Server (via exporter if enabled)

---

## 10. Cleanup

```bash
kubectl delete namespace monitoring
```

---

## 11. Next Steps

- Add Alertmanager
- Instrument .NET services with `prometheus-net`
- Configure HTTPS ingress
- Create Grafana users & roles
