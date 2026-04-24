#!/usr/bin/env bash
set -euo pipefail

# Local-only LLP documentation build wrapper.
# Uses a temporary DOC_DOCKERFILE override so project and submodule files stay untouched.

PROJECT_ROOT="${PROJECT_ROOT:-$PWD}"
DOC_DIR="${DOC_DIR:-documentation}"
SERVICE="doc"
DRY_RUN=false
KEEP_DOCKERFILE=false
BUILD_OPEN=false

usage() {
  cat <<'EOF'
Usage:
  llp-doc-local [options]

Options:
  --project-root <path>  Path to layers/liebherr checkout (default: current dir)
  --doc-dir <dir>        Documentation directory (default: documentation)
  --service <name>       yoctose service: doc | doc-dev (default: doc)
  --build-open           Build docs and open host _build/html/index.html
  --dry-run              Print command and temp Dockerfile path without executing
  --keep-dockerfile      Do not remove temporary Dockerfile
  -h, --help             Show this help

Examples:
  llp-doc-local
  llp-doc-local --build-open
  llp-doc-local --service doc-dev
  llp-doc-local --project-root ~/llp-dev/linux-llp/layers/liebherr
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root)
      PROJECT_ROOT="${2:-}"
      shift 2
      ;;
    --doc-dir)
      DOC_DIR="${2:-}"
      shift 2
      ;;
    --service)
      SERVICE="${2:-}"
      shift 2
      ;;
    --build-open)
      BUILD_OPEN=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --keep-dockerfile)
      KEEP_DOCKERFILE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ "$SERVICE" != "doc" && "$SERVICE" != "doc-dev" ]]; then
  echo "Error: --service must be 'doc' or 'doc-dev'" >&2
  exit 2
fi

if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "Error: project root not found: $PROJECT_ROOT" >&2
  exit 2
fi

if [[ ! -x "$PROJECT_ROOT/ci/shared/yoctose" ]]; then
  echo "Error: yoctose not found at $PROJECT_ROOT/ci/shared/yoctose" >&2
  echo "Hint: set --project-root to your layers/liebherr checkout." >&2
  exit 2
fi

if [[ ! -d "$PROJECT_ROOT/$DOC_DIR" ]]; then
  echo "Error: doc dir not found: $PROJECT_ROOT/$DOC_DIR" >&2
  exit 2
fi

TMP_DOCKERFILE="$(mktemp /tmp/llp-doc-local.XXXXXX.Dockerfile)"
cleanup() {
  if [[ "$KEEP_DOCKERFILE" == false && -f "$TMP_DOCKERFILE" ]]; then
    rm -f "$TMP_DOCKERFILE"
  fi
}
trap cleanup EXIT

cat > "$TMP_DOCKERFILE" <<'EOF'
FROM ubuntu:noble AS base
ARG DOC_DIR=.

COPY ${DOC_DIR}/Makefile /dev/null
COPY ${DOC_DIR}/uv.lock /dev/null
COPY ${DOC_DIR}/pyproject.toml /dev/null
COPY ${DOC_DIR}/.python-version /dev/null

RUN apt-get update && apt-get -y install python3-pip make git && \
    pip3 install --break-system-packages --no-cache-dir uv

COPY ${DOC_DIR}/Makefile ${DOC_DIR}/install-dep[s] /usr/local/sbin/

RUN rm /usr/local/sbin/Makefile && \
    test -x /usr/local/bin/uv && \
    ln -sf /usr/local/bin/uv /usr/local/bin/uvx

RUN if [ -f /usr/local/sbin/install-deps ]; then /usr/local/sbin/install-deps; fi

RUN usermod -m -d /home/yocto -l yocto ubuntu && groupmod -n yocto ubuntu

USER 1000:1000
ENV UV_PROJECT_ENVIRONMENT=/home/yocto/uv
ENV PATH=/home/yocto/uv/bin:${PATH}
WORKDIR /mnt/${DOC_DIR}

RUN --mount=type=bind,source=${DOC_DIR}/uv.lock,target=/mnt/uv.lock \
    --mount=type=bind,source=${DOC_DIR}/pyproject.toml,target=/mnt/pyproject.toml \
    --mount=type=bind,source=${DOC_DIR}/.python-version,target=/mnt/.python-version \
    uv sync --frozen

FROM base AS html
ENTRYPOINT ["uv", "run", "--frozen", "make", "html"]

FROM base
ENTRYPOINT ["/bin/bash"]
EOF

echo "[llp-doc-local] project root: $PROJECT_ROOT"
echo "[llp-doc-local] doc dir:      $DOC_DIR"
echo "[llp-doc-local] service:      $SERVICE"
echo "[llp-doc-local] dockerfile:   $TMP_DOCKERFILE"

if [[ "$BUILD_OPEN" == true && "$SERVICE" != "doc" ]]; then
  echo "[llp-doc-local] --build-open uses service 'doc'; overriding --service $SERVICE"
  SERVICE="doc"
fi

action_cmd=("$PROJECT_ROOT/ci/shared/yoctose" "run" "$SERVICE")
if [[ "$DRY_RUN" == true ]]; then
  echo "[llp-doc-local] dry-run command: DOC_DOCKERFILE=$TMP_DOCKERFILE ${action_cmd[*]}"
  if [[ "$BUILD_OPEN" == true ]]; then
    echo "[llp-doc-local] dry-run open: $PROJECT_ROOT/$DOC_DIR/_build/html/index.html"
  fi
  exit 0
fi

(
  cd "$PROJECT_ROOT"
  DOC_DOCKERFILE="$TMP_DOCKERFILE" "${action_cmd[@]}"
)

if [[ "$BUILD_OPEN" == true ]]; then
  index_file="$PROJECT_ROOT/$DOC_DIR/_build/html/index.html"
  if [[ -f "$index_file" ]]; then
    if command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$index_file" >/dev/null 2>&1 || true
    fi
    echo "[llp-doc-local] html index: $index_file"
  else
    echo "[llp-doc-local] Warning: expected output not found: $index_file" >&2
  fi
fi
