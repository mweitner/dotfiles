#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: print-ai-session-env.sh [project] [session]

Print the exact environment exports used by the ai-session-manager WhisperX flow.
This is a dry-run helper for the verified runtime setup without executing minutes generation.

Arguments:
  project                 AI project name (or set AI_PROJECT)
  session                 AI session name (or set AI_SESSION)

Options:
  --token-file <path>     Hugging Face token file (default: ~/dotfiles/.secrets/hf/.hf-les-ems-whisperx-diarization-local-2026-08)
  --asr-model <path>     Local Whisper model (default: /home/ldcwem0/tools/whisper.cpp/models/ggml-large-v3.bin)
  --whisperx-bin <path>  WhisperX CLI path (default: /home/ldcwem0/.local/bin/whisperx)
  --cache-dir <path>     Hugging Face cache root (default: /mnt/data/huggingface)
  --device <cpu|cuda>    WhisperX device (default: cpu)
  --help                 Show this help text

Examples:
  bash ~/dotfiles/ai/print-ai-session-env.sh les-ems-pilot-ecocoach 2026.08.27-technical-deep-dive
  AI_PROJECT=les-ems-pilot-ecocoach AI_SESSION=2026.08.27-technical-deep-dive bash ~/dotfiles/ai/print-ai-session-env.sh
EOF
}

PROJECT="${AI_PROJECT:-}"
SESSION="${AI_SESSION:-}"
TOKEN_FILE="${HF_TOKEN_FILE:-$HOME/dotfiles/.secrets/hf/.hf-les-ems-whisperx-diarization-local-2026-08}"
ASR_MODEL="${AI_ASR_MODEL:-/home/ldcwem0/tools/whisper.cpp/models/ggml-large-v3.bin}"
WHISPERX_BIN="${AI_WHISPERX_BIN:-/home/ldcwem0/.local/bin/whisperx}"
CACHE_DIR="${MODEL_DIR:-/mnt/data/huggingface}"
DEVICE="${AI_ASR_DEVICE:-cpu}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --token-file)
      [[ $# -gt 1 ]] || { echo "error: --token-file requires a value" >&2; exit 1; }
      TOKEN_FILE="$2"
      shift 2
      ;;
    --asr-model)
      [[ $# -gt 1 ]] || { echo "error: --asr-model requires a value" >&2; exit 1; }
      ASR_MODEL="$2"
      shift 2
      ;;
    --whisperx-bin)
      [[ $# -gt 1 ]] || { echo "error: --whisperx-bin requires a value" >&2; exit 1; }
      WHISPERX_BIN="$2"
      shift 2
      ;;
    --cache-dir)
      [[ $# -gt 1 ]] || { echo "error: --cache-dir requires a value" >&2; exit 1; }
      CACHE_DIR="$2"
      shift 2
      ;;
    --device)
      [[ $# -gt 1 ]] || { echo "error: --device requires a value" >&2; exit 1; }
      DEVICE="$2"
      shift 2
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

if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "error: token file not found: $TOKEN_FILE" >&2
  exit 1
fi

TOKEN="$(tr -d '\r\n' < "$TOKEN_FILE")"

mkdir -p "$CACHE_DIR/hub" "$CACHE_DIR/transformers"

cat <<EOF
export AI_PROJECT="$PROJECT"
export AI_SESSION="$SESSION"
export AI_ASR_MODEL="$ASR_MODEL"
export AI_WHISPERX_BIN="$WHISPERX_BIN"
export AI_ASR_DEVICE="$DEVICE"
export AI_ASR_BATCH_SIZE=1
export HF_TOKEN="$TOKEN"
export HUGGINGFACE_TOKEN="$TOKEN"
export HF_HOME="$CACHE_DIR"
export HF_HUB_CACHE="$CACHE_DIR/hub"
export HUGGINGFACE_HUB_CACHE="$CACHE_DIR/hub"
export TRANSFORMERS_CACHE="$CACHE_DIR/transformers"
export HF_HUB_DISABLE_SYMLINKS=1
export HF_HUB_DISABLE_SYMLINKS_WARNING=1
export SSL_CERT_FILE="/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem"
export REQUESTS_CA_BUNDLE="/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem"
export CURL_CA_BUNDLE="/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem"
export PATH="\$HOME/.local/bin:\$PATH"
EOF
