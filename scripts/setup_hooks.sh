#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

git config core.hooksPath .githooks
chmod +x .githooks/pre-commit

echo "Git hooks installed (.githooks/)."
