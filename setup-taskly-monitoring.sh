#!/bin/bash
set -e

echo "===== TASKLY MONITORING STACK ====="

# Verify Kubernetes context
CONTEXT=$(kubectl config current-context)
echo "Current context: $CONTEXT"

if [[ "$CONTEXT" != *"taskly-staging"* ]]; then
    echo "ERROR: Wrong Kubernetes context. Stopping."
    exit 1
fi

# Create monitoring namespace
kubectl create namespace monitoring \
  --dry-run=client -o yaml | kubectl apply -f -

# Add Helm repositories
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts \
  --force-update

helm repo add grafana \
  https://grafana.github.io/helm-charts \
  --force-update

helm repo update

# Prometheus + Grafana + Alertmanager
cat > /tmp/taskly-monitoring-values.yaml <<'VALUES'
grafana:
  enabled: true
  adminPassword: "taskly-admin-change-me"
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
  persistence:
    enabled: false
  additionalDataSources:
    - name: Loki
      type: loki
      access: proxy
      url: http://taskly-loki.monitoring.svc.cluster.local:3100
      isDefault: false

prometheus:
  enabled: true
  prometheusSpec:
    replicas: 1
    retention: 24h
    scrapeInterval: 15s
    evaluationInterval: 30s
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: 500m
        memory: 768Mi
    storageSpec: {}
    additionalScrapeConfigs:
      - job_name: taskly-api
        metrics_path: /metrics
        scrape_interval: 15s
        static_configs:
          - targets:
              - taskly-api.taskly-staging.svc.cluster.local:8000

alertmanager:
  enabled: true
  alertmanagerSpec:
    replicas: 1
    resources:
      requests:
        cpu: 25m
        memory: 64Mi
      limits:
        cpu: 100m
        memory: 128Mi
    storage: {}

prometheusOperator:
  resources:
    requests:
      cpu: 50m
      memory: 100Mi
    limits:
      cpu: 200m
      memory: 200Mi

kube-state-metrics:
  enabled: true
  resources:
    requests:
      cpu: 25m
      memory: 64Mi
    limits:
      cpu: 100m
      memory: 128Mi

nodeExporter:
  enabled: false

prometheus-node-exporter:
  enabled: false

defaultRules:
  create: false
VALUES

echo "Installing Prometheus, Grafana and Alertmanager..."

helm upgrade --install taskly-monitoring \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values /tmp/taskly-monitoring-values.yaml \
  --wait \
  --timeout 10m

# Install Loki
cat > /tmp/taskly-loki-values.yaml <<'VALUES'
deploymentMode: SingleBinary

loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  storage:
    type: filesystem
  schemaConfig:
    configs:
      - from: "2024-04-01"
        store: tsdb
        object_store: filesystem
        schema: v13
        index:
          prefix: index_
          period: 24h

singleBinary:
  replicas: 1
  persistence:
    enabled: false
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi

read:
  replicas: 0
write:
  replicas: 0
backend:
  replicas: 0

gateway:
  enabled: false

chunksCache:
  enabled: false
resultsCache:
  enabled: false

test:
  enabled: false
lokiCanary:
  enabled: false
VALUES

echo "Installing Loki..."

helm upgrade --install taskly-loki \
  grafana/loki \
  --namespace monitoring \
  --values /tmp/taskly-loki-values.yaml \
  --wait \
  --timeout 10m

# Install Promtail to collect Kubernetes container logs
cat > /tmp/taskly-promtail-values.yaml <<'VALUES'
config:
  clients:
    - url: http://taskly-loki.monitoring.svc.cluster.local:3100/loki/api/v1/push

resources:
  requests:
    cpu: 25m
    memory: 64Mi
  limits:
    cpu: 100m
    memory: 128Mi
VALUES

echo "Installing Promtail..."

helm upgrade --install taskly-promtail \
  grafana/promtail \
  --namespace monitoring \
  --values /tmp/taskly-promtail-values.yaml \
  --wait \
  --timeout 5m

# Create three Taskly alert rules
cat > /tmp/taskly-alerts.yaml <<'YAML'
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: taskly-alerts
  namespace: monitoring
  labels:
    release: taskly-monitoring
spec:
  groups:
    - name: taskly-api-alerts
      rules:
        - alert: TasklyHighErrorRate
          expr: |
            sum(rate(http_requests_total{status=~"5.."}[5m]))
            /
            clamp_min(sum(rate(http_requests_total[5m])), 0.001) > 0.05
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Taskly API error rate is above 5%"

        - alert: TasklyHighLatency
          expr: |
            histogram_quantile(0.95,
              sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
            ) > 1
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Taskly API p95 latency is above 1 second"

        - alert: TasklyAPIDown
          expr: up{job="taskly-api"} == 0
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "Taskly API is unavailable"
YAML

echo "Applying Taskly alert rules..."
kubectl apply -f /tmp/taskly-alerts.yaml

echo ""
echo "Waiting for monitoring pods..."
kubectl get pods -n monitoring

echo ""
echo "===== MONITORING SERVICES ====="
kubectl get services -n monitoring

echo ""
echo "===== ALERT RULES ====="
kubectl get prometheusrules -n monitoring

echo ""
echo "===== STEP 14 INSTALLATION COMPLETED ====="
