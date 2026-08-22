#!/usr/bin/env bash
#
# Nightly Postgres backup with verification.
#
# A backup nobody restores is not a backup, so every run reads the dump's table
# of contents back, and once a week it restores the whole dump into a throwaway
# database and counts rows. Failures post to ALERT_WEBHOOK_URL and exit non-zero
# so cron or any monitor picks them up.
#
#   ./script/backup_postgres.sh                 # dump + TOC verify, weekly full restore
#   VERIFY_RESTORE=always ./script/backup_postgres.sh
#   VERIFY_RESTORE=never  ./script/backup_postgres.sh
#
# Reads POSTGRES_* and ALERT_* from the compose env file. Run it from the
# directory holding docker-compose.production.yaml and .env.
#
# Suggested cron (daily 02:30, host time):
#   30 2 * * * cd /root/chatwoot && ./script/backup_postgres.sh >> log/backup_postgres.log 2>&1

set -Eeuo pipefail

ENV_FILE="${ENV_FILE:-.env}"
BACKUP_DIR="${BACKUP_DIR:-backups/postgres}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
DOCKER_NETWORK="${DOCKER_NETWORK:-chatwoot_network}"
PG_IMAGE="${PG_IMAGE:-postgres:16-alpine}"
VERIFY_RESTORE="${VERIFY_RESTORE:-weekly}"
STAMP="$(date +%Y%m%d%H%M%S)"
DUMP_NAME="chatwoot_${STAMP}.dump"

[ -f "$ENV_FILE" ] || { echo "env file not found: $ENV_FILE" >&2; exit 1; }
mkdir -p "$BACKUP_DIR"
BACKUP_ABS="$(cd "$BACKUP_DIR" && pwd)"

# shellcheck disable=SC1090
set -a; . "./$ENV_FILE"; set +a

notify_failure() {
  local message="$1"
  echo "BACKUP FAILED: ${message}" >&2
  if [ -n "${ALERT_WEBHOOK_URL:-}" ]; then
    curl -fsS -m "${ALERT_WEBHOOK_TIMEOUT_SECONDS:-10}" \
      -H 'Content-Type: application/json' \
      -d "$(printf '{"text":"%s postgres backup failed","status":"warning","check":"postgres_backup","detail":"%s"}' \
            "${ALERT_INSTANCE_NAME:-Chatwoot production}" "${message//\"/\'}")" \
      "$ALERT_WEBHOOK_URL" >/dev/null || echo "alert webhook post failed" >&2
  fi
}
trap 'notify_failure "unexpected error on line $LINENO"' ERR

run_pg() {
  docker run --rm --network "$DOCKER_NETWORK" --env-file "$ENV_FILE" \
    -v "${BACKUP_ABS}:/backup" "$PG_IMAGE" sh -lc "$1"
}

echo "==> dumping ${POSTGRES_DATABASE} to ${BACKUP_DIR}/${DUMP_NAME}"
run_pg "export PGPASSWORD=\"\$POSTGRES_PASSWORD\"; pg_dump -h \"\$POSTGRES_HOST\" -p \"\${POSTGRES_PORT:-5432}\" -U \"\$POSTGRES_USERNAME\" -d \"\$POSTGRES_DATABASE\" -Fc --no-owner --no-acl -f /backup/${DUMP_NAME}"

DUMP_PATH="${BACKUP_ABS}/${DUMP_NAME}"
DUMP_BYTES="$(wc -c < "$DUMP_PATH" | tr -d ' ')"
if [ "$DUMP_BYTES" -lt 1048576 ]; then
  notify_failure "dump is only ${DUMP_BYTES} bytes, refusing to trust it"
  trap - ERR
  exit 1
fi

echo "==> verifying dump table of contents"
run_pg "pg_restore -l /backup/${DUMP_NAME} > /backup/${DUMP_NAME}.toc"
TOC_LINES="$(grep -cve '^;' -e '^$' "${DUMP_PATH}.toc" || true)"
echo "    ${DUMP_BYTES} bytes, ${TOC_LINES} objects in the table of contents"

should_verify_restore() {
  case "$VERIFY_RESTORE" in
    always) return 0 ;;
    never) return 1 ;;
    weekly) [ "$(date +%u)" = "7" ] ;;
    *) return 1 ;;
  esac
}

if should_verify_restore; then
  RESTORE_DB="chatwoot_restore_check_${STAMP}"
  echo "==> restoring into ${RESTORE_DB} to prove the dump is usable"
  run_pg "export PGPASSWORD=\"\$POSTGRES_PASSWORD\"; \
    psql -h \"\$POSTGRES_HOST\" -p \"\${POSTGRES_PORT:-5432}\" -U \"\$POSTGRES_USERNAME\" -d postgres -v ON_ERROR_STOP=1 -c 'CREATE DATABASE ${RESTORE_DB}' && \
    pg_restore -h \"\$POSTGRES_HOST\" -p \"\${POSTGRES_PORT:-5432}\" -U \"\$POSTGRES_USERNAME\" -d ${RESTORE_DB} --no-owner --no-acl -j 2 /backup/${DUMP_NAME} && \
    psql -h \"\$POSTGRES_HOST\" -p \"\${POSTGRES_PORT:-5432}\" -U \"\$POSTGRES_USERNAME\" -d ${RESTORE_DB} -v ON_ERROR_STOP=1 -c 'SELECT count(*) AS accounts FROM accounts' -c 'SELECT count(*) AS conversations FROM conversations' -c 'SELECT count(*) AS messages FROM messages'" \
    | tee "${BACKUP_ABS}/${DUMP_NAME}.verify.txt"

  echo "==> dropping ${RESTORE_DB}"
  run_pg "export PGPASSWORD=\"\$POSTGRES_PASSWORD\"; psql -h \"\$POSTGRES_HOST\" -p \"\${POSTGRES_PORT:-5432}\" -U \"\$POSTGRES_USERNAME\" -d postgres -v ON_ERROR_STOP=1 -c 'DROP DATABASE ${RESTORE_DB}'"
fi

echo "==> pruning backups older than ${RETENTION_DAYS} days"
find "$BACKUP_ABS" -name 'chatwoot_*.dump*' -type f -mtime "+${RETENTION_DAYS}" -print -delete

trap - ERR
echo "==> backup complete: ${DUMP_PATH}"
