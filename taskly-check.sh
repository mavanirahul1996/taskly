#!/bin/bash

echo "======================================"
echo "       TASKLY PROJECT STATUS"
echo "======================================"

check_file() {
    if [ -f "$1" ]; then
        echo "[FOUND]   $1"
    else
        echo "[MISSING] $1"
    fi
}

echo ""
echo "========== 1. DOCKER =========="
docker --version
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"

echo ""
echo "========== 2. SONARQUBE =========="
if docker ps -a --format '{{.Names}}' | grep -q '^taskly-sonarqube$'; then
    docker inspect -f 'Container: {{.State.Status}}' taskly-sonarqube
else
    echo "[NOT INSTALLED] SonarQube container"
fi

echo ""
echo "========== 3. KUBERNETES =========="
kubectl config current-context
kubectl get nodes

echo ""
echo "========== 4. ARGO CD =========="
kubectl get pods -n argocd
kubectl get applications.argoproj.io -n argocd

echo ""
echo "========== 5. TASKLY STAGING =========="
kubectl get pods -n taskly-staging
kubectl get deployments -n taskly-staging
kubectl get services -n taskly-staging

echo ""
echo "========== 6. GITHUB ACTIONS =========="
check_file .github/workflows/ci-cd.yml
check_file sonar-project.properties

echo ""
echo "========== 7. TERRAFORM =========="
check_file terraform/environments/staging/main.tf
check_file terraform/environments/production/main.tf
check_file terraform/modules/eks/main.tf
check_file terraform/modules/vpc/main.tf

echo ""
echo "========== 8. MONITORING FILES =========="
find . -maxdepth 4 -type f \
    \( -iname '*prometheus*' -o \
       -iname '*grafana*' -o \
       -iname '*loki*' -o \
       -iname '*alert*' \) \
    -not -path './.git/*' 2>/dev/null | sort

echo ""
echo "========== 9. DOCUMENTATION =========="
check_file README.md
check_file docs/runbook.md
check_file docs/architecture.png

echo ""
echo "========== 10. GIT STATUS =========="
git status --short

echo ""
echo "======================================"
echo "       CHECK COMPLETED"
echo "======================================"
