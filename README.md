# Taskly — DevOps & Cloud Engineering Project

[![Taskly CI/CD](https://github.com/mavanirahul1996/taskly/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/mavanirahul1996/taskly/actions/workflows/ci-cd.yml)

Taskly is a task-management REST API built with **FastAPI**, **PostgreSQL** and **Redis**. This repository brings together application development and practical DevOps learning: Docker, automated tests, GitHub Actions, Terraform, Kubernetes and observability.

> **Project status:** The local Docker Compose stack and automated test workflow are defined in the repository. The CI workflow builds and pushes an image and updates the staging Kubernetes manifest on pushes to `main`. Production deployment is not active. Treat staging as a learning environment and verify the live cluster before describing it as currently running.

## Project at a glance

| Area | Technology |
|---|---|
| API | Python, FastAPI, Pydantic |
| Persistence | PostgreSQL, SQLAlchemy |
| Cache | Redis |
| Containers | Docker, Docker Compose |
| Tests | pytest, SQLite test database, fake Redis client |
| CI/CD | GitHub Actions, Docker Hub |
| Infrastructure as Code | Terraform modules for AWS networking, EKS, RDS and Redis |
| Orchestration | Kubernetes, Kustomize |
| Observability | Prometheus metrics, Grafana, Loki and alerting configuration |
| ML experiment | scikit-learn, MLflow (optional learning component) |

## Architecture

```mermaid
flowchart TD
    Client[Client / Swagger UI] --> API[FastAPI service]
    API --> DB[(PostgreSQL)]
    API --> Cache[(Redis)]
    API --> Metrics[/metrics endpoint]
    Metrics --> Prom[Prometheus]
    Prom --> Grafana[Grafana dashboards]
    API --> Logs[Structured application logs]
    Logs --> Loki[Loki]
    Dev[Developer push to main] --> CI[GitHub Actions]
    CI --> Tests[pytest]
    Tests --> Build[Build container image]
    Build --> Registry[Docker Hub]
    CI --> Manifest[Update staging image reference]
    Manifest --> K8s[Kubernetes staging manifests]
    TF[Terraform] --> AWS[AWS VPC, EKS, RDS and Redis]
```

The workflow updates the staging manifest after a successful test and image build. The workflow file does not itself run `kubectl apply`; a separate cluster-side sync or deployment action is required to roll that manifest out.

## Application features

- Create, list, retrieve, update and delete tasks.
- Store task records in PostgreSQL.
- Cache task data in Redis and invalidate cached records after writes.
- Health endpoint at `/health`.
- Prometheus metrics endpoint at `/metrics`.
- Structured request logs with a trace ID response header.
- Interactive API documentation at `/docs`.

## Run locally with Docker Compose

### Prerequisites

- Docker Engine or Docker Desktop
- Docker Compose plugin

Start the API, PostgreSQL and Redis:

```bash
docker compose up --build
```

Check the health endpoint:

```bash
curl http://localhost:8000/health
```

Open the interactive API documentation at [http://localhost:8000/docs](http://localhost:8000/docs).

The Compose file uses learning credentials and publishes PostgreSQL and Redis ports to localhost. Do not reuse the sample credentials or expose these services publicly.

## Run tests

The test suite uses an in-memory SQLite database and a fake Redis client, so it does not require the local PostgreSQL or Redis containers.

```bash
python3.12 -m venv .venv-dev
source .venv-dev/bin/activate
pip install -r requirements-dev.txt
PYTHONPATH=. pytest -v
```

The GitHub Actions workflow at [`.github/workflows/ci-cd.yml`](.github/workflows/ci-cd.yml) runs the tests on pushes and pull requests. On a push to `main`, it then builds and pushes the Docker image and updates the image tag in `k8s/base/deployment.yaml`.

Required GitHub Actions secrets for the image-push job:
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

## AWS infrastructure with Terraform

Terraform configuration for the staging environment is under `terraform/environments/staging`. The environment composes modules for a VPC, EKS, RDS and Redis.

Review the plan before making any infrastructure change:

```bash
cd terraform/environments/staging
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Do not run `terraform apply` or `terraform destroy` without reviewing the proposed changes, confirming the AWS account and region, and understanding the expected cost. Supply credentials through secure variables or a secret manager; do not commit real passwords or tokens.

## Kubernetes staging checks

The staging overlay is under `k8s/overlays/staging`. Before running commands, confirm that your current context points to the intended cluster:

```bash
kubectl config current-context
kubectl get nodes
kubectl get pods -n taskly-staging
kubectl get deployments -n taskly-staging
kubectl get services -n taskly-staging
```

If the application is deployed, inspect its rollout and logs:

```bash
kubectl rollout status deployment/taskly-api -n taskly-staging
kubectl logs deployment/taskly-api -n taskly-staging --since=10m
```

The manifests use Kubernetes Secrets for database and Redis connection strings. Create and populate those Secrets securely in the target namespace before starting the application.

## Monitoring

The application exposes Prometheus metrics at `/metrics`. The repository's monitoring instructions use Prometheus, Grafana and Loki.

For a configured staging monitoring stack, the README's Grafana port-forward example is:

```bash
kubectl port-forward -n monitoring svc/taskly-monitoring-grafana 13000:80
```

Then open [http://localhost:13000](http://localhost:13000). Retrieve credentials from the Kubernetes Secret; never store passwords in this README.

Configured alert rules do not prove that notifications were delivered. Verify the receiver and confirm receipt before describing Slack or email alerting as operational.

## Optional: task-priority ML experiment

The `model/` directory contains a separate learning exercise: a TF-IDF and logistic-regression classifier that predicts task priority from task text and logs an experiment to MLflow. It is not part of the API's Docker Compose runtime.

Use Python 3.10–3.12 for the model dependencies. Start the app stack, install `model/requirements.txt` in a separate virtual environment, seed sample tasks with `model/generate_data.py`, start an MLflow tracking server, and run `model/train.py`. The synthetic sample dataset is intentionally simple; its scores should not be presented as real-world model performance.

## Current scope and honest limitations

- Production deployment is not configured as an active release process.
- The CI workflow updates the staging manifest but does not run `kubectl apply` itself.
- Terraform configuration is infrastructure code; running `terraform plan` does not prove that resources are currently provisioned.
- Monitoring and alert configuration must be verified in the target cluster before claiming that dashboards or notifications are live.
- Review and rotate any learning credentials before using a shared or public environment.

## What this project demonstrates

Building and testing a Python API, connecting persistent and cached data services, packaging with Docker, automating CI with GitHub Actions, managing AWS infrastructure with Terraform, deploying through Kubernetes manifests and instrumenting an application for observability.


## Security scanning and current hardening status

The GitHub Actions Trivy workflow scans the repository for HIGH and CRITICAL vulnerabilities, infrastructure misconfigurations and exposed secrets. It is intentionally configured as a security gate: findings should be reviewed and fixed, not hidden by changing the scanner to always pass.

Recent hardening changes:
- The Taskly API Kubernetes container now uses a read-only root filesystem and a dedicated writable `/tmp` volume.
- The EKS Terraform module now configures KMS encryption for Kubernetes Secrets, with automatic key rotation.
- The RDS and Redis security groups no longer define unrestricted outbound rules.

The latest scan still reports infrastructure risks that need an architecture decision:
- The EKS API endpoint is public, although access is restricted to a single IPv4 `/32` allowlist. Trivy still flags public endpoint access.
- The public subnets automatically assign public IP addresses. The current learning environment places EKS worker nodes in those subnets.

For a production design, move worker nodes to private subnets, provide controlled outbound access through NAT or required VPC endpoints, and administer the cluster through VPN, SSM or a private runner before disabling public endpoint access. Do not apply those networking changes without checking connectivity and AWS costs first.

**Current status:** the security scan remains red by design until the remaining public-access and subnet findings are resolved. The KMS customer-managed key also has ongoing AWS charges; review current KMS pricing before applying the Terraform changes.
