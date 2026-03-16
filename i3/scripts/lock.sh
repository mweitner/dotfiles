#!/bin/sh

set -eu

img="/tmp/lockscreen-${USER}.png"

# Prefer native Wayland capture/lock under Sway, keep X11 fallback.
if command -v grim >/dev/null 2>&1 && command -v swaylock >/dev/null 2>&1; then
	grim "$img"
	convert "$img" -scale 10% -scale 1000% "$img"
	swaylock -i "$img"
elif command -v scrot >/dev/null 2>&1 && command -v i3lock >/dev/null 2>&1; then
	scrot -o "$img"
	convert "$img" -scale 10% -scale 1000% "$img"
	i3lock -u -i "$img"
else
	echo "No supported lock stack found (need grim+swaylock or scrot+i3lock)." >&2
	exit 1
fi
