#!/bin/bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-stayrelevantid}"
TOPIC="${TOPIC:-aeroscale-event-queue}"
COUNT="${COUNT:-500}"
BATCH="${BATCH:-10}"
DELAY="${DELAY:-10ms}"
ZONE="${ZONE:-asia-southeast1-a}"
CLUSTER="${CLUSTER:-aeroscale-gke}"
NAMESPACE="${NAMESPACE:-aeroscale}"

echo "============================================"
echo "  AeroScale Stress Test"
echo "============================================"
echo "  Project:   ${PROJECT_ID}"
echo "  Topic:     ${TOPIC}"
echo "  Messages:  ${COUNT}"
echo "  Batch:     ${BATCH}"
echo "  Delay:     ${DELAY}"
echo "============================================"
echo ""

echo "==> Getting GKE credentials"
gcloud container clusters get-credentials "${CLUSTER}" --zone="${ZONE}" --project="${PROJECT_ID}"

echo "==> Checking current pods"
kubectl get pods -n "${NAMESPACE}" -o wide

echo ""
echo "==> Publishing ${COUNT} messages..."
go run ./cmd/publisher --project="${PROJECT_ID}" --topic="${TOPIC}" --count="${COUNT}" --batch="${BATCH}" --delay="${DELAY}"

echo ""
echo "==> Watching pod scaling (press Ctrl+C to stop)..."
echo "    In another terminal, run:"
echo "      kubectl get hpa -n ${NAMESPACE} -w"
echo ""
kubectl get pods -n "${NAMESPACE}" -w