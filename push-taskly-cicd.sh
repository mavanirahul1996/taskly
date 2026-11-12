#!/bin/bash
set -e

echo "===== TASKLY CI/CD GIT PUSH ====="

# Ignore generated SonarQube files
touch .gitignore

grep -qxF '.scannerwork/' .gitignore || \
  echo '.scannerwork/' >> .gitignore

grep -qxF '.sonar/' .gitignore || \
  echo '.sonar/' >> .gitignore

# Validate workflow
git diff --check

# Stage only required files
git add .github/workflows/ci-cd.yml
git add sonar-project.properties
git add .gitignore

echo ""
echo "===== FILES TO COMMIT ====="
git diff --cached --stat

git commit -m "Add Taskly CI-CD with DockerHub and Argo CD deployment"

echo ""
echo "===== PUSHING TO GITHUB ====="
git push origin main

echo ""
echo "===== COMPLETED ====="
echo "Check: https://github.com/mavanirahul1996/taskly/actions"
