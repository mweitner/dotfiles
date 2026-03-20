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

---

## Recommended (Automated): fstab + systemd automount

Use the helper script from this repo:

```bash
setup-ugreen-nas-mount --mode fstab
```

What it does:

- installs `cifs-utils` if missing
- configures `/etc/hosts` alias `ugreen-nas` with both IPs
- writes a managed `/etc/fstab` entry with `x-systemd.automount`
- enables/restarts `mnt-data.automount`

Test:

```bash
ls /mnt/data
mount | grep '/mnt/data'
```

---

## Alternative: Native systemd `.mount` + `.automount`

If you prefer explicit units over `/etc/fstab`:

```bash
setup-ugreen-nas-mount --mode systemd-units
```

This writes:

- `/etc/systemd/system/mnt-data.mount`
- `/etc/systemd/system/mnt-data.automount`

Then enables `mnt-data.automount`.

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
