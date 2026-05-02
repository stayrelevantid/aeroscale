#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../infrastructure/terraform"

echo "============================================"
echo "  AeroScale — Terraform Destroy"
echo "============================================"
echo ""
echo "  WARNING: This will destroy ALL infrastructure"
echo "  - VPC, Subnet, Firewall"
echo "  - GKE Cluster"
echo "  - Pub/Sub Topic & Subscription"
echo "  - Cloud NAT & Router"
echo "  - Service Accounts & IAM bindings"
echo "  - Artifact Registry"
echo "  - KEDA Helm release & namespace"
echo ""
echo "  State will be removed from GCS backend."
echo ""

cd "${TF_DIR}"

echo "==> Running terraform plan -destroy..."
terraform plan -destroy -out=destroy.tfplan

echo ""
echo "==> Review the plan above carefully."
read -rp "Are you sure you want to destroy ALL resources? (y/N): " confirm

if [[ "${confirm,,}" != "y" ]]; then
    echo "Aborted."
    exit 0
fi

echo "==> Destroying infrastructure..."
terraform destroy -auto-approve destroy.tfplan

echo ""
echo "==> Destruction complete."
echo "==> Remaining state:"
terraform state list 2>/dev/null || echo "(state is empty)"

echo ""
echo "==> Cleanup: removing destroy plan file..."
rm -f destroy.tfplan