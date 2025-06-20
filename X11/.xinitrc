#!/bin/sh
set -x # debugging on
exec > "$HOME/.xinitrc.log" 2>&1 # Redirect all output to log file

# Start gnome-keyring-daemon components
eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
export SSH_AUTH_SOCK
export GPG_AGENT_INFO

echo "--- Running graphical desktop commands ---"
xrdb -merge "$HOME/.config/X11/.Xresources"
urxvtd -o -q -f &
udiskie -A &

echo "--- Executing i3 ---"
exec i3

# as of wiki.archlinux.org xinitrc
# mweitner however uncommented now because had not effect
#. /etc/X11/Xsession
