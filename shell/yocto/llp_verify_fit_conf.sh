#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  llp_verify_fit_conf.sh <deploy-dir-or-fitImage> [machine]

Examples:
  llp_verify_fit_conf.sh /home/user/build/tmp/deploy/images/imx6s-mcg imx6s-mcg
  llp_verify_fit_conf.sh /home/user/build/tmp/deploy/images/imx6s-mcg/fitImage imx6s-mcg
  llp_verify_fit_conf.sh ./build-docker/tmp/deploy/images/imx6s-mcg imx6s-mcg

The script reports the FIT default configuration using two methods:
1. mkimage -l <fitImage>   (if mkimage is installed)
2. parsing fitImage-its-<machine>
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage >&2
  exit 2
fi

input_path="$1"
machine="${2:-}"

if [[ -d "${input_path}" ]]; then
  deploy_dir="${input_path}"
  fit_image="${deploy_dir}/fitImage"
else
  fit_image="${input_path}"
  deploy_dir="$(dirname "${fit_image}")"
fi

if [[ ! -e "${fit_image}" ]]; then
  echo "Error: fitImage not found: ${fit_image}" >&2
  exit 3
fi

if [[ -z "${machine}" ]]; then
  machine="$(basename "${deploy_dir}")"
fi

its_file="${deploy_dir}/fitImage-its-${machine}"
if [[ ! -e "${its_file}" ]]; then
  # Fallback to a timestamped ITS if the symlink is absent.
  its_file="$(find "${deploy_dir}" -maxdepth 1 -type f -name 'fitImage-its--*.its' | head -n1 || true)"
fi

echo "FIT verification"
echo "deploy_dir: ${deploy_dir}"
echo "fitImage:   ${fit_image}"
echo "machine:    ${machine}"
echo ""

if command -v mkimage >/dev/null 2>&1; then
  echo "Method 1: mkimage -l"
  mkimage -l "${fit_image}" | grep -E 'FIT description:|Default Configuration:|Configuration [0-9] \(' || true
  echo ""
else
  echo "Method 1: mkimage -l"
  echo "mkimage not installed; run install-fedora-dev.sh to install uboot-tools"
  echo ""
fi

if [[ -n "${its_file}" && -e "${its_file}" ]]; then
  echo "Method 2: FIT ITS parsing"
  default_conf="$(grep -E '^[[:space:]]*default = ' "${its_file}" | sed -E 's/.*"([^"]+)".*/\1/' | head -n1 || true)"
  echo "ITS file: ${its_file}"
  if [[ -n "${default_conf}" ]]; then
    echo "Default configuration: ${default_conf}"
  fi
  echo "Configurations:"
  grep -E '^[[:space:]]*conf-[^[:space:]]+[[:space:]]*\{' "${its_file}" | sed -E 's/^[[:space:]]*([^[:space:]]+)[[:space:]]*\{.*/  \1/' || true
  echo ""
  if [[ -n "${default_conf}" ]]; then
    echo "Recommended U-Boot command:"
    echo "setenv fit_conf ${default_conf}"
  fi
else
  echo "Method 2: FIT ITS parsing"
  echo "No ITS file found in ${deploy_dir}" >&2
  exit 4
fi
