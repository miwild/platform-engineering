#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/Users/marni/.kube/config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT_DIR"

ACME_FILE="${ACME_FILE:-$ROOT_DIR/infra/Kubernetes/acme.json}"
K8S_DIR="infra/Kubernetes"

echo "Checking Kubernetes context..."
kubectl config current-context
kubectl get nodes

if [[ ! -s "$ACME_FILE" ]]; then
  echo "Error: ACME file not found or empty: $ACME_FILE"
  exit 1
fi

echo "Creating/updating Traefik ACME Secret..."
kubectl create secret generic traefik-acme \
  -n kube-system \
  --from-file=acme.json="$ACME_FILE" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create namespace platform-nextcloud \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Applying Traefik configuration..."
kubectl apply -f "$K8S_DIR/templates/traefik/helmchartconfig.yaml"
kubectl apply -f "$K8S_DIR/templates/traefik/ingress.yaml"

echo "Installing Argo CD..."
helm upgrade --install argocd \
  "$K8S_DIR/helm-charts/argocd" \
  --namespace argocd \
  --create-namespace


echo "Waiting for Argo CD application controller..."
kubectl rollout status statefulset/argocd-application-controller \
  -n argocd --timeout=180s

echo "Applying Argo CD Applications..."
kubectl apply -f infra/Kubernetes/helm-charts/argocd/application.yaml

echo "Registered Applications:"
kubectl get applications -n argocd
