#!/usr/bin/env bash
# Setup pre-commit in the current repository and apply SSL download workaround.
# Run inside a git repository: ./setup-pre-commit.sh

set -euo pipefail

PATCH_SYSTEM_RUNTIMES=true

print_usage() {
    cat <<'EOF'
Usage: setup-pre-commit.sh [--no-system-runtimes] [--help]

Options:
    --no-system-runtimes   Do not rewrite node/golang versions to "system"
    -h, --help             Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-system-runtimes)
            PATCH_SYSTEM_RUNTIMES=false
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

if ! command -v git >/dev/null 2>&1 || ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: run this script inside a git repository."
    exit 1
fi

if ! command -v pre-commit >/dev/null 2>&1; then
    echo "Error: pre-commit not found. Install it first (Fedora: sudo dnf install -y pre-commit)."
    exit 1
fi

if [[ ! -f .pre-commit-config.yaml ]]; then
    echo "Error: .pre-commit-config.yaml not found in $(pwd)."
    exit 1
fi

if [[ "$PATCH_SYSTEM_RUNTIMES" == true ]]; then
    if grep -qE '^[[:space:]]*node:[[:space:]]*' .pre-commit-config.yaml || \
         grep -qE '^[[:space:]]*golang:[[:space:]]*' .pre-commit-config.yaml; then
        cp .pre-commit-config.yaml ".pre-commit-config.yaml.bak.$(date +%Y%m%d-%H%M%S)"
        sed -i -E 's/^([[:space:]]*node:[[:space:]]*).*/\1system/' .pre-commit-config.yaml
        sed -i -E 's/^([[:space:]]*golang:[[:space:]]*).*/\1system/' .pre-commit-config.yaml
        echo "Updated .pre-commit-config.yaml: node/golang language versions -> system"
    else
        echo "No node/golang default language versions found to patch."
    fi
fi

if ! command -v node >/dev/null 2>&1; then
    echo "WARN: node is not installed. Node-based hooks may fail with language_version=system."
fi
if ! command -v go >/dev/null 2>&1; then
    echo "WARN: go is not installed. Go-based hooks may fail with language_version=system."
fi

echo "Installing pre-commit hook scripts..."
pre-commit install

echo
echo "Pre-caching hook environments..."
if pre-commit run --all-files; then
    echo "Pre-commit setup complete."
else
    echo "Pre-commit run reported failures."
    echo "If the failure is SSL certificate verification in Python 3.14 runtime downloads,"
    echo "keep node/golang at 'system' and use installed system runtimes."
    exit 1
fi
