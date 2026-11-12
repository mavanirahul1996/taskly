#!/usr/bin/env bash

set +e

REGION="eu-central-1"
PASS=0
FAIL=0
VERIFY=0

ok() {
  echo "[PASS] $1"
  ((PASS++))
}

bad() {
  echo "[MISSING] $1"
  ((FAIL++))
}

verify() {
  echo "[VERIFY] $1"
  ((VERIFY++))
}

section() {
  echo
  echo "========== $1 =========="
}

# Search only project source/config files, never virtualenv or git.
search_project() {
  grep -RilE "$1" \
    --exclude-dir=.git \
    --exclude-dir=.venv \
    --exclude-dir=.venv312 \
    --exclude-dir=venv \
    --exclude-dir=node_modules \
    --exclude-dir=__pycache__ \
    --include='*.tf' --include='*.yaml' --include='*.yml' \
    --include='*.py' --include='*.md' --include='*.json' \
    --include='*.sh' . 2>/dev/null | head -1
}

echo "=========================================="
echo "       TASKLY COMPLETE FINAL AUDIT"
echo "=========================================="
echo "Date: $(date)"
echo "Project: $PWD"
echo "AWS Region: $REGION"

if [[ ! -d .git ]]; then
  echo "ERROR: Run this script from Taskly project root."
  exit 1
fi

section "1. TERRAFORM INFRASTRUCTURE"

if find terraform -name '*.tf' -not -path '*/.terraform/*' 2>/dev/null | grep -q .; then
  ok "Terraform configuration exists"
else
  bad "Terraform configuration"
fi

if search_project 'backend[[:space:]]+"(s3|azurerm)"'; then
  ok "Remote state backend configuration found"
else
  bad "Terraform remote backend"
fi

if [[ -d terraform/environments/staging ]]; then
  ok "Staging Terraform environment exists"
else
  bad "Staging environment"
fi

if [[ -d terraform/environments/production ]] || search_project 'environment[[:space:]]*=[[:space:]]*"production"'; then
  ok "Production environment configuration found"
else
  bad "Production environment configuration"
fi

if search_project 'terraform destroy'; then
  ok "Terraform destroy instructions/reference found"
else
  verify "Terraform destroy documentation and clean destroy test"
fi

section "2. AWS MANAGED SERVICES"

if aws sts get-caller-identity >/dev/null 2>&1; then
  ok "AWS authentication"

  RDS=$(aws rds describe-db-instances --region "$REGION" \
    --query 'DBInstances[?Engine==`postgres`].DBInstanceIdentifier' \
    --output text 2>/dev/null)

  if [[ -n "$RDS" && "$RDS" != "None" ]]; then
    ok "PostgreSQL RDS found: $RDS"
  else
    bad "PostgreSQL RDS in $REGION"
  fi

  REDIS=$(aws elasticache describe-cache-clusters --region "$REGION" \
    --query 'CacheClusters[?Engine==`redis`].CacheClusterId' \
    --output text 2>/dev/null)

  REPL=$(aws elasticache describe-replication-groups --region "$REGION" \
    --query 'ReplicationGroups[].ReplicationGroupId' \
    --output text 2>/dev/null)

  if [[ -n "$REDIS" && "$REDIS" != "None" ]] || [[ -n "$REPL" && "$REPL" != "None" ]]; then
    ok "Managed Redis found: ${REDIS:-$REPL}"
  else
    bad "Managed Redis in $REGION"
  fi
else
  verify "AWS authentication unavailable; managed services not checked"
fi

section "3. GITHUB ACTIONS CI/CD"

WF=".github/workflows/ci-cd.yml"

if [[ -f "$WF" ]]; then
  ok "GitHub Actions workflow exists"

  grep -qiE 'pytest|unittest' "$WF" && ok "Test stage configured" || bad "Test stage"
  grep -qiE 'docker/build-push-action|docker build' "$WF" && ok "Docker build configured" || bad "Docker build"
  grep -qiE 'trivy|snyk|sonar|bandit|checkov' "$WF" && ok "Security scan configured" || bad "Security scan"
  grep -qiE 'docker/login-action|docker login' "$WF" && ok "Docker registry login configured" || bad "Docker registry login"
  grep -qiE 'github.sha|commit.sha' "$WF" && ok "Commit SHA tagging configured" || bad "Commit SHA image tagging"
  grep -qiE 'staging' "$WF" && ok "Staging deployment reference found" || bad "Staging deployment"
  grep -qiE 'production' "$WF" && ok "Production deployment reference found" || bad "Production deployment"
  grep -qiE 'environment:.*production|environment:[[:space:]]*$' "$WF" && verify "Check GitHub production environment protection and required reviewers" || bad "Manual approval gate configuration"
else
  bad "CI/CD workflow file"
fi

if search_project 'rollback|rollout undo'; then
  ok "Rollback reference found"
  verify "Rollback must be tested, not just documented"
else
  bad "Rollback documentation/mechanism"
fi

section "4. KUBERNETES AND ARGOCD"

if kubectl get nodes >/dev/null 2>&1; then
  kubectl get nodes
  if kubectl get nodes --no-headers | awk '$2 != "Ready" {bad=1} END {exit bad}'; then
    ok "All EKS nodes Ready"
  else
    bad "One or more EKS nodes are not Ready"
  fi
else
  bad "Kubernetes cluster connection"
fi

if kubectl get deployment taskly-api -n taskly-staging >/dev/null 2>&1; then
  kubectl get deployment taskly-api -n taskly-staging -o wide
  READY=$(kubectl get deployment taskly-api -n taskly-staging -o jsonpath='{.status.readyReplicas}')
  DESIRED=$(kubectl get deployment taskly-api -n taskly-staging -o jsonpath='{.spec.replicas}')
  [[ "$READY" == "$DESIRED" && -n "$READY" ]] && ok "Taskly deployment ready" || bad "Taskly deployment readiness"
else
  bad "Taskly staging deployment"
fi

if kubectl get applications.argoproj.io taskly-staging -n argocd >/dev/null 2>&1; then
  kubectl get applications.argoproj.io taskly-staging -n argocd
  SYNC=$(kubectl get applications.argoproj.io taskly-staging -n argocd -o jsonpath='{.status.sync.status}')
  HEALTH=$(kubectl get applications.argoproj.io taskly-staging -n argocd -o jsonpath='{.status.health.status}')
  [[ "$SYNC" == "Synced" && "$HEALTH" == "Healthy" ]] && ok "ArgoCD Synced and Healthy" || bad "ArgoCD application health"
else
  bad "ArgoCD staging application"
fi

section "5. MONITORING"

if kubectl get pods -n monitoring >/dev/null 2>&1; then
  kubectl get pods -n monitoring
  if kubectl get pods -n monitoring --no-headers | awk '$2 !~ /^[0-9]+\/[0-9]+$/ || $3 != "Running" {bad=1} END {exit bad}'; then
    ok "All monitoring pods Running and Ready"
  else
    bad "Monitoring pods need attention"
  fi
else
  bad "Monitoring namespace/pods"
fi

kubectl get servicemonitors,podmonitors -A >/dev/null 2>&1 \
  && ok "Prometheus scrape resources query succeeded" \
  || verify "Prometheus scrape resources"

if kubectl get prometheusrule taskly-alerts -n monitoring >/dev/null 2>&1; then
  RULES=$(kubectl get prometheusrule taskly-alerts -n monitoring -o jsonpath='{range .spec.groups[*].rules[*]}{.alert}{"\n"}{end}')
  echo "$RULES"
  COUNT=$(echo "$RULES" | grep -cve '^$')
  [[ "$COUNT" -ge 3 ]] && ok "At least three alert rules found" || bad "Three alert rules"
else
  bad "Taskly Prometheus alert rules"
fi

if search_project 'slack_configs|email_configs|webhook_configs'; then
  ok "Alertmanager notification receiver configuration found"
  verify "Send a test notification to confirm delivery"
else
  bad "Slack/email/webhook receiver configuration"
fi

section "6. APPLICATION METRICS AND LOGGING"

grep -RilE 'http_requests_total' --include='*.py' --exclude-dir=.venv --exclude-dir=.venv312 . 2>/dev/null | head -1 | grep -q . \
  && ok "Request counter source reference" || bad "Request counter"

grep -RilE 'http_request_duration_seconds|Histogram' --include='*.py' --exclude-dir=.venv --exclude-dir=.venv312 . 2>/dev/null | head -1 | grep -q . \
  && ok "Request duration histogram source reference" || bad "Request duration histogram"

grep -RilE 'tasks_created_total' --include='*.py' --exclude-dir=.venv --exclude-dir=.venv312 . 2>/dev/null | head -1 | grep -q . \
  && ok "Custom tasks_created_total metric source reference" || bad "Custom business metric"

grep -RilE 'trace_id|correlation_id' --include='*.py' --exclude-dir=.venv --exclude-dir=.venv312 . 2>/dev/null | head -1 | grep -q . \
  && ok "Trace ID source reference" || bad "Trace ID"

grep -RilE 'jsonlogger|structlog|pythonjsonlogger|JSONFormatter' --include='*.py' --exclude-dir=.venv --exclude-dir=.venv312 . 2>/dev/null | head -1 | grep -q . \
  && ok "JSON logger source reference" || verify "JSON structured logging implementation"

if search_project 'active_tasks|tasks_active|tasks_created_total'; then
  ok "Active tasks metric/reference found"
else
  bad "Active tasks metric"
fi

if search_project 'loki|promtail'; then
  ok "Loki/Promtail configuration reference found"
else
  bad "Loki log collection configuration"
fi

verify "Check Grafana dashboard visually for all four required panels"

section "7. DOCUMENTATION"

if [[ -f README.md ]]; then
  ok "README.md exists"
  grep -qiE 'terraform|provision' README.md && ok "README provisioning instructions" || bad "README provisioning instructions"
  grep -qiE 'deploy' README.md && ok "README deployment instructions" || bad "README deployment instructions"
  grep -qiE 'grafana|dashboard' README.md && ok "README dashboard instructions" || bad "README dashboard instructions"
  grep -qiE 'alert' README.md && ok "README alert instructions" || bad "README alert instructions"
else
  bad "README.md"
fi

if search_project 'incident runbook|runbook|error rate exceeds 5'; then
  ok "Incident runbook reference found"
else
  bad "Incident runbook"
fi

if search_project 'mermaid|architecture diagram'; then
  ok "Architecture diagram reference found"
elif find . -type f \( -iname '*architecture*.png' -o -iname '*architecture*.svg' -o -iname '*architecture*.drawio' \) -not -path '*/.git/*' | grep -q .; then
  ok "Architecture diagram file found"
else
  bad "Architecture diagram"
fi

section "8. FINAL SUMMARY"

echo "PASS:   $PASS"
echo "MISSING: $FAIL"
echo "VERIFY: $VERIFY"
echo
echo "IMPORTANT:"
echo "- This audit is read-only."
echo "- It does not run terraform destroy."
echo "- It does not deploy to production."
echo "- Manual approval, rollback, alert delivery and dashboard panels need functional tests."
echo "=========================================="
