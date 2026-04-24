#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  sync-llp-yoctose-secrets.sh [options]

Prepare yoctose-compatible secret file names for LLP in a target .secrets directory.

Options:
  --keys-dir <path>      Source keys directory (default: /opt/yocto/keys/llp)
  --target-dir <path>    Destination secrets directory
                         (default: ~/dotfiles/.secrets/yocto/yoctose/llp)
  --copy                 Copy files instead of symlinking
  --force                Overwrite existing destination files/symlinks
  --help, -h             Show this help and exit

Notes:
  - This script maps local key file names to yoctose compose feature file names.
  - It reports missing files (especially secure-boot keys) so you can request them.
  - To use with yoctose, set: export SECRETS_DIR=<target-dir>
EOF
}

KEYS_DIR="/opt/yocto/keys/llp"
TARGET_DIR="${HOME}/dotfiles/.secrets/yocto/yoctose/llp"
MODE="symlink"
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keys-dir)
      KEYS_DIR="${2:-}"
      shift 2
      ;;
    --target-dir)
      TARGET_DIR="${2:-}"
      shift 2
      ;;
    --copy)
      MODE="copy"
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -d "${KEYS_DIR}" ]]; then
  echo "Error: keys dir not found: ${KEYS_DIR}" >&2
  exit 1
fi

mkdir -p "${TARGET_DIR}"

# target_name|candidate1,candidate2,...
MAPPINGS=(
  "swupdate_key_password|swupdate-password.txt,swupdate_key_password"
  "swupdate_private_key|swupdate-private.pem,swupdate_private_key"
  "swupdate_public_key|swupdate-public.pem,swupdate_public_key"
  "scr_boot_rot_private_key|scr_boot_rot_private_key,ROOT_OF_TRUST_SECRET.pem"
  "scr_boot_trusted_world_private_key|scr_boot_trusted_world_private_key,TRUSTED_WORLD_SECRET.pem"
  "scr_boot_non_trusted_world_private_key|scr_boot_non_trusted_world_private_key,NON_TRUSTED_WORLD_SECRET.pem"
  "scr_boot_bl31_private_key|scr_boot_bl31_private_key,BL31_SECRET.pem"
  "scr_boot_bl32_private_key|scr_boot_bl32_private_key,BL32_SECRET.pem"
  "scr_boot_bl33_private_key|scr_boot_bl33_private_key,BL33_SECRET.pem"
  "scr_boot_scp_bl2_private_key|scr_boot_scp_bl2_private_key,SCP_BL2_SECRET.pem"
  "optee_ta_private_key|optee_ta_private_key,OPTEE_TA_SECRET.pem"
  "scr_boot_uboot_fit_key|scr_boot_uboot_fit_key,UBOOT_FIT.key"
  "scr_boot_uboot_fit_cert|scr_boot_uboot_fit_cert,UBOOT_FIT.crt"
)

linked=0
missing=0

link_or_copy() {
  local src="$1"
  local dst="$2"

  if [[ -e "${dst}" || -L "${dst}" ]]; then
    if [[ ${FORCE} -eq 1 ]]; then
      rm -f "${dst}"
    else
      echo "Info: destination exists, skipping (use --force): ${dst}"
      return 0
    fi
  fi

  if [[ "${MODE}" == "copy" ]]; then
    install -m 0600 "${src}" "${dst}"
  else
    ln -s "${src}" "${dst}"
  fi
}

for entry in "${MAPPINGS[@]}"; do
  target="${entry%%|*}"
  candidates_csv="${entry#*|}"

  found_src=""
  IFS=',' read -r -a candidates <<< "${candidates_csv}"
  for name in "${candidates[@]}"; do
    src="${KEYS_DIR}/${name}"
    if [[ -f "${src}" ]]; then
      found_src="${src}"
      break
    fi
  done

  if [[ -n "${found_src}" ]]; then
    dst="${TARGET_DIR}/${target}"
    link_or_copy "${found_src}" "${dst}"
    echo "OK: ${target} <- ${found_src}"
    linked=$((linked + 1))
  else
    echo "MISSING: ${target} (looked in ${KEYS_DIR})"
    missing=$((missing + 1))
  fi
done

# netrc is outside keys dir but needed by compose/features/netrc.yaml
if [[ -f "${HOME}/.netrc" ]]; then
  netrc_dst="${TARGET_DIR}/yocto_netrc"
  link_or_copy "${HOME}/.netrc" "${netrc_dst}"
  echo "OK: yocto_netrc <- ${HOME}/.netrc"
else
  echo "MISSING: yocto_netrc (${HOME}/.netrc not found)"
  missing=$((missing + 1))
fi

echo
echo "Summary: created/updated ${linked} mapped entries, missing ${missing}."
echo "Use with yoctose: export SECRETS_DIR='${TARGET_DIR}'"
