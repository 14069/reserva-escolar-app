#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-./supabase/export_csv}"
MYSQL_BIN="${MYSQL_BIN:-/opt/lampp/bin/mysql}"
MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_DATABASE="${MYSQL_DATABASE:-reserva_escolar_v2}"

mkdir -p "$OUT_DIR"

tables=(
  schools
  resource_categories
  users
  class_groups
  subjects
  lesson_slots
  resources
  bookings
  booking_lessons
)

for table in "${tables[@]}"; do
  echo "Exportando ${table}..."
  "$MYSQL_BIN" -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" \
    --batch --raw --skip-column-names \
    -e "SELECT * FROM ${MYSQL_DATABASE}.${table}" \
    | sed $'s/\t/,/g' > "${OUT_DIR}/${table}.csv"
done

echo "Arquivos CSV gerados em ${OUT_DIR}"
