#!/usr/bin/env bash
# Simple screenshot script for Sway using grim and slurp

# Default save directory
DIR="$HOME/pictures/screenshots"
mkdir -p "$DIR"

# Timestamp for filename
DEFAULT_FILE="$DIR/screenshot_$(date +%Y%m%d_%H%M%S).png"

# Argument handling
case $1 in
    full)
        # Capture full screen to default location
        grim "$DEFAULT_FILE"
        FILE="$DEFAULT_FILE"
        ;;
    region)
        # Capture selected region to default location
        GEOM=$(slurp) || exit 1
        grim -g "$GEOM" "$DEFAULT_FILE"
        FILE="$DEFAULT_FILE"
        ;;
    full-save-as)
        # Capture full screen, then pick save location via file dialog
        TMP=$(mktemp /tmp/grimshot-XXXXXX.png)
        grim "$TMP"
        FILE=$(zenity --file-selection --save --confirm-overwrite \
            --title="Save screenshot as" \
            --filename="$DEFAULT_FILE" \
            --file-filter="PNG files | *.png" 2>/dev/null)
        if [ -z "$FILE" ]; then
            rm -f "$TMP"
            exit 0  # user cancelled
        fi
        [[ "$FILE" != *.png ]] && FILE="${FILE}.png"
        mv "$TMP" "$FILE"
        ;;
    region-save-as)
        # Capture selected region, then pick save location via file dialog
        GEOM=$(slurp) || exit 1
        TMP=$(mktemp /tmp/grimshot-XXXXXX.png)
        grim -g "$GEOM" "$TMP"
        FILE=$(zenity --file-selection --save --confirm-overwrite \
            --title="Save screenshot as" \
            --filename="$DEFAULT_FILE" \
            --file-filter="PNG files | *.png" 2>/dev/null)
        if [ -z "$FILE" ]; then
            rm -f "$TMP"
            exit 0  # user cancelled
        fi
        [[ "$FILE" != *.png ]] && FILE="${FILE}.png"
        mv "$TMP" "$FILE"
        ;;
    *)
        echo "Usage: $0 {full|region|full-save-as|region-save-as}"
        exit 1
        ;;
esac

# Copy to clipboard and notify
if [ -f "$FILE" ]; then
    wl-copy --type image/png < "$FILE"
    notify-send "Screenshot Captured" "Saved to $FILE and copied to clipboard." -i "$FILE"
fi
