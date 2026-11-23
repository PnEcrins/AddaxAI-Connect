# MinIO bucket init for docker-compose.selfhost.yml. Upstream runs minio-init
# from the MinIO image (services/minio/Dockerfile, which carries mc) with
# entrypoint.sh bind-mounted; the self-hosted stack has no checkout to mount
# from, so this bakes the script into that same image instead.
#
# MINIO_IMAGE is the image built from services/minio/Dockerfile, so mc stays
# the exact version upstream pins. scripts/build-selfhost-images.sh builds
# it first and passes its tag here.
ARG MINIO_IMAGE=addaxai-connect-minio
FROM ${MINIO_IMAGE}

COPY services/minio-init/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
