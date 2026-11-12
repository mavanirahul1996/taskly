#!/bin/bash

echo "======================================"
echo " TASKLY MONITORING READINESS CHECK"
echo "======================================"

echo ""
echo "1. HELM VERSION"
if command -v helm >/dev/null 2>&1; then
    helm version --short
else
    echo "Helm is NOT installed"
fi

echo ""
echo "2. NODE CAPACITY"
kubectl describe nodes | grep -A8 "Allocated resources"

echo ""
echo "3. RUNNING PODS"
kubectl get pods -A

echo ""
echo "4. NODE RESOURCE USAGE"
if kubectl top nodes 2>/dev/null; then
    echo "Metrics available"
else
    echo "Metrics Server data unavailable"
fi

echo ""
echo "5. TASKLY METRICS ENDPOINT"
kubectl port-forward -n taskly-staging \
  svc/taskly-api 18000:8000 >/tmp/taskly-monitoring-portforward.log 2>&1 &

PF_PID=$!
sleep 5

if curl -fsS http://localhost:18000/metrics \
  -o /tmp/taskly-metrics.txt; then
    echo "Metrics endpoint is working"
    grep -E 'http_requests_total|http_request_duration_seconds|tasks_created_total' \
      /tmp/taskly-metrics.txt | head -15
else
    echo "Metrics endpoint check failed"
    cat /tmp/taskly-monitoring-portforward.log
fi

kill "$PF_PID" 2>/dev/null || true

echo ""
echo "6. EXISTING MONITORING NAMESPACE"
kubectl get namespace monitoring 2>/dev/null || \
  echo "Monitoring namespace not created yet"

echo ""
echo "======================================"
echo " PRECHECK COMPLETED"
echo "======================================"
