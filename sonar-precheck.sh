#!/bin/bash

echo "======================================"
echo "     SONARQUBE READINESS CHECK"
echo "======================================"

echo ""
echo "1. SYSTEM MEMORY"
free -h

echo ""
echo "2. DOCKER MEMORY LIMIT"
docker info --format 'Docker memory: {{.MemTotal}} bytes' 2>/dev/null

echo ""
echo "3. AVAILABLE DISK"
df -h .

echo ""
echo "4. CPU"
nproc

echo ""
echo "5. LINUX REQUIREMENTS"
sysctl vm.max_map_count
sysctl fs.file-max
ulimit -n
ulimit -u

echo ""
echo "6. SONAR SCANNER"
if command -v sonar-scanner >/dev/null 2>&1; then
    sonar-scanner --version
else
    echo "SonarScanner not installed"
fi

echo ""
echo "7. EXISTING SONAR CONFIG"
if [ -f sonar-project.properties ]; then
    cat sonar-project.properties
else
    echo "sonar-project.properties missing"
fi

echo ""
echo "8. CI SONAR CONFIG"
grep -nEi 'sonar|scan|qualitygate' \
    .github/workflows/ci-cd.yml 2>/dev/null || true

echo ""
echo "======================================"
echo "       PRECHECK COMPLETED"
echo "======================================"
