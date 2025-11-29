# Quick Reference: Prometheus & Grafana on Konecta ERP

## 🚀 Deploy to Your Cluster

Since your cluster is already running on GCP, deploy the monitoring stack:

```bash
# Deploy to dev environment
kubectl apply -k infrastructure/kubernetes/overlays/dev/

# Verify deployment
kubectl get pods -n monitoring
kubectl get svc -n monitoring
kubectl get pvc -n monitoring
```

## 🔍 Access Monitoring

### Prometheus (Metrics Collection)

```bash
# Port-forward to access locally
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Open in browser
http://localhost:9090

# Check targets: Status > Targets
# Run queries in the Graph tab
```

### Grafana (Dashboards)

```bash
# Port-forward to access locally
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Open in browser
http://localhost:3000

# Login credentials:
Username: admin
Password: admin
```

## 📊 Pre-configured Dashboards

1. **Kubernetes Cluster Overview** - Infrastructure metrics
2. **Konecta ERP Services** - Application performance

## 📁 Files Created

```
infrastructure/kubernetes/
├── base/
│   ├── prometheus/          # 7 files (namespace, RBAC, config, deployment, service, PVC, kustomization)
│   └── grafana/             # 6 files (datasources, dashboards, deployment, service, PVC, kustomization)
├── overlays/
│   ├── dev/monitoring-patch.yaml
│   ├── staging/monitoring-patch.yaml
│   └── prod/monitoring-patch.yaml
└── MONITORING.md            # Detailed deployment guide
```

## 🔧 Environment Configurations

| Environment | Service Type | Prometheus Storage | Grafana Storage   |
| ----------- | ------------ | ------------------ | ----------------- |
| Dev         | NodePort     | 5Gi                | 2Gi               |
| Staging     | LoadBalancer | 15Gi               | 5Gi               |
| Production  | LoadBalancer | 20Gi (2 replicas)  | 10Gi (2 replicas) |

## 📖 Documentation

- **README.md** - Updated with monitoring section
- **MONITORING.md** - Complete deployment and troubleshooting guide

## ✅ What's Monitored

- ✅ Kubernetes cluster (nodes, pods, containers)
- ✅ All microservices (API Gateway, Auth, HR, Finance, Inventory, Reporting, User Management)
- ✅ RabbitMQ
- ✅ SQL Server (if exporter added)

## 🎯 Next Steps

1. Deploy: `kubectl apply -k infrastructure/kubernetes/overlays/dev/`
2. Access Grafana: `kubectl port-forward -n monitoring svc/grafana 3000:3000`
3. View dashboards at http://localhost:3000
4. (Optional) Add metrics to your .NET services using `prometheus-net` library
