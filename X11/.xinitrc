#!/bin/sh

#
# Since using LightDM as a display manager, this file is not used anymore.
# However, it is still kept for reference and potential future use, when orignal light xserver
# session starting startx from within zsh/.zshrc is needed.
#
# Example call from within .zshrc:
#
# if [ "$(tty)" = "/dev/tty1" ]; then
#   echo "Starting i3 on $(tty) by startx"
#   pgrep i3 || exec startx "$XDG_CONFIG_HOME/X11/.xinitrc"
# fi
#
set -x # debugging on
exec > "$HOME/.xinitrc.log" 2>&1 # Redirect all output to log file

#
# Start gnome-keyring-daemon components
#
# This did not work, uncommented it
#eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
#export SSH_AUTH_SOCK
#export GPG_AGENT_INFO

echo "DISABLED at X11/.xinitrc --- Running graphical desktop commands ---"
#xrdb -merge "$HOME/.config/X11/.Xresources"
#urxvtd -o -q -f &
#udiskie -A &

echo "--- Executing i3 ---"
exec i3

# as of wiki.archlinux.org xinitrc
# mweitner however uncommented now because had not effect
#. /etc/X11/Xsession
