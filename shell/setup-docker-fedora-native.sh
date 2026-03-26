#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  setup-docker-fedora-native.sh [options]

Install and configure native Docker on Fedora with LLP-safe network defaults.

Options:
  --apply-daemon-config    Write /etc/docker/daemon.json with LLP-safe address ranges.
  --skip-daemon-config     Do not touch /etc/docker/daemon.json (default).
  --add-user-group         Add current user to docker group.
  --no-add-user-group      Do not modify user groups.
  -h, --help               Show help.

Notes:
- This script uses sudo for package install and service changes.
- If user is added to docker group, re-login is required.
EOF
}

APPLY_DAEMON_CONFIG=0
ADD_USER_GROUP=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply-daemon-config)
      APPLY_DAEMON_CONFIG=1
      shift
      ;;
    --skip-daemon-config)
      APPLY_DAEMON_CONFIG=0
      shift
      ;;
    --add-user-group)
      ADD_USER_GROUP=1
      shift
      ;;
    --no-add-user-group)
      ADD_USER_GROUP=0
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

if [[ ! -f /etc/fedora-release ]]; then
  echo "Error: this script is intended for Fedora hosts." >&2
  exit 1
fi

if ! command -v dnf >/dev/null 2>&1; then
  echo "Error: dnf not found." >&2
  exit 1
fi

echo "==> Installing native Docker packages on Fedora"
sudo dnf -y install dnf-plugins-core

DOCKER_REPO_URL="https://download.docker.com/linux/fedora/docker-ce.repo"
if sudo dnf config-manager addrepo --help >/dev/null 2>&1; then
  # Fedora 41+ / dnf5 syntax
  sudo dnf -y config-manager addrepo --from-repofile="${DOCKER_REPO_URL}" --overwrite
else
  # Legacy dnf4 syntax
  sudo dnf -y config-manager --add-repo "${DOCKER_REPO_URL}"
fi

sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "==> Enabling and starting Docker service"
sudo systemctl enable --now docker

if [[ ${APPLY_DAEMON_CONFIG} -eq 1 ]]; then
  echo "==> Writing LLP-safe Docker network configuration"
  sudo install -m 0755 -d /etc/docker
  sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
  "bip": "100.127.232.1/25",
  "fixed-cidr": "100.127.232.0/25",
  "default-address-pools": [
    {
      "base": "100.127.232.128/25",
      "size": 29
    }
  ]
}
EOF
  sudo systemctl restart docker
fi

if [[ ${ADD_USER_GROUP} -eq 1 ]]; then
  echo "==> Adding user '$USER' to docker group"
  sudo usermod -aG docker "$USER"
fi

echo "==> Verification"
command -v docker || true
docker --version || true
docker compose version || true

if [[ ${ADD_USER_GROUP} -eq 1 ]]; then
  echo "Info: log out and back in (or reboot) so docker group membership is applied."
fi
