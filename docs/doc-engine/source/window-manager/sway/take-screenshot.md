# Take Screenshot

On Wayland and Sway, `scrot` does not work because it relies on X11 protocols. The industry-standard replacement for
Sway is a combination of two tools:


1. `**grim**`: The tool that actually grabs the image (the "camera").
2. `**slurp**`: The tool that lets you select a region with your mouse (the "viewfinder").

## Install

```bash
sudo dnf install -y grim slurp wl-clipboard libnotify zenity
```

## Configure Sway

```sh
# Screenshots — quick save to ~/pictures/screenshots + clipboard
bindsym $mod+Shift+s exec ~/.config/sway/scripts/grimshot.sh region
bindsym $mod+Ctrl+s exec ~/.config/sway/scripts/grimshot.sh full
# Screenshots — pick save location via file dialog
bindsym $mod+Mod1+s exec ~/.config/sway/scripts/grimshot.sh region-save-as
bindsym $mod+Mod1+Ctrl+s exec ~/.config/sway/scripts/grimshot.sh full-save-as
```

All four bindings copy the result to the clipboard automatically, so you can immediately paste into Chromium, Slack,
or Jira without opening a file manager.

### Default save location

Quick-save screenshots land in `~/pictures/screenshots/screenshot_<timestamp>.png`.

### Choosing a custom save location

The `save-as` variants (`$mod+Alt+s` / `$mod+Alt+Ctrl+s`) capture first, then open a GTK file-save dialog
(via `zenity`) where you can navigate to any folder — useful when collecting screenshots for a specific ticket,
document, or fieldtest session.

## Design decision: why not the Print key?

The conventional Sway binding is `Print` (full) and `$mod+Print` (region). This was intentionally replaced with
`$mod+Shift+s` / `$mod+Ctrl+s` for the following reasons:

- **Logitech MX Mechanical keyboard**: this keyboard has no dedicated Print Screen key. The advertised substitute
  (`Fn+F7`) does not generate a `Print` keysym under Linux — it either produces nothing or a vendor-specific scancode
  that Sway does not map by default.
- **Muscle memory from Windows**: `Win+Shift+S` is the Microsoft Snipping Tool shortcut. Mirroring it with
  `$mod+Shift+s` means zero relearning cost when switching contexts.
- **Consistency**: using `$mod`-prefixed bindings keeps all custom shortcuts in one namespace and avoids relying on
  bare modifier-less keys that may conflict with application shortcuts.
