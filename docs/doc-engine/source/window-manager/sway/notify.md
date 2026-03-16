# Notifications on Sway (Wayland)

## Why mako?

- `mako` is the Wayland-native notification daemon for Sway (and other wlroots compositors).
- `dunst` is for X11 and does not integrate natively with Sway/Wayland.
- `notify-send` works out of the box with mako.

## Install

```bash
sudo dnf install -y mako
```

## Configure Sway

Add to your `~/.config/sway/config`:

```sh
exec mako
```

## Configure mako

Edit `~/.config/mako/config` (symlinked from your dotfiles):

```ini
font=monospace 11
background-color=#222222E6
text-color=#FFFFFF
border-color=#666666
border-size=2
padding=8
margin=10
anchor=top-right
max-visible=5
default-timeout=5000
```

## Usage

Send a test notification:

```bash
notify-send "Hello from mako!"
```

## References
- https://github.com/emersion/mako
- https://man.sr.ht/~emersion/mako/
