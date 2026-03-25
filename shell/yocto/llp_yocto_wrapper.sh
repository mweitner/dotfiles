#!/usr/bin/env bash
set -eo pipefail

# Shell-agnostic Yocto runner. Useful from fish/tmux where sourcing bash setup
# scripts directly is inconvenient.

WORKDIR="${WORKDIR:-$HOME/lpo-dev/linux-lpo}"
DISTRO_LAYER="${DISTRO_LAYER:-meta-liebherr-lpo-display}"
INIT_FLAGS=("-llpnetboot")
BITBAKE_UI="${BITBAKE_UI:-knotty}"
LOG_FILE="${LOG_FILE:-}"

usage() {
    cat <<'EOF'
Usage:
    llp-yocto-build [options] <bitbake-args...>

Options:
    --workdir <path>        Yocto project root (default: ~/lpo-dev/linux-lpo)
    --distro-layer <name>   Distro layer for llp_init_build.sh
                                                    (default: meta-liebherr-lpo-display)
    --init-flag <flag>      Extra init flag, repeatable (example: --init-flag -llpdev)
    --ui <name>             BitBake UI (default: knotty). Useful values: knotty, ncurses.
    --log-file <path>       Write full build output to file (via tee).
    -h, --help              Show help

Examples:
    llp-yocto-build lpo-display-image
    llp-yocto-build --workdir ~/dps-dev/linux-dps --distro-layer meta-liebherr-dps core-image-minimal
    llp-yocto-build --init-flag -llpdev -k lpo-display-image
    llp-yocto-build --ui ncurses --log-file ~/lpo-build-$(date +%F-%H%M).log -k lpo-display-image
EOF
}

BITBAKE_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --workdir)
            WORKDIR="${2:-}"
            shift 2
            ;;
        --distro-layer)
            DISTRO_LAYER="${2:-}"
            shift 2
            ;;
        --init-flag)
            INIT_FLAGS+=("${2:-}")
            shift 2
            ;;
        --ui)
            BITBAKE_UI="${2:-}"
            shift 2
            ;;
        --log-file)
            LOG_FILE="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            BITBAKE_ARGS+=("$1")
            shift
            ;;
    esac
done

if [[ ${#BITBAKE_ARGS[@]} -eq 0 ]]; then
    echo "Error: missing bitbake target/arguments" >&2
    usage
    exit 2
fi

if [[ ! -d "$WORKDIR" ]]; then
    echo "Error: workdir not found: $WORKDIR" >&2
    exit 2
fi

if [[ ! -f "$HOME/.local/bin/llp_init_build.sh" ]]; then
    echo "Error: ~/.local/bin/llp_init_build.sh not found." >&2
    echo "Run install-fedora.sh symlink phase or link it manually from dotfiles/shell/yocto." >&2
    exit 1
fi

# In tmux, keep an external log by default so output is preserved beyond
# terminal scrollback limits.
if [[ -z "$LOG_FILE" && -n "${TMUX:-}" ]]; then
    LOG_FILE="$WORKDIR/build/logs/bitbake-$(date +%Y%m%d-%H%M%S).log"
fi

cd "$WORKDIR"
TOPDIR="$(pwd)"
OEROOT="${TOPDIR}/layers/poky"

# llp_init_build.sh uses non-zero return codes internally for feature checks;
# temporarily disable errexit while sourcing to avoid false aborts.
set +e
# shellcheck disable=SC1091
source "$HOME/.local/bin/llp_init_build.sh" "$DISTRO_LAYER" "${INIT_FLAGS[@]}"
source_rc=$?
set -e
if [[ $source_rc -ne 0 ]]; then
    echo "Error: llp_init_build.sh failed with code $source_rc" >&2
    exit "$source_rc"
fi

# Check if stdout is a TTY (needed for ncurses UI)
HAS_TTY=0
[[ -t 1 ]] && HAS_TTY=1

# If ncurses requested but no TTY, fall back to knotty with warning
EFFECTIVE_UI="$BITBAKE_UI"
if [[ "$BITBAKE_UI" == "ncurses" && $HAS_TTY -eq 0 ]]; then
    echo "Warning: ncurses UI requested but no TTY available (piped output or background)." >&2
    echo "Falling back to knotty UI." >&2
    EFFECTIVE_UI="knotty"
fi

echo "==> Running: bitbake -u ${EFFECTIVE_UI} ${BITBAKE_ARGS[*]}"

# ncurses doesn't work through tee (breaks TTY); use direct terminal output.
# For logging with ncurses, let output go interactively to terminal.
# knotty (scrolling) mode benefits from tee piping to external log files.
if [[ "$EFFECTIVE_UI" == "ncurses" ]]; then
    bitbake -u "${EFFECTIVE_UI}" "${BITBAKE_ARGS[@]}"
elif [[ -n "$LOG_FILE" ]]; then
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "==> Full log: $LOG_FILE"
    bitbake -u "${EFFECTIVE_UI}" "${BITBAKE_ARGS[@]}" 2>&1 | tee -a "$LOG_FILE"
    bb_rc=${PIPESTATUS[0]}
    exit "$bb_rc"
else
    bitbake -u "${EFFECTIVE_UI}" "${BITBAKE_ARGS[@]}"
fi
