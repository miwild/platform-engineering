# Trivy Operator & Trivy UI Installation Notes

## Status Overview

| Component | Deployment | RBAC | Scanning |
|-----------|-----------|------|----------|
| Trivy Operator | ✅ Running (1/1) | ❌ Missing | ⚠️ Limited |
| Trivy UI | ✅ Running (1/1) | ❌ Missing | ⚠️ Limited |
| Traefik IngressRoute | ✅ Added | N/A | Pending apply |

### Helm Chart Directories
- **Trivy Operator**: `helm-charts/trivy/`
- **Trivy UI**: `helm-charts/trivy-ui/`

## Helm Repos

```bash
# Aqua Trivy Operator
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm repo update

# Trivy UI
helm repo add trivy-ui https://locustbaby.github.io/trivy-ui/
helm repo update
```

## Current Installation Commands

### Trivy Operator
```bash
helm upgrade --install trivy-operator aqua/trivy-operator \
  --namespace platform-trivy \
  --version 0.37.0 \
  --values helm-charts/trivy/values.yaml \
  --set compliance.enabled=false \
  --set clusterComplianceEnabled=false
```

### Trivy UI
```bash
helm upgrade --install trivy-ui trivy-ui/trivy-ui \
  --namespace platform-trivy \
  --version 0.0.4 \
  --values helm-charts/trivy-ui/values.yaml \
  --set rbac.create=false
```

## RBAC Limitation

The pi-agent service account (`agent-dev:pi-agent`) cannot create cluster-level RBAC
resources that grant permissions it doesn't already have. This is a Kubernetes security
feature (RBAC escalation prevention).

### Required Manual Step

An admin must apply the following RBAC resources:

```bash
kubectl apply -f helm-charts/trivy/rbac-override.yaml
```

This creates:
- `ClusterRole/trivy-operator` - full permissions for Trivy Operator
- `ClusterRoleBinding/trivy-operator` - binds ClusterRole to service account
- `Role/trivy-operator-leader-election` - leader election permissions
- `RoleBinding/trivy-operator-leader-election` - binds leader election role
- `ClusterRole/aggregate-*` - view aggregation roles for reports

## Auth Configuration

Trivy UI auth is configured via the `trivy-ui-auth` secret:

```bash
kubectl create secret generic trivy-ui-auth \
  -n platform-trivy \
  --from-file=auth.yaml=auth.yaml \
  --from-literal=session-secret="$(openssl rand -hex 32)"
```

**Note**: The trivy-ui chart (v0.0.4) does not have built-in `auth.mode` and `auth.local.existingSecret` values.
The auth configuration file (`auth.yaml`) is mounted and read by the trivy-ui application.

## Traefik IngressRoute

The IngressRoute has been added to:
`k3d-dev/templates/traefik/sample-ingressroute.yaml`

**Do NOT apply yet** - save for later use as instructed.

## Verification Commands

```bash
# Check pods
kubectl get pods -n platform-trivy

# Check services  
kubectl get svc -n platform-trivy

# Check reports (after RBAC is applied)
kubectl get vulnerabilityreports -A
kubectl get configauditreports -A
kubectl get rbacassessmentreports -A

# Check logs
kubectl logs -n platform-trivy deployment/trivy-operator
kubectl logs -n platform-trivy deployment/trivy-ui
```

## TLS

The IngressRoute uses `certResolver: letsencrypt` (matching existing patterns for Grafana,
Nextcloud, and ArgoCD), not `secretName: trivy-ui-tls`.

## Version Notes

- Trivy Operator: 0.37.0 (0.38.0 not available in aqua Helm repo)
- Trivy UI: 0.0.4 (app version v0.0.3)
