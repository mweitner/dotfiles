#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  llp_docker_shell.sh [options]

Launch a Yocto build container via docker-compose.yml in the workspace.

Supports any Liebherr Yocto project (linux-lpo, linux-dps, etc.) via --project and --project-keys flags.

Options:
  --workdir <path>                  Yocto project root (default: auto-detect from pwd,
                                    fallback to ~/lpo-dev/linux-lpo)
  --project <name>                  PROJECT env value (default: linux-lpo)
  --project-keys <name>             PROJECT_KEYS env value (default: lpo)
  --swupdate-password-file <path>   SWUPDATE_PASSWORD_FILE (default: /opt/yocto/keys/<project-keys>/swupdate-password.txt)
  --sota-auth-token <token>         SOTA_AUTH_TOKEN value (default: from environment)
  --templateconf <path>             TEMPLATECONF path in container
                                    (default: auto-detect from project-specific meta layers,
                                     fallback to meta-liebherr-lpo-display or poky)
  --docker-build-dir <path>         Host build dir target for /opt/yocto/build/<project> symlink
                                    (default: <workdir>/build-docker)
  --keep-conf                       Keep existing <docker-build-dir>/conf (skip template reset)
  --no-build-symlink                Do not manage /opt/yocto/build/<project> symlink
  --local-conf-append-file <path>   Host file appended to conf/local.conf after oe-init-build-env
                                    (default: <workdir>/.local-conf/local.conf.append)
  --no-local-conf-append            Disable local.conf append injection
  --llpnetboot                      Enable netboot_support local.conf injection (separate from general append)
  --netboot-append-file <path>      Host file appended for netboot_support
                                    (default: <workdir>/.local-conf/local.conf.netboot.append)
  --no-netboot-append               Disable netboot_support injection
  --dl-dir <path>                   Override DL_DIR in generated conf/local.conf
  --sstate-dir <path>               Override SSTATE_DIR in generated conf/local.conf
  --yocto-release <release>         Declare this project's Yocto release (e.g. scarthgap)
                                    Auto-selects PROJECT_SHARED_ROOT unless --project-shared-root
                                    is explicitly set. Warns if the share root does not exist.
  --project-shared-root <path>      Host path used for compose var PROJECT_SHARED_ROOT
                                    (default: /opt/yocto/shared)
  --create-share <release>          Create /opt/yocto/shared[-<release>] skeleton and use it
                                    for this run when --project-shared-root is not explicitly set
  --seed-from <release|path>        Seed created share from an existing release/path
                                    (copies downloads/sstate-cache, keeps existing target files)
  --list-yocto-releases             Print supported Yocto release history and exit
  --netrc-file <path>               Host .netrc to mount as /home/yocto/.netrc (default: ~/.netrc)
  --no-netrc                        Do not mount .netrc into container
  --service <name>                  Compose service (default: liebherr-linux-build-container)
  --no-init-build-env               Do not auto-source oe-init-build-env in container
  --no-x11                          Do not pass DISPLAY and /tmp/.X11-unix mount
  --selinux-z                       Add :z label option to X11 bind mount
  --no-build                        Skip compose --build
  --keep-container                  Skip compose --rm
  --print-only                      Print command without executing
  -h, --help                        Show help

Environment:
  SOTA_AUTH_TOKEN can be provided via environment instead of CLI.
  PROJECT_SHARED_ROOT can be provided via environment (default: /opt/yocto/shared).

Examples:
  llp_docker_shell.sh --project linux-lpo --project-keys lpo
  llp_docker_shell.sh --project linux-dps --project-keys dps
  llp_docker_shell.sh --project linux-dps --project-keys dps --print-only
  llp_docker_shell.sh --project linux-lpo --project-keys lpo --sota-auth-token "$SOTA_AUTH_TOKEN"
  llp_docker_shell.sh --project linux-dps --project-keys dps --project-shared-root /opt/yocto/shared-kirkstone
  llp_docker_shell.sh --project linux-dps-scarthgap --project-keys dps --yocto-release scarthgap
  llp_docker_shell.sh --project linux-dps --project-keys dps --yocto-release kirkstone
  llp_docker_shell.sh --project linux-dps --project-keys dps --create-share whinlatter --seed-from scarthgap
  llp_docker_shell.sh --project linux-dps --project-keys dps --yocto-release whinlatter --create-share whinlatter --seed-from scarthgap
EOF
}

# Format: release|yocto_version|lts_flag
YOCTO_RELEASE_HISTORY=(
  "kirkstone|4.0|LTS"
  "langdale|4.1|"
  "nanbield|4.3|"
  "scarthgap|5.0|LTS"
  "styhead|5.1|"
  "walnascar|5.2|"
  "whinlatter|5.3|"
)

release_index() {
  local release_name="$1"
  local i entry release
  for i in "${!YOCTO_RELEASE_HISTORY[@]}"; do
    entry="${YOCTO_RELEASE_HISTORY[$i]}"
    release="${entry%%|*}"
    if [[ "${release}" == "${release_name}" ]]; then
      echo "${i}"
      return 0
    fi
  done
  echo "-1"
}

release_root_path() {
  local release_name="$1"
  if [[ "${release_name}" == "kirkstone" ]]; then
    echo "/opt/yocto/shared"
  else
    echo "/opt/yocto/shared-${release_name}"
  fi
}

print_yocto_release_history() {
  local entry release yp_version lts_flag
  echo "Supported Yocto release history:"
  for entry in "${YOCTO_RELEASE_HISTORY[@]}"; do
    IFS='|' read -r release yp_version lts_flag <<< "${entry}"
    if [[ -n "${lts_flag}" ]]; then
      printf '  %-10s YP %-4s (%s)\n' "${release}" "${yp_version}" "${lts_flag}"
    else
      printf '  %-10s YP %-4s\n' "${release}" "${yp_version}"
    fi
  done
}

create_share_root_for_release() {
  local target_release="$1"
  local target_root target_index
  local i entry release yp_version lts_flag
  local base_release=""
  local base_root=""

  target_index="$(release_index "${target_release}")"
  if [[ "${target_index}" -lt 0 ]]; then
    echo "Error: unsupported release for --create-share: ${target_release}" >&2
    print_yocto_release_history >&2
    return 2
  fi

  target_root="$(release_root_path "${target_release}")"

  # Resolve a predecessor that already exists on host (nearest previous release wins).
  for (( i=target_index-1; i>=0; i-- )); do
    entry="${YOCTO_RELEASE_HISTORY[$i]}"
    IFS='|' read -r release yp_version lts_flag <<< "${entry}"
    base_root="$(release_root_path "${release}")"
    if [[ -d "${base_root}" ]]; then
      base_release="${release}"
      break
    fi
  done

  sudo mkdir -p "${target_root}/downloads" "${target_root}/sstate-cache"
  sudo chown -R "$USER:$USER" "${target_root}"
  sudo chmod -R 775 "${target_root}"

  if [[ ! -f "${target_root}/.llp-share-info" ]]; then
    {
      echo "release=${target_release}"
      echo "root=${target_root}"
      echo "container_mount=/opt/yocto/shared"
      if [[ -n "${base_release}" ]]; then
        echo "base_release=${base_release}"
        echo "base_root=$(release_root_path "${base_release}")"
      else
        echo "base_release=none"
        echo "base_root=none"
      fi
      echo "created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } | sudo tee "${target_root}/.llp-share-info" >/dev/null
    sudo chown "$USER:$USER" "${target_root}/.llp-share-info"
    sudo chmod 664 "${target_root}/.llp-share-info"
  fi

  echo "Preflight: ensured Yocto share for ${target_release}: ${target_root}" >&2
  if [[ -n "${base_release}" ]]; then
    echo "Preflight: nearest existing predecessor detected: ${base_release} ($(release_root_path "${base_release}"))" >&2
  else
    echo "Preflight: no existing predecessor share detected; created fresh skeleton only." >&2
  fi

  echo "${target_root}"
}

resolve_seed_source_root() {
  local source_spec="$1"
  local source_index

  source_index="$(release_index "${source_spec}")"
  if [[ "${source_index}" -ge 0 ]]; then
    echo "$(release_root_path "${source_spec}")"
    return 0
  fi

  if [[ "${source_spec}" == /* ]]; then
    echo "${source_spec}"
    return 0
  fi

  echo "Error: --seed-from expects a known release name or absolute path, got: ${source_spec}" >&2
  return 2
}

seed_share_root_from_source() {
  local target_root="$1"
  local source_root="$2"
  local copied_any=0

  if [[ ! -d "${source_root}" ]]; then
    echo "Error: seed source root not found: ${source_root}" >&2
    return 2
  fi

  for subdir in downloads sstate-cache; do
    if [[ ! -d "${source_root}/${subdir}" ]]; then
      echo "Warning: seed source missing ${subdir}: ${source_root}/${subdir}" >&2
      continue
    fi

    mkdir -p "${target_root}/${subdir}"

    if command -v rsync >/dev/null 2>&1; then
      rsync -a --ignore-existing --info=NAME0 "${source_root}/${subdir}/" "${target_root}/${subdir}/"
    else
      cp -an "${source_root}/${subdir}/." "${target_root}/${subdir}/"
    fi
    copied_any=1
  done

  if [[ "${copied_any}" -eq 0 ]]; then
    echo "Warning: no seed content copied (source missing both downloads and sstate-cache)." >&2
  else
    echo "Preflight: seed completed from ${source_root} into ${target_root}" >&2
  fi
}

# Auto-detect workspace root from current directory if not specified
auto_detect_workdir() {
  local cwd="$PWD"
  while [[ "$cwd" != "/" ]]; do
    if [[ -f "$cwd/layers/liebherr/ci/docker-compose.yml" ]]; then
      echo "$cwd"
      return 0
    fi
    cwd="$(dirname "$cwd")"
  done
  # Fallback to linux-lpo default if not found
  echo "$HOME/lpo-dev/linux-lpo"
}

WORKDIR="${WORKDIR:-$(auto_detect_workdir)}"
PROJECT="${PROJECT:-linux-lpo}"
PROJECT_KEYS="${PROJECT_KEYS:-lpo}"
SWUPDATE_PASSWORD_FILE=""
SOTA_AUTH_TOKEN="${SOTA_AUTH_TOKEN:-}"
# TEMPLATECONF will be auto-detected later based on available meta layers
TEMPLATECONF="${TEMPLATECONF:-}"
DOCKER_BUILD_DIR=""
MANAGE_BUILD_SYMLINK=1
RESET_CONF=1
LOCAL_CONF_APPEND_FILE=""
ENABLE_LOCAL_CONF_APPEND=1
NETBOOT_SUPPORT=0
NETBOOT_APPEND_FILE=""
ENABLE_NETBOOT_APPEND=1
DL_DIR_OVERRIDE="${LLP_DL_DIR:-}"
SSTATE_DIR_OVERRIDE="${LLP_SSTATE_DIR:-}"
PROJECT_SHARED_ROOT="${PROJECT_SHARED_ROOT:-/opt/yocto/shared}"
PROJECT_SHARED_ROOT_SET_BY_CLI=0
YOCTO_RELEASE=""
CREATE_SHARE_RELEASE=""
SEED_FROM=""
LIST_YOCTO_RELEASES=0
NETRC_FILE="${NETRC_FILE:-$HOME/.netrc}"
ENABLE_NETRC=1
SERVICE="liebherr-linux-build-container"
ENABLE_X11=1
X11_SELINUX_Z=0
DO_BUILD=1
DO_RM=1
INIT_BUILD_ENV=1
PRINT_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workdir)
      WORKDIR="${2:-}"
      shift 2
      ;;
    --project)
      PROJECT="${2:-}"
      shift 2
      ;;
    --project-keys)
      PROJECT_KEYS="${2:-}"
      shift 2
      ;;
    --swupdate-password-file)
      SWUPDATE_PASSWORD_FILE="${2:-}"
      shift 2
      ;;
    --sota-auth-token)
      SOTA_AUTH_TOKEN="${2:-}"
      shift 2
      ;;
    --templateconf)
      TEMPLATECONF="${2:-}"
      shift 2
      ;;
    --docker-build-dir)
      DOCKER_BUILD_DIR="${2:-}"
      shift 2
      ;;
    --keep-conf)
      RESET_CONF=0
      shift
      ;;
    --no-build-symlink)
      MANAGE_BUILD_SYMLINK=0
      shift
      ;;
    --local-conf-append-file)
      LOCAL_CONF_APPEND_FILE="${2:-}"
      shift 2
      ;;
    --no-local-conf-append)
      ENABLE_LOCAL_CONF_APPEND=0
      shift
      ;;
    --llpnetboot)
      NETBOOT_SUPPORT=1
      shift
      ;;
    --netboot-append-file)
      NETBOOT_APPEND_FILE="${2:-}"
      shift 2
      ;;
    --no-netboot-append)
      ENABLE_NETBOOT_APPEND=0
      shift
      ;;
    --dl-dir)
      DL_DIR_OVERRIDE="${2:-}"
      shift 2
      ;;
    --sstate-dir)
      SSTATE_DIR_OVERRIDE="${2:-}"
      shift 2
      ;;
    --yocto-release)
      YOCTO_RELEASE="${2:-}"
      shift 2
      ;;
    --project-shared-root|--yocto-shared-root)
      PROJECT_SHARED_ROOT="${2:-}"
      PROJECT_SHARED_ROOT_SET_BY_CLI=1
      shift 2
      ;;
    --create-share)
      CREATE_SHARE_RELEASE="${2:-}"
      shift 2
      ;;
    --seed-from)
      SEED_FROM="${2:-}"
      shift 2
      ;;
    --list-yocto-releases)
      LIST_YOCTO_RELEASES=1
      shift
      ;;
    --netrc-file)
      NETRC_FILE="${2:-}"
      shift 2
      ;;
    --no-netrc)
      ENABLE_NETRC=0
      shift
      ;;
    --service)
      SERVICE="${2:-}"
      shift 2
      ;;
    --no-init-build-env)
      INIT_BUILD_ENV=0
      shift
      ;;
    --no-x11)
      ENABLE_X11=0
      shift
      ;;
    --selinux-z)
      X11_SELINUX_Z=1
      shift
      ;;
    --no-build)
      DO_BUILD=0
      shift
      ;;
    --keep-container)
      DO_RM=0
      shift
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
      usage
      exit 2
      ;;
  esac
done

if [[ ${LIST_YOCTO_RELEASES} -eq 1 ]]; then
  print_yocto_release_history
  exit 0
fi

# --yocto-release: validate and auto-select PROJECT_SHARED_ROOT when not explicitly set.
# For any non-kirkstone release, also ensure the share root skeleton exists on the host.
if [[ -n "${YOCTO_RELEASE}" ]]; then
  release_idx="$(release_index "${YOCTO_RELEASE}")"
  if [[ "${release_idx}" -lt 0 ]]; then
    echo "Error: unsupported --yocto-release: ${YOCTO_RELEASE}" >&2
    print_yocto_release_history >&2
    exit 2
  fi
  if [[ ${PROJECT_SHARED_ROOT_SET_BY_CLI} -eq 0 ]]; then
    PROJECT_SHARED_ROOT="$(release_root_path "${YOCTO_RELEASE}")"
  fi
  # Automatically ensure the share root exists for non-default (non-kirkstone) releases.
  # Kirkstone uses /opt/yocto/shared which is created by install-fedora.sh; no auto-create needed.
  if [[ "${YOCTO_RELEASE}" != "kirkstone" ]] && [[ ${PROJECT_SHARED_ROOT_SET_BY_CLI} -eq 0 ]]; then
    if [[ ! -d "${PROJECT_SHARED_ROOT}" ]]; then
      echo "Info: share root for '${YOCTO_RELEASE}' not found; creating skeleton: ${PROJECT_SHARED_ROOT}" >&2
    fi
    if [[ ${PRINT_ONLY} -eq 1 ]]; then
      echo "Info: --print-only active; skipping auto-create for ${PROJECT_SHARED_ROOT}." >&2
    else
      create_share_root_for_release "${YOCTO_RELEASE}" >/dev/null
    fi
  fi
fi

if [[ -n "${SEED_FROM}" ]] && [[ -z "${CREATE_SHARE_RELEASE}" ]]; then
  echo "Error: --seed-from requires --create-share." >&2
  exit 2
fi

if [[ -n "${CREATE_SHARE_RELEASE}" ]]; then
  create_share_index="$(release_index "${CREATE_SHARE_RELEASE}")"
  if [[ "${create_share_index}" -lt 0 ]]; then
    echo "Error: unsupported release for --create-share: ${CREATE_SHARE_RELEASE}" >&2
    print_yocto_release_history >&2
    exit 2
  fi

  if [[ ${PRINT_ONLY} -eq 1 ]]; then
    created_share_root="$(release_root_path "${CREATE_SHARE_RELEASE}")"
    echo "Info: --print-only active; skipping create/seed mutations for ${created_share_root}."
  else
    created_share_root="$(create_share_root_for_release "${CREATE_SHARE_RELEASE}")"
    if [[ -n "${SEED_FROM}" ]]; then
      seed_source_root="$(resolve_seed_source_root "${SEED_FROM}")"
      seed_share_root_from_source "${created_share_root}" "${seed_source_root}"
    fi
  fi

  if [[ ${PROJECT_SHARED_ROOT_SET_BY_CLI} -eq 0 ]]; then
    PROJECT_SHARED_ROOT="${created_share_root}"
  else
    echo "Info: --project-shared-root explicitly set (${PROJECT_SHARED_ROOT}); not overriding with --create-share output (${created_share_root})."
  fi
fi

if [[ -z "${SWUPDATE_PASSWORD_FILE}" ]]; then
  SWUPDATE_PASSWORD_FILE="/opt/yocto/keys/${PROJECT_KEYS}/swupdate-password.txt"
fi

# When --project-shared-root is given without explicit --dl-dir / --sstate-dir,
# keep the bind mount source on the host but use the container-visible mount
# path for local.conf cache overrides.
if [[ -n "${PROJECT_SHARED_ROOT}" ]]; then
  if [[ -z "${DL_DIR_OVERRIDE}" ]]; then
    DL_DIR_OVERRIDE="/opt/yocto/shared/downloads"
  fi
  if [[ -z "${SSTATE_DIR_OVERRIDE}" ]]; then
    SSTATE_DIR_OVERRIDE="/opt/yocto/shared/sstate-cache"
  fi
fi

if [[ -z "${DOCKER_BUILD_DIR}" ]]; then
  DOCKER_BUILD_DIR="${WORKDIR}/build-docker"
fi

if [[ -z "${LOCAL_CONF_APPEND_FILE}" ]]; then
  LOCAL_CONF_APPEND_FILE="${WORKDIR}/.local-conf/local.conf.append"
fi

if [[ -z "${NETBOOT_APPEND_FILE}" ]]; then
  NETBOOT_APPEND_FILE="${WORKDIR}/.local-conf/local.conf.netboot.append"
fi

 # Auto-detect TEMPLATECONF based on available distro layers first, not project name.
 # This supports variants like linux-dps-scarthgap while still handling kirkstone/scarthgap layouts.
 if [[ -z "${TEMPLATECONF}" ]]; then
   if [[ -d "${WORKDIR}/layers/meta-liebherr-dps/conf/templates/default" ]]; then
     # New-style templates (e.g. scarthgap)
     TEMPLATECONF="/opt/yocto/workspace/layers/meta-liebherr-dps/conf/templates/default"
   elif [[ -f "${WORKDIR}/layers/meta-liebherr-dps/conf/bblayers.conf.sample" ]]; then
     # Old-style templates (e.g. kirkstone)
     TEMPLATECONF="/opt/yocto/workspace/layers/meta-liebherr-dps/conf"
   elif [[ -d "${WORKDIR}/layers/meta-liebherr-lpo-display/conf/templates/default" ]]; then
     TEMPLATECONF="/opt/yocto/workspace/layers/meta-liebherr-lpo-display/conf/templates/default"
   elif [[ -f "${WORKDIR}/layers/meta-liebherr-lpo-display/conf/bblayers.conf.sample" ]]; then
     TEMPLATECONF="/opt/yocto/workspace/layers/meta-liebherr-lpo-display/conf"
   elif [[ -d "${WORKDIR}/layers/liebherr/meta-liebherr-distro/conf/templates/default" ]]; then
     # llp distro: meta-liebherr-distro lives inside layers/liebherr/
     TEMPLATECONF="/opt/yocto/workspace/layers/liebherr/meta-liebherr-distro/conf/templates/default"
   elif [[ -f "${WORKDIR}/layers/liebherr/meta-liebherr-distro/conf/bblayers.conf.sample" ]]; then
     TEMPLATECONF="/opt/yocto/workspace/layers/liebherr/meta-liebherr-distro/conf"
   elif [[ -d "${WORKDIR}/layers/poky/conf/templates/default" ]]; then
     TEMPLATECONF="/opt/yocto/workspace/layers/poky/conf/templates/default"
   elif [[ -d "${WORKDIR}/layers/poky/meta-poky/conf/templates/default" ]]; then
     TEMPLATECONF="/opt/yocto/workspace/layers/poky/meta-poky/conf/templates/default"
   else
     # Keep previous fallback for compatibility, but this should normally be unreachable.
     TEMPLATECONF="/opt/yocto/workspace/layers/poky/meta-poky/conf/templates/default"
   fi
 fi

 # Normalize TEMPLATECONF for Yocto templates layout only if the auto-detected path requires it.
 # For kirkstone: /conf is the template directory itself (old-style, .sample files)
 # For scarthgap+: /conf/templates/default is the template directory (new-style)
 # Only normalize if path ends with /conf AND contains no templates/ subdirectory.
 if [[ "${TEMPLATECONF}" == */conf ]] && [[ ! "${TEMPLATECONF}" =~ /templates/ ]]; then
   # Check if this looks like an old-style (kirkstone) template directory
   if [[ -f "${WORKDIR}/layers/meta-liebherr-dps/conf/bblayers.conf.sample" && \
         "${TEMPLATECONF}" == */meta-liebherr-dps/conf ]]; then
     # Old kirkstone style: keep /conf as-is
     :
   else
     # New style: assume /conf needs /templates/default appended
     guessed_templateconf="${TEMPLATECONF}/templates/default"
     echo "Info: TEMPLATECONF points to .../conf; using ${guessed_templateconf}"
     TEMPLATECONF="${guessed_templateconf}"
   fi
 fi

COMPOSE_FILE="${WORKDIR}/layers/liebherr/ci/docker-compose.yml"
if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "Error: compose file not found: ${COMPOSE_FILE}" >&2
  exit 1
fi



if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker command not found." >&2
  echo "Hint: run /home/ldcwem0/dotfiles/shell/setup-docker-fedora-native.sh --apply-daemon-config" >&2
  exit 1
fi

if [[ ! -d "${WORKDIR}" ]]; then
  echo "Error: workdir not found: ${WORKDIR}" >&2
  exit 1
fi

if [[ ! -f "${SWUPDATE_PASSWORD_FILE}" ]]; then
  echo "Warning: SWUPDATE password file not found on host: ${SWUPDATE_PASSWORD_FILE}" >&2
fi

if [[ -z "${SOTA_AUTH_TOKEN}" ]]; then
  echo "Warning: SOTA_AUTH_TOKEN is empty. Set env var or pass --sota-auth-token." >&2
fi

# Derive LPO/project-specific secret file paths from the keys directory,
# mirroring llp_init_build.sh logic. Prefer env-provided values over defaults.
_keys_root="/opt/yocto/keys/${PROJECT_KEYS}"

# Secure boot secrets are mandatory for LLP distro builds.
secure_boot_required=0
if [[ "${PROJECT_KEYS}" == "llp" ]] || [[ "${PROJECT}" == *"llp"* ]]; then
  secure_boot_required=1
fi

resolve_secret_from_keys_root() {
  local var_name="$1"
  shift
  local candidate

  # Respect explicit environment overrides.
  if [[ -n "${!var_name:-}" ]]; then
    return 0
  fi

  for candidate in "$@"; do
    if [[ -f "${_keys_root}/${candidate}" ]]; then
      printf -v "${var_name}" '%s' "${_keys_root}/${candidate}"
      return 0
    fi
  done

  return 1
}

# SWUpdate local secret compatibility: support both legacy underscore names and
# expected dashed names by creating missing aliases in the active key directory.
if [[ -f "${_keys_root}/swupdate_key_password" ]] && [[ ! -e "${_keys_root}/swupdate-password.txt" ]]; then
  ln -snf "${_keys_root}/swupdate_key_password" "${_keys_root}/swupdate-password.txt"
fi
if [[ -f "${_keys_root}/swupdate_private_key" ]] && [[ ! -e "${_keys_root}/swupdate-private.pem" ]]; then
  ln -snf "${_keys_root}/swupdate_private_key" "${_keys_root}/swupdate-private.pem"
fi
if [[ -f "${_keys_root}/swupdate_public_key" ]] && [[ ! -e "${_keys_root}/swupdate-public.pem" ]]; then
  ln -snf "${_keys_root}/swupdate_public_key" "${_keys_root}/swupdate-public.pem"
fi
if [[ -f "${_keys_root}/swupdate-password.txt" ]] && [[ ! -e "${_keys_root}/swupdate_key_password" ]]; then
  ln -snf "${_keys_root}/swupdate-password.txt" "${_keys_root}/swupdate_key_password"
fi
if [[ -f "${_keys_root}/swupdate-private.pem" ]] && [[ ! -e "${_keys_root}/swupdate_private_key" ]]; then
  ln -snf "${_keys_root}/swupdate-private.pem" "${_keys_root}/swupdate_private_key"
fi
if [[ -f "${_keys_root}/swupdate-public.pem" ]] && [[ ! -e "${_keys_root}/swupdate_public_key" ]]; then
  ln -snf "${_keys_root}/swupdate-public.pem" "${_keys_root}/swupdate_public_key"
fi

if [[ -z "${SWUPDATE_PASSWORD_FILE:-}" ]] || [[ ! -f "${SWUPDATE_PASSWORD_FILE:-}" ]]; then
  resolve_secret_from_keys_root SWUPDATE_PASSWORD_FILE \
    "swupdate-password.txt" "swupdate_key_password" || true
fi

if [[ -z "${MOSQUITTO_PSK_FILE:-}" ]]; then
  if [[ -f "${_keys_root}/mosquitto-psk.txt" ]]; then
    MOSQUITTO_PSK_FILE="${_keys_root}/mosquitto-psk.txt"
  fi
fi
if [[ -z "${MOSQUITTO_PSK_FILE:-}" ]] || [[ ! -f "${MOSQUITTO_PSK_FILE:-}" ]]; then
  echo "Warning: MOSQUITTO_PSK_FILE not found (expected ${_keys_root}/mosquitto-psk.txt). mosquitto recipes may fail." >&2
fi

if [[ -z "${LPO_DATASTATION_PRIVATEKEY:-}" ]]; then
  if [[ -f "${_keys_root}/id_rsa_lpo_datastation" ]]; then
    LPO_DATASTATION_PRIVATEKEY="${_keys_root}/id_rsa_lpo_datastation"
  fi
fi
if [[ -z "${LPO_DATASTATION_PRIVATEKEY:-}" ]]; then
  echo "Warning: LPO_DATASTATION_PRIVATEKEY not found (expected ${_keys_root}/id_rsa_lpo_datastation)." >&2
fi

if [[ -z "${SWUPDATE_PRIVATE_KEY:-}" ]] || [[ ! -f "${SWUPDATE_PRIVATE_KEY:-}" ]]; then
  resolve_secret_from_keys_root SWUPDATE_PRIVATE_KEY \
    "swupdate-private.pem" "swupdate_private_key" || true
fi
if [[ -z "${SWUPDATE_PUBLIC_KEY:-}" ]] || [[ ! -f "${SWUPDATE_PUBLIC_KEY:-}" ]]; then
  resolve_secret_from_keys_root SWUPDATE_PUBLIC_KEY \
    "swupdate-public.pem" "swupdate_public_key" || true
fi

# Safety warning: detect accidental dev->prod secret reuse for LLP SWUpdate
# credentials. This is informational only and does not block local builds.
if [[ "${PROJECT_KEYS}" == "llp" ]]; then
  active_keys_root_real="$(realpath -m "${_keys_root}")"
  dev_keys_root_real="$(realpath -m "/opt/yocto/keys/llp/dev")"

  if [[ "${active_keys_root_real}" != "${dev_keys_root_real}" ]] && [[ -d "${dev_keys_root_real}" ]]; then
    swupdate_identical_count=0

    if [[ -f "${active_keys_root_real}/swupdate-password.txt" ]] && [[ -f "${dev_keys_root_real}/swupdate-password.txt" ]] \
       && cmp -s "${active_keys_root_real}/swupdate-password.txt" "${dev_keys_root_real}/swupdate-password.txt"; then
      swupdate_identical_count=$((swupdate_identical_count + 1))
      echo "Warning: LLP SWUpdate password in ${active_keys_root_real} is identical to dev profile." >&2
    fi

    if [[ -f "${active_keys_root_real}/swupdate-private.pem" ]] && [[ -f "${dev_keys_root_real}/swupdate-private.pem" ]] \
       && cmp -s "${active_keys_root_real}/swupdate-private.pem" "${dev_keys_root_real}/swupdate-private.pem"; then
      swupdate_identical_count=$((swupdate_identical_count + 1))
      echo "Warning: LLP SWUpdate private key in ${active_keys_root_real} is identical to dev profile." >&2
    fi

    if [[ -f "${active_keys_root_real}/swupdate-public.pem" ]] && [[ -f "${dev_keys_root_real}/swupdate-public.pem" ]] \
       && cmp -s "${active_keys_root_real}/swupdate-public.pem" "${dev_keys_root_real}/swupdate-public.pem"; then
      swupdate_identical_count=$((swupdate_identical_count + 1))
      echo "Warning: LLP SWUpdate public key in ${active_keys_root_real} is identical to dev profile." >&2
    fi

    if [[ ${swupdate_identical_count} -gt 0 ]]; then
      echo "Warning: ${swupdate_identical_count}/3 LLP SWUpdate secret files match dev. Verify intended profile usage." >&2
    fi
  fi
fi

# Secure boot secret file defaults: accept both yoctose-style secret names and
# explicit file names used by CI/Jenkins.
resolve_secret_from_keys_root ROOT_OF_TRUST_SECRET_FILE \
  "scr_boot_rot_private_key" "ROOT_OF_TRUST_SECRET.pem" || true
resolve_secret_from_keys_root TRUSTED_WORLD_SECRET_FILE \
  "scr_boot_trusted_world_private_key" "TRUSTED_WORLD_SECRET.pem" || true
resolve_secret_from_keys_root NON_TRUSTED_WORLD_SECRET_FILE \
  "scr_boot_non_trusted_world_private_key" "NON_TRUSTED_WORLD_SECRET.pem" || true
resolve_secret_from_keys_root BL31_SECRET_FILE \
  "scr_boot_bl31_private_key" "BL31_SECRET.pem" || true
resolve_secret_from_keys_root BL32_SECRET_FILE \
  "scr_boot_bl32_private_key" "BL32_SECRET.pem" || true
resolve_secret_from_keys_root BL33_SECRET_FILE \
  "scr_boot_bl33_private_key" "BL33_SECRET.pem" || true
resolve_secret_from_keys_root SCP_BL2_SECRET_FILE \
  "scr_boot_scp_bl2_private_key" "SCP_BL2_SECRET.pem" || true
resolve_secret_from_keys_root OPTEE_TA_SECRET_FILE \
  "optee_ta_private_key" "OPTEE_TA_SECRET.pem" || true
resolve_secret_from_keys_root UBOOT_FIT_KEY_FILE \
  "scr_boot_uboot_fit_key" "UBOOT_FIT.key" || true
resolve_secret_from_keys_root UBOOT_FIT_CERT_FILE \
  "scr_boot_uboot_fit_cert" "UBOOT_FIT.crt" || true

# U-Boot FIT signing via uboot-mkimage -k expects a basename with sibling
# <name>.key and <name>.crt files. Keep the canonical LLP secret names, but
# create compatibility symlinks in the active keys directory for local builds.
if [[ -n "${UBOOT_FIT_KEY_FILE:-}" ]] && [[ -f "${UBOOT_FIT_KEY_FILE}" ]] \
   && [[ -n "${UBOOT_FIT_CERT_FILE:-}" ]] && [[ -f "${UBOOT_FIT_CERT_FILE}" ]]; then
  if [[ ! -e "${_keys_root}/scr_boot_uboot_fit_key.key" ]]; then
    ln -snf "${UBOOT_FIT_KEY_FILE}" "${_keys_root}/scr_boot_uboot_fit_key.key"
  fi
  if [[ ! -e "${_keys_root}/scr_boot_uboot_fit_key.crt" ]]; then
    ln -snf "${UBOOT_FIT_CERT_FILE}" "${_keys_root}/scr_boot_uboot_fit_key.crt"
  fi
fi

if [[ ${secure_boot_required} -eq 1 ]]; then
  secure_boot_missing=()

  if [[ -z "${ROOT_OF_TRUST_SECRET_FILE:-}" ]] || [[ ! -f "${ROOT_OF_TRUST_SECRET_FILE:-}" ]]; then
    secure_boot_missing+=("ROOT_OF_TRUST_SECRET_FILE (expected ${_keys_root}/scr_boot_rot_private_key)")
  fi
  if [[ -z "${TRUSTED_WORLD_SECRET_FILE:-}" ]] || [[ ! -f "${TRUSTED_WORLD_SECRET_FILE:-}" ]]; then
    secure_boot_missing+=("TRUSTED_WORLD_SECRET_FILE (expected ${_keys_root}/scr_boot_trusted_world_private_key)")
  fi
  if [[ -z "${NON_TRUSTED_WORLD_SECRET_FILE:-}" ]] || [[ ! -f "${NON_TRUSTED_WORLD_SECRET_FILE:-}" ]]; then
    secure_boot_missing+=("NON_TRUSTED_WORLD_SECRET_FILE (expected ${_keys_root}/scr_boot_non_trusted_world_private_key)")
  fi
  if [[ -z "${BL31_SECRET_FILE:-}" ]] || [[ ! -f "${BL31_SECRET_FILE:-}" ]]; then
    secure_boot_missing+=("BL31_SECRET_FILE (expected ${_keys_root}/scr_boot_bl31_private_key)")
  fi
  if [[ -z "${BL32_SECRET_FILE:-}" ]] || [[ ! -f "${BL32_SECRET_FILE:-}" ]]; then
    secure_boot_missing+=("BL32_SECRET_FILE (expected ${_keys_root}/scr_boot_bl32_private_key)")
  fi
  if [[ -z "${BL33_SECRET_FILE:-}" ]] || [[ ! -f "${BL33_SECRET_FILE:-}" ]]; then
    secure_boot_missing+=("BL33_SECRET_FILE (expected ${_keys_root}/scr_boot_bl33_private_key)")
  fi
  if [[ -z "${SCP_BL2_SECRET_FILE:-}" ]] || [[ ! -f "${SCP_BL2_SECRET_FILE:-}" ]]; then
    secure_boot_missing+=("SCP_BL2_SECRET_FILE (expected ${_keys_root}/scr_boot_scp_bl2_private_key)")
  fi
  if [[ -z "${OPTEE_TA_SECRET_FILE:-}" ]] || [[ ! -f "${OPTEE_TA_SECRET_FILE:-}" ]]; then
    secure_boot_missing+=("OPTEE_TA_SECRET_FILE (expected ${_keys_root}/optee_ta_private_key)")
  fi
  if [[ -z "${UBOOT_FIT_KEY_FILE:-}" ]] || [[ ! -f "${UBOOT_FIT_KEY_FILE:-}" ]]; then
    secure_boot_missing+=("UBOOT_FIT_KEY_FILE (expected ${_keys_root}/scr_boot_uboot_fit_key)")
  fi
  if [[ -z "${UBOOT_FIT_CERT_FILE:-}" ]] || [[ ! -f "${UBOOT_FIT_CERT_FILE:-}" ]]; then
    secure_boot_missing+=("UBOOT_FIT_CERT_FILE (expected ${_keys_root}/scr_boot_uboot_fit_cert)")
  fi

  if [[ ${#secure_boot_missing[@]} -gt 0 ]]; then
    echo "Error: missing LLP secure boot secrets for project '${PROJECT}' (keys: ${PROJECT_KEYS})." >&2
    echo "       Checked under: ${_keys_root}" >&2
    for missing in "${secure_boot_missing[@]}"; do
      echo "  - ${missing}" >&2
    done
    echo "Hint: sync available keys with: /home/ldcwem0/dotfiles/shell/yocto/sync-llp-yoctose-secrets.sh --force" >&2
    echo "Hint: obtain the missing secure boot key material from CI credential owners." >&2
    exit 2
  fi
fi

# LH_IOT_CLOUD_MQTT_PASSWORD: honour existing env, no default file.
LH_IOT_CLOUD_MQTT_PASSWORD="${LH_IOT_CLOUD_MQTT_PASSWORD:-}"

unset _keys_root

# Ensure selected environment variables are imported by BitBake metadata.
bb_env_passthrough="${BB_ENV_PASSTHROUGH_ADDITIONS:-}"
for var in SWUPDATE_PASSWORD_FILE SWUPDATE_PRIVATE_KEY SWUPDATE_PUBLIC_KEY \
           SOTA_AUTH_TOKEN MOSQUITTO_PSK_FILE LPO_DATASTATION_PRIVATEKEY \
           LH_IOT_CLOUD_MQTT_PASSWORD ROOT_OF_TRUST_SECRET_FILE \
           TRUSTED_WORLD_SECRET_FILE NON_TRUSTED_WORLD_SECRET_FILE \
           BL31_SECRET_FILE BL32_SECRET_FILE BL33_SECRET_FILE \
           SCP_BL2_SECRET_FILE OPTEE_TA_SECRET_FILE UBOOT_FIT_KEY_FILE \
           UBOOT_FIT_CERT_FILE; do
  case " ${bb_env_passthrough} " in
    *" ${var} "*) ;;
    *) bb_env_passthrough="${bb_env_passthrough} ${var}" ;;
  esac
done
# Trim optional leading whitespace for cleaner output.
bb_env_passthrough="${bb_env_passthrough# }"

if [[ ${ENABLE_NETRC} -eq 1 ]]; then
  if [[ ! -f "${NETRC_FILE}" ]]; then
    echo "Warning: .netrc file not found on host: ${NETRC_FILE}" >&2
    echo "         Private git fetches may fail. Use --netrc-file or --no-netrc." >&2
  else
    # Warn if group/other permission bits are present (OpenSSH/git best practice is 600).
    netrc_mode=$(stat -c '%a' "${NETRC_FILE}" 2>/dev/null || echo "")
    if [[ -n "${netrc_mode}" ]] && [[ "${netrc_mode}" != "600" ]]; then
      echo "Warning: ${NETRC_FILE} mode is ${netrc_mode}; recommended is 600." >&2
    fi
  fi
fi

# Skip all mutating preflight operations in print-only mode.
if [[ ${PRINT_ONLY} -ne 1 ]]; then
  # Preflight: ensure host-side /opt/yocto/build directory has correct ownership/permissions
  # so container user (yocto, uid 1000) can write to mounted volumes.
  if [[ -d "/opt/yocto/build" ]]; then
    build_owner=$(stat -c '%U:%G' /opt/yocto/build 2>/dev/null || echo "unknown")
    build_perms=$(stat -c '%a' /opt/yocto/build 2>/dev/null || echo "unknown")
    if [[ "$build_owner" != "$USER:$USER" ]] || [[ "$build_perms" != "775" ]]; then
      echo "Preflight: fixing host /opt/yocto/build ownership and permissions..."
      sudo chown -R "$USER:$USER" /opt/yocto/build 2>/dev/null || true
      sudo chmod -R 775 /opt/yocto/build 2>/dev/null || true
    fi
  fi

  if [[ ${MANAGE_BUILD_SYMLINK} -eq 1 ]]; then
    build_link="/opt/yocto/build/${PROJECT}"
    mkdir -p "$(dirname "${DOCKER_BUILD_DIR}")"
    mkdir -p "${DOCKER_BUILD_DIR}"

    # Normalize legacy migration layout:
    # /opt/yocto/build/<project> -> <workdir>/build-docker/
    # with all artifacts accidentally under <workdir>/build-docker/<project>/...
    nested_project_dir="${DOCKER_BUILD_DIR}/${PROJECT}"
    if [[ -d "${nested_project_dir}" ]] && [[ ! -e "${DOCKER_BUILD_DIR}/conf" ]] && [[ ! -e "${DOCKER_BUILD_DIR}/tmp" ]]; then
      # Flatten only if the docker build dir contains no other entries besides the nested project dir.
      if [[ -z "$(find "${DOCKER_BUILD_DIR}" -mindepth 1 -maxdepth 1 ! -name "${PROJECT}" -print -quit 2>/dev/null)" ]]; then
        shopt -s dotglob nullglob
        mv "${nested_project_dir}"/* "${DOCKER_BUILD_DIR}/" 2>/dev/null || true
        shopt -u dotglob nullglob
        rmdir "${nested_project_dir}" 2>/dev/null || true
        echo "Preflight: flattened legacy ${nested_project_dir} into ${DOCKER_BUILD_DIR}"
      fi
    fi

    if [[ -L "${build_link}" ]]; then
      current_target="$(readlink -f "${build_link}" 2>/dev/null || true)"
      wanted_target="$(readlink -f "${DOCKER_BUILD_DIR}" 2>/dev/null || true)"
      if [[ -n "${wanted_target}" ]] && [[ "${current_target}" != "${wanted_target}" ]]; then
        ln -sfn "${DOCKER_BUILD_DIR}" "${build_link}"
        echo "Preflight: switched ${build_link} -> ${DOCKER_BUILD_DIR}"
      fi
    elif [[ -e "${build_link}" ]]; then
      # Existing non-symlink path: preserve data before converting to symlink.
      if [[ ! -e "${DOCKER_BUILD_DIR}" ]] || [[ -z "$(ls -A "${DOCKER_BUILD_DIR}" 2>/dev/null)" ]]; then
        # Move build contents into target directory (not the directory itself),
        # so DOCKER_BUILD_DIR does not end up with an extra nested <project>/ folder.
        mkdir -p "${DOCKER_BUILD_DIR}"
        shopt -s dotglob nullglob
        mv "${build_link}"/* "${DOCKER_BUILD_DIR}/" 2>/dev/null || true
        shopt -u dotglob nullglob
        rmdir "${build_link}" 2>/dev/null || true
      else
        backup_path="${build_link}.backup.$(date +%Y%m%d-%H%M%S)"
        mv "${build_link}" "${backup_path}" 2>/dev/null || true
        echo "Preflight: moved existing ${build_link} to ${backup_path}"
      fi
      ln -sfn "${DOCKER_BUILD_DIR}" "${build_link}"
      echo "Preflight: created ${build_link} -> ${DOCKER_BUILD_DIR}"
    else
      ln -sfn "${DOCKER_BUILD_DIR}" "${build_link}"
      echo "Preflight: created ${build_link} -> ${DOCKER_BUILD_DIR}"
    fi
  fi

  # Match llp_init_build behavior: clear existing conf so oe-init-build-env recreates
  # local.conf and bblayers.conf from TEMPLATECONF on each run.
  if [[ ${INIT_BUILD_ENV} -eq 1 ]]; then
    if [[ ${RESET_CONF} -eq 1 ]]; then
      if [[ -d "${DOCKER_BUILD_DIR}/conf" ]]; then
        echo "Preflight: removing existing ${DOCKER_BUILD_DIR}/conf to regenerate from TEMPLATECONF"
        rm -rf "${DOCKER_BUILD_DIR}/conf"
      fi
    else
      echo "Preflight: keeping existing ${DOCKER_BUILD_DIR}/conf (--keep-conf)"
    fi
    mkdir -p "${DOCKER_BUILD_DIR}"
  fi
fi

x11_mount="/tmp/.X11-unix:/tmp/.X11-unix:rw"
if [[ ${X11_SELINUX_Z} -eq 1 ]]; then
  x11_mount="/tmp/.X11-unix:/tmp/.X11-unix:rw,z"
fi

netrc_mount_opts=":ro"
if [[ ${X11_SELINUX_Z} -eq 1 ]]; then
  netrc_mount_opts=":ro,z"
fi

cmd=(
  docker compose -f "${COMPOSE_FILE}" run
)

if [[ ${DO_RM} -eq 1 ]]; then
  cmd+=(--rm)
fi
if [[ ${DO_BUILD} -eq 1 ]]; then
  cmd+=(--build)
fi

cmd+=(
  -e "SWUPDATE_PASSWORD_FILE=${SWUPDATE_PASSWORD_FILE}"
  -e "SWUPDATE_PRIVATE_KEY=${SWUPDATE_PRIVATE_KEY:-}"
  -e "SWUPDATE_PUBLIC_KEY=${SWUPDATE_PUBLIC_KEY:-}"
  -e "SOTA_AUTH_TOKEN=${SOTA_AUTH_TOKEN}"
  -e "MOSQUITTO_PSK_FILE=${MOSQUITTO_PSK_FILE:-}"
  -e "LPO_DATASTATION_PRIVATEKEY=${LPO_DATASTATION_PRIVATEKEY:-}"
  -e "LH_IOT_CLOUD_MQTT_PASSWORD=${LH_IOT_CLOUD_MQTT_PASSWORD:-}"
  -e "ROOT_OF_TRUST_SECRET_FILE=${ROOT_OF_TRUST_SECRET_FILE:-}"
  -e "TRUSTED_WORLD_SECRET_FILE=${TRUSTED_WORLD_SECRET_FILE:-}"
  -e "NON_TRUSTED_WORLD_SECRET_FILE=${NON_TRUSTED_WORLD_SECRET_FILE:-}"
  -e "BL31_SECRET_FILE=${BL31_SECRET_FILE:-}"
  -e "BL32_SECRET_FILE=${BL32_SECRET_FILE:-}"
  -e "BL33_SECRET_FILE=${BL33_SECRET_FILE:-}"
  -e "SCP_BL2_SECRET_FILE=${SCP_BL2_SECRET_FILE:-}"
  -e "OPTEE_TA_SECRET_FILE=${OPTEE_TA_SECRET_FILE:-}"
  -e "UBOOT_FIT_KEY_FILE=${UBOOT_FIT_KEY_FILE:-}"
  -e "UBOOT_FIT_CERT_FILE=${UBOOT_FIT_CERT_FILE:-}"
  -e "BB_ENV_PASSTHROUGH_ADDITIONS=${bb_env_passthrough}"
  -e "TEMPLATECONF=${TEMPLATECONF}"
)

if [[ ${ENABLE_X11} -eq 1 ]]; then
  cmd+=(
    -e "DISPLAY=${DISPLAY:-}"
    -v "${x11_mount}"
  )
fi

if [[ ${ENABLE_NETRC} -eq 1 ]] && [[ -f "${NETRC_FILE}" ]]; then
  cmd+=(
    -v "${NETRC_FILE}:/home/yocto/.netrc${netrc_mount_opts}"
  )
fi

container_localconf_append_file="/tmp/llp-local-conf-append.conf"
if [[ ${ENABLE_LOCAL_CONF_APPEND} -eq 1 ]]; then
  if [[ -f "${LOCAL_CONF_APPEND_FILE}" ]]; then
    cmd+=(
      -v "${LOCAL_CONF_APPEND_FILE}:${container_localconf_append_file}:ro"
    )
  else
    echo "Info: local.conf append file not found, skipping: ${LOCAL_CONF_APPEND_FILE}"
  fi
fi

container_netboot_append_file="/tmp/llp-netboot-local-conf-append.conf"
if [[ ${NETBOOT_SUPPORT} -eq 1 ]] && [[ ${ENABLE_NETBOOT_APPEND} -eq 1 ]]; then
  if [[ -f "${NETBOOT_APPEND_FILE}" ]]; then
    cmd+=(
      -v "${NETBOOT_APPEND_FILE}:${container_netboot_append_file}:ro"
    )
  else
    echo "Info: netboot append file not found; using built-in netboot snippet: ${NETBOOT_APPEND_FILE}"
  fi
fi

cmd+=(
  --user "$(id -u):$(id -g)"
  "${SERVICE}"
)

if [[ ${INIT_BUILD_ENV} -eq 1 ]]; then
  cmd+=(
    bash -lc
    "cd /opt/yocto/workspace && source layers/poky/oe-init-build-env /opt/yocto/build/${PROJECT} && if [[ -f ${container_localconf_append_file} ]]; then printf '\n# llp_docker_shell local.conf.append injection\n' >> /opt/yocto/build/${PROJECT}/conf/local.conf && cat ${container_localconf_append_file} >> /opt/yocto/build/${PROJECT}/conf/local.conf; fi && if [[ ${NETBOOT_SUPPORT} -eq 1 ]]; then if [[ -f ${container_netboot_append_file} ]]; then printf '\n# llp_docker_shell netboot_support injection (file)\n' >> /opt/yocto/build/${PROJECT}/conf/local.conf && cat ${container_netboot_append_file} >> /opt/yocto/build/${PROJECT}/conf/local.conf; else printf '\n# llp_docker_shell netboot_support injection (builtin)\nIMAGE_INSTALL:append = \" nfs-utils-client\"\n' >> /opt/yocto/build/${PROJECT}/conf/local.conf; fi; fi && exec bash -i"
  )
fi

echo "==> Workdir: ${WORKDIR}"
echo "==> Compose: ${COMPOSE_FILE}"
echo "==> Project env: PROJECT=${PROJECT} PROJECT_KEYS=${PROJECT_KEYS} PROJECT_SHARED_ROOT=${PROJECT_SHARED_ROOT}"
if [[ ${MANAGE_BUILD_SYMLINK} -eq 1 ]]; then
  echo "==> Build symlink: /opt/yocto/build/${PROJECT} -> ${DOCKER_BUILD_DIR}"
fi
echo "==> BitBake passthrough: ${bb_env_passthrough}"
if [[ ${ENABLE_NETRC} -eq 1 ]]; then
  echo "==> Netrc mount: ${NETRC_FILE} -> /home/yocto/.netrc"
fi
if [[ ${INIT_BUILD_ENV} -eq 1 ]]; then
  echo "==> Container init: cd /opt/yocto/workspace + source oe-init-build-env /opt/yocto/build/${PROJECT}"
  if [[ ${ENABLE_LOCAL_CONF_APPEND} -eq 1 ]]; then
    echo "==> local.conf append: ${LOCAL_CONF_APPEND_FILE}"
  fi
  if [[ ${NETBOOT_SUPPORT} -eq 1 ]] && [[ ${ENABLE_NETBOOT_APPEND} -eq 1 ]]; then
    echo "==> netboot append: ${NETBOOT_APPEND_FILE}"
  fi
fi

if [[ ${PRINT_ONLY} -eq 1 ]]; then
  printf 'PROJECT=%q PROJECT_KEYS=%q PROJECT_SHARED_ROOT=%q ' "${PROJECT}" "${PROJECT_KEYS}" "${PROJECT_SHARED_ROOT}"
  printf '%q ' "${cmd[@]}"
  printf '\n'
  exit 0
fi

(
  cd "${WORKDIR}"
  PROJECT="${PROJECT}" PROJECT_KEYS="${PROJECT_KEYS}" PROJECT_SHARED_ROOT="${PROJECT_SHARED_ROOT}" "${cmd[@]}"
)
