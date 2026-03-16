#!/usr/bin/env bash
# Simple screenshot script for Sway using grim and slurp

# Create directory if it doesn't exist
DIR="$HOME/pictures/screenshots"
mkdir -p "$DIR"

# Timestamp for filename
FILE="$DIR/screenshot_$(date +%Y%m%d_%H%M%S).png"

# Argument handling
case $1 in
    full)
        # Capture full screen
        grim "$FILE"
        ;;
    region)
        # Capture selected region
        slurp | grim -g - "$FILE"
        ;;
    *)
        echo "Usage: $0 {full|region}"
        exit 1
        ;;
esac

# Copy to clipboard and notify
if [ -f "$FILE" ]; then
    cat "$FILE" | wl-copy --type image/png
    notify-send "Screenshot Captured" "Saved to $FILE and copied to clipboard." -i "$FILE"
fi
