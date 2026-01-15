#!/bin/bash
# =============================================================================
# Destroy Script - インフラ削除
# =============================================================================

set -e

ENV=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "============================================="
echo "Destroying ${ENV} environment"
echo "============================================="
echo ""
echo "WARNING: This will destroy all resources!"
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

cd "${PROJECT_DIR}/terraform"

terraform destroy -var-file="environments/${ENV}.tfvars" -auto-approve

echo ""
echo "============================================="
echo "Destruction complete!"
echo "============================================="
