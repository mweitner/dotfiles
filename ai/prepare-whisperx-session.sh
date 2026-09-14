#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: prepare-whisperx-session.sh [options]

Prepare a dedicated uv-managed WhisperX runtime for ai-session-manager diarization.

Options:
  --python <version>             Python version to use for the uv tool sandbox (default: 3.11)
  --install                     Install WhisperX into the uv tool sandbox if missing
  --show-path                   Print the resolved whisperx CLI path
  --print-env                   Print shell exports for ai-session-manager diarization
  --help                        Show this help text

Examples:
  bash ~/dotfiles/ai/prepare-whisperx-session.sh --install
  AI_WHISPERX_BIN=~/.local/bin/whisperx ~/dotfiles/ai/ai-session-manager.sh create-minutes --diarize
  eval "$(bash ~/dotfiles/ai/prepare-whisperx-session.sh --print-env)"
EOF
}

PYTHON_VERSION="3.11"
INSTALL_WHISPERX=false
SHOW_PATH=false
PRINT_ENV=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --python)
      shift
      [[ $# -gt 0 ]] || { echo "error: --python requires a version" >&2; exit 1; }
      PYTHON_VERSION="$1"
      ;;
    --install)
      INSTALL_WHISPERX=true
      ;;
    --show-path)
      SHOW_PATH=true
      ;;
    --print-env)
      PRINT_ENV=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

export PATH="$HOME/.local/bin:$PATH"

resolve_system_ca_bundle() {
  local candidate=""
  for candidate in \
    /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
    /etc/ssl/certs/ca-certificates.crt \
    /etc/ssl/cert.pem; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

SYSTEM_CA_BUNDLE="$(resolve_system_ca_bundle || true)"
if [[ -n "$SYSTEM_CA_BUNDLE" ]]; then
  export SSL_CERT_FILE="$SYSTEM_CA_BUNDLE"
  export REQUESTS_CA_BUNDLE="$SYSTEM_CA_BUNDLE"
  export CURL_CA_BUNDLE="$SYSTEM_CA_BUNDLE"
fi

NAS_HF_ROOT="/mnt/data/huggingface"
mkdir -p "$NAS_HF_ROOT/hub" "$NAS_HF_ROOT/transformers"
if [[ -d "$NAS_HF_ROOT" ]]; then
  export HF_HOME="$NAS_HF_ROOT"
  export HF_HUB_CACHE="$NAS_HF_ROOT/hub"
  export HUGGINGFACE_HUB_CACHE="$NAS_HF_ROOT/hub"
  export TRANSFORMERS_CACHE="$NAS_HF_ROOT/transformers"
  export HF_HUB_DISABLE_SYMLINKS=1
  export HF_HUB_DISABLE_SYMLINKS_WARNING=1
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "Installing uv first..."
  if ! curl -fsSL https://astral.sh/uv/install.sh | sh; then
    echo "error: uv installation failed" >&2
    exit 1
  fi
  export PATH="$HOME/.local/bin:$PATH"
fi

if [[ "$INSTALL_WHISPERX" == true || "$SHOW_PATH" == true || "$PRINT_ENV" == true ]]; then
  if ! command -v whisperx >/dev/null 2>&1; then
    echo "Installing whisperx in a dedicated uv sandbox..."
    uv tool install --python "$PYTHON_VERSION" whisperx || {
      echo "error: uv tool install whisperx failed" >&2
      exit 1
    }
  fi

  if ! command -v huggingface-cli >/dev/null 2>&1; then
    echo "Installing huggingface_hub[cli] for the HF token / model access checks..."
    uv tool install --python "$PYTHON_VERSION" "huggingface_hub[cli]" || {
      echo "error: uv tool install huggingface_hub[cli] failed" >&2
      exit 1
    }
  fi
fi

RESOLVED_BIN=""
if command -v whisperx >/dev/null 2>&1; then
  RESOLVED_BIN="$(command -v whisperx)"
elif [[ -x "$HOME/.local/bin/whisperx" ]]; then
  RESOLVED_BIN="$HOME/.local/bin/whisperx"
fi

if [[ "$SHOW_PATH" == true ]]; then
  if [[ -n "$RESOLVED_BIN" ]]; then
    echo "$RESOLVED_BIN"
  else
    echo "error: whisperx not found" >&2
    exit 1
  fi
  exit 0
fi

if [[ "$PRINT_ENV" == true || "$INSTALL_WHISPERX" == true ]]; then
  echo "# whisperx is provided by the uv sandboxed tool: $RESOLVED_BIN" >&2 || true
fi

if [[ "$PRINT_ENV" == true ]]; then
  if [[ -z "$RESOLVED_BIN" ]]; then
    echo "error: whisperx not found" >&2
    exit 1
  fi
  echo "export AI_WHISPERX_BIN='$RESOLVED_BIN'"
  echo "export PATH='$HOME/.local/bin:$PATH'"
  if [[ -n "$SYSTEM_CA_BUNDLE" ]]; then
    echo "export SSL_CERT_FILE='$SYSTEM_CA_BUNDLE'"
    echo "export REQUESTS_CA_BUNDLE='$SYSTEM_CA_BUNDLE'"
    echo "export CURL_CA_BUNDLE='$SYSTEM_CA_BUNDLE'"
  fi
  if [[ -d "$NAS_HF_ROOT" ]]; then
    echo "export HF_HOME='$NAS_HF_ROOT'"
    echo "export HF_HUB_CACHE='$NAS_HF_ROOT/hub'"
    echo "export HUGGINGFACE_HUB_CACHE='$NAS_HF_ROOT/hub'"
    echo "export TRANSFORMERS_CACHE='$NAS_HF_ROOT/transformers'"
    echo "export HF_HUB_DISABLE_SYMLINKS=1"
    echo "export HF_HUB_DISABLE_SYMLINKS_WARNING=1"
  fi
  exit 0
fi

if [[ -n "$RESOLVED_BIN" ]]; then
  echo "WhisperX sandbox is ready."
  echo "Resolved CLI: $RESOLVED_BIN"
  echo "Make it active with: export AI_WHISPERX_BIN='$RESOLVED_BIN'"
  echo "Or use: eval \"\$(bash ~/dotfiles/ai/prepare-whisperx-session.sh --print-env)\""
else
  echo "error: whisperx is still unavailable after installation" >&2
  exit 1
fi
