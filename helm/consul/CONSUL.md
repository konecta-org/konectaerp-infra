# Consul Service Discovery

Consul is deployed in each environment (dev, staging, prod) for service discovery and health checking.

## Accessing Consul UI

### Dev Environment

```bash
# Port-forward to Consul UI
kubectl port-forward svc/consul-ui -n dev 8500:80

# Access at http://localhost:8500
```

### Staging Environment

```bash
kubectl port-forward svc/consul-ui -n staging 8500:80
```

### Production Environment

```bash
kubectl port-forward svc/consul-ui -n prod 8500:80
```

## Configuration

Each environment has its own Consul cluster with environment-specific settings:

- **Dev**: 1 server replica, reduced resources
- **Staging**: 3 server replicas, standard resources
- **Production**: 5 server replicas, enhanced HA and resources

## ArgoCD Management

Consul is managed through ArgoCD applications:
- `dev-consul` - Dev environment Consul
- `staging-consul` - Staging environment Consul
- `prod-consul` - Production environment Consul

View and manage Consul through the ArgoCD UI at https://localhost:8080

## Service Registration

Services automatically register with Consul when deployed. Check the Consul UI to see all registered services.
