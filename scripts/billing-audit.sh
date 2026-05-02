#!/bin/bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-stayrelevantid}"

echo "============================================"
echo "  AeroScale — Billing Audit"
echo "============================================"
echo "  Project: ${PROJECT_ID}"
echo "============================================"
echo ""

echo "==> Billing Account:"
gcloud beta billing accounts list --format="table(name,displayName,open)" 2>/dev/null || echo "  (no access or no billing accounts)"
echo ""

echo "==> Project Billing Status:"
gcloud beta billing projects describe "${PROJECT_ID}" --format="table(billingAccountName,billingEnabled)" 2>/dev/null || echo "  (could not retrieve)"
echo ""

echo "==> Enabled APIs/Services:"
gcloud services list --project="${PROJECT_ID}" --enabled --format="table(name,title)" 2>/dev/null || echo "  (could not retrieve)"
echo ""

echo "==> Budget Alerts (if any):"
gcloud billing budgets list \
    --billing-account=$(gcloud beta billing projects describe "${PROJECT_ID}" --format="value(billingAccountName)" 2>/dev/null | sed 's/billingAccounts\///' || echo "") \
    --format="table(name,displayName,amount)" 2>/dev/null || echo "  (no budgets or no access)"
echo ""

echo "==> Compute Engine Usage Summary:"
echo "  Instances:"
gcloud compute instances list --project="${PROJECT_ID}" --format="table(name,zone,status,machineType.basename())" 2>/dev/null || echo "    (none)"
echo "  Disks:"
gcloud compute disks list --project="${PROJECT_ID}" --format="table(name,zone,sizeGb,status)" 2>/dev/null || echo "    (none)"
echo ""

echo "============================================"
echo "  Billing audit complete."
echo "  Review GCP Console for detailed cost breakdown:"
echo "  https://console.cloud.google.com/billing?project=${PROJECT_ID}"
echo "============================================"