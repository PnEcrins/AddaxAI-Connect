#!/bin/bash
# Builds every image docker-compose.selfhost.yml needs, tagged with the
# IMAGE_* variable that compose file reads for that service (full
# reference, registry + tag included — see .env.selfhost.example). Run from
# anywhere; always builds from the repo root regardless of your current
# directory, since several Dockerfiles COPY the shared/ library and
# scripts/ from there.
#
# Reads IMAGE_* from .env at the repo root if present, same as docker
# compose would. Override on the command line instead:
#   IMAGE_API=ghcr.io/you/addaxai-connect-api:latest ./scripts/build-selfhost-images.sh


set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
cd "$repo_root"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi


# name:context:dockerfile:env_var, space separated. frontend's context is
# its own directory (multi-stage npm build); every other service builds
# from the repo root so the Dockerfile can COPY shared/ and scripts/.
services=(
  "api:.:services/api/Dockerfile:IMAGE_API"
  "bulk-upload:.:services/bulk-upload/Dockerfile:IMAGE_BULK_UPLOAD"
  "detection:.:services/detection/Dockerfile:IMAGE_DETECTION"
  "classification-deepfaune:.:services/classification-deepfaune/Dockerfile:IMAGE_CLASSIFICATION_DEEPFAUNE"
  "classification-speciesnet:.:services/classification-speciesnet/Dockerfile:IMAGE_CLASSIFICATION_SPECIESNET"
  "notifications:.:services/notifications/Dockerfile:IMAGE_NOTIFICATIONS"
  "notifications-email:.:services/notifications-email/Dockerfile:IMAGE_NOTIFICATIONS_EMAIL"
  "minio-init:.:services/minio-init/Dockerfile:IMAGE_MINIO_INIT"
  "frontend:services/frontend:services/frontend/Dockerfile:IMAGE_FRONTEND"
)

for entry in "${services[@]}"; do
  IFS=':' read -r name context dockerfile env_var <<< "$entry"
  tag="${!env_var:-}"
  if [ -z "$tag" ]; then
    echo "Missing $env_var in .env (needed to tag the $name image)" >&2
    exit 1
  fi
done

echo
echo "Built:"
for entry in "${services[@]}"; do
  IFS=':' read -r name _ _ env_var <<< "$entry"
  echo "  ${name} -> ${!env_var}"
done
