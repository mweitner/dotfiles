#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "--- Installing Poetry Dependencies for All Components ---"

# This array lists the directories of your Python components
# ADJUST THIS ARRAY TO LIST YOUR ACTUAL SUB-PROJECT FOLDERS
components=("canopen2mqtt" "cmcontrol" "cmtkiotclient" "gsp2mqtt" "mqttlimiter" "candbc2mqtt" "cmconfig" "cmshared" "cmtools/mqtt_pub" "mqttbridge" "mqttmerger")

for dir in "${components[@]}"; do
    if [ -d "$dir" ]; then
        echo "Processing project in: $dir"
        cd "$dir" || continue
        
        # Check if pyproject.toml exists (ensures it's a Poetry project)
        if [ -f "pyproject.toml" ]; then
            # Run the installation, including dev dependencies for development environment
            # --no-interaction is essential for container builds
            poetry install --no-interaction || true
            echo "Successfully installed dependencies for $dir."
        else
            echo "Skipping $dir: pyproject.toml not found."
        fi
        
        # Move back to the root workspace folder
        cd "$OLDPWD"
    else
        echo "Warning: Directory $dir not found. Skipping."
    fi
done

echo "--- All components initialized. ---"

# Ensure the VS Code Python extension sees the virtual environment
poetry env use python3

# Give the script execution permission
chmod +x .devcontainer/setup_poetry.sh
