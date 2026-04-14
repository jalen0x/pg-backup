#!/bin/bash
set -euo pipefail

echo "Starting pg-backup container"
echo "Database: ${PGDATABASE}"
echo "Bucket: ${BUCKET}"
echo "Schedule hours (UTC): ${SCHEDULE:-0 9 12 16}"
echo "Retention days: ${RETENTION_DAYS:-7}"

cat > /tmp/.s3cfg <<EOF
[default]
access_key = ${ACCESS_KEY_ID}
secret_key = ${SECRET_ACCESS_KEY}
host_base = ${HOST_BASE}
host_bucket = %(bucket)s.${HOST_BASE}
use_https = True
EOF

export PGPASSWORD="${POSTGRES_PASS}"

run_backup() {
  local timestamp
  timestamp=$(date -u +%Y-%m-%d-%H%M)
  local filename="${timestamp}.${PGDATABASE}.dump.gz"
  local s3_path="s3://${BUCKET}/${filename}"

  echo "[$(date -u)] Starting backup: ${filename}"

  pg_dump -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT:-5432}" -U "${POSTGRES_USER}" -Fc --clean "${PGDATABASE}" | gzip > /tmp/backup.gz

  s3cmd -c /tmp/.s3cfg put /tmp/backup.gz "${s3_path}"
  rm -f /tmp/backup.gz

  echo "[$(date -u)] Uploaded ${s3_path}"

  local cutoff
  cutoff=$(date -u -d "-${RETENTION_DAYS:-7} days" +%Y-%m-%d)
  echo "[$(date -u)] Removing backups older than ${cutoff}"

  s3cmd -c /tmp/.s3cfg ls "s3://${BUCKET}/" | while read -r line; do
    local file
    file=$(echo "${line}" | awk '{print $4}')
    local basename
    basename=$(basename "${file}")
    local file_date
    file_date=$(echo "${basename}" | grep -oP '^\d{4}-\d{2}-\d{2}' || true)

    if [[ -n "${file_date}" && "${file_date}" < "${cutoff}" ]]; then
      echo "[$(date -u)] Deleting old backup: ${file}"
      s3cmd -c /tmp/.s3cfg del "${file}"
    fi
  done

  if [[ -n "${HEARTBEAT_URL:-}" ]]; then
    curl -s -X POST "${HEARTBEAT_URL}" || echo "[$(date -u)] Heartbeat failed"
  fi

  echo "[$(date -u)] Backup complete"
}

if [[ "${1:-}" == "--once" ]]; then
  run_backup
  exit 0
fi

IFS=' ' read -ra SCHEDULE_HOURS <<< "${SCHEDULE:-0 9 12 16}"

echo "Waiting for next scheduled backup..."

while true; do
  current_hour=$(date -u +%-H)
  current_min=$(date -u +%-M)

  for hour in "${SCHEDULE_HOURS[@]}"; do
    if [[ "${current_hour}" -eq "${hour}" && "${current_min}" -eq 0 ]]; then
      run_backup || echo "[$(date -u)] Backup failed"
    fi
  done

  sleep 60
done
