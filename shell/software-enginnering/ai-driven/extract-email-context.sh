#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/extract-email-context.py"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 command not found in PATH." >&2
  exit 1
fi

if [[ ! -f "$PY_SCRIPT" ]]; then
  echo "Error: shared extractor script not found: $PY_SCRIPT" >&2
  exit 1
fi

exec python3 "$PY_SCRIPT" "$@"
