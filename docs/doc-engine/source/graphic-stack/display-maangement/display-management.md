# Display Management on Sway/Wayland

This setup uses Wayland-native tools (`kanshi` and `swaymsg`) instead of X11 `xrandr`.

## Current Working Layout (Dell WD19TB)

Hardware:
- Laptop: HP ZBook Power G11
- Dock: Dell WD19TB (Thunderbolt)
- External monitors: 2x Samsung U28E850 (4K)

Output mapping in Sway:
- `DP-7` = left external monitor
- `DP-6` = center external monitor
- `eDP-1` = laptop panel on the right

Active profile values:
- `DP-7`: `3840x2160@30Hz`, `scale 2`, `position 0,0`
- `DP-6`: `3840x2160@60Hz`, `scale 2`, `position 1920,0`
- `eDP-1`: `2560x1600@120Hz`, `scale 1.25`, `position 3840,0`

Logical geometry:
- 4K at scale 2 gives `1920x1080` logical size for each external display
- Desktop order: `[DP-7 left] [DP-6 center] [eDP-1 right]`

## Why Not xrandr

`xrandr` configures X11 outputs. In Sway/Wayland, use:
- `kanshi` for auto profile switching (dock/undock)
- `swaymsg output ...` for manual immediate changes

## Recommended Workflow

1. Keep canonical profiles in `~/.config/kanshi/config`
2. Keep manual overrides in `~/.local/bin/monitor-*`
3. Trigger scripts via Sway mode bindings when needed
4. Let kanshi auto-switch on hotplug

## Useful Commands

Show current outputs:
```bash
swaymsg -t get_outputs
```

Apply home-office layout:
```bash
~/.local/bin/monitor-home-office
```

Apply laptop-only layout:
```bash
~/.local/bin/monitor-laptop-only
```

Switch kanshi profile directly:
```bash
kanshctl switch-profile home-office
kanshctl switch-profile laptop-only
kanshctl switch-profile ulm-office
```

## UI Alternative

There is no direct RandR GUI equivalent on Wayland, but `wdisplays` is a practical visual arranger:

```bash
sudo dnf install -y wdisplays
wdisplays
```

Notes:
- `wdisplays` applies layout live
- It does not persist kanshi config automatically
- After arranging visually, copy final positions back into kanshi/scripts

## Troubleshooting

### Left and center monitors swapped

If cursor crossing does not match physical order, swap `DP-6` and `DP-7` positions in:
- `~/.config/kanshi/config`
- `~/.local/bin/monitor-home-office`
- `~/.local/bin/monitor-ulm-office`

Current correct order is:
- `DP-7` at `position 0,0`
- `DP-6` at `position 1920,0`

### One 4K monitor only runs at 30Hz

If only `3840x2160@30Hz` is available, it is usually a cable/port bandwidth limit.

Options:
- Keep 4K@30Hz (max detail)
- Use `2560x1440@60Hz` (smoother motion)
- Move cable/port on dock or use better cable to recover 4K@60Hz

### Kanshi does not switch automatically

```bash
systemctl --user status kanshi
journalctl --user -u kanshi -f
```

Force profile for testing:
```bash
kanshctl switch-profile home-office
```
