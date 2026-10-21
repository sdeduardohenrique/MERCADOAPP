#!/usr/bin/env bash
# ============================================================================
# SomaAí — diagnóstico rápido no dispositivo (ADB)
#
# Uso:
#   ./tools/diagnose_somaai.sh                # usa o serial padrão
#   ./tools/diagnose_somaai.sh <serial>       # outro aparelho
#
# O script instala o APK release, abre o app e imprime os logs relevantes.
# Se o MIUI bloquear com INSTALL_FAILED_USER_RESTRICTED, ative
# "Instalar via USB" em Opções do desenvolvedor (pode exigir conta Mi).
# ============================================================================
set -u

ADB="${ADB:-$HOME/android-sdk/platform-tools/adb}"
SERIAL="${1:-6D4TQKXGONGAU8FE}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APK="$SCRIPT_DIR/../somaai-arm64-release.apk"
PKG="com.example.mercado_app"

echo "== Dispositivo =="
if ! "$ADB" -s "$SERIAL" get-state >/dev/null 2>&1; then
  echo "Aparelho $SERIAL não encontrado. Conecte via USB e autorize a depuração."
  exit 1
fi
echo "OK: $SERIAL"

echo
echo "== Instalando $APK =="
if ! "$ADB" -s "$SERIAL" install -r "$APK"; then
  echo
  echo "Falha na instalação."
  echo "No MIUI: Configurações > Opções do desenvolvedor > 'Instalar via USB'."
  echo "Alternativa: instalar manualmente por Downloads/somaai-arm64-release.apk."
  exit 2
fi

echo
echo "== Limpando logcat =="
"$ADB" -s "$SERIAL" logcat -c

echo "== Abrindo o app =="
"$ADB" -s "$SERIAL" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 \
  || "$ADB" -s "$SERIAL" shell am start -n "$PKG/.MainActivity" >/dev/null 2>&1

echo "Aguardando 10s para o primeiro frame..."
sleep 10

echo
echo "== Logs (flutter / crashes / SomaAí) =="
"$ADB" -s "$SERIAL" logcat -d -v time \
  | grep -E "flutter|AndroidRuntime|FATAL|SomaAí|SomaAi|ActivityManager|Exception|CRASH" \
  | tail -200

echo
echo "== Processo em execução =="
"$ADB" -s "$SERIAL" shell pidof "$PKG" || echo "Processo NÃO está rodando (crash na inicialização?)"
