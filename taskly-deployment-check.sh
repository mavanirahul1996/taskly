#!/bin/bash

echo "=================================="
echo " TASKLY DEPLOYMENT VERIFICATION"
echo "=================================="

echo ""
echo "1. GITHUB LOCAL COMMIT"
git log -1 --oneline

echo ""
echo "2. GIT STATUS"
git status --short

echo ""
echo "3. GITHUB WORKFLOW"
if [ -f .github/workflows/ci-cd.yml ]; then
    echo "CI/CD workflow exists"
else
    echo "CI/CD workflow missing"
fi

echo ""
echo "4. DOCKER IMAGE IN KUBERNETES"
kubectl get deployment taskly-api \
  -n taskly-staging \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""

echo ""
echo "5. ARGO CD APPLICATION"
kubectl get application taskly-staging \
  -n argocd \
  -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status

echo ""
echo "6. TASKLY POD"
kubectl get pods -n taskly-staging

echo ""
echo "7. TASKLY SERVICE"
kubectl get svc -n taskly-staging

echo ""
echo "=================================="
echo " VERIFICATION COMPLETED"
echo "=================================="

echo ""
echo "GitHub Actions:"
echo "https://github.com/mavanirahul1996/taskly/actions"
