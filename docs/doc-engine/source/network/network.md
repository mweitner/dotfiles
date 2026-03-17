# Network Setup (Fedora)

Recommended setup for this dotfiles environment on Fedora:

- Use `NetworkManager` for all network orchestration (Ethernet, Wi-Fi, VPN).
- Use `iwd` as the Wi-Fi backend for NetworkManager.
- Use terminal tools daily: `nmcli` and `nmtui`.
- Optionally use `nm-applet` for lightweight tray GUI access.

This matches a terminal-first workflow and keeps configuration reproducible.

## Current State Note

If `wpa_supplicant.service` is running as a standalone service, disable it before switching to `iwd` backend.

Example observed state:

```text
systemctl status wpa_supplicant.service
Active: active (running)
```

## Install Required Packages

```bash
sudo dnf install -y NetworkManager iwd xdg-utils \
	network-manager-applet nm-connection-editor
```

Compatibility note: some Fedora releases still provide `NetworkManager-gnome` as a meta package.

## Enable Core Services

```bash
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now iwd
```

## Configure NetworkManager to Use iwd

Create `/etc/NetworkManager/conf.d/10-wifi-backend.conf`:

```ini
[device]
wifi.backend=iwd
```

Commands:

```bash
sudo mkdir -p /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/10-wifi-backend.conf >/dev/null <<'EOF'
[device]
wifi.backend=iwd
EOF
```

## Migrate from Standalone wpa_supplicant

When `wpa_supplicant.service` is active, stop and disable it to avoid competing Wi-Fi management.

```bash
sudo systemctl stop wpa_supplicant.service
sudo systemctl disable wpa_supplicant.service
```

Optional hard block (prevents accidental manual starts):

```bash
sudo systemctl mask wpa_supplicant.service
```

Then restart NetworkManager:

```bash
sudo systemctl restart NetworkManager
```

## Verify Backend and Device State

```bash
nmcli general status
nmcli device status
nmcli radio wifi
```

Quick backend check in logs:

```bash
journalctl -u NetworkManager -b | grep -Ei 'iwd|wpa_supplicant'
```

Expected outcome:

- Wi-Fi is managed by NetworkManager via `iwd` backend.
- `wpa_supplicant.service` is inactive/disabled (or masked).

## Daily Operations (CLI/TUI)

Scan networks:

```bash
nmcli device wifi rescan
nmcli device wifi list
```

Connect to Wi-Fi:

```bash
nmcli device wifi connect "SSID" password "PASSWORD"
```

Edit and manage connections via TUI:

```bash
nmtui
```

## Optional GUI Layer (`nm-applet`)

For occasional point-and-click network actions, use NetworkManager's tray applet:

- `nm-applet` runs in the tray (Waybar `tray` module).
- `nm-connection-editor` provides full GUI connection editing.

This setup keeps terminal-first workflow while offering a lightweight GUI fallback.

### Waybar Integration

The Waybar `network` module can open NetworkManager UI on click:

- Left click: open `nm-connection-editor` (floating window in Sway).
- Right click: open `nmtui` via dedicated Sway scratchpad toggle script.
- Fallback for left click (if GUI editor missing): same `nmtui` scratchpad toggle.

### `nmtui` Scratchpad Behavior

- `nmtui` uses a dedicated Foot title (`nmtui-float`) with Sway rules.
- `nmtui` is launched with dedicated Foot `app_id`/title (`nmtui-float`) for reliable matching.
- Window is always floating, centered, and resized larger (`1400x1000`) to avoid truncated dialogs.
- In fish, running `nmtui` directly also routes to the scratchpad toggle when running under Sway.
- A wrapper script is linked to `~/.local/bin/nmtui`, so launcher-based invocations (for example `wofi --show run`) also use the same scratchpad flow.
- Dedicated shortcut: `$mod+Shift+n` opens/toggles the `nmtui` scratchpad directly.

## Notes

- Do not use `iwctl` for regular connection management when NetworkManager is controlling Wi-Fi.
- Keep `wpa_supplicant` package installed if needed by dependencies; only the standalone service should stay disabled.
- Recommended default in this repo: `nmcli` + `nmtui`; use `nm-applet` as optional convenience.

## Troubleshooting: `iwctl` Segmentation Fault

Observed on Fedora (`iwd-3.11-1.fc43`):

```text
iwctl
Waiting for IWD to start...
... terminated by signal SIGSEGV
```

This is an `iwctl` client crash (userspace) and not necessarily an `iwd` daemon failure.
`iwd.service` can still be healthy while `iwctl` crashes.

Check service health:

```bash
systemctl status iwd.service
journalctl -u iwd -b --no-pager | tail -n 80
```

Check crash evidence:

```bash
coredumpctl list iwctl
coredumpctl info iwctl
```

Recommended workflow on this setup:

- Continue using `NetworkManager` with `iwd` backend.
- Use `nmcli` / `nmtui` for connection management.
- Avoid `iwctl` until Fedora ships a fixed build.

Optional update check:

```bash
dnf check-update iwd readline libell
```

If the issue persists on latest packages, file/report with:

- `rpm -q iwd readline libell`
- `coredumpctl info iwctl`
- `journalctl -u iwd -b`
