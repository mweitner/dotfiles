# Dell WD19TB Thunderbolt Dock

## Hardware

| Item | Detail |
|------|--------|
| Dock model | Dell WD19TB Thunderbolt Dock |
| Connection | Thunderbolt 3 (40 Gb/s, 2 lanes × 20 Gb/s) |
| Host laptop | HP ZBook Power G11 |
| Thunderbolt UUID | `c9030000-0060-640e-8318-d4272ec36925` |

## Critical: Use the Thunderbolt USB-C Port

The HP ZBook Power G11 has **two USB-C ports on the left side**. They are not equivalent:

- **First USB-C port** — regular USB 3.x only; displays work but **USB data (keyboard, mouse, ethernet) does not pass through**
- **Second USB-C port** — Thunderbolt 3; full dock functionality including USB passthrough

Always connect the WD19TB to the **second (rear) USB-C port** on the left side.

## Why Keyboard/Mouse Don't Work Without Authorization

Thunderbolt uses a security model where the OS must explicitly authorize a device before USB data tunnels are opened. DisplayPort tunnels are pre-auth (so external displays light up immediately), but USB devices behind the dock remain blocked until authorization.

Symptoms on an unauthorized dock:
- External monitors work
- Keyboard, mouse, ethernet do NOT enumerate (not visible in `lsusb` or `/dev/input/`)
- `cat /sys/bus/thunderbolt/devices/1-1/authorized` returns `0`

## Setup (Automated via install script)

`install-fedora.sh` handles this automatically:

1. Installs `bolt` (Thunderbolt device manager)
2. Starts `bolt` (socket/dbus-activated on Fedora)
3. Enrolls the WD19TB with `--policy auto` if the dock is connected at install time

To reproduce manually:

```bash
sudo dnf install -y bolt
sudo systemctl start bolt

# Authorize the dock for this session
sudo sh -c 'echo 1 > /sys/bus/thunderbolt/devices/1-1/authorized'

# Enroll permanently (auto-authorizes on every future connection)
sudo boltctl enroll --policy auto c9030000-0060-640e-8318-d4272ec36925
```

## Verify Dock is Enrolled

```bash
boltctl list
```

Expected output shows `policy: auto` and a `stored:` timestamp:

```
 ● Dell WD19TB Thunderbolt Dock
   ├─ uuid:       c9030000-0060-640e-8318-d4272ec36925
   ├─ status:     authorized
   ├─ authorized: ...
   └─ stored:     ...
      ├─ policy:  auto
      └─ key:     no
```

If `stored:` is absent, the dock is not enrolled and will block USB on next reboot.

## Verify USB Devices After Connection

```bash
lsusb | grep -v "Linux Foundation"
```

With the WD19TB authorized and peripherals connected, Bus 005 should show:

```
Bus 005 Device 004: ID 413c:b06e Dell Computer Corp. Dell dock
Bus 005 Device 005: ID 046a:0076 CHERRY MX-Board 3.0 G80-3850
Bus 005 Device 006: ID 046d:c069 Logitech, Inc. M-U0007 [Corded Mouse M500]
Bus 005 Device 007: ID 0bda:402e Realtek Semiconductor Corp. USB Audio
Bus 006 Device 004: ID 0bda:8153 Realtek Semiconductor Corp. RTL8153 Gigabit Ethernet Adapter
```

## Ethernet via Dock

The dock exposes three Realtek RTL8153 Gigabit Ethernet adapters (`r8152` driver). The primary one active on the home network:

```bash
ip link show enp0s20f0u2u3   # or check: ip link show | grep enp
```

NetworkManager should pick it up automatically once the dock is authorized. If DHCP doesn't trigger:

```bash
nmcli connection up "Wired connection 1" ifname enp0s20f0u2u3
```

## Display Outputs

With the WD19TB on the Thunderbolt port, Sway sees:

| Output | Source |
|--------|--------|
| `eDP-1` | Laptop built-in display |
| `DP-6` | Dock DisplayPort/HDMI output 1 |
| `DP-7` | Dock DisplayPort/HDMI output 2 |

Final working layout:
- Left: `DP-7` (`3840x2160@30Hz`, `scale 2`, `position 0,0`)
- Center: `DP-6` (`3840x2160@60Hz`, `scale 2`, `position 1920,0`)
- Right: `eDP-1` (`2560x1600@120Hz`, `scale 1.25`, `position 3840,0`)

Display profiles are managed by kanshi and helper scripts.
For visual rearrangement on Wayland, use `wdisplays` and then copy final coordinates into kanshi/scripts.

## Troubleshooting

**Displays work but keyboard/mouse don't:**
- Check `cat /sys/bus/thunderbolt/devices/1-1/authorized` — if `0`, authorize manually:
  ```bash
  sudo sh -c 'echo 1 > /sys/bus/thunderbolt/devices/1-1/authorized'
  ```
- Then re-enroll to make it permanent:
  ```bash
  sudo boltctl enroll --policy auto c9030000-0060-640e-8318-d4272ec36925
  ```

**Dock not detected at all (no `thunderbolt` entries in dmesg):**
- Verify cable is in the **second USB-C port** (Thunderbolt), not the first

**After reboot, USB devices missing again:**
- `boltctl list` — check `stored:` is present with `policy: auto`
- If missing, re-run install script with dock connected, or enroll manually as above

**Ethernet DHCP timeout:**
- Confirm dock is Thunderbolt-authorized first (`boltctl list`)
- Check interface name: `ip link show | grep enp0s20`
- Retry: `nmcli connection up "Wired connection 1" ifname <interface>`
