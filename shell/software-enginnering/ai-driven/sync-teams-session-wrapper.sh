#!/usr/bin/env bash
set -euo pipefail

# Project-local wrapper for Teams session sync.
# Shared logic is maintained in dotfiles and reused here.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHARED_DEFAULT="$HOME/dotfiles/shell/software-enginnering/ai-driven/sync-teams-session.sh"
SHARED_SCRIPT="${SYNC_TEAMS_SESSION_SCRIPT:-$SHARED_DEFAULT}"

if ! command -v bash >/dev/null 2>&1; then
  echo "Error: bash not found in PATH." >&2
  exit 1
fi

if [[ ! -f "$SHARED_SCRIPT" ]]; then
  echo "Error: shared sync script not found: $SHARED_SCRIPT" >&2
  echo "Hint: set SYNC_TEAMS_SESSION_SCRIPT to your shared script path." >&2
  exit 1
fi

# Ensure default output path resolves against this doc-engine root when caller does not pass --output.
cd "$ROOT_DIR"
exec "$SHARED_SCRIPT" "$@"
