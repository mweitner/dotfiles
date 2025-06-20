#!/bin/sh

echo "In i3 terminal:"
echo "DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS"
echo "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
echo "XDG_SESSION_TYPE=$XDG_SESSION_TYPE"
echo "XDG_SESSION_DESKTOP=$XDG_SESSION_DESKTOP"
echo "SSH_AUTH_SOCK=$SSH_AUTH_SOCK"
echo "GPG_AGENT_INFO=$GPG_AGENT_INFO"

# We want to see Type=x11 for your graphical session.
loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}' | head -n 1) -p Type -p LbEnabled -p LbCloned
