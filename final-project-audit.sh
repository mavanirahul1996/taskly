#!/usr/bin/env bash

# Taskly Final Project - Read-only audit
# Run from the Taskly repository root.

set +e

REGION="eu-central-1"
PASS=0
WARN=0
FAIL=0

check() {
    local name="$1"
    local result="$2"
    local detail="$3"

    if [[ "$result" == "PASS" ]]; then
        printf "\033[32m[PASS]\033[0m %s — %s\n" "$name" "$detail"
        ((PASS++))
    elif [[ "$result" == "FAIL" ]]; then
        printf "\033[31m[FAIL]\033[0m %s — %s\n" "$name" "$detail"
        ((FAIL++))
    else
        printf "\033[33m[VERIFY]\033[0m %s — %s\n" "$name" "$detail"
        ((WARN++))
    fi
}

has_file() {
    find . -type f -not -path './.git/*' \
        -not -path './.venv*/*' \
        -not -path './node_modules/*' \
        -iname "$1" -print -quit 2>/dev/null | grep -q .
}

search_files() {
    grep -RilE "$1" \
        --include='*.tf' --include='*.yaml' --include='*.yml' \
        --include='*.py' --include='*.md' --include='*.json' \
        --exclude-dir=.git --exclude-dir=.venv312 \
        --exclude-dir=node_modules . 2>/dev/null | head -1
}

echo
echo "=================================================="
echo "          TASKLY FINAL PROJECT AUDIT"
echo "=================================================="
echo "Date: $(date)"
echo "Directory: $PWD"
echo "AWS Region: $REGION"

if [[ ! -d .git ]]; then
    echo "ERROR: Run this script from the Taskly repository root."
    exit 1
fi

# --------------------------------------------------
echo
echo "1. INFRASTRUCTURE"
# --------------------------------------------------

if has_file '*.tf'; then
    check "Terraform files" PASS "Terraform configuration found"
else
    check "Terraform files" FAIL "No Terraform files found"
fi

if search_files 'backend[[:space:]]+"(s3|azurerm)"'; then
    check "Terraform remote backend" PASS "Remote backend configuration found"
else
    check "Terraform remote backend" VERIFY "No S3/Azure remote backend declaration found"
fi

if search_files 'production|prod'; then
    check "Production Terraform/config files" PASS "Production reference found"
else
    check "Production environment" FAIL "No production reference found"
fi

if search_files 'staging'; then
    check "Staging environment" PASS "Staging reference found"
else
    check "Staging environment" FAIL "No staging reference found"
fi

if command -v aws >/dev/null 2>&1; then
    if aws sts get-caller-identity --output text >/dev/null 2>&1; then
        check "AWS authentication" PASS "AWS CLI authenticated"

        RDS=$(aws rds describe-db-instances \
            --region "$REGION" \
            --query 'DBInstances[?DBInstanceStatus==`available`].DBInstanceIdentifier' \
            --output text 2>/dev/null)

        if [[ -n "$RDS" && "$RDS" != "None" ]]; then
            check "Managed RDS PostgreSQL" PASS "$RDS"
        else
            check "Managed RDS PostgreSQL" FAIL "No available RDS instance found in $REGION"
        fi

        REDIS=$(aws elasticache describe-replication-groups \
            --region "$REGION" \
            --query 'ReplicationGroups[?Status==`available`].ReplicationGroupId' \
            --output text 2>/dev/null)

        CACHE=$(aws elasticache describe-cache-clusters \
            --region "$REGION" \
            --query 'CacheClusters[?CacheClusterStatus==`available`].CacheClusterId' \
            --output text 2>/dev/null)

        if [[ -n "$REDIS" && "$REDIS" != "None" ]]; then
            check "Managed Redis" PASS "$REDIS"
        elif [[ -n "$CACHE" && "$CACHE" != "None" ]]; then
            check "Managed Redis" PASS "$CACHE"
        else
            check "Managed Redis" FAIL "No available ElastiCache resource found in $REGION"
        fi
    else
        check "AWS authentication" VERIFY "AWS CLI login/permissions unavailable"
        check "Managed RDS PostgreSQL" VERIFY "Could not query AWS"
        check "Managed Redis" VERIFY "Could not query AWS"
    fi
else
    check "AWS CLI" VERIFY "AWS CLI not installed"
fi

if search_files 'terraform.*destroy|destroy.*terraform'; then
    check "Terraform destroy documentation" PASS "Destroy instructions/reference found"
else
    check "Terraform destroy documentation" VERIFY "No destroy instructions found; clean destroy not tested"
fi

# --------------------------------------------------
echo
echo "2. CI/CD"
# --------------------------------------------------

if has_file 'ci-cd.yml' || has_file 'ci-cd.yaml'; then
    check "GitHub Actions workflow" PASS "CI/CD workflow file found"
else
    check "GitHub Actions workflow" FAIL "CI/CD workflow file not found"
fi

if search_files 'pytest|unittest'; then
    check "Automated tests in repository" PASS "Test command/reference found"
else
    check "Automated tests in repository" FAIL "No test command found"
fi

if search_files 'docker build|build-push-action'; then
    check "Docker build" PASS "Docker build step found"
else
    check "Docker build" FAIL "Docker build step not found"
fi

if search_files 'trivy|snyk|sonar|bandit|checkov|security scan'; then
    check "Security scan" PASS "Security scanning reference found"
else
    check "Security scan" FAIL "No security scanning reference found"
fi

if search_files 'docker/login-action|docker login'; then
    check "Docker registry login" PASS "Registry login step found"
else
    check "Docker registry login" VERIFY "Registry login not found"
fi

if search_files 'github.sha|commit.sha'; then
    check "Commit SHA image tag" PASS "SHA tagging reference found"
else
    check "Commit SHA image tag" FAIL "Commit SHA tagging not found"
fi

if search_files 'deploy.*staging|staging.*deploy'; then
    check "Staging deployment workflow" PASS "Staging deployment reference found"
else
    check "Staging deployment workflow" FAIL "No staging deployment reference found"
fi

if search_files 'environment:.*production|production.*environment|deploy.*production'; then
    check "Production deployment/manual gate" PASS "Production deployment reference found; approval must be verified in GitHub"
else
    check "Production deployment/manual gate" FAIL "Production deployment reference not found"
fi

if search_files 'rollback|roll back|rollout undo'; then
    check "Rollback instructions/mechanism" PASS "Rollback reference found; test still required"
else
    check "Rollback instructions/mechanism" FAIL "Rollback reference not found"
fi

# --------------------------------------------------
echo
echo "3. OBSERVABILITY"
# --------------------------------------------------

if kubectl get pods -n monitoring >/dev/null 2>&1; then
    MON=$(kubectl get pods -n monitoring --no-headers 2>/dev/null)
    if [[ -n "$MON" ]] && ! echo "$MON" | awk '$2 !~ /^[0-9]+\/[0-9]+$/ || $3 != "Running" {bad=1} END {exit bad}'; then
        check "Monitoring pods" PASS "All listed monitoring pods Running and Ready"
    else
        check "Monitoring pods" VERIFY "Some monitoring pods need attention"
    fi
else
    check "Monitoring pods" VERIFY "Cannot query monitoring namespace"
fi

if kubectl get servicemonitors,podmonitors -A >/dev/null 2>&1; then
    check "Prometheus scrape configuration" PASS "ServiceMonitor/PodMonitor resources query succeeded"
else
    check "Prometheus scrape configuration" VERIFY "Could not query scrape resources"
fi

if kubectl get prometheusrules -n monitoring taskly-alerts >/dev/null 2>&1; then
    RULES=$(kubectl get prometheusrule taskly-alerts -n monitoring -o jsonpath='{range .spec.groups[*].rules[*]}{.alert}{"\n"}{end}' 2>/dev/null)
    COUNT=$(echo "$RULES" | grep -cve '^$')
    if [[ "$COUNT" -ge 3 ]]; then
        check "Three Prometheus alert rules" PASS "$COUNT alert rules found"
    else
        check "Three Prometheus alert rules" FAIL "Only $COUNT rules found"
    fi
else
    check "Prometheus alert rules" FAIL "taskly-alerts not found"
fi

if search_files 'http_request_duration_seconds|request_duration'; then
    check "Latency histogram instrumentation" PASS "Histogram metric reference found"
else
    check "Latency histogram instrumentation" VERIFY "Histogram not found in source/config"
fi

if search_files 'http_requests_total'; then
    check "Request count metric" PASS "http_requests_total reference found"
else
    check "Request count metric" VERIFY "Request counter not found in repository"
fi

if search_files 'active_tasks|tasks_active|active.tasks'; then
    check "Active tasks dashboard/metric" PASS "Active tasks reference found"
else
    check "Active tasks dashboard/metric" FAIL "Active tasks metric/panel reference not found"
fi

if search_files 'loki|promtail'; then
    check "Loki log collection config" PASS "Loki/Promtail reference found"
else
    check "Loki log collection config" FAIL "No Loki/Promtail reference found"
fi

if search_files 'slack_configs|email_configs|webhook_configs'; then
    check "Alertmanager notification routing config" PASS "Notification receiver reference found; delivery needs testing"
else
    check "Alertmanager notification routing" FAIL "No Slack/email/webhook receiver config found"
fi

# --------------------------------------------------
echo
echo "4. APPLICATION INSTRUMENTATION"
# --------------------------------------------------

if search_files 'json.*formatter|jsonlogger|structlog|pythonjsonlogger'; then
    check "Structured JSON logging" PASS "JSON logging implementation reference found"
else
    check "Structured JSON logging" VERIFY "JSON logger implementation not detected"
fi

if search_files 'trace_id|trace-id|correlation_id'; then
    check "Trace ID in application" PASS "Trace/correlation ID reference found"
else
    check "Trace ID in application" FAIL "Trace ID reference not found"
fi

if search_files 'tasks_created_total'; then
    check "Custom tasks_created_total metric" PASS "Custom metric reference found"
else
    check "Custom tasks_created_total metric" FAIL "Custom business metric not found"
fi

# --------------------------------------------------
echo
echo "5. DOCUMENTATION"
# --------------------------------------------------

if [[ -f README.md ]]; then
    check "README.md" PASS "README exists"
    for pattern in 'terraform|provision' 'deploy' 'grafana|dashboard' 'alert'; do
        if grep -qiE "$pattern" README.md; then
            check "README: $pattern" PASS "Mentioned in README"
        else
            check "README: $pattern" FAIL "Not found in README"
        fi
    done
else
    check "README.md" FAIL "README not found"
fi

if search_files 'incident runbook|runbook|error rate exceeds 5|5%'; then
    check "Incident runbook" PASS "Runbook/5% error-rate reference found"
else
    check "Incident runbook" FAIL "Runbook not found"
fi

if has_file '*architecture*' || has_file '*diagram*' || search_files 'mermaid|architecture diagram'; then
    check "Architecture diagram" PASS "Architecture diagram/reference found"
else
    check "Architecture diagram" FAIL "Architecture diagram not found"
fi

# --------------------------------------------------
echo
echo "6. LIVE TASKLY STATUS"
# --------------------------------------------------

if kubectl get deployment taskly-api -n taskly-staging >/dev/null 2>&1; then
    READY=$(kubectl get deployment taskly-api -n taskly-staging -o jsonpath='{.status.readyReplicas}')
    DESIRED=$(kubectl get deployment taskly-api -n taskly-staging -o jsonpath='{.spec.replicas}')
    IMAGE=$(kubectl get deployment taskly-api -n taskly-staging -o jsonpath='{.spec.template.spec.containers[0].image}')
    echo "Deployment replicas: ${READY:-0}/${DESIRED:-0}"
    echo "Deployed image: $IMAGE"

    if [[ "$READY" == "$DESIRED" && -n "$READY" && "$READY" != "0" ]]; then
        check "Taskly staging deployment" PASS "Ready replicas match desired replicas"
    else
        check "Taskly staging deployment" FAIL "Replicas are not fully ready"
    fi
else
    check "Taskly staging deployment" FAIL "taskly-api deployment not found"
fi

if kubectl get applications.argoproj.io taskly-staging -n argocd >/dev/null 2>&1; then
    SYNC=$(kubectl get applications.argoproj.io taskly-staging -n argocd -o jsonpath='{.status.sync.status}')
    HEALTH=$(kubectl get applications.argoproj.io taskly-staging -n argocd -o jsonpath='{.status.health.status}')
    echo "ArgoCD sync: $SYNC | health: $HEALTH"
    if [[ "$SYNC" == "Synced" && "$HEALTH" == "Healthy" ]]; then
        check "ArgoCD staging application" PASS "Synced and Healthy"
    else
        check "ArgoCD staging application" FAIL "Sync/health requires attention"
    fi
else
    check "ArgoCD staging application" VERIFY "Application not found or ArgoCD unavailable"
fi

# --------------------------------------------------
echo
echo "=================================================="
echo "                AUDIT SUMMARY"
echo "=================================================="
echo "PASS:   $PASS"
echo "FAIL:   $FAIL"
echo "VERIFY: $WARN"
echo
echo "Note: PASS means evidence was found, not that every"
echo "external workflow or notification was functionally tested."
echo "Terraform destroy is deliberately NOT executed."
echo "=================================================="
