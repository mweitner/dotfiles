#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  generate-llp-dev-secureboot-secrets.sh [options]

Generate development-only secure boot key material for local LLP builds.

Options:
  --keys-dir <path>    Target keys directory
                       (default: ~/dotfiles/.secrets/yocto/keys/llp/dev)
  --force              Overwrite existing files
  -h, --help           Show help

Generated files:
  scr_boot_rot_private_key
  scr_boot_trusted_world_private_key
  scr_boot_non_trusted_world_private_key
  scr_boot_bl31_private_key
  scr_boot_bl32_private_key
  scr_boot_bl33_private_key
  scr_boot_scp_bl2_private_key
  optee_ta_private_key
  scr_boot_uboot_fit_key
  scr_boot_uboot_fit_cert

Security note:
  These keys are for local development only and must never be used for production signing.
EOF
}

KEYS_DIR="${HOME}/dotfiles/.secrets/yocto/keys/llp/dev"
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keys-dir)
      KEYS_DIR="${2:-}"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument '$1'" >&2
      usage >&2
      exit 2
      ;;
  esac
done

resolved_keys_dir="$(realpath -m "${KEYS_DIR}")"
case "${resolved_keys_dir}" in
  */.secrets/yocto/keys/llp/prod|*/.secrets/yocto/keys/llp/prod/*)
    echo "Error: refusing to generate development keys in prod directory: ${resolved_keys_dir}" >&2
    exit 1
    ;;
esac

if ! command -v openssl >/dev/null 2>&1; then
  echo "Error: openssl not found" >&2
  exit 1
fi

mkdir -p "${KEYS_DIR}"

gen_rsa_key() {
  local out="$1"
  if [[ -e "${out}" && ${FORCE} -ne 1 ]]; then
    echo "Skip existing: ${out}"
    return 0
  fi
  openssl genrsa -out "${out}" 2048 >/dev/null 2>&1
  chmod 600 "${out}"
  echo "Generated: ${out}"
}

gen_rsa_key "${KEYS_DIR}/scr_boot_rot_private_key"
gen_rsa_key "${KEYS_DIR}/scr_boot_trusted_world_private_key"
gen_rsa_key "${KEYS_DIR}/scr_boot_non_trusted_world_private_key"
gen_rsa_key "${KEYS_DIR}/scr_boot_bl31_private_key"
gen_rsa_key "${KEYS_DIR}/scr_boot_bl32_private_key"
gen_rsa_key "${KEYS_DIR}/scr_boot_bl33_private_key"
gen_rsa_key "${KEYS_DIR}/scr_boot_scp_bl2_private_key"
gen_rsa_key "${KEYS_DIR}/optee_ta_private_key"
gen_rsa_key "${KEYS_DIR}/scr_boot_uboot_fit_key"

# U-Boot FIT uses a key + certificate pair.
fit_key="${KEYS_DIR}/scr_boot_uboot_fit_key"
fit_cert="${KEYS_DIR}/scr_boot_uboot_fit_cert"
if [[ -e "${fit_cert}" && ${FORCE} -ne 1 ]]; then
  echo "Skip existing: ${fit_cert}"
else
  openssl req -batch -new -x509 -key "${fit_key}" -out "${fit_cert}" -days 36500 -subj "/CN=llp-dev-fit/" >/dev/null 2>&1
  chmod 644 "${fit_cert}"
  echo "Generated: ${fit_cert}"
fi

echo
echo "Done. Development secure boot keys are available in: ${KEYS_DIR}"
echo "Reminder: never use these keys for production images."
