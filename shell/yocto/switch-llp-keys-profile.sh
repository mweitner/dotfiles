#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  switch-llp-keys-profile.sh <project> [profile] [options]

Point /opt/yocto/keys/<project> at the selected project key directory.

If the requested profile directory exists, it is used.
If the profile is omitted, it defaults to "dev".
If the requested profile is "dev" and no profile directory exists, the script
falls back to the flat project directory so older layouts continue to work.

Options:
  --link-path <path>   Symlink to update
                       (default: /opt/yocto/keys/<project>)
  --keys-root <path>   Project keys root
                       (default: ~/dotfiles/.secrets/yocto/keys)
  --print-only         Show the change without applying it
  -h, --help           Show help

Examples:
  switch-llp-keys-profile.sh llp
  switch-llp-keys-profile.sh llp prod
  switch-llp-keys-profile.sh dps
  switch-llp-keys-profile.sh lpo dev
EOF
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 2
fi

PROJECT="$1"
shift

PROFILE="dev"
if [[ $# -gt 0 ]] && [[ "${1}" != --* ]]; then
  PROFILE="$1"
  shift
fi

LINK_PATH="/opt/yocto/keys/${PROJECT}"
KEYS_ROOT="${HOME}/dotfiles/.secrets/yocto/keys"
PRINT_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --link-path)
      LINK_PATH="${2:-}"
      shift 2
      ;;
    --keys-root)
      KEYS_ROOT="${2:-}"
      shift 2
      ;;
    --print-only)
      PRINT_ONLY=1
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

PROJECT_ROOT="${KEYS_ROOT}/${PROJECT}"
PROFILE_TARGET="${PROJECT_ROOT}/${PROFILE}"
TARGET_PATH=""

if [[ -d "${PROFILE_TARGET}" ]]; then
  TARGET_PATH="${PROFILE_TARGET}"
elif [[ "${PROFILE}" == "dev" ]] && [[ -d "${PROJECT_ROOT}" ]]; then
  TARGET_PATH="${PROJECT_ROOT}"
else
  echo "Error: key directory not found for project '${PROJECT}' and profile '${PROFILE}'." >&2
  echo "       Checked: ${PROFILE_TARGET}" >&2
  if [[ -d "${PROJECT_ROOT}" ]]; then
    echo "       Project root exists: ${PROJECT_ROOT}" >&2
  fi
  exit 1
fi

if [[ ! -d "${PROJECT_ROOT}" ]]; then
  echo "Error: project keys root not found: ${PROJECT_ROOT}" >&2
  exit 1
fi

if [[ -e "${LINK_PATH}" && ! -L "${LINK_PATH}" ]]; then
  echo "Error: ${LINK_PATH} exists and is not a symlink. Refusing to replace it." >&2
  exit 1
fi

current_target=""
if [[ -L "${LINK_PATH}" ]]; then
  current_target="$(readlink -f "${LINK_PATH}")"
fi

echo "Project: ${PROJECT}"
echo "Profile: ${PROFILE}"
echo "Current link: ${LINK_PATH}"
if [[ -n "${current_target}" ]]; then
  echo "Current target: ${current_target}"
else
  echo "Current target: <not set>"
fi
echo "New target: ${TARGET_PATH}"

if [[ "${TARGET_PATH}" == "${PROJECT_ROOT}" ]] && [[ "${PROFILE}" == "dev" ]]; then
  echo "Info: ${PROJECT} has no dedicated dev profile directory; using flat project root."
fi

if [[ ${PRINT_ONLY} -eq 1 ]]; then
  exit 0
fi

mkdir -p "$(dirname "${LINK_PATH}")"
ln -sfn "${TARGET_PATH}" "${LINK_PATH}"

echo "Updated ${LINK_PATH} -> $(readlink -f "${LINK_PATH}")"
