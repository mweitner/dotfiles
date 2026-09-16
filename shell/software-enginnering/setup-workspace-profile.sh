#!/usr/bin/env bash
set -euo pipefail

PROFILE="ai-prompt-engineering"
WORKSPACE_NAME=""
MODE=""
WORKSPACE_ROOT=""
TARGET_ROOT=""
WORKSPACE_REPO_URL=""
WORKSPACE_BRANCH=""
PROFILE_FILE_OVERRIDE=""
USER_NAME="${USER:-$(id -un)}"
ROOT_DIR=""
DRY_RUN="false"
CLONE_TIMEOUT_SECONDS="0"
WORKSPACE_CLONED="false"

usage() {
cat <<'EOF'
Usage:
  setup-workspace-profile.sh <init|sync|update|status> [--workspace-root PATH] [--workspace-repo-url URL] [--workspace-branch BRANCH] [--profile PROFILE] [--profile-file PATH] [--user USER] [--root-dir PATH] [--target-root PATH] [--dry-run] [--clone-timeout SECONDS]

Examples:
  setup-workspace-profile.sh update --workspace-root /home/$USER/ems-dev
  setup-workspace-profile.sh sync --workspace-root /home/$USER/ems-dev --target-root /home/$USER/ems-dev-test1
  setup-workspace-profile.sh init --workspace-root /home/$USER/ems-dev --target-root /home/$USER/ems-dev-test2
  setup-workspace-profile.sh sync --workspace-repo-url ssh://ugreen-nas/volume1/data/repos/ems-dev-workspace.git --dry-run
  setup-workspace-profile.sh status --workspace-root /home/$USER/ems-dev
  setup-workspace-profile.sh update --workspace-root /home/$USER/ems-dev --profile-file .vscode/workspace-profiles/ai-prompt-engineering.json

Commands:
  init    Fresh scaffold mode. Requires --target-root and a fresh target root; supports optional super-project bootstrap clone.
  sync    Git synchronization mode for initialized super projects. Handles submodules and optional repo cloning.
  update  Consistency mode for initialized super projects without git network actions.
  status  Read-only status for initialized super projects using .super-project metadata.

Options:
  --workspace-root PATH      Root path of the super-project.
  --workspace-repo-url URL   Super-project git remote used only in init command.
  --workspace-branch BRANCH  Optional branch used when cloning --workspace-repo-url.
  --profile-file PATH        Profile file path (absolute or relative to --workspace-root).
  --dry-run                  Show planned actions without writing files, creating directories, or cloning.
  --clone-timeout SECONDS    Timeout per git clone operation. Use 0 to disable timeout.
  --root-dir PATH            Root directory used for <root_dir> placeholders in profile paths.
EOF
}

workspace_dir_name_from_url() {
  local url="$1"
  local trimmed="${url%/}"
  local name="${trimmed##*/}"
  name="${name%.git}"
  if [[ -z "${name}" ]]; then
    name="workspace"
  fi
  printf '%s\n' "${name}"
}

bootstrap_workspace_repo() {
  if [[ -z "${WORKSPACE_REPO_URL}" ]]; then
    return
  fi

  if [[ "${MODE}" != "init" ]]; then
    echo "--workspace-repo-url is supported only in init command." >&2
    exit 1
  fi

  if [[ -z "${WORKSPACE_ROOT}" ]]; then
    if [[ -n "${TARGET_ROOT}" ]]; then
      WORKSPACE_ROOT="${TARGET_ROOT}"
    else
      local repo_dir_name
      repo_dir_name="$(workspace_dir_name_from_url "${WORKSPACE_REPO_URL}")"
      WORKSPACE_ROOT="${PWD}/${repo_dir_name}"
    fi
  fi

  if [[ -d "${WORKSPACE_ROOT}/.git" ]]; then
    echo "Using existing workspace repository: ${WORKSPACE_ROOT}"
    return
  fi

  if [[ -e "${WORKSPACE_ROOT}" && ! -d "${WORKSPACE_ROOT}" ]]; then
    echo "Workspace root exists and is not a directory: ${WORKSPACE_ROOT}" >&2
    exit 1
  fi

  if [[ -d "${WORKSPACE_ROOT}" ]]; then
    if [[ -n "$(find "${WORKSPACE_ROOT}" -mindepth 1 -maxdepth 1 2>/dev/null | head -n 1)" ]]; then
      echo "Workspace root exists but is not a git repository: ${WORKSPACE_ROOT}" >&2
      exit 1
    fi
  fi

  local clone_cmd=(git clone)
  if [[ -n "${WORKSPACE_BRANCH}" ]]; then
    clone_cmd+=(--branch "${WORKSPACE_BRANCH}" --single-branch)
  fi
  clone_cmd+=("${WORKSPACE_REPO_URL}" "${WORKSPACE_ROOT}")

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[DRY-RUN] Would clone workspace repository: ${WORKSPACE_REPO_URL} -> ${WORKSPACE_ROOT}"
    if [[ -n "${WORKSPACE_BRANCH}" ]]; then
      echo "[DRY-RUN] Would use workspace branch: ${WORKSPACE_BRANCH}"
    fi
    return
  fi

  mkdir -p "$(dirname "${WORKSPACE_ROOT}")"
  "${clone_cmd[@]}"
  WORKSPACE_CLONED="true"
}

is_directory_empty() {
  local dir_path="$1"
  [[ -z "$(find "${dir_path}" -mindepth 1 -maxdepth 1 2>/dev/null | head -n 1)" ]]
}

assert_fresh_init_target() {
  if [[ "${MODE}" != "init" ]]; then
    return
  fi

  if [[ -e "${TARGET_ROOT}" && ! -d "${TARGET_ROOT}" ]]; then
    echo "Init mode requires a directory target root: ${TARGET_ROOT}" >&2
    exit 1
  fi

  if [[ -d "${TARGET_ROOT}" ]] && ! is_directory_empty "${TARGET_ROOT}"; then
    if [[ "${WORKSPACE_CLONED}" == "true" && "${TARGET_ROOT}" == "${WORKSPACE_ROOT}" && -d "${TARGET_ROOT}/.git" ]]; then
      return
    fi
    if [[ "${TARGET_ROOT}" == "${WORKSPACE_ROOT}" && -d "${TARGET_ROOT}/.git" ]]; then
      return
    fi
    echo "Init mode requires a fresh empty target root: ${TARGET_ROOT}" >&2
    echo "Use sync or update for existing workspace roots." >&2
    exit 1
  fi
}

ensure_super_project_meta() {
  local meta_root="${WORKSPACE_ROOT}/.super-project"
  local meta_file="${meta_root}/setup-state.json"
  local gitignore_file="${WORKSPACE_ROOT}/.gitignore"

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[DRY-RUN] Would ensure super-project metadata dir: ${meta_root}"
    echo "[DRY-RUN] Would write super-project metadata file: ${meta_file}"
    echo "[DRY-RUN] Would ensure .gitignore contains: .super-project/"
    return
  fi

  mkdir -p "${meta_root}"
  jq -n \
    --arg profile "${PROFILE_NAME}" \
    --arg workspace_name "${WORKSPACE_NAME}" \
    --arg command "${MODE}" \
    --arg source_root "${WORKSPACE_ROOT}" \
    --arg target_root "${TARGET_ROOT}" \
    --arg profile_file "${PROFILE_FILE}" \
    --arg template_file "${TEMPLATE}" \
    --arg workspace_repo_url "${WORKSPACE_REPO_URL}" \
    --arg workspace_branch "${WORKSPACE_BRANCH}" \
    --arg root_dir "${ROOT_DIR}" \
    --arg user_name "${USER_NAME}" \
    --arg dry_run "${DRY_RUN}" \
    --arg clone_timeout_seconds "${CLONE_TIMEOUT_SECONDS}" \
    --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      profile: $profile,
      workspace_name: $workspace_name,
      command: $command,
      source_root: $source_root,
      target_root: $target_root,
      profile_file: $profile_file,
      template_file: $template_file,
      workspace_repo_url: $workspace_repo_url,
      workspace_branch: $workspace_branch,
      root_dir: $root_dir,
      user_name: $user_name,
      dry_run: ($dry_run == "true"),
      clone_timeout_seconds: ($clone_timeout_seconds | tonumber),
      generated_at_utc: $generated_at
    }' > "${meta_file}"

  if [[ ! -f "${gitignore_file}" ]]; then
    printf '.super-project/\n' > "${gitignore_file}"
  elif ! grep -Fxq '.super-project/' "${gitignore_file}"; then
    printf '\n.super-project/\n' >> "${gitignore_file}"
  fi
}

require_super_project_meta() {
  SUPER_PROJECT_META_FILE="${WORKSPACE_ROOT}/.super-project/setup-state.json"
  if [[ ! -f "${SUPER_PROJECT_META_FILE}" ]]; then
    echo "Missing super-project metadata: ${WORKSPACE_ROOT}/.super-project/setup-state.json" >&2
    echo "This workspace is not initialized. Re-run init first." >&2
    exit 1
  fi
}

load_super_project_meta_context() {
  local meta_profile=""
  local meta_profile_file=""
  local meta_root_dir=""
  local meta_user_name=""
  local meta_target_root=""

  meta_profile="$(jq -r '.profile // empty' "${SUPER_PROJECT_META_FILE}")"
  meta_profile_file="$(jq -r '.profile_file // empty' "${SUPER_PROJECT_META_FILE}")"
  meta_root_dir="$(jq -r '.root_dir // empty' "${SUPER_PROJECT_META_FILE}")"
  meta_user_name="$(jq -r '.user_name // empty' "${SUPER_PROJECT_META_FILE}")"
  meta_target_root="$(jq -r '.target_root // empty' "${SUPER_PROJECT_META_FILE}")"

  if [[ -n "${meta_profile}" ]]; then
    PROFILE="${meta_profile}"
  fi
  if [[ -n "${meta_profile_file}" && -z "${PROFILE_FILE_OVERRIDE}" ]]; then
    PROFILE_FILE_OVERRIDE="${meta_profile_file}"
  fi
  if [[ -n "${meta_root_dir}" ]]; then
    ROOT_DIR="${meta_root_dir}"
  fi
  if [[ -n "${meta_user_name}" ]]; then
    USER_NAME="${meta_user_name}"
  fi
  if [[ -n "${meta_target_root}" && -z "${TARGET_ROOT}" ]]; then
    TARGET_ROOT="${meta_target_root}"
  fi
}

resolve_path() {
  local base="$1"
  local path="$2"
  if [[ "${path}" == /* ]]; then
    printf '%s\n' "${path}"
  else
    printf '%s\n' "${base}/${path}"
  fi
}

expand_project_path() {
  local raw_path="$1"
  local expanded="${raw_path}"
  expanded="${expanded//<root_dir>/${ROOT_DIR}}"
  expanded="${expanded//<user_home>/\/home\/${USER_NAME}}"
  resolve_path "${TARGET_ROOT}" "${expanded}"
}

ensure_checkout() {
  local repo_dir="$1"
  local checkout_branch="$2"
  local default_branch=""

  default_branch="$(git -C "${repo_dir}" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)"
  if [[ -z "${default_branch}" ]]; then
    default_branch="$(git -C "${repo_dir}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  fi

  if [[ -n "${default_branch}" && "${default_branch}" != "HEAD" ]]; then
    git -C "${repo_dir}" checkout -q "${default_branch}" >/dev/null 2>&1 || true
  fi

  if [[ -n "${checkout_branch}" && "${checkout_branch}" != "${default_branch}" ]]; then
    if git -C "${repo_dir}" show-ref --verify --quiet "refs/remotes/origin/${checkout_branch}"; then
      git -C "${repo_dir}" checkout -q -B "${checkout_branch}" --track "origin/${checkout_branch}" >/dev/null 2>&1 || true
    else
      git -C "${repo_dir}" checkout -q -B "${checkout_branch}" >/dev/null 2>&1 || true
    fi
  fi
}

canonical_dir_path() {
  local dir_path="$1"
  (cd "${dir_path}" 2>/dev/null && pwd -P) || true
}

is_git_repo_root() {
  local dir_path="$1"
  local repo_root=""
  local dir_abs=""
  local repo_abs=""

  if ! git -C "${dir_path}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 1
  fi

  repo_root="$(git -C "${dir_path}" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -z "${repo_root}" ]]; then
    return 1
  fi

  dir_abs="$(canonical_dir_path "${dir_path}")"
  repo_abs="$(canonical_dir_path "${repo_root}")"
  [[ -n "${dir_abs}" && -n "${repo_abs}" && "${dir_abs}" == "${repo_abs}" ]]
}

if (($# == 0)); then
  usage >&2
  exit 1
fi

case "$1" in
  init|sync|update|status)
    MODE="$1"
    shift
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "Missing or invalid command: $1" >&2
    echo "Expected one of: init, sync, update, status" >&2
    usage >&2
    exit 1
    ;;
esac

while (($# > 0)); do
  case "$1" in
    --workspace-root)
      WORKSPACE_ROOT="$2"
      shift 2
      ;;
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --profile-file)
      PROFILE_FILE_OVERRIDE="$2"
      shift 2
      ;;
    --mode)
      echo "--mode is no longer supported. Use a subcommand: init, sync, update, or status." >&2
      exit 1
      ;;
    --workspace-repo-url)
      WORKSPACE_REPO_URL="$2"
      shift 2
      ;;
    --workspace-branch)
      WORKSPACE_BRANCH="$2"
      shift 2
      ;;
    --user)
      USER_NAME="$2"
      shift 2
      ;;
    --root-dir)
      ROOT_DIR="$2"
      shift 2
      ;;
    --target-root)
      TARGET_ROOT="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --clone-timeout)
      CLONE_TIMEOUT_SECONDS="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${ROOT_DIR}" ]]; then
  ROOT_DIR="/home/${USER_NAME}"
fi

if ! [[ "${CLONE_TIMEOUT_SECONDS}" =~ ^[0-9]+$ ]]; then
  echo "Invalid --clone-timeout value: ${CLONE_TIMEOUT_SECONDS} (expected non-negative integer seconds)" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Required tool not found: jq" >&2
  exit 1
fi

if [[ "${MODE}" == "init" ]]; then
  if [[ -z "${TARGET_ROOT}" ]]; then
    echo "init requires --target-root." >&2
    exit 1
  fi

  if [[ -z "${WORKSPACE_ROOT}" && -n "${TARGET_ROOT}" ]]; then
    WORKSPACE_ROOT="${TARGET_ROOT}"
  fi

  bootstrap_workspace_repo

  if [[ -z "${WORKSPACE_ROOT}" ]]; then
    echo "Init could not resolve workspace root from --target-root/--workspace-root." >&2
    exit 1
  fi

  if [[ -z "${TARGET_ROOT}" ]]; then
    TARGET_ROOT="${WORKSPACE_ROOT}"
  fi

  assert_fresh_init_target
else
  if [[ -n "${WORKSPACE_REPO_URL}" ]]; then
    echo "--workspace-repo-url is supported only in init command." >&2
    exit 1
  fi

  if [[ -z "${WORKSPACE_ROOT}" ]]; then
    WORKSPACE_ROOT="$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null || true)"
  fi

  if [[ -z "${WORKSPACE_ROOT}" ]]; then
    echo "sync/update/status must run inside a git repository or use --workspace-root." >&2
    exit 1
  fi

  if ! git -C "${WORKSPACE_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Workspace root is not a git repository: ${WORKSPACE_ROOT}" >&2
    exit 1
  fi

  require_super_project_meta
  load_super_project_meta_context
  if [[ -z "${TARGET_ROOT}" ]]; then
    TARGET_ROOT="${WORKSPACE_ROOT}"
  fi
fi

if [[ -n "${PROFILE_FILE_OVERRIDE}" ]]; then
  PROFILE_FILE="$(resolve_path "${WORKSPACE_ROOT}" "${PROFILE_FILE_OVERRIDE}")"
else
  PROFILE_FILE="${WORKSPACE_ROOT}/.vscode/workspace-profiles/${PROFILE}.json"
fi

if [[ ! -f "${PROFILE_FILE}" ]]; then
  if [[ "${DRY_RUN}" == "true" && -n "${WORKSPACE_REPO_URL}" && "${MODE}" != "update" ]]; then
    echo "[DRY-RUN] Profile file not found yet: ${PROFILE_FILE}"
    echo "[DRY-RUN] Expected in remote bootstrap dry-run because clone is not executed."
    echo "[DRY-RUN] Re-run without --dry-run to execute clone and continue setup."
    exit 0
  fi
  echo "Profile file not found: ${PROFILE_FILE}" >&2
  exit 1
fi

PROFILE_NAME="$(jq -r '.profile // empty' "${PROFILE_FILE}")"
if [[ -z "${PROFILE_NAME}" ]]; then
  echo "Invalid profile file (missing .profile): ${PROFILE_FILE}" >&2
  exit 1
fi

WORKSPACE_NAME="$(jq -r '.workspace_name // empty' "${PROFILE_FILE}")"
if [[ -z "${WORKSPACE_NAME}" || "${WORKSPACE_NAME}" == "null" ]]; then
  WORKSPACE_NAME="${PROFILE_NAME}"
fi
if [[ "${WORKSPACE_NAME}" == *"/"* ]]; then
  echo "Invalid profile file (.workspace_name must not contain '/'): ${PROFILE_FILE}" >&2
  exit 1
fi

PROFILE="${PROFILE_NAME}"

DESCRIPTION="$(jq -r '.description // ""' "${PROFILE_FILE}")"
WORKSPACE_TEMPLATE_REL="$(jq -r '.setup.workspace_template // empty' "${PROFILE_FILE}")"
if [[ -z "${WORKSPACE_TEMPLATE_REL}" || "${WORKSPACE_TEMPLATE_REL}" == "null" ]]; then
  WORKSPACE_TEMPLATE_REL=".vscode/workspace-profiles/${PROFILE}.local.code-workspace.template"
fi
MANAGE_SUBMODULES="$(jq -r '.setup.manage_submodules // true' "${PROFILE_FILE}")"
ENSURE_PROJECT_PATHS="$(jq -r '.setup.ensure_project_paths // true' "${PROFILE_FILE}")"

REGENERATE_WORKSPACE_FILE="false"
SYNC_PROJECT_PATHS="false"
SYNC_VISIBLE_FOLDERS="false"
SYNC_SUBMODULES="false"
ENABLE_GIT_SYNC="false"

case "${MODE}" in
  init)
    REGENERATE_WORKSPACE_FILE="true"
    SYNC_PROJECT_PATHS="true"
    SYNC_VISIBLE_FOLDERS="true"
    ;;
  sync)
    REGENERATE_WORKSPACE_FILE="true"
    SYNC_PROJECT_PATHS="true"
    SYNC_VISIBLE_FOLDERS="true"
    SYNC_SUBMODULES="true"
    ENABLE_GIT_SYNC="true"
    ;;
  update)
    REGENERATE_WORKSPACE_FILE="true"
    SYNC_PROJECT_PATHS="true"
    SYNC_VISIBLE_FOLDERS="true"
    ;;
  status)
    ;;
esac

TEMPLATE="$(resolve_path "${WORKSPACE_ROOT}" "${WORKSPACE_TEMPLATE_REL}")"
OUTPUT="${TARGET_ROOT}/.vscode/${WORKSPACE_NAME}.local.code-workspace"

if [[ "${MODE}" != "status" && ! -f "${TEMPLATE}" ]]; then
  echo "Template not found: ${TEMPLATE}" >&2
  exit 1
fi

if [[ "${MODE}" != "status" ]]; then
  ensure_super_project_meta
fi

if [[ "${MODE}" != "status" && "${DRY_RUN}" == "true" ]]; then
  echo "[DRY-RUN] Would ensure output directory exists: $(dirname "${OUTPUT}")"
elif [[ "${MODE}" != "status" ]]; then
  mkdir -p "$(dirname "${OUTPUT}")"
fi

if [[ "${MODE}" != "status" && "${REGENERATE_WORKSPACE_FILE}" == "true" ]]; then
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[DRY-RUN] Would regenerate workspace file: ${OUTPUT}"
  else
    sed -e "s|/home/<your-user>/|/home/${USER_NAME}/|g" -e "s|<root_dir>|${ROOT_DIR}|g" "${TEMPLATE}" > "${OUTPUT}"
    echo "Regenerated workspace file: ${OUTPUT}"
  fi
elif [[ "${MODE}" != "status" && -f "${OUTPUT}" ]]; then
  echo "Workspace file already exists: ${OUTPUT}"
  echo "Leaving it unchanged in update mode."
elif [[ "${MODE}" != "status" ]]; then
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[DRY-RUN] Would generate workspace file: ${OUTPUT}"
  else
    sed -e "s|/home/<your-user>/|/home/${USER_NAME}/|g" -e "s|<root_dir>|${ROOT_DIR}|g" "${TEMPLATE}" > "${OUTPUT}"
    echo "Generated workspace file: ${OUTPUT}"
  fi
fi

if [[ "${SYNC_SUBMODULES}" == "true" && "${MANAGE_SUBMODULES}" == "true" && -d "${WORKSPACE_ROOT}/.git" && -f "${WORKSPACE_ROOT}/.gitmodules" ]]; then
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[DRY-RUN] Would run: git -C ${WORKSPACE_ROOT} submodule update --init --recursive"
  else
    git -C "${WORKSPACE_ROOT}" submodule update --init --recursive || true
  fi
fi

if [[ "${SYNC_PROJECT_PATHS}" == "true" && "${ENSURE_PROJECT_PATHS}" == "true" ]]; then
  while IFS=$'\t' read -r project_name project_type project_scope project_path_raw; do
    if [[ -z "${project_name}" || -z "${project_path_raw}" ]]; then
      continue
    fi

    if [[ "${project_scope}" == *-external ]]; then
      if [[ "${project_path_raw}" != /* && "${project_path_raw}" != \<root_dir\>/* && "${project_path_raw}" != \<user_home\>/* ]]; then
        echo "Invalid external path for ${project_name}: ${project_path_raw}" >&2
        echo "External paths must be absolute or start with <root_dir>/ or <user_home>/" >&2
        exit 1
      fi
    fi

    abs_project_path="$(expand_project_path "${project_path_raw}")"
    if [[ ! -e "${abs_project_path}" ]]; then
      if [[ "${DRY_RUN}" == "true" ]]; then
        echo "[DRY-RUN] Would create project path: ${abs_project_path}"
      else
        mkdir -p "${abs_project_path}"
      fi
    fi
  done < <(
    jq -r '(.projects // [])[]? | [.name, (.type // "repo"), .scope, .path] | @tsv' "${PROFILE_FILE}"
  )
fi

if [[ "${SYNC_VISIBLE_FOLDERS}" == "true" ]]; then
  while IFS=$'\t' read -r project_name project_path_raw; do
    if [[ -z "${project_name}" || -z "${project_path_raw}" ]]; then
      continue
    fi
    abs_project_path="$(expand_project_path "${project_path_raw}")"
    if [[ "${DRY_RUN}" == "true" ]]; then
      echo "[DRY-RUN] Would add visible workspace folder: ${project_name} -> ${abs_project_path}"
      continue
    fi
    tmp_file="$(mktemp)"
    jq --arg name "${project_name}" --arg path "${abs_project_path}" '
      .folders = ((.folders // [])
        | map(select(.name != $name and .path != $path))
        + [{"name": $name, "path": $path}])' "${OUTPUT}" > "${tmp_file}"
    mv "${tmp_file}" "${OUTPUT}"
  done < <(
    jq -r '(.projects // [])[]? | select((.visible // false) == true) | [.name, .path] | @tsv' "${PROFILE_FILE}"
  )
fi

YOCTO_PROJECTS_CSV="$(jq -r '[(.projects // [])[]? | select((.type // "") == "yocto") | .name] | join(", ")' "${PROFILE_FILE}")"
if [[ -z "${YOCTO_PROJECTS_CSV}" || "${YOCTO_PROJECTS_CSV}" == "null" ]]; then
  YOCTO_PROJECTS_CSV="(none)"
fi

CLONE_PENDING_LINES=""
CLONE_DONE_LINES=""
CLONE_PRESENT_LINES=""
CLONE_SKIPPED_LINES=""
CLONE_FAILED_LINES=""
CLONE_CONSIDERED_COUNT=0
CLONE_PENDING_COUNT=0
CLONE_DONE_COUNT=0
CLONE_PRESENT_COUNT=0
CLONE_SKIPPED_COUNT=0
CLONE_FAILED_COUNT=0

if [[ "${CLONE_TIMEOUT_SECONDS}" -gt 0 && "${ENABLE_GIT_SYNC}" == "true" && "${DRY_RUN}" != "true" ]]; then
  if ! command -v timeout >/dev/null 2>&1; then
    echo "Warning: timeout command not found; ignoring --clone-timeout ${CLONE_TIMEOUT_SECONDS}." >&2
    CLONE_TIMEOUT_SECONDS="0"
  fi
fi

while IFS=$'\t' read -r project_name project_type project_scope project_path_raw clone_url checkout_branch; do
  if [[ -z "${project_name}" || "${project_type}" != "repo" ]]; then
    continue
  fi

  if [[ "${project_scope}" != "public" ]]; then
    continue
  fi

  if [[ -z "${clone_url}" || "${clone_url}" == "null" ]]; then
    continue
  fi

  CLONE_CONSIDERED_COUNT=$((CLONE_CONSIDERED_COUNT + 1))
  abs_project_path="$(expand_project_path "${project_path_raw}")"
  if is_git_repo_root "${abs_project_path}"; then
    CLONE_PRESENT_LINES+="- ${project_name}: already present at ${project_path_raw}"$'\n'
    CLONE_PRESENT_COUNT=$((CLONE_PRESENT_COUNT + 1))
    continue
  fi

  if [[ "${ENABLE_GIT_SYNC}" != "true" ]]; then
    CLONE_PENDING_LINES+="- ${project_name}: ${project_path_raw} -> ${clone_url}"$'\n'
    CLONE_PENDING_COUNT=$((CLONE_PENDING_COUNT + 1))
    continue
  fi

  if [[ -e "${abs_project_path}" && ! -d "${abs_project_path}" ]]; then
    CLONE_SKIPPED_LINES+="- ${project_name}: target exists and is not a directory (${project_path_raw})"$'\n'
    CLONE_PENDING_LINES+="- ${project_name}: ${project_path_raw} -> ${clone_url}"$'\n'
    CLONE_SKIPPED_COUNT=$((CLONE_SKIPPED_COUNT + 1))
    CLONE_PENDING_COUNT=$((CLONE_PENDING_COUNT + 1))
    continue
  fi

  if [[ -d "${abs_project_path}" ]]; then
    if [[ -n "$(find "${abs_project_path}" -mindepth 1 -maxdepth 1 2>/dev/null | head -n 1)" ]]; then
      CLONE_SKIPPED_LINES+="- ${project_name}: target directory is non-empty (${project_path_raw})"$'\n'
      CLONE_PENDING_LINES+="- ${project_name}: ${project_path_raw} -> ${clone_url}"$'\n'
      CLONE_SKIPPED_COUNT=$((CLONE_SKIPPED_COUNT + 1))
      CLONE_PENDING_COUNT=$((CLONE_PENDING_COUNT + 1))
      continue
    fi
    if [[ "${DRY_RUN}" == "true" ]]; then
      echo "[DRY-RUN] Would remove empty directory before clone: ${abs_project_path}"
    else
      rmdir "${abs_project_path}" || true
    fi
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[DRY-RUN] Would clone ${clone_url} into ${abs_project_path}"
    if [[ -n "${checkout_branch}" && "${checkout_branch}" != "null" ]]; then
      echo "[DRY-RUN] Would checkout branch '${checkout_branch}' after clone"
    fi
    CLONE_PENDING_LINES+="- ${project_name}: ${project_path_raw} -> ${clone_url}"$'\n'
    CLONE_PENDING_COUNT=$((CLONE_PENDING_COUNT + 1))
    continue
  fi

  mkdir -p "$(dirname "${abs_project_path}")"
  clone_ok="false"
  if [[ "${CLONE_TIMEOUT_SECONDS}" -gt 0 ]]; then
    if timeout "${CLONE_TIMEOUT_SECONDS}s" git clone "${clone_url}" "${abs_project_path}" >/dev/null 2>&1; then
      clone_ok="true"
    else
      clone_rc="$?"
      if [[ "${clone_rc}" -eq 124 ]]; then
        CLONE_FAILED_LINES+="- ${project_name}: clone timed out after ${CLONE_TIMEOUT_SECONDS}s (${clone_url})"$'\n'
      else
        CLONE_FAILED_LINES+="- ${project_name}: clone failed (${clone_url})"$'\n'
      fi
    fi
  else
    if git clone "${clone_url}" "${abs_project_path}" >/dev/null 2>&1; then
      clone_ok="true"
    else
      CLONE_FAILED_LINES+="- ${project_name}: clone failed (${clone_url})"$'\n'
    fi
  fi

  if [[ "${clone_ok}" == "true" ]]; then
    ensure_checkout "${abs_project_path}" "${checkout_branch:-}"
    if [[ -n "${checkout_branch}" && "${checkout_branch}" != "null" ]]; then
      CLONE_DONE_LINES+="- ${project_name}: cloned into ${project_path_raw} (checkout: ${checkout_branch})"$'\n'
    else
      CLONE_DONE_LINES+="- ${project_name}: cloned into ${project_path_raw}"$'\n'
    fi
    CLONE_DONE_COUNT=$((CLONE_DONE_COUNT + 1))
  else
    CLONE_PENDING_LINES+="- ${project_name}: ${project_path_raw} -> ${clone_url}"$'\n'
    CLONE_FAILED_COUNT=$((CLONE_FAILED_COUNT + 1))
    CLONE_PENDING_COUNT=$((CLONE_PENDING_COUNT + 1))
  fi
done < <(
  jq -r '(.projects // [])[]?
    | [.name, (.type // "repo"), .scope, .path, (.clone_url // ""), (.checkout_branch // "")]
    | @tsv' "${PROFILE_FILE}"
)

if [[ "${MODE}" == "status" ]]; then
  META_COMMAND="$(jq -r '.command // "unknown"' "${SUPER_PROJECT_META_FILE}")"
  META_GENERATED_AT="$(jq -r '.generated_at_utc // "unknown"' "${SUPER_PROJECT_META_FILE}")"
  WORKSPACE_GIT_REPO="false"
  if git -C "${WORKSPACE_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    WORKSPACE_GIT_REPO="true"
  fi
  WORKSPACE_FILE_PRESENT="false"
  if [[ -f "${OUTPUT}" ]]; then
    WORKSPACE_FILE_PRESENT="true"
  fi
cat <<EOF
Super-project status.
Profile: ${PROFILE_NAME}
Command: ${MODE}
Last setup command: ${META_COMMAND}
Last setup timestamp (UTC): ${META_GENERATED_AT}
Workspace source root: ${WORKSPACE_ROOT}
Workspace target root: ${TARGET_ROOT}
Workspace file: ${OUTPUT}
Workspace file present: ${WORKSPACE_FILE_PRESENT}
Workspace git repository: ${WORKSPACE_GIT_REPO}
Root dir: ${ROOT_DIR}
Dry-run: ${DRY_RUN}
Clone timeout (seconds): ${CLONE_TIMEOUT_SECONDS}
Notes:
- Public projects must never reference, mention, or hard-depend on private projects.
- Private projects remain local context and are not referenced from public deliverables.
- Yocto projects: ${YOCTO_PROJECTS_CSV}
EOF
else
cat <<EOF
Workspace setup complete.
Profile: ${PROFILE_NAME}
Workspace name: ${WORKSPACE_NAME}
Command: ${MODE}
Description: ${DESCRIPTION}
Workspace source root: ${WORKSPACE_ROOT}
Workspace target root: ${TARGET_ROOT}
Workspace file: ${OUTPUT}
Root dir: ${ROOT_DIR}
Dry-run: ${DRY_RUN}
Clone timeout (seconds): ${CLONE_TIMEOUT_SECONDS}
Notes:
- Public projects must never reference, mention, or hard-depend on private projects.
- Private projects remain local context and are not referenced from public deliverables.
- Yocto projects: ${YOCTO_PROJECTS_CSV}
EOF
fi

if [[ -n "${CLONE_PENDING_LINES}" ]]; then
cat <<EOF
Public repositories still pending clone in this target root:
${CLONE_PENDING_LINES}
EOF
fi

if [[ -n "${CLONE_DONE_LINES}" ]]; then
cat <<EOF
Auto-cloned public repositories:
${CLONE_DONE_LINES}
EOF
fi

if [[ -n "${CLONE_PRESENT_LINES}" ]]; then
cat <<EOF
Public repositories already present:
${CLONE_PRESENT_LINES}
EOF
fi

if [[ -n "${CLONE_SKIPPED_LINES}" ]]; then
cat <<EOF
Auto-clone skipped:
${CLONE_SKIPPED_LINES}
EOF
fi

if [[ -n "${CLONE_FAILED_LINES}" ]]; then
cat <<EOF
Auto-clone failed:
${CLONE_FAILED_LINES}
EOF
fi

echo "Clone summary: considered=${CLONE_CONSIDERED_COUNT} present=${CLONE_PRESENT_COUNT} cloned=${CLONE_DONE_COUNT} pending=${CLONE_PENDING_COUNT} skipped=${CLONE_SKIPPED_COUNT} failed=${CLONE_FAILED_COUNT}"
