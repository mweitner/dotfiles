# Logitech Bluetooth Keyboard and Mouse Pairing (Fedora + Sway)

This setup uses `bluetoothctl` directly so it works in TTY, Sway, and remote shell sessions.

## Quick Start

Open a terminal and run:

```bash
bluetoothctl
power on
agent on
default-agent
pairable on
discoverable on
scan on
```

Put the keyboard and mouse into pairing mode, then for each device MAC address:

```bash
pair XX:XX:XX:XX:XX:XX
trust XX:XX:XX:XX:XX:XX
connect XX:XX:XX:XX:XX:XX
```

Finish with:

```bash
scan off
quit
```

Verify:

```bash
bluetoothctl devices Connected
```

## Current Connected Devices (Home Office)

Recorded on `2026-03-23` from:

```bash
bluetoothctl devices Connected
```

Current devices:
- `DD:79:06:40:03:15` - `MX MCHNCL` (keyboard)
- `DB:C3:31:3F:76:9A` - `MX Master 3S` (mouse)

Quick reconnect commands:

```bash
bluetoothctl
connect DD:79:06:40:03:15
connect DB:C3:31:3F:76:9A
quit
```

## Preconditions

Check Bluetooth service and adapter status:

```bash
systemctl is-active bluetooth
systemctl is-enabled bluetooth
rfkill list
bluetoothctl list
```

Expected:
- service is `active` and `enabled`
- adapter appears as `hci0`
- Bluetooth is not soft/hard blocked

## Pairing Procedure (Detailed)

1. Start interactive controller:

```bash
bluetoothctl
```

2. Prepare the local adapter:

```bash
power on
agent on
default-agent
pairable on
discoverable on
```

3. Start scanning:

```bash
scan on
```

4. Put devices into pairing mode:
- Logitech keyboard: hold one Easy-Switch key (`1`, `2`, or `3`) for about 3 seconds until LED blinks rapidly.
- Logitech mouse: hold the pairing button until LED blinks rapidly.

5. In scan output, identify both device MAC addresses and run:

```bash
pair <keyboard-mac>
trust <keyboard-mac>
connect <keyboard-mac>

pair <mouse-mac>
trust <mouse-mac>
connect <mouse-mac>
```

6. Stop scan and leave:

```bash
scan off
quit
```

7. Verify final state:

```bash
bluetoothctl devices Connected
```

## PIN / Passkey Notes (Keyboard)

If BlueZ asks for confirmation or passkey entry:
- Type the shown digits on the Logitech keyboard.
- Press `Enter` on the Logitech keyboard.
- Accept prompt in `bluetoothctl` if requested.

## Reconnect After Reboot or Dock Change

Usually auto-connect works once the device is trusted.

Manual reconnect:

```bash
bluetoothctl
connect <device-mac>
quit
```

## Remove and Re-Pair (If Needed)

If pairing became stale:

```bash
bluetoothctl
remove <device-mac>
scan on
```

Then perform the standard `pair` -> `trust` -> `connect` sequence again.

## Troubleshooting

### Device never appears during scan

- Ensure device is really in pairing mode (fast blinking LED).
- Turn Bluetooth off/on once:

```bash
bluetoothctl
power off
power on
scan on
```

### Pair succeeds but connect fails

- Retry connect once.
- If still failing, remove and re-pair.

### Adapter is blocked

```bash
rfkill list
rfkill unblock bluetooth
```

### Service not running

```bash
sudo systemctl enable --now bluetooth
systemctl status bluetooth
```

### Useful live logs

```bash
journalctl -u bluetooth -f
```
