#!/bin/bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-stayrelevantid}"
REGION="${REGION:-asia-southeast1}"
REPO="${REPO:-aeroscale-docker}"
IMAGE="${IMAGE:-aeroscale-worker}"
CLUSTER="${CLUSTER:-aeroscale-gke}"
ZONE="${ZONE:-asia-southeast1-a}"
NAMESPACE="${NAMESPACE:-aeroscale}"

FULL_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}/${IMAGE}"
TAG="${1:-latest}"

echo "==> Building Docker image: ${FULL_IMAGE}:${TAG}"
docker build -t "${FULL_IMAGE}:${TAG}" .

echo "==> Pushing Docker image: ${FULL_IMAGE}:${TAG}"
docker push "${FULL_IMAGE}:${TAG}"

echo "==> Getting GKE credentials"
gcloud container clusters get-credentials "${CLUSTER}" --zone="${ZONE}" --project="${PROJECT_ID}"

echo "==> Deploying to GKE namespace: ${NAMESPACE}"
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/trigger-authentication.yaml
kubectl apply -f k8s/scaled-object.yaml

echo "==> Updating deployment image to ${FULL_IMAGE}:${TAG}"
kubectl set image deployment/aeroscale-worker \
  worker="${FULL_IMAGE}:${TAG}" \
  -n "${NAMESPACE}"

echo "==> Waiting for rollout..."
kubectl rollout status deployment/aeroscale-worker -n "${NAMESPACE}" --timeout=120s

echo "==> Done!"