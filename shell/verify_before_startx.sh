#!/bin/sh

echo "In TTY before startx:"
echo "DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS"
echo "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
echo "XDG_SESSION_TYPE=$XDG_SESSION_TYPE"
echo "XDG_SESSION_DESKTOP=$XDG_SESSION_DESKTOP"

# It is ok to see Type=tty for tty session.
loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}' | head -n 1) -p Type -p LbEnabled -p LbCloned
