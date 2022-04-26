xrdb -merge "$HOME/.config/X11/.Xresources"
urxvtd -o -q -f
udiskie -A &
exec i3

# as of wiki.archlinux.org xinitrc
. /etc/X11/Xsession
