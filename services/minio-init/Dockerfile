FROM quay.io/minio/mc:RELEASE.2025-08-13T08-35-41Z

COPY services/minio-init/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
