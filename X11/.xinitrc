xrdb -merge "$HOME/.config/X11/.Xresources"
urxvtd -o -q -f
udiskie -A &
exec i3

