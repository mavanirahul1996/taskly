#!/bin/bash
set -e

echo "=================================="
echo " INSTALLING TASKLY SONARQUBE"
echo "=================================="

# Check Docker
if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker is not running."
    exit 1
fi

# Check port 9000
if (echo >/dev/tcp/127.0.0.1/9000) 2>/dev/null; then
    echo "ERROR: Port 9000 is already in use."
    exit 1
fi

# Set open-file limit for this session
ulimit -n 131072 || {
    echo "ERROR: Could not increase open-file limit."
    echo "Please send me: ulimit -Hn"
    exit 1
}

# Correct local SonarQube project configuration
cat > sonar-project.properties <<'PROPERTIES'
sonar.projectKey=taskly
sonar.projectName=Taskly
sonar.sources=.
sonar.tests=tests
sonar.python.version=3.12
sonar.sourceEncoding=UTF-8
sonar.exclusions=**/.venv/**,**/.venv-dev/**,**/__pycache__/**,**/.pytest_cache/**,**/terraform/**,**/k8s/**,**/.git/**
sonar.test.inclusions=tests/**/*.py
PROPERTIES

# Download official free Community Build
docker pull sonarqube:community

# Create persistent volumes
docker volume create taskly_sonarqube_data
docker volume create taskly_sonarqube_extensions
docker volume create taskly_sonarqube_logs

# Start SonarQube
docker run -d \
  --name taskly-sonarqube \
  --restart unless-stopped \
  --memory=5g \
  --memory-swap=5g \
  --cpus=4 \
  --ulimit nofile=131072:131072 \
  --ulimit nproc=8192:8192 \
  -p 9000:9000 \
  -v taskly_sonarqube_data:/opt/sonarqube/data \
  -v taskly_sonarqube_extensions:/opt/sonarqube/extensions \
  -v taskly_sonarqube_logs:/opt/sonarqube/logs \
  sonarqube:community

echo ""
echo "SonarQube container started."
echo "Waiting for startup..."

for i in $(seq 1 60); do
    if curl -fsS http://localhost:9000/api/system/status >/dev/null 2>&1; then
        echo ""
        echo "SONARQUBE IS RESPONDING!"
        break
    fi
    sleep 5
done

echo ""
docker ps --filter name=taskly-sonarqube
echo ""
docker logs --tail 20 taskly-sonarqube

echo ""
echo "Open: http://localhost:9000"
echo "Default login: admin"
echo "Default password: admin"
