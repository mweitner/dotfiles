#!/bin/sh

set -eu

img="/tmp/lockscreen-${USER}.png"

blur_image() {
	# Prefer ImageMagick v7 entrypoint, fallback to legacy convert.
	if command -v magick >/dev/null 2>&1; then
		magick "$1" -scale 10% -scale 1000% "$1"
	elif command -v convert >/dev/null 2>&1; then
		convert "$1" -scale 10% -scale 1000% "$1"
	else
		echo "No ImageMagick tool found (magick/convert). Locking without blur." >&2
	fi
}

# Prefer native Wayland capture/lock under Sway, keep X11 fallback.
if command -v grim >/dev/null 2>&1 && command -v swaylock >/dev/null 2>&1; then
	grim "$img"
	blur_image "$img"
	swaylock -i "$img"
elif command -v scrot >/dev/null 2>&1 && command -v i3lock >/dev/null 2>&1; then
	scrot -o "$img"
	blur_image "$img"
	i3lock -u -i "$img"
else
	echo "No supported lock stack found (need grim+swaylock or scrot+i3lock)." >&2
	exit 1
fi
