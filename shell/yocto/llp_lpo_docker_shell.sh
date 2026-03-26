#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  llp_lpo_docker_shell.sh [options]

Launch the LLP Yocto build container for linux-lpo via:
  layers/liebherr/ci/docker-compose.yml

Options:
  --workdir <path>                  Yocto project root (default: ~/lpo-dev/linux-lpo)
  --project <name>                  PROJECT env value (default: linux-lpo)
  --project-keys <name>             PROJECT_KEYS env value (default: lpo)
  --swupdate-password-file <path>   SWUPDATE_PASSWORD_FILE (default: /opt/yocto/keys/<project-keys>/swupdate-password.txt)
  --sota-auth-token <token>         SOTA_AUTH_TOKEN value (default: from environment)
  --templateconf <path>             TEMPLATECONF path in container
                                    (default: /opt/yocto/workspace/layers/meta-liebherr-lpo-display/conf)
  --service <name>                  Compose service (default: liebherr-linux-build-container)
  --no-x11                          Do not pass DISPLAY and /tmp/.X11-unix mount
  --selinux-z                       Add :z label option to X11 bind mount
  --no-build                        Skip compose --build
  --keep-container                  Skip compose --rm
  --print-only                      Print command without executing
  -h, --help                        Show help

Environment:
  SOTA_AUTH_TOKEN can be provided via environment instead of CLI.

Examples:
  llp_lpo_docker_shell.sh
  llp_lpo_docker_shell.sh --print-only
  llp_lpo_docker_shell.sh --sota-auth-token "$SOTA_AUTH_TOKEN"
EOF
}

WORKDIR="${WORKDIR:-$HOME/lpo-dev/linux-lpo}"
PROJECT="${PROJECT:-linux-lpo}"
PROJECT_KEYS="${PROJECT_KEYS:-lpo}"
SWUPDATE_PASSWORD_FILE=""
SOTA_AUTH_TOKEN="${SOTA_AUTH_TOKEN:-}"
TEMPLATECONF="${TEMPLATECONF:-/opt/yocto/workspace/layers/meta-liebherr-lpo-display/conf}"
SERVICE="liebherr-linux-build-container"
ENABLE_X11=1
X11_SELINUX_Z=0
DO_BUILD=1
DO_RM=1
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
    --service)
      SERVICE="${2:-}"
      shift 2
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

x11_mount="/tmp/.X11-unix:/tmp/.X11-unix:rw"
if [[ ${X11_SELINUX_Z} -eq 1 ]]; then
  x11_mount="/tmp/.X11-unix:/tmp/.X11-unix:rw,z"
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
  -e "TEMPLATECONF=${TEMPLATECONF}"
)

if [[ ${ENABLE_X11} -eq 1 ]]; then
  cmd+=(
    -e "DISPLAY=${DISPLAY:-}"
    -v "${x11_mount}"
  )
fi

cmd+=(
  --user "$(id -u):$(id -g)"
  "${SERVICE}"
)

echo "==> Workdir: ${WORKDIR}"
echo "==> Compose: ${COMPOSE_FILE}"
echo "==> Project env: PROJECT=${PROJECT} PROJECT_KEYS=${PROJECT_KEYS}"

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
