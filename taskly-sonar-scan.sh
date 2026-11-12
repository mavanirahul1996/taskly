#!/bin/bash
set -e

echo "Installing SonarScanner..."

sudo apt-get update
sudo apt-get install -y unzip curl openjdk-17-jre

VERSION="7.2.0.5079"
ZIP="sonar-scanner-cli-${VERSION}-linux-x64.zip"

curl -fL \
"https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/${ZIP}" \
-o "/tmp/${ZIP}"

sudo unzip -o "/tmp/${ZIP}" -d /opt

sudo ln -sf \
"/opt/sonar-scanner-${VERSION}-linux-x64/bin/sonar-scanner" \
/usr/local/bin/sonar-scanner

echo ""
echo "SonarScanner installed:"
sonar-scanner --version

echo ""
read -rsp "Paste your SonarQube token: " SONAR_TOKEN
echo ""

if [ -z "$SONAR_TOKEN" ]; then
    echo "ERROR: Token is empty."
    exit 1
fi

export SONAR_TOKEN

echo ""
echo "Starting Taskly code scan..."

sonar-scanner \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.token="$SONAR_TOKEN"

unset SONAR_TOKEN

echo ""
echo "Scan submitted successfully."
echo "Check Quality Gate: http://localhost:9000"
