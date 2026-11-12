# Tasks API

A minimal FastAPI task tracker backed by Postgres, with a Redis read-through cache.

## Quick Start (Docker)

```bash
docker compose up
```

This starts three containers — `api`, `db` (Postgres), and `redis` — wired together with the
right env vars and healthchecks. The API is then available at http://localhost:8000, and
Postgres/Redis are also published to `localhost:5432` / `localhost:6379` so you can reach them
from tools or scripts running on your host (e.g. the model training scripts below).

Once it's up:

```bash
curl http://localhost:8000/health
# {"status":"ok","service":"tasks-api"}
```

## Running Locally Without Docker

**Use Python 3.10–3.12.** The pinned `pydantic==2.7.0` / `pydantic-core==2.18.1` has no
prebuilt wheel for Python 3.13+, so pip will try to compile it from source and fail. If
`python3 -V` shows 3.13 or newer, install 3.12 separately (e.g. `brew install python@3.12`)
and use that to create the venv below.

The app still needs a Postgres database and a Redis instance to run, even outside Docker. The
easiest way to get both is to let Docker run just those two:

```bash
docker compose up -d db redis
```

Then run the API itself on your host:

```bash
python3.12 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload
```

By default the app connects to `postgresql+psycopg2://tasks:tasks@localhost:5432/tasks` and
`redis://localhost:6379/0` — override with the `DATABASE_URL` / `REDIS_URL` env vars if your
setup differs.

## Using the Swagger UI

FastAPI serves interactive API docs (Swagger UI) at `/docs` whenever the app is running.

1. Start the app (`uvicorn main:app --reload` or `docker compose up`).
2. Open http://localhost:8000/docs in a browser.
3. Expand an endpoint, e.g. `POST /tasks`, and click **Try it out**.
4. Edit the example request body, e.g.:
   ```json
   {
     "title": "Write the report",
     "description": "Due Friday",
     "priority": "medium"
   }
   ```
5. Click **Execute** to send the request and see the live response below, including the
   assigned `id`.
6. Use the `id` from that response to try `GET /tasks/{task_id}`, `PATCH /tasks/{task_id}`, or
   `DELETE /tasks/{task_id}` the same way.
7. `GET /tasks` lists everything currently stored; `GET /health` is a quick liveness check.

A raw OpenAPI schema is also available at `/openapi.json` if you want to feed it into another
tool (Postman, codegen, etc).

## Running Tests

```bash
python3.12 -m venv .venv-dev
source .venv-dev/bin/activate   # Windows: .venv-dev\Scripts\activate
pip install -r requirements-dev.txt
pytest
```

The test suite (`tests/`) covers the CRUD endpoints and cache invalidation. It runs against an
in-memory SQLite database and a fake Redis client, so it needs neither Docker nor a real
Postgres/Redis instance — safe to run on its own, with or without `docker compose up`.

## Verifying the API End-to-End

A quick manual smoke test once the app is running (via Docker or locally), beyond the Swagger
UI:

```bash
# health check
curl http://localhost:8000/health

# create a task
curl -X POST http://localhost:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Write report","description":"Due Friday","priority":"medium"}'

# list tasks (id from the response above)
curl http://localhost:8000/tasks

# fetch, update, delete a single task
curl http://localhost:8000/tasks/1
curl -X PATCH http://localhost:8000/tasks/1 -H "Content-Type: application/json" \
  -d '{"title":"Write report","done":true,"priority":"high"}'
curl -X DELETE http://localhost:8000/tasks/1 -w "%{http_code}\n"

# both should now 404
curl -w "%{http_code}\n" http://localhost:8000/tasks/1
curl -w "%{http_code}\n" http://localhost:8000/tasks/999
```

If you want to confirm the data is really persisted in Postgres and cached in Redis rather than
held in memory:

```bash
docker compose exec db psql -U tasks -d tasks -c "select * from tasks;"
docker compose exec redis redis-cli keys '*'
```

## Task-priority model

`model/train.py` trains a trivial TF-IDF + logistic regression classifier that predicts a
task's `priority` (low/medium/high) from its title + description, and logs it to MLflow. It's
the starter kit for the MLFlowOps project option. Unlike the app itself, this part of the repo
uses its own venv (see below) to keep the ML dependencies (`mlflow`, `pandas`, `scikit-learn`)
out of the API's runtime image, and it is **not** part of `compose.yaml` — it's meant to be run
from your host against the app's Postgres database.

Training reads directly from the app's Postgres `tasks` table — any task with a `priority` set
(via the API/Swagger or the seed script below) becomes a training row. There's no separate
dataset file to keep in sync with the app.

### Step by step: seed data and train, alongside `docker compose up`

1. **Start the app stack** (need at least Postgres reachable; the full stack is fine too):
   ```bash
   docker compose up -d
   ```
   Postgres is published on `localhost:5432`, so scripts run on your host can reach it with the
   same default `DATABASE_URL` the app uses.

2. **Set up the model venv** (separate from the app's venv):

   **Use Python 3.10–3.12.** `mlflow` pulls in `pyarrow`, which has no prebuilt wheel for very
   new Python versions (3.13+) on several platforms — pip will try to build it from source and
   fail with a `cmake` error unless you have the full C++ build toolchain installed. If
   `python3 -V` shows 3.13 or newer, install 3.12 separately (e.g. `brew install python@3.12`)
   and use that to create the venv below.
   ```bash
   python3.12 -m venv .venv-model
   source .venv-model/bin/activate   # Windows: .venv-model\Scripts\activate
   pip install -r model/requirements.txt
   ```

3. **Seed labeled data** into the running Postgres container (or create your own tasks with a
   `priority` through the API/Swagger UI instead):
   ```bash
   DATABASE_URL=postgresql+psycopg2://tasks:tasks@localhost:5432/tasks python model/generate_data.py
   ```

4. **Start a local MLflow tracking server** — this isn't part of `docker compose`, so run it
   yourself, in another terminal, still inside `.venv-model`:
   ```bash
   mlflow server --host 127.0.0.1 --port 5050 --backend-store-uri ./mlruns
   ```
   > On macOS, avoid the commonly-used port 5000 — it's usually already bound by the built-in
   > AirPlay Receiver, and MLflow will fail to start there with a confusing "Address already in
   > use" error. Port 5050 (as above) or any other free port works fine.

5. **Run training**, pointing at both the database and the tracking server:
   ```bash
   DATABASE_URL=postgresql+psycopg2://tasks:tasks@localhost:5432/tasks \
   MLFLOW_TRACKING_URI=http://127.0.0.1:5050 \
   python model/train.py
   ```
   You should see something like `accuracy=1.000 f1_macro=1.000` printed at the end (the
   synthetic seed data is intentionally easy to classify perfectly — real usage data will be
   noisier).

6. **Verify the run landed in MLflow**: open http://127.0.0.1:5050 in a browser, find the
   `task-priority-classifier` experiment, and confirm the run shows the logged params
   (`train_rows`, `test_rows`, `model_type`), metrics (`accuracy`, `f1_macro`), and a registered
   model version.

If you run `train.py` before any labeled tasks exist, it fails fast with a clear error telling
you to run `generate_data.py` or create tasks with a `priority` first, rather than crashing
deep inside pandas/scikit-learn.

<!-- TASKLY_FINAL_SECTION_START -->

# Taskly – Final DevOps Project

## Project overview

Taskly is a task-management application built with a FastAPI backend.
The project uses PostgreSQL for persistent data and Redis for caching.
Docker packages the application, while Kubernetes runs the application
containers.

The current cloud implementation is deployed to AWS EKS in the staging
environment. Production infrastructure has not been provisioned.

## Architecture

```text
Developer
   |
   v
GitHub Repository
   |
   v
GitHub Actions
   |-- Automated tests
   |-- Container security scan
   |-- Docker image build and push
   |
   v
DockerHub
   |
   v
Kubernetes / AWS EKS (Staging)
   |
   |-- Taskly API
   |-- PostgreSQL (AWS RDS)
   |-- Redis (AWS ElastiCache)
   |
   v
Monitoring
   |-- Prometheus
   |-- Grafana
   |-- Loki
   |-- Promtail
   |-- Alertmanager
```

## AWS infrastructure provisioning

Terraform configuration is maintained under the `terraform/` directory.
Review the environment configuration before provisioning resources.

Example commands:

```bash
cd terraform/environments/staging
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Review the Terraform plan before considering any infrastructure change.
Do not run `terraform apply` or `terraform destroy` without reviewing
the proposed changes and confirming the expected AWS costs.

## Staging deployment

Check the current Kubernetes context:

```bash
kubectl config current-context
kubectl get nodes
kubectl get pods -n taskly-staging
kubectl get deployments -n taskly-staging
kubectl get services -n taskly-staging
```

Check application rollout:

```bash
kubectl rollout status deployment/taskly-api -n taskly-staging
```

Check application logs:

```bash
kubectl logs deployment/taskly-api -n taskly-staging --since=10m
```

To inspect JSON-formatted log lines when `jq` is installed:

```bash
kubectl logs deployment/taskly-api -n taskly-staging --since=10m \
  | jq -R 'fromjson? // .'
```

## CI/CD pipeline

The GitHub Actions pipeline currently handles automated testing,
container image build/push, and staging manifest updates.

A separate security workflow scans repository files and configuration
using Trivy. Findings classified as HIGH or CRITICAL fail the scan.

The production deployment workflow is a disabled template. It requires:

- A provisioned production EKS cluster.
- A production Kubernetes overlay at `k8s/overlays/production`.
- An AWS IAM role configured for GitHub Actions OIDC.
- GitHub repository variables for production configuration.
- A protected GitHub Environment named `production`, with required
  reviewers configured in GitHub Settings.

Production deployment is NOT currently active or completed.

## Monitoring and Grafana

Start Grafana port forwarding:

```bash
kubectl port-forward -n monitoring \
  svc/taskly-monitoring-grafana 13000:80
```

Open:

```text
http://localhost:13000
```

Dashboard:

```text
http://localhost:13000/d/taskly-final-monitoring
```

Retrieve the Grafana admin password from the Kubernetes Secret rather
than storing credentials in this README:

```bash
SECRET=$(kubectl get secret -n monitoring \
  -l app.kubernetes.io/name=grafana,app.kubernetes.io/instance=taskly-monitoring \
  -o jsonpath='{.items[0].metadata.name}')

kubectl get secret "$SECRET" -n monitoring \
  -o jsonpath='{.data.admin-password}' | base64 -d
echo
```

For the final presentation, verify these four dashboard panels:

1. API request rate.
2. HTTP 5xx error rate.
3. API p95 latency.
4. Active tasks count.

Do not claim the fourth panel is implemented until it is visible and
working with real application data.

## Alerts

Check the configured Prometheus alert rules:

```bash
kubectl get prometheusrules -A
```

Check alert status in Prometheus:

```bash
kubectl port-forward -n monitoring \
  svc/taskly-monitoring-kube-prometheus-prometheus 19090:9090
```

Open:

```text
http://localhost:19090/alerts
```

Check Alertmanager:

```bash
kubectl port-forward -n monitoring \
  svc/taskly-monitoring-kube-prometheus-alertmanager 19093:9093
```

Open:

```text
http://localhost:19093
```

Configured alert rules do not prove that Slack or email notifications
were delivered. Test the configured receiver and confirm receipt before
presenting alert delivery as verified.

## Rollback procedure

First inspect rollout history:

```bash
kubectl rollout history deployment/taskly-api -n taskly-staging
```

Review the available revisions. To roll back the staging deployment:

```bash
kubectl rollout undo deployment/taskly-api -n taskly-staging
```

Verify the result:

```bash
kubectl rollout status deployment/taskly-api -n taskly-staging
kubectl get pods -n taskly-staging
```

Only describe rollback as tested after successfully performing and
verifying this procedure.

## Azure equivalent architecture

The current project is implemented on AWS. The following table shows
how the architecture could be adapted to Microsoft Azure.

| AWS service | Azure equivalent |
|---|---|
| Amazon EKS | Azure Kubernetes Service (AKS) |
| VPC / Subnets | Azure Virtual Network / Subnets |
| Security Groups | Network Security Groups |
| Amazon RDS PostgreSQL | Azure Database for PostgreSQL Flexible Server |
| Amazon ElastiCache Redis | Azure Managed Redis |
| EKS Pod Identity / IAM roles | Microsoft Entra Workload ID / Managed Identity |
| DockerHub (current image registry) | Azure Container Registry (ACR) |
| Prometheus / Grafana / Loki | Can run on AKS; Azure Monitor is another option |
| Terraform | Terraform |
| GitHub Actions | GitHub Actions |

This Azure section is an architecture mapping, not a deployed or
tested Azure environment.

## Final verification checklist

- [ ] GitHub Actions tests pass.
- [ ] Trivy security scan passes or findings are reviewed.
- [ ] Staging application is healthy.
- [ ] Grafana dashboard shows all four required panels.
- [ ] JSON logs are visible in Loki.
- [ ] Rollback has been executed and verified.
- [ ] Slack/email alert delivery has been confirmed.
- [ ] Production deployment remains clearly identified as not deployed.

<!-- TASKLY_FINAL_SECTION_END -->
