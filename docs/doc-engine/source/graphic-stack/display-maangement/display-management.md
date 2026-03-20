# Display Management on Sway/Wayland

On your previous Ubuntu system, you used `xrandr` (X11) for multi-monitor management. This document covers the recommended Wayland-native approach for Fedora + Sway.

## Current Environment

**Hardware Setup:**
- Laptop display: `eDP-1` (1920×1080, built-in)
- External displays: two LDC monitors via docking station
- Configurations:
  - **Home office:** eDP-1 (right) + DP-1-1 (left, 1920×1200) + DP-1-2 (center, 1920×1200)
  - **Laptop only:** eDP-1 (single display)
  - **Ulm office:** eDP-1 (right) + DP-1-1 (left, 1920×1200) + DP-1-2 (center, 1920×1200)

---

## Recommended: kanshi (Automatic Profile Switching)

**kanshi** is a daemon that automatically detects monitor hotplug events and applies saved profiles. Ideal for your docking station setup—it switches configurations automatically when you dock/undock.

### Install

```bash
sudo dnf install -y kanshi libnotify
```

Also add to Fedora installer Phase 1 packages.

### Configure

Create `~/.config/kanshi/config`:

```bash
mkdir -p ~/.config/kanshi
cat > ~/.config/kanshi/config << 'EOF'
# Laptop only (single display)
profile laptop-only {
  output eDP-1 enable mode 1920x1080@60Hz position 0 0 scale 1.25
}

# Home office docking: three displays
# Left: DP-1-1 (1920x1200)
# Center: DP-1-2 (1920x1200)
# Right: eDP-1 (1920x1080, scaled 1.25)
profile home-office {
  output eDP-1 enable mode 1920x1080@60Hz position 3840 120 scale 1.25
  output DP-1-1 enable mode 1920x1200@60Hz position 0 0
  output DP-1-2 enable mode 1920x1200@60Hz position 1920 0
  output HDMI-1 disable
  output DP-1 disable
  output DP-1-3 disable
}

# Ulm office docking (same physical layout as home, same resolutions)
profile ulm-office {
  output eDP-1 enable mode 1920x1080@60Hz position 3840 120 scale 1.25
  output DP-1-1 enable mode 1920x1200@60Hz position 0 0
  output DP-1-2 enable mode 1920x1200@60Hz position 1920 0
  output HDMI-1 disable
  output DP-1 disable
  output DP-1-3 disable
}
EOF
```

**Notes:**
- Positions are in pixels (cumulative left-to-right)
- Scale 1.25 for eDP-1 because it's HiDPI (HP ZBook)
- External monitors at 1:1 scale
- `disable` unused outputs to ensure clean state

### Enable and Start

```bash
systemctl --user enable kanshi
systemctl --user start kanshi
```

### Verify

Check kanshi is running and monitoring:

```bash
systemctl --user status kanshi
journalctl --user -u kanshi -f
```

When you dock/undock, journalctl will show profile switches. If nothing happens, manually trigger:

```bash
kanshctl switch-profile home-office
```

### Manual Profile Switching

If you want explicit control without relying on hotplug detection:

```bash
kanshctl switch-profile laptop-only
kanshctl switch-profile home-office
kanshctl switch-profile ulm-office
```

Or add bindings to `~/.config/sway/config`:

```sway
# Display profiles via kanshi
bindsym $mod+x mode "$mode_display"

set $mode_display \
      Displays \
      (l) laptop, (h) home-office, (u) ulm-office

mode "$mode_display" {
  bindsym l exec --no-startup-id kanshctl switch-profile laptop-only, mode "default"
  bindsym h exec --no-startup-id kanshctl switch-profile home-office, mode "default"
  bindsym u exec --no-startup-id kanshctl switch-profile ulm-office, mode "default"
  bindsym Return mode "default"
  bindsym Escape mode "default"
}
```

---

## Alternative: Wayland-Native Shell Scripts

If you prefer explicit scripts over kanshi daemon, create Wayland-native versions using `swaymsg output`:

### Example: `~/.local/bin/monitor-home-office`

```bash
#!/usr/bin/env bash
set -euo pipefail

swaymsg output eDP-1 mode 1920x1080@60Hz position 3840 120 scale 1.25
swaymsg output DP-1-1 mode 1920x1200@60Hz position 0 0
swaymsg output DP-1-2 mode 1920x1200@60Hz position 1920 0
swaymsg output HDMI-1 disable
swaymsg output DP-1 disable
swaymsg output DP-1-3 disable
```

**Advantages:**
- No daemon needed
- Direct control via Sway IPC
- Works alongside kanshi

**Disadvantages:**
- Manual triggering needed (no auto-detection)
- Requires explicit script for each location

### Example: `~/.local/bin/monitor-laptop-only`

```bash
#!/usr/bin/env bash
set -euo pipefail

swaymsg output eDP-1 mode 1920x1080@60Hz position 0 0 scale 1.25
swaymsg output DP-1-1 disable
swaymsg output DP-1-2 disable
swaymsg output HDMI-1 disable
swaymsg output DP-1 disable
swaymsg output DP-1-3 disable
```

Then use in Sway keybindings as alternative to kanshi:

```sway
bindsym $mod+x exec --no-startup-id ~/.local/bin/monitor-home-office
```

---

## Legacy: X11 xrandr Scripts (For Reference)

Your existing X11-based scripts still work in Sway via XWayland compatibility:

**Home office** (`~/.config/X11/monitor-ldc-homeoffice.sh`):
```bash
xrandr --output eDP-1 --primary --mode 1920x1080 --pos 3840x0 \
  --output DP-1-1 --mode 1920x1080 --pos 0x0 \
  --output DP-1-2 --mode 1920x1080 --pos 1920x0
```

These scripts still work but are not Wayland-native. Prefer kanshi or `swaymsg` for new setups.

---

## Troubleshooting

### Profiles not switching automatically

1. Check kanshi is running:
   ```bash
   systemctl --user status kanshi
   ```

2. Monitor hotplug detection:
   ```bash
   journalctl --user -u kanshi -f
   # Plug/unplug monitor, watch for detection
   ```

3. Manual trigger to test profile:
   ```bash
   kanshctl switch-profile home-office
   swaymsg -t get_outputs  # Verify output states
   ```

### Display positions or resolutions need adjustment

Query current outputs:

```bash
swaymsg -t get_outputs
```

Adjust `~/.config/kanshi/config` positions and refresh:

```bash
systemctl --user restart kanshi
```

### HiDPI scaling issues on eDP-1

Your laptop display (HP ZBook) uses `scale 1.25`. If text appears too large/small:

```bash
# Test in kanshi config or swaymsg:
swaymsg output eDP-1 scale 1.5
swaymsg output eDP-1 scale 1.0
```

Then update `~/.config/kanshi/config` with preferred value.

### Workspace or window positions reset after profile switch

Add to `~/.config/sway/config`:

```sway
# Sticky workspace to prevent jumping
workspace_auto_back_and_forth yes

# Preserve output assignments across profile switches
output * adaptive_sync on
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Start kanshi daemon | `systemctl --user start kanshi` |
| Stop kanshi daemon | `systemctl --user stop kanshi` |
| Check kanshi logs | `journalctl --user -u kanshi -f` |
| Switch to home-office | `kanshctl switch-profile home-office` |
| List available outputs | `swaymsg -t get_outputs` |
| Test mode on eDP-1 | `swaymsg output eDP-1 mode 1920x1080@60Hz` |
| Disable output | `swaymsg output DP-1-1 disable` |
| Manual script trigger | `~/.local/bin/monitor-home-office` |

---

## Summary

1. **Recommended:** Use **kanshi** for automatic profile switching on dock/undock.
2. **Setup:** Install, create `~/.config/kanshi/config` with your three profiles, enable daemon.
3. **Optional:** Add Sway keybindings for manual profile switching or scripts if you prefer explicit control.
4. **Fallback:** Existing X11 scripts still work but are not Wayland-native.

This gives you a modern, reproducible, and automatic display management workflow for your multi-location setup.
