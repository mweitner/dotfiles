#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: run-ai-session-minutes.sh [project] [session] [options]

Wrap the real ai-session-manager.sh create-minutes flow with the verified
WhisperX + local Whisper model defaults for this workspace.

Arguments:
  project                 AI project name (or set AI_PROJECT)
  session                 AI session name (or set AI_SESSION)

Options:
  --title <text>          Meeting title (default: "<project> <session>")
  --owner <name>          Owner name (default: TBD)
  --date <YYYY-MM-DD>    Meeting date (default: today)
  --force                 Alias for --overwrite to force rerun
  --no-overwrite          Skip overwrite even if files exist
  --help                  Show this help text

Examples:
  bash ~/dotfiles/ai/run-ai-session-minutes.sh les-ems-pilot-ecocoach 2026.08.27-technical-deep-dive
  AI_PROJECT=les-ems-pilot-ecocoach AI_SESSION=2026.08.27-technical-deep-dive bash ~/dotfiles/ai/run-ai-session-minutes.sh
EOF
}

PROJECT="${AI_PROJECT:-}"
SESSION="${AI_SESSION:-}"
TITLE=""
OWNER="${AI_OWNER:-TBD}"
MEETING_DATE="${AI_DATE:-$(date +%F)}"
OVERWRITE=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --project)
      [[ $# -gt 1 ]] || { echo "error: --project requires a value" >&2; exit 1; }
      PROJECT="$2"
      shift 2
      ;;
    --session)
      [[ $# -gt 1 ]] || { echo "error: --session requires a value" >&2; exit 1; }
      SESSION="$2"
      shift 2
      ;;
    --title)
      [[ $# -gt 1 ]] || { echo "error: --title requires a value" >&2; exit 1; }
      TITLE="$2"
      shift 2
      ;;
    --owner)
      [[ $# -gt 1 ]] || { echo "error: --owner requires a value" >&2; exit 1; }
      OWNER="$2"
      shift 2
      ;;
    --date)
      [[ $# -gt 1 ]] || { echo "error: --date requires a value" >&2; exit 1; }
      MEETING_DATE="$2"
      shift 2
      ;;
    --no-overwrite)
      OVERWRITE=false
      shift
      ;;
    --force)
      OVERWRITE=true
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -z "$PROJECT" ]]; then
        PROJECT="$1"
      elif [[ -z "$SESSION" ]]; then
        SESSION="$1"
      else
        echo "error: unexpected positional argument: $1" >&2
        usage >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$PROJECT" || -z "$SESSION" ]]; then
  echo "error: both project and session must be provided" >&2
  usage >&2
  exit 1
fi

export AI_PROJECT="$PROJECT"
export AI_SESSION="$SESSION"

HF_TOKEN_FILE="${HF_TOKEN_FILE:-$HOME/dotfiles/.secrets/hf/.hf-les-ems-whisperx-diarization-local-2026-08}"
AI_ASR_MODEL="${AI_ASR_MODEL:-/home/ldcwem0/tools/whisper.cpp/models/ggml-large-v3.bin}"
AI_WHISPERX_BIN="${AI_WHISPERX_BIN:-/home/ldcwem0/.local/bin/whisperx}"
AI_ASR_DEVICE="${AI_ASR_DEVICE:-cpu}"
AI_ASR_BATCH_SIZE="${AI_ASR_BATCH_SIZE:-1}"
MODEL_DIR="${MODEL_DIR:-/mnt/data/huggingface}"

if [[ -z "$TITLE" ]]; then
  TITLE="${AI_PROJECT} ${AI_SESSION}"
fi

if [[ ! -f "$HF_TOKEN_FILE" ]]; then
  echo "error: HF token file not found: $HF_TOKEN_FILE" >&2
  exit 1
fi

export HF_TOKEN="$(tr -d '\r\n' < "$HF_TOKEN_FILE")"
export HUGGINGFACE_TOKEN="$HF_TOKEN"
export AI_ASR_MODEL
export AI_WHISPERX_BIN
export AI_ASR_DEVICE
export AI_ASR_BATCH_SIZE
export HF_HOME="$MODEL_DIR"
export HF_HUB_CACHE="$MODEL_DIR/hub"
export HUGGINGFACE_HUB_CACHE="$MODEL_DIR/hub"
export TRANSFORMERS_CACHE="$MODEL_DIR/transformers"
export HF_HUB_DISABLE_SYMLINKS=1
export HF_HUB_DISABLE_SYMLINKS_WARNING=1
export SSL_CERT_FILE="${SSL_CERT_FILE:-/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem}"
export REQUESTS_CA_BUNDLE="${REQUESTS_CA_BUNDLE:-$SSL_CERT_FILE}"
export CURL_CA_BUNDLE="${CURL_CA_BUNDLE:-$SSL_CERT_FILE}"

mkdir -p "$MODEL_DIR/hub" "$MODEL_DIR/transformers"

if [[ ! -x "$AI_WHISPERX_BIN" ]]; then
  if command -v whisperx >/dev/null 2>&1; then
    AI_WHISPERX_BIN="$(command -v whisperx)"
  else
    echo "error: whisperx not found at $AI_WHISPERX_BIN and not on PATH" >&2
    echo "       Suggestion: bash ~/dotfiles/ai/prepare-whisperx-session.sh --install" >&2
    exit 1
  fi
fi

export AI_WHISPERX_BIN

echo "==> Project: $AI_PROJECT"
echo "==> Session: $AI_SESSION"
echo "==> ASR model: $AI_ASR_MODEL"
echo "==> WhisperX bin: $AI_WHISPERX_BIN"
echo "==> HF token file: $HF_TOKEN_FILE"
echo "==> Cache dir: $MODEL_DIR"

# Ensure the sandbox env and paths are active for the current shell.
eval "$(bash "$SCRIPT_DIR/prepare-whisperx-session.sh" --print-env 2>/dev/null || true)"

CMD=(bash "$DOTFILES_DIR/ai/ai-session-manager.sh" create-minutes --title "$TITLE" --owner "$OWNER" --date "$MEETING_DATE" --diarize)
if [[ "$OVERWRITE" == true ]]; then
  CMD+=(--overwrite)
fi

printf '\n==> Running: %s\n' "${CMD[*]}"
"${CMD[@]}"
