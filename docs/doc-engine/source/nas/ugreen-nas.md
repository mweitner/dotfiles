# UGREEN NAS Auto-Mount on Fedora

This setup mounts the NAS share `/data` at `/mnt/data` automatically when accessed.

Network variants used in this environment:

- Home office NAS IP: `192.168.1.110`
- Company dev network NAS IP: `192.168.3.91`

Credentials file stored in dotfiles secrets:

```bash
~/dotfiles/.secrets/.smbcredentials_ugreen
```

Content:

```text
username=ldcwem0
password=<see 1Password>
```

Set strict permissions:

```bash
chmod 600 ~/dotfiles/.secrets/.smbcredentials_ugreen
```

## Quick Commands

Home office (NAS on `192.168.1.110`):

```bash
setup-ugreen-nas-mount --mode systemd-units --site home
ls /mnt/data
```

ULM office (dev switch + dnsmasq + NAS on `192.168.3.91`):

```bash
setup-ulm-office-mode --site auto
ls /mnt/data
```

Check current status:

```bash
nas-status
```

If setup fails with known signatures (`sudo` TTY, `scp` destination path,
TLS cert trust, apt broken dependencies), jump to:

- [Known Issue Signatures And Fixes](#known-issue-signatures-and-fixes)

---

## Recommended (Automated): Native systemd `.mount` + `.automount`

Use the helper script from this repo:

```bash
setup-ugreen-nas-mount --mode systemd-units --site auto
```

If you are at ULM office on the machine-network switch, first activate the
lightweight dnsmasq profile that serves the office subnet and NAS alias:

```bash
setup-dnsmasq-profile --profile ulm-nas
```

What it does:

- installs `cifs-utils` if missing
- configures `/etc/hosts` alias `ugreen-nas` with both IPs
- orders IPs site-aware (`--site auto|home|work`) so reachable site is preferred first
- writes `/etc/systemd/system/mnt-data.mount`
- writes `/etc/systemd/system/mnt-data.automount`
- enables/restarts `mnt-data.automount`

Test:

```bash
ls /mnt/data
mount | grep '/mnt/data'
```

---

## Alternative: fstab + systemd automount

If you prefer fstab-managed configuration:

```bash
setup-ugreen-nas-mount --mode fstab --site auto
```

This writes a managed block in `/etc/fstab` and enables/restarts
`mnt-data.automount`.

## ULM Office One-Shot Workflow

Use this helper to prepare network profile + dnsmasq + NAS automount in one run:

```bash
setup-ulm-office-mode --site auto
```

What it does:

- rebinds mining profile to the currently attached adapter MAC
- activates `Machine-mining-excavator-GW` (expected `192.168.3.1/24`)
- switches dnsmasq to `ulm-nas` profile
- enables IPv4 forwarding + NAT masquerading for `192.168.3.0/24` to the uplink
- applies NAS automount via `systemd` units
- triggers mount and prints `nas-status`

Default interface mapping in this environment:

- machine network ingress: `enx00e04cb828b5` (`192.168.3.1/24`)
- internet uplink egress: `enx98e74325ccf7` (`10.146.72.96/23`)

Show current forwarding/NAT state:

```bash
setup-machine-internet-sharing --show
```

## Dual-Adapter Workflow: Mining + LPO At The Same Time

This setup keeps NAS/mining on one USB2Ethernet adapter and LPO on a second
USB2Ethernet adapter in parallel.

Concrete example with current adapter registry:

- `adapter-a` (`00:E0:4C:B8:28:B5` / `enx00e04cb828b5`) for `mining`
- `adapter-c` (`3C:49:37:05:47:46` / `enx3c4937054746`) for `lpo`

Apply the mapping:

```bash
setup-adapters --group mining=a --group lpo=c
```

Bring up both gateway profiles:

```bash
nmcli connection up Machine-mining-excavator-GW
nmcli connection up Machine-lpo-CSM-GW
```

Switch dnsmasq to mining/NAS profile and ensure NAS mount is ready:

```bash
setup-dnsmasq-profile --profile ulm-nas
setup-ugreen-nas-mount --mode systemd-units --site auto
ls /mnt/data
```

Verification:

```bash
nmcli connection show Machine-mining-excavator-GW | grep mac-address
nmcli connection show Machine-lpo-CSM-GW | grep mac-address
ip -4 addr show enx00e04cb828b5
ip -4 addr show enx3c4937054746
nas-status
```

Expected result:

- mining gateway profile bound to adapter-a (`192.168.3.1/24`)
- lpo gateway profile bound to adapter-c (`192.168.2.1/24`)
- NAS reachable/mounted from the mining network while LPO network remains active

Optional overrides:

```bash
setup-ulm-office-mode --interface enx00e04cb828b5
setup-ulm-office-mode --connection "Machine-mining-excavator-GW"
setup-ulm-office-mode --dns-profile ulm-nas
setup-ulm-office-mode --site work
```

---

## Git Repository Management

The NAS can host bare git repositories at `/volume1/data/repos/` for remote backup
or collaborative development. SSH-based authentication is used (key-based, passwordless).

### Prerequisite: CA Trust For Office TLS Inspection

On the ULM office network, outbound HTTPS from NAS may be TLS-inspected. Before
`apt` can install `git`, install enterprise CA certificates onto NAS:

```bash
setup-nas-ca-certificates --host ugreen-nas --test-apt
```

Then install git:

```bash
ssh -t ugreen-nas "sudo apt-get install -y git && git --version"
```

If apt reports broken dependencies, repair once then retry install:

```bash
ssh -t ugreen-nas "sudo dpkg --configure -a && sudo apt-get --fix-broken install -y && sudo apt-get install -y git"
```

### Initial SSH Setup (One-Time)

Generate SSH key and add it to NAS authorized_keys:

```bash
setup-nas-ssh-key
```

For home NAS:

```bash
setup-nas-ssh-key --host ugreen-nas-home
```

What it does:

- generates `~/.ssh/id_ed25519_ugreen_nas` if it doesn't exist
- adds public key to `~/.ssh/authorized_keys` on the NAS
- tests SSH connection
- output: `ssh ugreen-nas` (or `ssh ugreen-nas-home`) now works without password

### Create a Git Repository

Create a new bare repository on the NAS:

```bash
setup-nas-git-repo my-project
```

Output will show the clone URL:

```text
Repository: my-project
Host: ugreen-nas (192.168.3.91)
Path: /volume1/data/repos/my-project.git

Clone this repository:
  git clone ssh://ugreen-nas/volume1/data/repos/my-project.git my-project
```

Clone and initialize:

```bash
setup-nas-git-repo my-project --clone ~/src
cd ~/src/my-project
```

This creates the repo, clones it locally, and pushes an initial commit.

### Push Existing Repository

If you have an existing git repository, add the NAS as a remote:

```bash
git remote add nas-storage ssh://ugreen-nas/volume1/data/repos/project-name.git
git branch -M main
git push -u nas-storage main
```

### Manage Repositories

List repositories on NAS:

```bash
ssh ugreen-nas ls -la /volume1/data/repos/
```

Delete a repository:

```bash
setup-nas-git-repo project-name --delete
```

### SSH Host Aliases

- `ugreen-nas`: ULM office network (192.168.3.91)
- `ugreen-nas-home`: Home network (192.168.1.110)

Both use SSH key `~/.ssh/id_ed25519_ugreen_nas` and connect as user `michael`.

### Clone URL Formats

Direct SSH:

```bash
git clone ssh://ugreen-nas/volume1/data/repos/project-name.git
```

Via SSH host alias:

```bash
git clone ssh://ugreen-nas/volume1/data/repos/project-name.git
```

Shorthand (if set up as remote):

```bash
git clone ugreen-nas:repos/project-name.git
```

---

## Manual fstab Entry (Reference)

If you want to manage it manually, use:

```fstab
//ugreen-nas/data /mnt/data cifs credentials=/home/ldcwem0/dotfiles/.secrets/.smbcredentials_ugreen,uid=1000,gid=1000,iocharset=utf8,vers=3.1.1,file_mode=0664,dir_mode=0775,_netdev,nofail,x-systemd.mount-timeout=15s,x-systemd.automount,x-systemd.idle-timeout=5min 0 0
```

Also add both addresses in `/etc/hosts`:

```hosts
192.168.1.110 ugreen-nas
192.168.3.91 ugreen-nas
```

Reload and test:

```bash
sudo systemctl daemon-reload
sudo systemctl restart mnt-data.automount
ls /mnt/data
```

---

## Troubleshooting

- `mount error(13): Permission denied`
  - check username/password in `~/dotfiles/.secrets/.smbcredentials_ugreen`
  - ensure file mode is `600`

- mount hangs on one site
  - verify NAS is reachable in current network (`ping 192.168.1.110` or `ping 192.168.3.91`)
  - check `/etc/hosts` managed block from the helper script

- verify automount state

```bash
systemctl status mnt-data.automount
systemctl status mnt-data.mount
```

### Known Issue Signatures And Fixes

Use this quick map when NAS setup fails with familiar messages.

1. `sudo: a terminal is required to read the password`

Cause: command executed via non-interactive SSH.

Fix:

```bash
ssh -t ugreen-nas "sudo <command>"
```

2. `scp: dest open ... No such file or directory` (on NAS uploads)

Cause: NAS `scp/sftp` destination path behavior is inconsistent in this environment.

Fix: use `setup-nas-ca-certificates` (it streams files over SSH to `$HOME/tmp`
instead of relying on `scp`).

3. `Certificate verification failed: The certificate is NOT trusted` (apt)

Cause: office network TLS inspection (`LIS-SSL-SCAN-CA02`) not trusted on NAS.

Fix:

```bash
setup-nas-ca-certificates --host ugreen-nas --test-apt
```

4. `Ign: ... deb.debian.org ...` / apt hangs at `0% [Working]`

Cause: dev-pc machine-network routing or DNS path not fully active.

Fix:

```bash
setup-ulm-office-mode --site auto
setup-machine-internet-sharing --show
setup-dnsmasq-profile --show
```

5. `E: Unable to locate package git` after TLS errors

Cause: apt index not updated because HTTPS trust failed.

Fix: resolve TLS trust first (see #3), then run:

```bash
ssh -t ugreen-nas "sudo apt-get update && sudo apt-get install -y git"
```

6. `You might want to run 'apt --fix-broken install'`

Cause: partially broken package state on NAS.

Fix:

```bash
ssh -t ugreen-nas "sudo dpkg --configure -a && sudo apt-get --fix-broken install -y && sudo apt-get install -y git"
```

---

## Verification

After setup, use the `nas-status` helper to verify overall health:

```bash
nas-status
```

Expected output:

```text
NAS alias:            ugreen-nas
Home IP (192.168.1.110): up
Work IP (192.168.3.91): down
Reachable NAS IP:      192.168.1.110
Mount point:           /mnt/data
Mounted:               yes
Mount source:          systemd-1
//ugreen-nas/data
mnt-data.automount:    active
mnt-data.mount:        active

Directory preview (/mnt/data):
dev
media
private
sat600
```

Full directory structure on the NAS (from `tree -L 2 /mnt/data/`):

```text
/mnt/data/
├── dev
│   ├── backup
│   ├── cloud
│   ├── dev-python
│   ├── document
│   ├── keys
│   ├── keys_backup.tar.gz
│   ├── leg-cms
│   ├── leg-cms-next
│   ├── leg-cms-projects
│   ├── linux-dps
│   ├── linux-dps-projects
│   ├── linux-dps-review
│   ├── linux-litu3
│   ├── linux-litu3-projects
│   ├── linux-llp
│   ├── linux-lpo
│   ├── linux-lpo-minimal
│   ├── linux-lpo-projects
│   ├── linux-smd
│   ├── linux-smd-projects
│   ├── llp-distro
│   ├── llp-distro-projects
│   ├── lmt-smd-projects
│   ├── lost+found
│   ├── montavista-projects
│   ├── system-architecture
│   ├── testfile
│   └── yocto-tool-projects
├── media
│   ├── ebooks
│   └── vms
├── private
│   ├── backups
│   ├── documents
│   └── synology_old
└── sat600

36 directories, 2 files
```
