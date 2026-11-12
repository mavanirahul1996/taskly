#!/bin/bash

echo "========================================"
echo "       TASKLY FINAL PROJECT AUDIT"
echo "========================================"

PASS=0
WARN=0
FAIL=0

ok()   { echo " [PASS] $1"; ((PASS++)); }
warn() { echo " [WARN] $1"; ((WARN++)); }
fail() { echo " [FAIL] $1"; ((FAIL++)); }

echo
echo "1. LOCAL PROJECT CHECKS"
echo "----------------------------------------"

[ -f README.md ] && ok "README exists" || fail "README missing"
[ -f .github/workflows/security-scan.yml ] && ok "Security workflow exists" || fail "Security workflow missing"
[ -f .github/workflows/production-deploy.yml ] && ok "Production workflow exists" || fail "Production workflow missing"

if grep -q 'if:.*false' .github/workflows/production-deploy.yml 2>/dev/null; then
  ok "Production deployment intentionally disabled"
else
  warn "Production workflow condition needs manual review"
fi

git diff --check >/dev/null 2>&1 && ok "Git diff check" || warn "Git diff check needs review"

echo
echo "2. GITHUB ACTIONS / TRIVY"
echo "----------------------------------------"

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  gh run list --workflow security-scan.yml --limit 3
  echo
  echo "Latest Security Scan:"
  gh run list --workflow security-scan.yml --limit 1
else
  warn "GitHub CLI missing or not authenticated. Check Actions on GitHub website."
fi

echo
echo "3. KUBERNETES / STAGING"
echo "----------------------------------------"

if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
  ok "Kubernetes cluster reachable"
  echo "Context: $(kubectl config current-context)"

  kubectl get nodes

  if kubectl get namespace taskly-staging >/dev/null 2>&1; then
    ok "taskly-staging namespace exists"
    kubectl get pods -n taskly-staging
    kubectl get deployments -n taskly-staging
  else
    fail "taskly-staging namespace not found"
  fi

  echo
  echo "4. MONITORING"
  echo "----------------------------------------"

  if kubectl get namespace monitoring >/dev/null 2>&1; then
    ok "Monitoring namespace exists"
    kubectl get pods -n monitoring

    kubectl get prometheusrules -n monitoring

    if kubectl get prometheusrule taskly-alerts -n monitoring >/dev/null 2>&1; then
      ok "Taskly Prometheus alert rules exist"
      kubectl get prometheusrule taskly-alerts -n monitoring -o yaml
    else
      warn "taskly-alerts PrometheusRule not found"
    fi
  else
    fail "Monitoring namespace missing"
  fi
else
  warn "Kubernetes cluster not reachable. Skipping cluster checks."
fi

echo
echo "5. PRODUCTION STATUS"
echo "----------------------------------------"
echo "Production EKS cluster was not provisioned."
echo "Production deployment workflow is intentionally disabled."
warn "Production deployment is not completed (expected)."

echo
echo "6. FINAL SUMMARY"
echo "----------------------------------------"
echo "PASS: $PASS"
echo "WARN: $WARN"
echo "FAIL: $FAIL"
echo
echo "Manual verification still required:"
echo "- Grafana four required dashboard panels"
echo "- JSON logs visible in Loki"
echo "- Slack/email alert delivery"
echo "- Staging rollback test"
echo "- Actual Trivy scan result"
echo
echo "Audit completed. No infrastructure changes made."
