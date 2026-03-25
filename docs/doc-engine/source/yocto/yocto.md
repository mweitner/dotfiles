# Yocto Build Environment

Embedded Linux Development > Yocto Project

This guide covers the reproducible Yocto build environment setup for Liebherr LPO/LLP/DPS embedded display projects.

## Overview

The Yocto build environment supports multiple distro projects:

- **meta-liebherr-lpo-display**: LPO display firmware (imx6q-display5 target)
- **meta-liebherr-llp**: LLP variant builds
- **meta-liebherr-dps**: DPS variant builds

## Key Architecture

```
~/lpo-dev/linux-lpo/                    # Yocto workspace root
├── layers/poky/                        # Core Poky distribution
├── layers/meta-imx/                    # i.MX BSP layer
└── build/lpo/                          # Build artifacts (auto-created)

/opt/yocto/shared/                      # Shared resources across all Yocto projects
├── downloads/                          # BitBake source cache (resumable, checked)
└── sstate-cache/                       # Shared state cache

/opt/yocto/keys/                        # Project-specific secrets (symlinked from dotfiles)
├── lpo/mosquitto-psk.txt               # PSK credentials
├── lpo/sota-auth.txt                   # SOTA authentication
└── lpo/datastation-privatekey.pem      # E2E crypto key
```

## Quick Start

### 1. Initial Setup

```bash
bash ~/dotfiles/install-fedora.sh
```

This creates the `/opt/yocto/keys/` symlinks automatically, pointing to `~/dotfiles/.secrets/yocto/keys/`.

### 2. Initialize Build Environment

```bash
cd ~/lpo-dev/linux-lpo
TOPDIR="$(pwd)" OEROOT="${TOPDIR}/layers/poky" \
  source ~/.local/bin/llp_init_build.sh meta-liebherr-lpo-display
```

This:
- Initializes `build/lpo/` with correct `local.conf` and `bblayers.conf`
- Exports all required secret file environment variables
- Configures Yocto mirror preferences for reliable downloads
- Enables fail-fast validation for missing critical files

### 3. Run Build

```bash
bitbake lpo-display-image
```

## Key Features

### Secure Secret Management

All project credentials (Mosquitto PSK, private keys, auth tokens) are stored in `dotfiles/.secrets/` and symlinked to `/opt/yocto/keys/` via the install script. The build environment automatically detects and exports these files.

See [Secrets Management](./secrets-management.md) for details.

### Resilient Download Handling

Yocto builds download large source artifacts that may fail mid-transfer on unstable networks. Two helper tools mitigate this:

- **`yocto-prefetch-source`**: Generic resumable download with SHA256 verification
- **`yocto-prefetch-recipe-source`**: Recipe-aware wrapper that automatically extracts URLs and checksums

See [Build Environment & Helpers](./build-environment.md) for usage.

### Mirror Preference Configuration

The build system is configured to prefer the Yocto HTTPS mirror over upstream SourceForge, reducing failure rates:

```
INHERIT += "own-mirrors"
SOURCE_MIRROR_URL = "https://downloads.yoctoproject.org/mirror/sources/"
```

If a download still fails after prefetch, the build will automatically retry from upstream mirrors.

## Troubleshooting

### Missing Mosquitto PSK File

**Error**: `cat: /opt/yocto/keys/lpo/mosquitto-psk.txt: No such file or directory`

**Solution**: 
1. Ensure the file exists in `~/.secrets/yocto/keys/lpo/mosquitto-psk.txt`
2. Re-run `bash ~/dotfiles/install-fedora.sh` to recreate symlinks
3. Verify: `ls -la /opt/yocto/keys/lpo/`

### Source Download Failures (mid-transfer)

**Symptom**: Downloads consistently fail at ~2-3 MB with `errno=104` (connection reset)

**Solution**:
```bash
# Prefetch the recipe's sources with resumable downloads
yocto-prefetch-recipe-source --recipe meta/recipes-graphics/jpeg/libjpeg-turbo_3.0.1.bb

# Then re-run bitbake
bitbake lpo-display-image
```

See [Build Environment & Helpers](./build-environment.md) for advanced options.

### BitBake Environment Variable Not Passed

**Symptom**: Recipe sees unset `${MOSQUITTO_PSK_FILE}` or other exported variables

**Cause**: Variable not in `BB_ENV_PASSTHROUGH_ADDITIONS`

**Solution**: 
- Check `build/lpo/local.conf` for `BB_ENV_PASSTHROUGH_ADDITIONS` entry
- Manually add if missing: `export BB_ENV_PASSTHROUGH_ADDITIONS="... MOSQUITTO_PSK_FILE SOTA_AUTH_TOKEN ..."`
- Re-source the init script: `source ~/.local/bin/llp_init_build.sh meta-liebherr-lpo-display`

## Related Documentation

- [Secrets Management](./secrets-management.md) — Handling PSK files and private keys
- [Build Environment & Helpers](./build-environment.md) — Download helpers and configuration
