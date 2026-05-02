#!/bin/bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-stayrelevantid}"
REGION="${REGION:-asia-southeast1}"
REPO="${REPO:-aeroscale-docker}"
BUCKET="${BUCKET:-aeroscale-tf-state}"

echo "============================================"
echo "  AeroScale — Cleanup"
echo "============================================"
echo "  Project: ${PROJECT_ID}"
echo "  Region:  ${REGION}"
echo "============================================"
echo ""

echo "==> Listing Artifact Registry images:"
gcloud artifacts images list \
  --repository="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}" \
  --project="${PROJECT_ID}" \
  --format="table(package,version,createTime)" 2>/dev/null || echo "  (no images or repository not found)"
echo ""

read -rp "Delete all images in Artifact Registry? (y/N): " confirm_ar
if [[ "${confirm_ar,,}" == "y" ]]; then
    IMAGES=$(gcloud artifacts images list \
        --repository="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}" \
        --project="${PROJECT_ID}" \
        --format="value(package)" 2>/dev/null || true)

    if [[ -n "${IMAGES}" ]]; then
        echo "${IMAGES}" | while read -r img; do
            echo "  Deleting image: ${img}"
            gcloud artifacts images delete "${img}" \
                --repository="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}" \
                --project="${PROJECT_ID}" \
                --quiet 2>/dev/null || echo "  (failed to delete ${img})"
        done
        echo "  All images deleted."
    else
        echo "  No images to delete."
    fi
else
    echo "  Skipped Artifact Registry cleanup."
fi

echo ""

read -rp "Delete Artifact Registry repository? (y/N): " confirm_repo
if [[ "${confirm_repo,,}" == "y" ]]; then
    gcloud artifacts repositories delete "${REPO}" \
        --location="${REGION}" \
        --project="${PROJECT_ID}" \
        --quiet 2>/dev/null || echo "  (failed to delete repository)"
    echo "  Repository deleted."
else
    echo "  Skipped repository deletion."
fi

echo ""

read -rp "Delete GCS bucket (${BUCKET}) with Terraform state? (y/N): " confirm_bucket
if [[ "${confirm_bucket,,}" == "y" ]]; then
    gsutil rm -r "gs://${BUCKET}" 2>/dev/null || echo "  (failed to delete bucket)"
    echo "  Bucket deleted."
else
    echo "  Kept GCS bucket for future reference."
fi

echo ""
echo "============================================"
echo "  Cleanup complete."
echo "============================================"