# USB Ethernet Adapter Management

This guide covers setup of multiple USB2Ethernet adapters (typically Realtek r8152) for machine-network connectivity.

## Quick Start

List registered adapters:
```bash
setup-adapters --list-adapters
```

Assign all machine profiles to adapter-c:
```bash
setup-adapters --adapter c
```

Assign different adapters per machine group:
```bash
setup-adapters --group crane=a --group concrete=b --group mining=c --group lpo=c
```

## Background: Why Multiple Adapters?

Your machine-network use cases (crane, concrete, mining, LPO) often involve simultaneous connections to incompatible networks. Without isolation, DHCP and routing would conflict. Multiple USB Ethernet adapters solve this by providing independent IP stacks per network:

- `adapter-a`: Machine network A (crane testrig)
- `adapter-b`: Machine network B (concrete mixing plant)
- `adapter-c`: Machine network C (mining excavator, LPO battery-trailer)

Each adapter can have its own NetworkManager profile with fixed IP, routes, and never-default policy.

## Adapter Registry

Current adapters (auto-detected MAC → preferred name):

| Name | MAC | Interface | Device |
|------|-----|-----------|--------|
| adapter-a | `00:E0:4C:B8:28:B5` | enx00e04cb828b5 | Realtek r8152 |
| adapter-b | `00:E0:4C:68:05:C8` | enx00e04c6805c8 | Realtek r8152 |
| adapter-c | `3C:49:37:05:47:46` | enx3c4937054746 | Realtek r8152 |

**Note:** Interface names are derived from MAC addresses via udev policy (`10-usb-ethernet-enx.link`) applied at first boot by `install-fedora.sh`.

## Network Profile Groups

Profiles are organized into four groups:

- **crane**: Machine-crane-rope-testrig-GW, Machine-crane-rope-testrig-TU
- **concrete**: Machine-concrete-mixing-plant-GW, Machine-concrete-mixing-plant-TU
- **mining**: Machine-mining-excavator-GW, Machine-mining-excavator-TU
- **lpo**: Machine-lpo-CSM, Machine-lpo-CSM-GW, Machine-lpo-dc5

Each profile specifies fixed IP(s), gateway, and never-default routing policy.

## Usage Examples

### All profiles on adapter-a (default)
```bash
setup-adapters --adapter a
```

### Per-group assignment
```bash
setup-adapters \
  --group crane=a \
  --group concrete=b \
  --group mining=c \
  --group lpo=c
```

### Mixed: most on adapter-a, one specific on adapter-b
```bash
setup-adapters \
  --adapter a \
  --profile Machine-lpo-dc5=b
```

### Preview changes without applying
```bash
setup-adapters --adapter c --dry-run
```

### Get help
```bash
setup-adapters --help
```

## Workflow

1. Plug in adapters (they auto-enumerate as enx<mac> by default).
2. Determine which adapter to use for which machine network.
3. Run `setup-adapters` with desired mapping:
   ```bash
   setup-adapters --group lpo=c --group mining=b
   ```
4. Run `nmcli connection show | grep '^Machine-'` to list created profiles.
5. Activate profile manually:
   ```bash
   nmcli connection up Machine-lpo-dc5
   ```
   Or set `autoconnect=yes` if the adapter is always connected in that environment.

## Troubleshooting

### Adapter not showing in `setup-adapters --list-adapters`

- Verify adapter is plugged in: `ip -br link | grep enx`
- Check dmesg for r8152 driver load: `dmesg | grep r8152`
- If adapter shows but with different MAC, update the registry in `~/.local/bin/setup-adapters` or use `setup-machine-network-profiles` directly with `--usb-mac <MAC>`.

### Profile not connecting

- Check NetworkManager status: `nmcli connection show Machine-lpo-dc5`
- Verify adapter is UP: `ip -br link | grep enx3c4937054746`
- Check DHCP or static IP config in the profile: `nmcli connection show Machine-lpo-dc5 | grep ipv4`
- View NetworkManager logs: `journalctl -u NetworkManager -f`

### Profile bound to wrong adapter

- List all profiles: `nmcli connection show | grep -i machine`
- Show profile details: `nmcli connection show Machine-lpo-dc5 | grep mac-address`
- Re-assign by running `setup-adapters` again with the correct mapping.

## Advanced: Manual Profile Creation

If you prefer to not use adapter names, you can create profiles directly with `setup-machine-network-profiles`:

```bash
setup-machine-network-profiles \
  --usb-mac 3C:49:37:05:47:46 \
  --group-mac lpo=00:E0:4C:68:05:C8
```

See `setup-machine-network-profiles --help` for all options.

## Installing New Adapters

If you add USB adapters later:

1. Plug in the adapter and identify its MAC in `ip -br link | grep enx`.
2. Edit `~/.local/bin/setup-adapters` and add a new entry to the `ADAPTERS` array:
   ```bash
   [d]="XX:XX:XX:XX:XX:XX"
   ```
3. Run `setup-adapters --list-adapters` to confirm.
4. Use the new adapter-d in your setup commands.

Alternatively, keep the adapter registry in `~/dotfiles/shell/setup-adapters.sh` and re-run `install-fedora.sh Phase 2` to re-symlink.
