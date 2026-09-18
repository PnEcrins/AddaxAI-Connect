#!/bin/sh
# Applies pending migrations before the API starts serving, so no request
# ever hits a stale schema. Runs on every container start, not just the
# first — alembic upgrade head is a no-op once the DB is already current.
set -e

echo "Running database migrations..."
alembic upgrade head
echo "Migrations complete."

exec "$@"
