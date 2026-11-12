#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$PWD/terraform/environments"
STAGING="$ROOT/staging"
PRODUCTION="$ROOT/production"
REGION="eu-central-1"

echo "================================================"
echo "       TASKLY INFRASTRUCTURE FINAL CHECK"
echo "================================================"

command -v terraform >/dev/null || { echo "Terraform missing"; exit 1; }
command -v aws >/dev/null || { echo "AWS CLI missing"; exit 1; }

echo
echo "1. AWS ACCOUNT"
aws sts get-caller-identity
echo "Region: $REGION"

echo
echo "2. LIVE MANAGED INFRASTRUCTURE"
aws eks describe-cluster --name taskly-staging \
  --region "$REGION" \
  --query 'cluster.{Name:name,Status:status}' --output table

aws rds describe-db-instances --region "$REGION" \
  --query "DBInstances[?DBInstanceIdentifier=='taskly-staging-postgres'].{ID:DBInstanceIdentifier,Engine:Engine,Status:DBInstanceStatus}" \
  --output table

aws elasticache describe-replication-groups --region "$REGION" \
  --query "ReplicationGroups[?ReplicationGroupId=='taskly-staging-redis'].{ID:ReplicationGroupId,Status:Status,Engine:Engine}" \
  --output table

echo
echo "3. STAGING TERRAFORM VALIDATION"
cd "$STAGING"
terraform init -input=false
terraform validate
terraform state list

echo
echo "4. ENTER EXISTING TERRAFORM SECRETS"
echo "Use the SAME values used when creating the existing RDS and Redis."
read -rsp "Existing PostgreSQL password: " DB_PASSWORD
echo
read -rsp "Existing Redis auth token: " REDIS_TOKEN
echo

if [[ -z "$DB_PASSWORD" || -z "$REDIS_TOKEN" ]]; then
  echo "ERROR: Both existing secrets are required."
  unset DB_PASSWORD REDIS_TOKEN
  exit 1
fi

export TF_VAR_db_password_rahul="$DB_PASSWORD"
export TF_VAR_redis_auth_token_rahul="$REDIS_TOKEN"
unset DB_PASSWORD REDIS_TOKEN

echo
echo "5. STAGING TERRAFORM PLAN"
PLAN="/tmp/taskly-staging-final-review.tfplan"

set +e
terraform plan -input=false -lock-timeout=30s \
  -out="$PLAN"
PLAN_EXIT=$?
set -e

unset TF_VAR_db_password_rahul TF_VAR_redis_auth_token_rahul

if [[ "$PLAN_EXIT" -ne 0 ]]; then
  echo "ERROR: Staging plan failed. Review the Terraform error."
  exit "$PLAN_EXIT"
fi

echo
echo "6. PLAN SUMMARY"
terraform show -no-color "$PLAN" | tail -45

echo
echo "IMPORTANT: No terraform apply or destroy was executed."
echo "Review the plan for replacement or destruction before applying."

echo
echo "7. PRODUCTION CONFIGURATION"
if [[ -d "$PRODUCTION" ]]; then
  echo "[FOUND] $PRODUCTION"
  find "$PRODUCTION" -maxdepth 2 -type f \
    ! -path '*/.terraform/*' -print

  if find "$PRODUCTION" -maxdepth 1 -name '*.tf' -print -quit | grep -q .; then
    cd "$PRODUCTION"
    echo "Production Terraform validation:"
    terraform init -backend=false -input=false
    terraform validate
  else
    echo "[PENDING] Production Terraform root has no .tf configuration."
  fi
else
  echo "[PENDING] Production directory missing."
fi

echo
echo "================================================"
echo "       INFRASTRUCTURE REVIEW FINISHED"
echo "================================================"
echo "Staging plan: $PLAN"
echo "No resources were created, modified or deleted."
