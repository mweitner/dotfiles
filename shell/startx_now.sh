#!/bin/sh

echo "Starting i3 on $(tty)"
if ! pgrep i3 >/dev/null 2>&1; then
    exec startx "$XDG_CONFIG_HOME/X11/.xinitrc"
fi
echo "i3 started successfully on $(tty)"

echo "Expecting to see gnome-keyring password prompt"
echo "If you do not see it, please check your gnome-keyring configuration."
