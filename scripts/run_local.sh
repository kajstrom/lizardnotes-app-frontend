#!/usr/bin/env bash
set -euo pipefail

# Detect Brave — apt installs to /usr/bin/brave-browser, snap installs to /snap/bin/brave
if [ -x "/usr/bin/brave-browser" ]; then
  BRAVE_PATH="/usr/bin/brave-browser"
elif [ -x "/snap/bin/brave" ]; then
  BRAVE_PATH="/snap/bin/brave"
else
  echo "Error: Brave browser not found."
  echo "Install via apt:  https://brave.com/linux/"
  echo "  or via snap:    snap install brave"
  exit 1
fi

echo "Fetching config from AWS SSM..."

fetch_ssm() {
  local param="$1"
  local value
  if ! value=$(aws ssm get-parameter --name "$param" --query "Parameter.Value" --output text 2>&1); then
    echo "Error: Failed to fetch SSM parameter '$param'"
    echo "$value"
    echo "Ensure the AWS CLI is configured with the correct account and region."
    exit 1
  fi
  echo "$value"
}

API_URL=$(fetch_ssm "/lizardnotes/apigateway/apiUrl")
COGNITO_USER_POOL_ID=$(fetch_ssm "/lizardnotes/cognito/userPoolId")
COGNITO_APP_CLIENT_ID=$(fetch_ssm "/lizardnotes/cognito/appClientId")

echo "Config fetched. Starting Flutter in Brave..."

CHROME_EXECUTABLE="$BRAVE_PATH" flutter run -d chrome \
  --dart-define=API_URL="$API_URL" \
  --dart-define=COGNITO_USER_POOL_ID="$COGNITO_USER_POOL_ID" \
  --dart-define=COGNITO_APP_CLIENT_ID="$COGNITO_APP_CLIENT_ID"
