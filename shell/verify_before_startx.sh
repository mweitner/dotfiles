#!/bin/sh

echo "In TTY before startx:"
echo "DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS"
echo "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
echo "XDG_SESSION_TYPE=$XDG_SESSION_TYPE"
echo "XDG_SESSION_DESKTOP=$XDG_SESSION_DESKTOP"

# It is ok to see Type=tty for tty session.
session_id=$(loginctl | awk -v user="$(whoami)" '$3 == user { print $1; exit }')
if [ -n "${session_id}" ]; then
	loginctl show-session "${session_id}" -p Type -p LbEnabled -p LbCloned
fi
