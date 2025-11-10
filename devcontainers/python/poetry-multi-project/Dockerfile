# Use a clean, stable Debian-based Python image
FROM mcr.microsoft.com/devcontainers/python:3.11-bookworm
# [1] Install Poetry and system dependencies
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    # Install system tools needed for dev (like curl, git, build-essential)
    && apt-get -y install --no-install-recommends curl wget git build-essential \
    && pip install --no-cache-dir pipx \
    # Add pipx's installation path to the PATH for the current user
    && /usr/local/bin/pipx ensurepath \
    # Install Poetry globally using pipx (the recommended isolation tool)
    && /usr/local/bin/pipx install poetry \
    # Add poetry to the global path
    && ln -s /root/.local/bin/poetry /usr/local/bin/poetry \
    && apt-get clean && rm -rf /var/lib/apt/lists/*