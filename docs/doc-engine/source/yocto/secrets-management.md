# Secrets Management

Embedded Linux Development > Yocto Project

This guide covers how Yocto build credentials (PSK files, private keys, auth tokens) are organized, stored, and exported to recipes.

## Architecture

### Storage Organization

All project secrets are stored in `~/.secrets/yocto/keys/` inside the dotfiles repository:

```
~/.secrets/yocto/keys/
├── lpo/
│   ├── mosquitto-psk.txt          # Mosquitto broker PSK credentials
│   ├── sota-auth.txt              # SOTA authentication token
│   └── datastation-privatekey.pem # E2E encryption private key
├── llp/
│   ├── mosquitto-psk.txt
│   └── sota-auth.txt
└── dps/
    ├── mosquitto-psk.txt
    └── sota-auth.txt
```

### Symlink Mount Points

During `bash ~/dotfiles/install-fedora.sh`, symlinks are created in the system-wide location:

```
/opt/yocto/keys/
├── lpo/   → ~/.secrets/yocto/keys/lpo/
├── llp/   → ~/.secrets/yocto/keys/llp/
└── dps/   → ~/.secrets/yocto/keys/dps/
```

**Why symlinks?** 
- Allows recipes to use a consistent path (`/opt/yocto/keys/lpo/mosquitto-psk.txt`)
- Keeps secrets in version-controlled dotfiles without exposing in global configs
- Enables sharing across multiple Yocto build workspaces

## Build Environment Export

### Automatic Export via llp_init_build.sh

The initialization script `~/.local/bin/llp_init_build.sh` automatically detects and exports secrets:

```bash
# Exports these environment variables to BitBake:
export MOSQUITTO_PSK_FILE="/opt/yocto/keys/${PROJECT}/mosquitto-psk.txt"
export SOTA_AUTH_TOKEN="/opt/yocto/keys/${PROJECT}/sota-auth.txt"
export LPO_DATASTATION_PRIVATEKEY="/opt/yocto/keys/lpo/datastation-privatekey.pem"

# Registers them with BitBake passthrough:
BB_ENV_PASSTHROUGH_ADDITIONS="MOSQUITTO_PSK_FILE SOTA_AUTH_TOKEN LPO_DATASTATION_PRIVATEKEY"
```

### External Variable Override

You can override the default paths by exporting before init:

```bash
# Use custom PSK file location
export MOSQUITTO_PSK_FILE="/path/to/my/custom/mosquitto-psk.txt"

# Then initialize
TOPDIR="$(pwd)" OEROOT="${TOPDIR}/layers/poky" \
  source ~/.local/bin/llp_init_build.sh meta-liebherr-lpo-display
```

The script honors externally-set paths and will not override them.

## Recipe Access Patterns

### Direct Environment Variable

In `.bb` recipes:

```bitbake
# mosquitto_%.bbappend
do_configure() {
    # Safe: init script ensures MOSQUITTO_PSK_FILE is set on LPO builds
    cat ${MOSQUITTO_PSK_FILE} > ${S}/psk_config.h
}
```

The build system validates that `MOSQUITTO_PSK_FILE` is present before attempting recipe execution. If missing, the build fails fast with a helpful error message.

### Via Copied Artifact

For persistent inclusion in the image:

```bitbake
do_install() {
    install -m 600 ${MOSQUITTO_PSK_FILE} ${D}/etc/mosquitto/psk.conf
}
```

## Fail-Fast Validation

The init script validates critical secrets for each distro layer:

```bash
# meta-liebherr-lpo-display REQUIRES:
# - /opt/yocto/keys/lpo/mosquitto-psk.txt must exist
# - MOSQUITTO_PSK_FILE must be exported

# If missing, the script exits with rc 252 before BitBake runs:
if [[ ! -f "${MOSQUITTO_PSK_FILE}" ]]; then
    echo "ERROR: Missing MOSQUITTO_PSK_FILE for LPO display builds"
    exit 252
fi
```

**Benefit**: Avoids wasting compute cycles on recipes that will fail due to missing credentials upfront.

## Troubleshooting

### Error: "No such file or directory" for PSK

**Symptom**: Build fails with recipe unable to read `${MOSQUITTO_PSK_FILE}`

**Diagnosis**:
```bash
# Check if symlink exists
ls -la /opt/yocto/keys/lpo/mosquitto-psk.txt

# Check if source file exists
ls -la ~/.secrets/yocto/keys/lpo/mosquitto-psk.txt

# Verify export
echo $MOSQUITTO_PSK_FILE
```

**Fix**:
```bash
# Restore symlinks
bash ~/dotfiles/install-fedora.sh

# Re-initialize build
TOPDIR="$(pwd)" OEROOT="${TOPDIR}/layers/poky" \
  source ~/.local/bin/llp_init_build.sh meta-liebherr-lpo-display
```

### Git Ignoring Secrets Properly

The dotfiles `.gitignore` should contain:

```
.secrets/
/.secrets/
**/.secrets/
```

Verify no secrets are tracked:

```bash
cd ~/dotfiles
git log --all --full-history --diff-filter=D -- ".secrets/*"
```

### Permissions Issues

If running with `sudo` or in restricted environments:

```bash
# Ensure readable by build user
sudo chmod 644 /opt/yocto/keys/lpo/mosquitto-psk.txt

# Verify build user can read
sudo -u <builduser> cat /opt/yocto/keys/lpo/mosquitto-psk.txt
```

## Related Documentation

- [Yocto Overview](./yocto.md) — General Yocto setup
- [Build Environment & Helpers](./build-environment.md) — Download helpers and configurations
