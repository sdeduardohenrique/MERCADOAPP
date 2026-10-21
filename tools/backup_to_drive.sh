#!/usr/bin/env bash
#
# Backup do SomaAí para o Google Drive via rclone.
#
# O que entra:
#   - código, testes, docs, skills, scripts e patches;
#   - projeto Android/iOS;
#   - .git local (histórico do Git);
#   - APK release, se existir.
#
# O que NÃO entra:
#   - build/, .dart_tool/, .venv/, HABILIDADES/tools/;
#   - SDK local "~/", caches do Gradle, .idea/, .vscode/;
#   - .env, keystores, key.properties e outros segredos.
#
# Uso:
#   bash tools/backup_to_drive.sh
#   bash tools/backup_to_drive.sh --dry-run
#   bash tools/backup_to_drive.sh --local-only
#
# Variáveis opcionais:
#   STAGING_DIR=$HOME/Backups/MERCADOAPP
#   RCLONE_REMOTE=gdrive:MERCADOAPP-Backup
#   RCLONE_BIN=/caminho/para/rclone
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGING_DIR="${STAGING_DIR:-$HOME/Backups/MERCADOAPP}"
RCLONE_REMOTE="${RCLONE_REMOTE:-gdrive:MERCADOAPP-Backup}"
DRY_RUN=0
LOCAL_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --local-only) LOCAL_ONLY=1 ;;
    --help|-h)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *)
      echo "Opção desconhecida: $arg" >&2
      echo "Use --dry-run, --local-only ou --help." >&2
      exit 1
      ;;
  esac
done

if ! command -v rsync >/dev/null 2>&1; then
  echo "ERRO: rsync não encontrado. Instale com: sudo apt install rsync" >&2
  exit 1
fi

RCLONE_BIN="${RCLONE_BIN:-}"
if [ -z "$RCLONE_BIN" ]; then
  if command -v rclone >/dev/null 2>&1; then
    RCLONE_BIN="$(command -v rclone)"
  elif [ -x "$HOME/.local/bin/rclone" ]; then
    RCLONE_BIN="$HOME/.local/bin/rclone"
  fi
fi

if [ "$LOCAL_ONLY" -eq 0 ]; then
  if [ -z "$RCLONE_BIN" ]; then
    echo "ERRO: rclone não encontrado. Instale com:" >&2
    echo "  sudo apt update && sudo apt install -y rclone" >&2
    echo "Ou use --local-only para testar apenas a cópia local." >&2
    exit 1
  fi

  REMOTE_NAME="${RCLONE_REMOTE%%:*}"
  if ! "$RCLONE_BIN" listremotes | grep -qx "${REMOTE_NAME}:"; then
    echo "ERRO: remote rclone '${REMOTE_NAME}:' não configurado." >&2
    echo "Rode: $RCLONE_BIN config" >&2
    echo "Crie um remote chamado '${REMOTE_NAME}' do tipo drive." >&2
    exit 1
  fi
fi

mkdir -p "$STAGING_DIR"

echo "Projeto:  $PROJECT_DIR"
echo "Staging:  $STAGING_DIR"
echo "Remote:   $RCLONE_REMOTE"
echo

# Rsync: primeiro as regras de inclusão, depois as de exclusão.
rsync -a --delete \
  --include='/.env.example' \
  --exclude='/.env' \
  --exclude='/.env.*' \
  --exclude='/~/' \
  --exclude='build/' \
  --exclude='.dart_tool/' \
  --exclude='.venv/' \
  --exclude='HABILIDADES/tools/' \
  --exclude='android/.gradle/' \
  --exclude='android/.kotlin/' \
  --exclude='android/local.properties' \
  --exclude='ios/Pods/' \
  --exclude='ios/.symlinks/' \
  --exclude='ios/Flutter/ephemeral/' \
  --exclude='.idea/' \
  --exclude='.vscode/' \
  --exclude='*.iml' \
  --exclude='*.jks' \
  --exclude='*.keystore' \
  --exclude='key.properties' \
  --exclude='*.log' \
  --exclude='coverage/' \
  --exclude='.DS_Store' \
  --exclude='.flutter-plugins-dependencies' \
  "$PROJECT_DIR/" "$STAGING_DIR/"

echo "Cópia local pronta: $(du -sh "$STAGING_DIR" | cut -f1)"

if [ "$LOCAL_ONLY" -eq 1 ]; then
  echo "Modo --local-only: nada foi enviado ao Drive."
  exit 0
fi

STAMP="$(date +%Y-%m-%d_%H%M%S)"
BACKUP_DIR="$RCLONE_REMOTE/history/$STAMP"
DEST="$RCLONE_REMOTE/current"

if [ "$DRY_RUN" -eq 1 ]; then
  echo
  echo "DRY RUN: mostrando o que seria enviado para $DEST"
  "$RCLONE_BIN" sync "$STAGING_DIR/" "$DEST/" \
    --backup-dir "$BACKUP_DIR" \
    --dry-run \
    --progress \
    --stats-one-line
  echo "DRY RUN concluído; nada foi alterado no Drive."
  exit 0
fi

echo
echo "Enviando para $DEST ..."
"$RCLONE_BIN" sync "$STAGING_DIR/" "$DEST/" \
  --backup-dir "$BACKUP_DIR" \
  --progress \
  --stats-one-line

echo
echo "Verificando integridade..."
"$RCLONE_BIN" check "$STAGING_DIR/" "$DEST/" --one-way

echo
echo "Backup concluído: $DEST"
echo "Versões anteriores: $RCLONE_REMOTE/history/"
echo "Staging local: $STAGING_DIR"
