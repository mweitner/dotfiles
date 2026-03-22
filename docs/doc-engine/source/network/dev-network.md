# ldh-ldc - Dev Network

Details setup of the development network. Example is my current ldc development laptop.

Details about NetworkManager:

* [Setup Network Manager](/doc/4fda1cec-ace9-48f7-a52d-0a6ff210c410)

# Create Machine Network Profile

Create a machine network profile for each machine network:


:::info
Each profile is prefixed with "Machine-" and suffixed with its use case like "-TU" for telematic unit use case.

:::

| Name | IP Range | Gateway | dev-pc asTU (Telematic Unit) | dev-pc asgateway |
|------|----------|---------|------------------------------|------------------|
| crane-rope-testrig | 192.168.32/16 | 192.168.32.1 | tu1:* 192.168.32.150/23 <br> * 169.254.1.41/16 | 192.168.32.1     |
| concrete-mixing-plant | 192.168.5/24 | 192.168.5.120 | tu1:* 192.168.5.211/24 <br> * 169.254.1.211/16tu2:* 192.168.5.212/24 <br> * 169.254.1.212/16 | 192.168.5.120    |
| mining-excavator | 192.168.3/24 | 192.168.3.1 | tu1:* 192.168.3.101/24 <br> * 169.254.1.41/16tu2:* 192.168.3.102/24 <br> * 169.254.1.42/16tu3:* 192.168.3.103/24 <br> * 169.254.1.43/16tu4:* 192.168.3.104/24 <br> * 169.254.1.44/16 | 192.168.3.1      |

# Multi-Adapter Setup

Multi-Adapter Setup: Persistent and Flexible Networking

This documentation summarizes the configuration strategy used to isolate main network connectivity (docking station/Wi-Fi) from specialized static machine network setups (reusable USB-to-Ethernet adapter). The core fix involved using **MAC address binding** to prevent profile conflicts.

## 1. ⚙️ Interface and MAC Address Bindings

The key to stability is strictly binding each connection profile to its respective physical hardware via its MAC address.

On Fedora, USB2Ethernet adapters may appear as `enp...` (for example `enp0s20f0u2u3`) instead of `enx...`.
This is expected with predictable interface names and does not matter when profiles are MAC-bound.

| **Device Name** | **Connection Use** | **MAC Address** | **Bound Profile(s)** |
|-------------|----------------|-------------|------------------|
| `**enxf4ee08caae80**` | Docking Station / Main Network | `**F4:EE:08:CA:AE:80**` | `Wired connection 1` |
| `**enx00e04cb828b5**` | Reusable USB Adapter / Field Work | `**00:E0:4C:B8:28:B5**` | **All** `**Machine-\***` **profiles** |

### Permanent Fix Commands:

The following commands enforced the separation and cleared the persistent IP conflict on the docking station:

```javascript
# 1. Clear the persistent static IP from the docking station profile
sudo nmcli connection modify "Wired connection 1" ipv4.addresses ""

# 2. Bind Docking Station to its MAC and remove gateway
sudo nmcli connection modify "Wired connection 1" \
    802-3-ethernet.mac-address F4:EE:08:CA:AE:80 \
    ipv4.method auto \
    ipv4.gateway ""

# 3. Create/update all Machine-* profiles and bind them to the USB adapter MAC
cd ~/dotfiles
./shell/setup-machine-network-profiles.sh --usb-mac 00:E0:4C:B8:28:B5
```

You can safely rerun this script after adding a new profile or changing addresses.


---

## 2. 🏠 Main Network (Office/Home) Configuration

When connected via the docking station (`enxf4ee08caae80`), the setup prioritizes Wi-Fi for general routing:

* `**HAUDEV**` **(Wi-Fi):** Provides the **primary default route** for internet access (metric 600).
* `**Wired connection 1**` **(Docking):** Connects via **DHCP**, but is configured with `ipv4.gateway ""` to **prevent it from setting a conflicting default route**. It is only used for local LAN access.

**Verification (Expected Output):** The docking station adapter should only show the DHCP IP (e.g., `10.146.72.26/23`) and **no static 192.168.x.x addresses**.


---

## 3. 🏭 Field Work (Machine Network) Configuration

For field work, you switch the reusable USB adapter between roles (Gateway or TU) using `**nmtui**`. All `Machine-*` profiles are set to `**autoconnect no**` and use `**ipv4.method manual**` (static) configuration.

### A. Profile Examples:

| **Profile Name** | **IP Configuration** | **Role** |
|--------------|------------------|------|
| `**Machine-concrete-mixing-plant-GW**` | Single static IP (`192.168.5.211/24`) and Gateway (`192.168.5.120`). | Dev-PC acts as a single access point. |
| `**Machine-mining-excavator-TU**` | Multiple static IPs (`192.168.3.x/24` and `169.254.x.x/16`) and Gateway (`192.168.3.1`). | Dev-PC acts as a complex Telematic Unit. |

### B. Activation Procedure:


1. Plug in the reusable USB adapter (it may be named `enx...` or `enp...` depending on udev naming).
2. Launch the text UI: `nmtui`
3. Select **"Activate a connection"**.
4. Choose the required profile (e.g., `**Machine-mining-excavator-TU**`) and press `<Activate>`.
5. This action automatically deactivates any other `Machine-*` profile and applies the correct static IPs and gateway to the USB adapter.


\