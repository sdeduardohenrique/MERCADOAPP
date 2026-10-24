#!/usr/bin/env bash
# ============================================================================
# SomaAí — build do APK de release com as chaves do .env
# ============================================================================
# Uso:
#   ./tools/build_apk.sh                 # build completo (split-per-abi)
#   ./tools/build_apk.sh --target-platform android-arm64
#
# As chaves abaixo são lidas do .env e injetadas via --dart-define, porque o
# app não carrega o .env em runtime:
#   - GOOGLE_WEB_CLIENT_ID  (obrigatória para o login Google)
#   - TOMTOM_API_KEY        (opcional; sem ela o app usa só PostGIS + manual)
# ============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE="${ENV_FILE:-.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERRO: $ENV_FILE não encontrado. Copie .env.example para .env." >&2
  exit 1
fi

# Lê uma chave do .env sem executar o arquivo (evita efeitos colaterais).
read_env() {
  local key="$1"
  local value
  value="$(grep -E "^[[:space:]]*${key}=" "$ENV_FILE" | tail -n 1 | cut -d= -f2- || true)"
  # Remove aspas simples/duplas e espaços nas pontas.
  value="${value%\"}"; value="${value#\"}"
  value="${value%\'}"; value="${value#\'}"
  printf '%s' "$(echo "$value" | xargs || true)"
}

GOOGLE_WEB_CLIENT_ID="$(read_env GOOGLE_WEB_CLIENT_ID)"
TOMTOM_API_KEY="$(read_env TOMTOM_API_KEY)"

if [[ -z "$GOOGLE_WEB_CLIENT_ID" ]]; then
  echo "ERRO: GOOGLE_WEB_CLIENT_ID não configurado em $ENV_FILE." >&2
  exit 1
fi

if [[ -z "$TOMTOM_API_KEY" ]]; then
  echo "AVISO: TOMTOM_API_KEY vazio — busca de mercados usará apenas a base interna."
fi

ARGS=(
  --release
  --split-per-abi
  "--dart-define=GOOGLE_WEB_CLIENT_ID=${GOOGLE_WEB_CLIENT_ID}"
)

if [[ -n "$TOMTOM_API_KEY" ]]; then
  ARGS+=("--dart-define=TOMTOM_API_KEY=${TOMTOM_API_KEY}")
fi

flutter build apk "${ARGS[@]}" "$@"

ARM64_APK="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
if [[ -f "$ARM64_APK" ]]; then
  cp "$ARM64_APK" somaai-arm64-release.apk
  echo
  echo "APK pronto: somaai-arm64-release.apk"
  sha256sum somaai-arm64-release.apk
fi
