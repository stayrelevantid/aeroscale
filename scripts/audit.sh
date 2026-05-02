#!/bin/bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-stayrelevantid}"
REGION="${REGION:-asia-southeast1}"

echo "============================================"
echo "  AeroScale — Resource Audit"
echo "============================================"
echo "  Project: ${PROJECT_ID}"
echo "  Region:  ${REGION}"
echo "============================================"
echo ""

echo "==> Unattached Disks:"
gcloud compute disks list --project="${PROJECT_ID}" --filter="users:-" --format="table(name,zone,sizeGb,status)" 2>/dev/null || echo "  (none found)"
echo ""

echo "==> Forwarding Rules (Load Balancers):"
gcloud compute forwarding-rules list --project="${PROJECT_ID}" --format="table(name,region,target,ports)" 2>/dev/null || echo "  (none found)"
echo ""

echo "==> Static IP Addresses:"
gcloud compute addresses list --project="${PROJECT_ID}" --format="table(name,region,address,status)" 2>/dev/null || echo "  (none found)"
echo ""

echo "==> Firewall Rules:"
gcloud compute firewall-rules list --project="${PROJECT_ID}" --format="table(name,network,direction,priority,sourceRanges.list():label=SRC_RANGES,allowed[].map().list():label=ALLOW)" 2>/dev/null || echo "  (none found)"
echo ""

echo "==> Pub/Sub Topics:"
gcloud pubsub topics list --project="${PROJECT_ID}" --format="table(name,messageRetentionDuration)" 2>/dev/null || echo "  (none found)"
echo ""

echo "==> Pub/Sub Subscriptions:"
gcloud pubsub subscriptions list --project="${PROJECT_ID}" --format="table(name,topic,messageRetentionDuration,ackDeadlineSeconds)" 2>/dev/null || echo "  (none found)"
echo ""

echo "==> GKE Clusters:"
gcloud container clusters list --project="${PROJECT_ID}" --format="table(name,location,status,nodeCount,masterVersion)" 2>/dev/null || echo "  (none found)"
echo ""

echo "==> Artifact Registry Repositories:"
gcloud artifacts repositories list --project="${PROJECT_ID}" --location="${REGION}" --format="table(name,format,description)" 2>/dev/null || echo "  (none found)"
echo ""

echo "==> Service Accounts (project-level):"
gcloud iam service-accounts list --project="${PROJECT_ID}" --format="table(email,displayName)" --filter="email:aeroscale" 2>/dev/null || echo "  (none found)"
echo ""

echo "============================================"
echo "  Audit complete."
echo "============================================"