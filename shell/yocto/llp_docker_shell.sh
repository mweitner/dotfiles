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
  --no-build-symlink                Do not manage /opt/yocto/build/<project> symlink
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

Examples:
  llp_docker_shell.sh --project linux-lpo --project-keys lpo
  llp_docker_shell.sh --project linux-dps --project-keys dps
  llp_docker_shell.sh --project linux-dps --project-keys dps --print-only
  llp_docker_shell.sh --project linux-lpo --project-keys lpo --sota-auth-token "$SOTA_AUTH_TOKEN"
EOF
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
    --no-build-symlink)
      MANAGE_BUILD_SYMLINK=0
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

if [[ -z "${SWUPDATE_PASSWORD_FILE}" ]]; then
  SWUPDATE_PASSWORD_FILE="/opt/yocto/keys/${PROJECT_KEYS}/swupdate-password.txt"
fi

if [[ -z "${DOCKER_BUILD_DIR}" ]]; then
  DOCKER_BUILD_DIR="${WORKDIR}/build-docker"
fi

 # Auto-detect TEMPLATECONF based on project and available meta layers
 if [[ -z "${TEMPLATECONF}" ]]; then
   # Try project-specific naming first
   if [[ "${PROJECT}" == "linux-dps" ]]; then
     # Kirkstone (linux-dps) uses old-style templates directly in /conf (no /conf/templates/ subdir)
     if [[ -f "${WORKDIR}/layers/meta-liebherr-dps/conf/bblayers.conf.sample" ]]; then
       TEMPLATECONF="/opt/yocto/workspace/layers/meta-liebherr-dps/conf"
     else
       # Fall back to generic default
       TEMPLATECONF="/opt/yocto/workspace/layers/poky/meta-poky/conf/templates/default"
     fi
   elif [[ "${PROJECT}" == "linux-lpo" ]]; then
     # Scarthgap (linux-lpo) uses newer-style templates in /conf/templates/
     TEMPLATECONF="/opt/yocto/workspace/layers/meta-liebherr-lpo-display/conf/templates/default"
   else
     # Generic fallback for unknown projects
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

# Ensure selected environment variables are imported by BitBake metadata.
bb_env_passthrough="${BB_ENV_PASSTHROUGH_ADDITIONS:-}"
for var in SWUPDATE_PASSWORD_FILE SOTA_AUTH_TOKEN; do
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
  -e "SOTA_AUTH_TOKEN=${SOTA_AUTH_TOKEN}"
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

cmd+=(
  --user "$(id -u):$(id -g)"
  "${SERVICE}"
)

if [[ ${INIT_BUILD_ENV} -eq 1 ]]; then
  cmd+=(
    bash -lc
    "cd /opt/yocto/workspace && source layers/poky/oe-init-build-env /opt/yocto/build/${PROJECT} && exec bash -i"
  )
fi

echo "==> Workdir: ${WORKDIR}"
echo "==> Compose: ${COMPOSE_FILE}"
echo "==> Project env: PROJECT=${PROJECT} PROJECT_KEYS=${PROJECT_KEYS}"
if [[ ${MANAGE_BUILD_SYMLINK} -eq 1 ]]; then
  echo "==> Build symlink: /opt/yocto/build/${PROJECT} -> ${DOCKER_BUILD_DIR}"
fi
echo "==> BitBake passthrough: ${bb_env_passthrough}"
if [[ ${ENABLE_NETRC} -eq 1 ]]; then
  echo "==> Netrc mount: ${NETRC_FILE} -> /home/yocto/.netrc"
fi
if [[ ${INIT_BUILD_ENV} -eq 1 ]]; then
  echo "==> Container init: cd /opt/yocto/workspace + source oe-init-build-env /opt/yocto/build/${PROJECT}"
fi

if [[ ${PRINT_ONLY} -eq 1 ]]; then
  printf 'PROJECT=%q PROJECT_KEYS=%q ' "${PROJECT}" "${PROJECT_KEYS}"
  printf '%q ' "${cmd[@]}"
  printf '\n'
  exit 0
fi

(
  cd "${WORKDIR}"
  PROJECT="${PROJECT}" PROJECT_KEYS="${PROJECT_KEYS}" "${cmd[@]}"
)
