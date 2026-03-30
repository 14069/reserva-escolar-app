#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env.flutter.local"

load_env_file() {
  local file_path="$1"

  if [[ ! -f "$file_path" ]]; then
    return
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    if [[ -z "$line" || "${line:0:1}" == "#" ]]; then
      continue
    fi

    if [[ "$line" != *=* ]]; then
      continue
    fi

    local key="${line%%=*}"
    local value="${line#*=}"

    if [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "${value:0:1}" == "'" && "${value: -1}" == "'" ]]; then
      value="${value:1:${#value}-2}"
    fi

    export "$key=$value"
  done < "$file_path"
}

usage() {
  cat <<'EOF'
Uso:
  ./scripts/flutter_with_api.sh web
  ./scripts/flutter_with_api.sh apk
  ./scripts/flutter_with_api.sh appbundle
  ./scripts/flutter_with_api.sh run-web

Antes:
  1. Copie .env.flutter.example para .env.flutter.local
  2. Preencha API_BASE_URL com a URL da API publicada
EOF
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

load_env_file "$ENV_FILE"

if [[ -z "${API_BASE_URL:-}" ]]; then
  echo "API_BASE_URL não definida. Crie ${ENV_FILE} a partir de .env.flutter.example."
  exit 1
fi

cd "$ROOT_DIR"

case "$1" in
  web)
    flutter build web --release --dart-define="API_BASE_URL=${API_BASE_URL}"
    ;;
  apk)
    flutter build apk --release --dart-define="API_BASE_URL=${API_BASE_URL}"
    ;;
  appbundle)
    flutter build appbundle --release --dart-define="API_BASE_URL=${API_BASE_URL}"
    ;;
  run-web)
    flutter run -d chrome --dart-define="API_BASE_URL=${API_BASE_URL}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
