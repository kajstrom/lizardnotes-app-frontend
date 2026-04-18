#!/usr/bin/env bash
set -euo pipefail

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

echo "Config fetched. Building Flutter web release..."

flutter build web --release \
  --dart-define=API_URL="$API_URL" \
  --dart-define=COGNITO_USER_POOL_ID="$COGNITO_USER_POOL_ID" \
  --dart-define=COGNITO_APP_CLIENT_ID="$COGNITO_APP_CLIENT_ID"

echo "Build complete. Output in build/web/"
