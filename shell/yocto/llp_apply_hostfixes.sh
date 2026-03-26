#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  llp_apply_hostfixes.sh [yocto-project-root]

Applies the current Yocto host compatibility fixes by:
1) Applying BitBake Python 3.14 multiprocessing patch in layers/poky.
2) Copying recipe fix overlay files into layers/.

If yocto-project-root is omitted, the current directory is used.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="${SCRIPT_DIR}/bitbake-python314-multiprocessing-fork.patch"
OVERLAY_DIR="${SCRIPT_DIR}/yocto-hostfixes-overlay"
PROJECT_ROOT="${1:-$PWD}"
LAYERS_DIR="${PROJECT_ROOT}/layers"
POKY_DIR="${LAYERS_DIR}/poky"

if [[ ! -f "${PATCH_FILE}" ]]; then
  echo "Error: missing patch file: ${PATCH_FILE}" >&2
  exit 1
fi

if [[ ! -d "${OVERLAY_DIR}" ]]; then
  echo "Error: missing overlay directory: ${OVERLAY_DIR}" >&2
  exit 1
fi

if [[ ! -d "${LAYERS_DIR}" ]]; then
  echo "Error: missing layers directory: ${LAYERS_DIR}" >&2
  exit 1
fi

if [[ ! -d "${POKY_DIR}" ]]; then
  echo "Error: missing poky directory: ${POKY_DIR}" >&2
  exit 1
fi

echo "==> Project root: ${PROJECT_ROOT}"

if grep -q "set_start_method('fork', force=True)" "${POKY_DIR}/bitbake/bin/bitbake-worker" 2>/dev/null; then
  echo "==> BitBake multiprocessing fix already present; skipping patch"
else
  echo "==> Applying BitBake multiprocessing patch"
  (
    cd "${POKY_DIR}"
    patch -p1 --forward < "${PATCH_FILE}"
  )
fi

echo "==> Installing overlay files into layers/"
while IFS= read -r -d '' rel; do
  rel="${rel#./}"
  src="${OVERLAY_DIR}/${rel}"
  dst="${LAYERS_DIR}/${rel}"
  mkdir -p "$(dirname "${dst}")"
  cp "${src}" "${dst}"
  echo "  installed: layers/${rel}"
done < <(cd "${OVERLAY_DIR}" && find . -type f -print0)

echo "==> Host fixes applied successfully"
