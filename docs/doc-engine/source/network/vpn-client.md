# VPN Client — GlobalProtect on Fedora

Liebherr LDC uses a GlobalProtect VPN gateway with SAML authentication.

On Ubuntu the `gpclient` wrapper from the `yuezk/globalprotect-openconnect` PPA provided
both a GUI and CLI. **That PPA is Ubuntu-only.** A Fedora COPR exists and is the
**recommended approach** — raw `openconnect` fails SAML auth with this Azure AD tenant.

- **Preferred:** `gpclient` from the `yuezk/globalprotect-openconnect` COPR (installed automatically by `install-fedora.sh`).
- **Fallback:** `openconnect` directly (standard Fedora repos, version 9.12+, `--protocol=gp` since v8).
- `vpn-on` detects whichever is installed and uses the preferred backend automatically.

---

## Recommended: openconnect CLI

### Install

```bash
sudo dnf install -y openconnect vpnc-script
```

### Connect (Recommended)

```bash
vpn-on lis01.vpn.liebherr.com
```

`vpn-on` performs:

1. user-space SAML login (`openconnect --authenticate` with browser)
2. privileged tunnel setup (`sudo openconnect --cookie-on-stdin`)

This avoids common SAML failures from running the full login flow under `sudo`.

Equivalent to the Ubuntu `gpclient connect lis01.vpn.liebherr.com --hip` command.

- SAML/browser-based authentication: a browser window pops up automatically.
- HIP report (Host Information Profile): included by default in `--protocol=gp`.

### Disconnect

```bash
# Send SIGINT to the running openconnect process
sudo pkill -SIGINT openconnect
```

---

## Certificate Installation

Liebherr requires two internal CA certificates to be trusted.

Required certificates:

- `LiebherrEnterpriseCA02.crt`
- `LiebherrRootCA2.crt`

Install them into the system trust store (Fedora path differs from Ubuntu):

```bash
sudo cp LiebherrEnterpriseCA02.crt /etc/pki/ca-trust/source/anchors/
sudo cp LiebherrRootCA2.crt       /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
```

> On Ubuntu the command is `update-ca-certificates` and the path is
> `/usr/local/share/ca-certificates/`.  On Fedora use `update-ca-trust` and
> `/etc/pki/ca-trust/source/anchors/`.

Also import the certificates into Firefox and Chrome via their built-in
certificate manager (Settings → Privacy & Security → Certificates).

---

## Preferred: gpclient via COPR (yuezk)

The same author who maintains the Ubuntu PPA (`yuezk`) also provides a Fedora COPR.
**`install-fedora.sh` enables this COPR and installs `globalprotect-openconnect` automatically** during Phase 1 (packages). Manual install if needed:

```bash
sudo dnf copr enable yuezk/globalprotect-openconnect
sudo dnf install -y globalprotect-openconnect
```

This installs `gpclient` (CLI) and — when no license is required — the GUI.

> **Important:** since v8.20 the GUI requires a license.
> CLI-only usage via `gpclient connect` or raw `openconnect` does not require a license.

With COPR installed, `vpn-on` will automatically prefer `gpclient`:

```bash
vpn-on lis01.vpn.liebherr.com
# equivalent to: sudo gpclient connect lis01.vpn.liebherr.com --hip
```

Confirmed working on Fedora 43 with `gpclient` v2.5.1 (`globalprotect-openconnect` package).
Successful connection log excerpt:

```text
[INFO  gpclient::connect] Connecting to the only available gateway: lis01.vpn.liebherr.com
[INFO  openconnect::ffi] HIP report submitted successfully.
[INFO  gpclient::connect] Wrote PID … to /var/run/gpclient.lock
```

---

## Sway Scratchpad Integration

As VPN control is frequently toggled, wire it to a scratchpad binding.

Add a scratchpad toggle for the VPN connection terminal in `sway/config`:

```
bindsym $mod+v exec foot --app-id vpn-float -e $HOME/.local/bin/vpn-on lis01.vpn.liebherr.com
for_window [app_id="vpn-float"] floating enable
for_window [app_id="vpn-float"] resize set 900 500
for_window [app_id="vpn-float"] move position center
for_window [app_id="vpn-float"] border none
```

---

## Troubleshooting

### SAML / browser window does not appear

```bash
sudo openconnect --protocol=gp --useragent="AnyConnect" lis01.vpn.liebherr.com
```

If you see:

```text
When SAML authentication is complete, specify destination form field ...
Failed to parse XML server response
```

then use the split auth/tunnel workflow via `vpn-on` (or run `openconnect --authenticate` as normal user first).

If you still see:

```text
When SAML authentication is complete, specify destination form field ...
Failed to parse XML server response
Failed to complete authentication
```

this is typically an Azure AD SAML form parsing mismatch in raw `openconnect`.
For this tenant, use `gpclient` (yuezk COPR) and keep `--hip`:

```bash
sudo dnf copr enable yuezk/globalprotect-openconnect
sudo dnf install -y globalprotect-openconnect
vpn-on lis01.vpn.liebherr.com
```

`vpn-on` automatically prefers `gpclient` when available.

Force a specific browser for SAML if needed:

```bash
sudo openconnect --protocol=gp --browser=firefox lis01.vpn.liebherr.com
```

### Status 512 / Invalid credentials

Clean any cached session state:

```bash
sudo openconnect --protocol=gp --no-cookiejar lis01.vpn.liebherr.com
```

### Docker network conflicts

Docker bridge networks can conflict with VPN-assigned routes.
Stop Docker before connecting if you see missing routes to internal hosts:

```bash
sudo systemctl stop docker
sudo openconnect --protocol=gp lis01.vpn.liebherr.com
# restart Docker after disconnecting
sudo systemctl start docker
```

### HIP report warning

`--protocol=gp` sends the HIP report automatically.
If the gateway still blocks internal routes, force explicit HIP:

```bash
sudo openconnect --protocol=gp --hip-report lis01.vpn.liebherr.com
```

---

## Migration Notes from Ubuntu

| Ubuntu (gpclient PPA)                        | Fedora equivalent                                      |
|----------------------------------------------|--------------------------------------------------------|
| `sudo apt install globalprotect-openconnect` | `sudo dnf copr enable yuezk/globalprotect-openconnect && sudo dnf install -y globalprotect-openconnect` (automated by `install-fedora.sh`) |
| `sudo gpclient connect HOST --hip`           | `vpn-on HOST` (prefers `gpclient` if installed, falls back to `openconnect`)  |
| `sudo update-ca-certificates`                | `sudo update-ca-trust`                                 |
| `/usr/local/share/ca-certificates/`          | `/etc/pki/ca-trust/source/anchors/`                    |
| GUI `gpclient` (PPA)                         | COPR `yuezk/globalprotect-openconnect` (license req.)  |
