#!/bin/sh

echo "Starting i3 on $(tty)"
pgrep i3 || exec startx "$XDG_CONFIG_HOME/X11/.xinitrc"
if [ $? -ne 0 ]; then
    echo "Failed to start i3. Please check your configuration."
    exit 1
fi
echo "i3 started successfully on $(tty)"

echo "Expecting to see gnome-keyring password prompt"
echo "If you do not see it, please check your gnome-keyring configuration."
