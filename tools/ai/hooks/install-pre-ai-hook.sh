#!/usr/bin/env bash
# Install/uninstall/status helper for the example AI pre-commit hook.

set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
HOOK_SRC="$ROOT/tools/ai/hooks/pre-ai-model-select.sh"
HOOK_DST="$ROOT/.git/hooks/pre-commit"
BACKUP="$ROOT/.git/hooks/pre-commit.backup.ai.$(date +%Y%m%d-%H%M%S)"

usage() {
  cat <<'EOF'
Usage:
  tools/ai/hooks/install-pre-ai-hook.sh --status
  tools/ai/hooks/install-pre-ai-hook.sh --install
  tools/ai/hooks/install-pre-ai-hook.sh --uninstall
  tools/ai/hooks/install-pre-ai-hook.sh --uninstall-restore

Behavior:
  --status     show whether the AI hook is installed
  --install    backup existing pre-commit hook (if any) and install AI hook
  --uninstall  remove AI hook if installed (restoration is manual via backup file)
  --uninstall-restore  remove AI hook and restore latest backup if available
EOF
}

latest_backup_file() {
  find "$ROOT/.git/hooks" -maxdepth 1 -type f -name 'pre-commit.backup.ai.*' | sort | tail -n1
}

is_ai_hook_installed() {
  # Primary check: exact content match with the source hook.
  if [ -f "$HOOK_DST" ] && [ -f "$HOOK_SRC" ] && cmp -s "$HOOK_DST" "$HOOK_SRC"; then
    return 0
  fi

  # Secondary check: marker/output lines from the AI hook script.
  if [ -f "$HOOK_DST" ] && grep -q "Running AI model selection for task:" "$HOOK_DST"; then
    return 0
  fi

  return 1
}

status() {
  if is_ai_hook_installed; then
    echo "AI pre-commit hook is installed: $HOOK_DST"
    return 0
  fi

  if [ -f "$HOOK_DST" ]; then
    echo "A pre-commit hook exists, but it is not the AI hook: $HOOK_DST"
    return 1
  fi

  echo "No pre-commit hook installed."
  return 1
}

install_hook() {
  if [ ! -f "$HOOK_SRC" ]; then
    echo "Hook source not found: $HOOK_SRC" >&2
    exit 2
  fi

  if [ -f "$HOOK_DST" ]; then
    cp "$HOOK_DST" "$BACKUP"
    echo "Backed up existing hook to: $BACKUP"
  fi

  cp "$HOOK_SRC" "$HOOK_DST"
  chmod +x "$HOOK_DST"
  echo "Installed AI hook to: $HOOK_DST"
}

uninstall_hook() {
  if is_ai_hook_installed; then
    rm -f "$HOOK_DST"
    echo "Removed AI hook from: $HOOK_DST"
    echo "If you need previous hook, restore latest backup from .git/hooks/"
    return 0
  fi

  echo "AI hook is not currently installed; nothing to remove."
}

restore_latest_backup() {
  local backup
  backup=$(latest_backup_file)

  if [ -z "$backup" ]; then
    echo "No backup hook found to restore in .git/hooks/" >&2
    return 1
  fi

  if [ -f "$HOOK_DST" ] && ! is_ai_hook_installed; then
    echo "Refusing to overwrite existing non-AI pre-commit hook: $HOOK_DST" >&2
    echo "Move it away manually, then re-run --uninstall-restore if needed." >&2
    return 1
  fi

  cp "$backup" "$HOOK_DST"
  chmod +x "$HOOK_DST"
  echo "Restored pre-commit hook from backup: $backup"
}

uninstall_and_restore_hook() {
  if is_ai_hook_installed; then
    rm -f "$HOOK_DST"
    echo "Removed AI hook from: $HOOK_DST"
  fi

  restore_latest_backup
}

if [ $# -ne 1 ]; then
  usage
  exit 2
fi

case "$1" in
--status)
  status
  ;;
--install)
  install_hook
  ;;
--uninstall)
  uninstall_hook
  ;;
--uninstall-restore)
  uninstall_and_restore_hook
  ;;
*)
  usage
  exit 2
  ;;
esac
