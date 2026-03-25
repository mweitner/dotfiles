# Build Environment & Helpers

Embedded Linux Development > Yocto Project

This guide covers the build initialization script, mirror configuration, and the two helper utilities for resilient source downloads.

## Build Initialization Script

Location: `~/.local/bin/llp_init_build.sh`

### Purpose

Prepares the Yocto build environment for a specific distro layer by:
1. Sourcing `oe-init-build-env` from Poky
2. Detecting and exporting project secrets (PSK files, private keys)
3. Configuring BitBake environment variable passthrough
4. Injecting mirror preferences into `local.conf`
5. Validating critical files exist (fail-fast)

### Usage

```bash
cd ~/lpo-dev/linux-lpo
TOPDIR="$(pwd)" OEROOT="${TOPDIR}/layers/poky" \
  source ~/.local/bin/llp_init_build.sh meta-liebherr-lpo-display
```

**Parameters**:
- `TOPDIR`: Working directory (must export before sourcing)
- `OEROOT`: Path to Poky distribution (must export before sourcing)
- ARG#1: Distro layer name (e.g., `meta-liebherr-lpo-display`)

### What It Configures

#### Secret File Exports

```bash
# Detected and exported for LPO builds:
export MOSQUITTO_PSK_FILE="/opt/yocto/keys/lpo/mosquitto-psk.txt"
export SOTA_AUTH_TOKEN="/opt/yocto/keys/lpo/sota-auth.txt"
export LPO_DATASTATION_PRIVATEKEY="/opt/yocto/keys/lpo/datastation-privatekey.pem"
```

These are automatically added to `BB_ENV_PASSTHROUGH_ADDITIONS` using a deduplication helper.

#### Mirror Configuration

Injected into `build/lpo/local.conf`:

```
INHERIT += "own-mirrors"
SOURCE_MIRROR_URL = "https://downloads.yoctoproject.org/mirror/sources/"
```

This tells BitBake to try the Yocto HTTPS mirror first before falling back to upstream sources (SourceForge, GNU, etc.), reducing mid-transfer connection failures.

#### Fail-Fast Validation

For `meta-liebherr-lpo-display`, the script validates:

```bash
# Exits with rc 252 if missing:
- MOSQUITTO_PSK_FILE must exist and be readable
```

Prevents wasting cycles on recipes that require unavailable credentials.

## Download Helper Utilities

Two helper utilities assist with retrieving sources reliably in environments with unstable networks (e.g., when VPN drops mid-transfer).

### yocto-prefetch-source

**Location**: `~/.local/bin/yocto-prefetch-source`

**Purpose**: Generic resumable download utility with SHA256 verification

**Typical Issue**:
```
ERROR: Unable to fetch URL http://example.com/file.tar.gz from any source
ERROR: Fetcher failure: Unable to find checksum for file (errno=104 Connection reset by peer)
```

**Usage**:

```bash
# Download a source URL with automatic resumable retries
yocto-prefetch-source \
  --url https://downloads.sourceforge.net/libjpeg-turbo/libjpeg-turbo-3.0.1.tar.gz \
  --sha256 22429507714ae147b3acacd299e82099fce5d9f456882fc28e252e4579ba2a75 \
  --dl-dir /opt/yocto/shared/downloads \
  --attempts 20 \
  --connect-timeout 20 \
  --sleep 1
```

**Options**:
```
--url <url>                  Source URL to download (required)
--sha256 <hex>              Expected SHA256 checksum (required)
--dl-dir <path>             Download directory (default: /opt/yocto/shared/downloads)
--attempts <n>              Max retry attempts (default: 20)
--connect-timeout <sec>     Connection timeout (default: 30)
--sleep <sec>               Delay between retries (default: 2)
```

**How It Works**:
1. Uses `curl -C -` for resumable transfers
2. Retries failed downloads with exponential backoff
3. Verifies SHA256 after each attempt
4. Exits immediately on checksum match (success)
5. Exits on checksum mismatch (corrupted artifact)

**Example Output**:

```
==> URL: https://downloads.sourceforge.net/libjpeg-turbo/libjpeg-turbo-3.0.1.tar.gz
==> SHA256: 22429507714ae147b3acacd299e82099fce5d9f456882fc28e252e4579ba2a75
==> Attempt 1/20: Downloading...
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
 67 2662k   67 1800k    0     0   450k      0  0:00:05  0:00:03  0:00:02  602k

==> Current file: /opt/yocto/shared/downloads/libjpeg-turbo-3.0.1.tar.gz (2800900 bytes)
==> Checksum OK: 22429507714ae147b3acacd299e82099fce5d9f456882fc28e252e4579ba2a75
```

### yocto-prefetch-recipe-source

**Location**: `~/.local/bin/yocto-prefetch-recipe-source`

**Purpose**: Recipe-aware wrapper that extracts URLs and checksums automatically

**Motivation**: Avoids manual URL/SHA256 lookup for each troublesome recipe

**Usage**:

```bash
# Prefetch sources for a specific Yocto recipe
yocto-prefetch-recipe-source \
  --recipe meta/recipes-graphics/jpeg/libjpeg-turbo_3.0.1.bb \
  --attempts 20 \
  --dl-dir /opt/yocto/shared/downloads
```

**Options**:
```
--recipe <path>             Path to .bb recipe file (required)
--dl-dir <path>             Download directory (default: /opt/yocto/shared/downloads)
--attempts <n>              Max retry attempts (default: 20)
--connect-timeout <sec>     Connection timeout (default: 30)
--sleep <sec>               Delay between retries (default: 2)
```

**How It Works**:
1. Parses the `.bb` recipe file for `SRC_URI` and `SRC_URI[sha256sum]`
2. Extracts the first resolvable URL (handles template vars like `${SOURCEFORGE_MIRROR}`)
3. Resolves template variables (`${BPN}`, `${PV}`, etc.)
4. Delegates to `yocto-prefetch-source` with extracted URL/SHA256

**Example**:

```bash
$ yocto-prefetch-recipe-source --recipe libjpeg-turbo_3.0.1.bb
==> Recipe: /home/user/lpo-dev/linux-lpo/meta/recipes-graphics/jpeg/libjpeg-turbo_3.0.1.bb
==> URL: https://downloads.sourceforge.net/libjpeg-turbo/libjpeg-turbo-3.0.1.tar.gz
==> SHA256: 22429507714ae147b3acacd299e82099fce5d9f456882fc28e252e4579ba2a75
==> Attempt 1/20: Downloading...
==> Current file: /opt/yocto/shared/downloads/libjpeg-turbo-3.0.1.tar.gz (2800900 bytes)
==> Checksum OK: 22429507714ae147b3acacd299e82099fce5d9f456882fc28e252e4579ba2a75
```

### Workflow: Fixing Download Failures

**Scenario**: BitBake fails to fetch a source mid-transfer

```bash
ERROR: Unable to fetch URL https://downloads.sourceforge.net/libjpeg-turbo/libjpeg-turbo-3.0.1.tar.gz from any source
```

**Solution**:

1. **Identify the problematic recipe**:
   ```bash
   cd ~/lpo-dev/linux-lpo
   # Find .bb file for package
   find . -name "*libjpeg*" -type f | grep -E '\.bb'
   ```

2. **Prefetch its sources**:
   ```bash
   yocto-prefetch-recipe-source --recipe ./meta/recipes-graphics/jpeg/libjpeg-turbo_3.0.1.bb
   ```

3. **Resume the build**:
   ```bash
   cd build/lpo
   bitbake lpo-display-image
   ```

BitBake will find the source in `DL_DIR` and continue without re-fetching.

## Troubleshooting

### Helper Command Not Found

**Error**: `command not found: yocto-prefetch-source`

**Solution**:
```bash
# Recreate symlinks
bash ~/dotfiles/install-fedora.sh

# Verify they're in PATH
which yocto-prefetch-source yocto-prefetch-recipe-source

# Check ~/.local/bin is in $PATH
echo $PATH | grep -q ~/.local/bin || export PATH="$PATH:$HOME/.local/bin"
```

### Download Still Fails After Prefetch

**Cause**: Recipe uses alternate mirror or non-standard URL template

**Debug**:
```bash
# Check what URL the recipe actually uses
bitbake -e lpo-display-image | grep "^SRC_URI="

# Check mirror template variables
bitbake -e lpo-display-image | grep -E "SOURCEFORGE_MIRROR|GNU_MIRROR|KERNELORG_MIRROR"
```

### Checksum Mismatch in Prefetch

**Error**: `ERROR: Checksum mismatch for downloaded file`

**Cause**: Recipe's declared SHA256 doesn't match downloaded artifact

**Debug**:
```bash
# Verify checksum manually
sha256sum /opt/yocto/shared/downloads/libjpeg-turbo-3.0.1.tar.gz

# Check recipe for correct SHA256
grep -i "sha256sum" /path/to/recipe_file.bb
```

**Fix**: Update recipe with correct checksum or source URL

### Mirror Preferences Not Applied

**Symptom**: BitBake still tries upstream mirrors first

**Verify**:
```bash
# Check local.conf has mirror config
grep -E "INHERIT|SOURCE_MIRROR_URL" ~/lpo-dev/linux-lpo/build/lpo/local.conf

# Rebuild local.conf
cd ~/lpo-dev/linux-lpo/build/lpo
rm -f local.conf
TOPDIR="$(pwd)/.." OEROOT="${TOPDIR}/layers/poky" \
  source ~/.local/bin/llp_init_build.sh meta-liebherr-lpo-display
```

## Related Documentation

- [Yocto Overview](./yocto.md) — General Yocto setup
- [Secrets Management](./secrets-management.md) — Handling PSK files and private keys
