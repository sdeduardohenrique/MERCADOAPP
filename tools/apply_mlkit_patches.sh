#!/usr/bin/env bash
#
# Reaplica os patches locais dos plugins google_mlkit_* usados pelo SomaAí.
#
# Contexto: o Flutter 3.47 / Android SDK 36 exige namespace no Gradle e
# compileSdkVersion 36. Os plugins google_mlkit_* 0.7.0/0.4.0 são antigos e
# precisam desses ajustes. O `flutter pub cache repair` baixa os pacotes
# originais e desfaz os patches; execute este script depois do repair.
#
# Uso:
#   bash tools/apply_mlkit_patches.sh
#
# Variáveis opcionais:
#   PUB_CACHE=/caminho/para/.pub-cache
#
set -euo pipefail

PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
BASE="$PUB_CACHE/hosted/pub.dev"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="$SCRIPT_DIR/mlkit_patches"

if ! command -v patch >/dev/null 2>&1; then
  echo "ERRO: comando 'patch' não encontrado. Instale com: sudo apt install patch" >&2
  exit 1
fi

apply_if_needed() {
  local pkg="$1"
  local namespace="$2"
  local dir="$BASE/$pkg"

  if [ ! -d "$dir" ]; then
    echo "ERRO: pacote não encontrado em $dir" >&2
    echo "Execute 'flutter pub get' antes deste script." >&2
    exit 1
  fi

  if grep -q "namespace '$namespace'" "$dir/android/build.gradle" 2>/dev/null &&
     grep -q 'compileSdkVersion 36' "$dir/android/build.gradle" 2>/dev/null &&
     ! grep -q 'package="com.google_mlkit' "$dir/android/src/main/AndroidManifest.xml" 2>/dev/null; then
    echo "OK (já aplicado): $pkg"
    return 0
  fi

  echo "Aplicando patch: $pkg"
  patch -p1 --forward -d "$dir" < "$PATCH_DIR/$pkg.patch"
  echo "OK: $pkg"
}

apply_if_needed "google_mlkit_commons-0.4.0" "com.google.mlkit.commons"
apply_if_needed "google_mlkit_text_recognition-0.7.0" "com.google.mlkit.text_recognition"
apply_if_needed "google_mlkit_barcode_scanning-0.7.0" "com.google.mlkit.barcode_scanning"

echo
echo "Patches do ML Kit aplicados/verificados com sucesso."
