#!/bin/bash
set -e

echo "===== TASKLY MONITORING PREREQUISITES ====="

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

# Install Helm without sudo
if ! command -v helm >/dev/null 2>&1; then
    echo "Installing Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
      -o /tmp/get-helm-3.sh

    HELM_INSTALL_DIR="$HOME/.local/bin" USE_SUDO=false \
      bash /tmp/get-helm-3.sh
fi

grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null \
  || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"

echo ""
echo "Helm version:"
helm version --short

# Confirm correct EKS context
echo ""
echo "Current Kubernetes context:"
kubectl config current-context

# Add Metrics Server Helm repository
echo ""
echo "Adding Metrics Server repository..."
helm repo add metrics-server \
  https://kubernetes-sigs.github.io/metrics-server/ \
  --force-update

helm repo update

# Install lightweight Metrics Server
echo ""
echo "Installing Metrics Server..."

helm upgrade --install metrics-server \
  metrics-server/metrics-server \
  --namespace kube-system \
  --set replicas=1 \
  --set resources.requests.cpu=50m \
  --set resources.requests.memory=64Mi \
  --set resources.limits.cpu=200m \
  --set resources.limits.memory=200Mi \
  --wait \
  --timeout 5m

echo ""
echo "Waiting for Metrics Server..."
kubectl rollout status deployment/metrics-server \
  -n kube-system --timeout=180s

echo ""
echo "Checking node metrics..."
for i in $(seq 1 12); do
    if kubectl top nodes; then
        break
    fi
    sleep 10
done

echo ""
echo "Metrics Server pods:"
kubectl get pods -n kube-system | grep metrics-server

echo ""
echo "===== PREREQUISITES COMPLETED ====="
