#!/bin/sh
# Garage init: node layout, app key, buckets, lifecycle. Same buckets as
# services/minio-init/entrypoint.sh. Idempotent.
#
# Two ways to run it:
# - On the Garage server, from this directory, after `docker compose up -d`.
#   The garage image has no shell, so it drives the CLI with
#   `docker compose exec` and reads ./.env.
# - As the garage-init service of docker-compose.dev.yml
#   (GARAGE_INIT_IN_CONTAINER=1), from Dockerfile.init, sharing the garage
#   container's network so the CLI and S3 API are on 127.0.0.1.
#
# GARAGE_KEY_ID / GARAGE_KEY_SECRET, when set, import that key instead of
# letting Garage generate one, so the app's credentials can be fixed ahead.
# Garage wants an id of GK + 24 hex chars and a 64 hex chars secret.

set -eu

KEY_NAME=addaxai
BUCKETS="raw-images crops thumbnails models project-images project-documents bulk-upload-staging"

if [ "${GARAGE_INIT_IN_CONTAINER:-}" = 1 ]; then
  garage() { /usr/local/bin/garage "$@"; }
  s3api() { aws --endpoint-url http://127.0.0.1:3900 s3api "$@"; }
else
  cd "$(dirname "$0")"
  . ./.env
  garage() { docker compose exec -T garage /garage "$@"; }
  s3api() {
    docker run --rm --network host \
      -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION \
      amazon/aws-cli --endpoint-url http://127.0.0.1:3900 s3api "$@"
  }
fi

# --- Layout (once) ---------------------------------------------------------
if garage status | grep -q "NO ROLE ASSIGNED"; then
  node_id="$(garage node id -q | cut -d@ -f1)"
  garage layout assign -z dc1 -c "$GARAGE_CAPACITY" "$node_id"
  current="$(garage layout show | sed -n 's/.*[Cc]urrent cluster layout version: *\([0-9]*\).*/\1/p')"
  garage layout apply --version "$(( ${current:-0} + 1 ))"
else
  echo "Layout already applied"
fi

# --- App key ---------------------------------------------------------------
if ! garage key info "$KEY_NAME" > /dev/null 2>&1; then
  if [ -n "${GARAGE_KEY_ID:-}" ] && [ -n "${GARAGE_KEY_SECRET:-}" ]; then
    garage key import --yes -n "$KEY_NAME" "$GARAGE_KEY_ID" "$GARAGE_KEY_SECRET"
  else
    garage key create "$KEY_NAME"
  fi
fi
key_info="$(garage key info "$KEY_NAME" --show-secret)"
key_id="$(echo "$key_info" | awk '/Key ID:/ {print $3}')"
secret="$(echo "$key_info" | awk '/Secret key:/ {print $3}')"

# --- Buckets ---------------------------------------------------------------
for b in $BUCKETS; do
  garage bucket info "$b" > /dev/null 2>&1 || garage bucket create "$b"
  garage bucket allow --read --write --owner "$b" --key "$KEY_NAME"
done

# --- Lifecycle -------------------------------------------------------------
# Annotated notification images live under thumbnails/annotated/ and are only
# needed until the messages go out (see minio-init). Garage has no `mc`, so
# set it through the S3 API.
export AWS_ACCESS_KEY_ID="$key_id"
export AWS_SECRET_ACCESS_KEY="$secret"
export AWS_DEFAULT_REGION=us-east-1
s3api put-bucket-lifecycle-configuration --bucket thumbnails \
  --lifecycle-configuration '{"Rules":[{"ID":"expire-annotated","Status":"Enabled","Filter":{"Prefix":"annotated/"},"Expiration":{"Days":1}}]}'

echo
echo "Garage ready. App-side .env:"
echo "  MINIO_ENDPOINT=${GARAGE_DOMAIN:-garage:3900}"
echo "  MINIO_ROOT_USER=$key_id"
echo "  MINIO_ROOT_PASSWORD=$secret"
