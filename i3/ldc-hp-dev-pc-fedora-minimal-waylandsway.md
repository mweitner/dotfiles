# ldc-hp-dev-pc - Fedora Minimal + Wayland/Sway

# Dev Laptop Setup: Fedora Minimal + Wayland/Sway

**Hardware:** HP ZBook Power G11 (16") **Processor:** Intel(R) Core(TM) Ultra 9 285H **Target Workflow:** Embedded Linux (Yocto), Tiling WM, Mouseless

## Phase 0: Backup & Windows Preparation


1. **Extract Windows License Key** Open **PowerShell** as Administrator and run:

   `(Get-WmiObject -query 'select * from SoftwareLicensingService').OA3xOriginalProductKey `
2. **Create Fedora Installation Media (Native Linux** `**dd**`**)**

   `sudo dd if=~/Downloads/Fedora-Server-dvd-x86_64-41.iso of=/dev/sdX bs=4M status=progress && sync `
3. **Disable Fast Startup (On the ZBook)**
   * *Control Panel > Power Options > Choose what the power buttons do* -> *Change settings that are currently unavailable* -> Uncheck **Turn on fast startup**.
4. **BIOS/UEFI Settings (Reboot and spam F10)**
   * **Storage:** Disable **VMD Controller** if the NVMe drive is not detected.
   * **Boot Order:** Use **F9** at startup to select the USB boot device.

## Phase 0.5: The Installation Process (Fedora 41/Server)


1. **Software Selection**
   * **Base Environment:** Select **Minimal Install**.
2. **Partitioning & Encryption (Unified Btrfs Pool)**
   * **efi-system:** `/boot/efi` (600 MiB, vfat, Unencrypted).
   * **boot-boot:** `/boot` (1 GiB, ext4, Unencrypted).
   * **fedora-root:** `/` (Btrfs Pool, Encrypted).
   * **swap-space:** `swap` (32 GiB, Encrypted).

## Phase 1: Post-Install Base System

After the first reboot, log in to the TTY and update.

`sudo dnf update -y sudo dnf install -y bash-completion curl wget git pciutils usbutils `

## Phase 1.5: Yocto Shared Directory Setup

`sudo mkdir -p /opt/yocto/shared/downloads sudo mkdir -p /opt/yocto/shared/sstate-cache sudo chown -R $USER:$USER /opt/yocto sudo chmod -R 775 /opt/yocto sudo chattr +C /opt/yocto/shared/downloads sudo chattr +C /opt/yocto/shared/sstate-cache `

## Phase 2: The Wayland Stack (greetd + Sway)

### 1. Install Core Packages

`sudo dnf install -y sway greetd greetd-selinux tuigreet swaylock swayidle brightnessctl waybar wofi mako foot wl-clipboard grim slurp `

### 2. Configure greetd

Edit `/etc/greetd/config.toml`:

`[default_session] command = "/usr/bin/tuigreet --time --remember --cmd sway" user = "greetd" `

Apply permissions and enable service:

`sudo chown greetd:greetd /var/lib/greetd sudo systemctl enable --now greetd `

## Phase 3: Developer Tooling & Yocto

### 1. Shell & Multiplexing

`sudo dnf install -y zsh fish tmux foot chsh -s /usr/bin/fish `

> Terminal emulator: **foot**
> Shell interpreters: **zsh**, **fish** (to try out)

### 2. Neovim & Modern CLI Tools

`sudo dnf install -y neovim ripgrep fd-find fzf htop btop `

### 3. Yocto Host Dependencies (Fedora 41+)

```bash
sudo dnf install -y gawk make wget tar bzip2 gzip python3 patch \
    perl-Data-Dumper perl-Thread-Queue perl-Text-ParseWords \
    diffutils diffstat git cpp gcc gcc-c++ binutils findutils \
    unzip perl-File-Compare perl-File-Copy perl-locale \
    zlib-devel openssl-devel xz bzip2-devel libffi-devel \
    ncurses-devel sqlite-devel readline-devel \lz4 zstd 
```

## Phase 4: Hardware & Power (HP ZBook G11)

* **Power:**

  ```bash
  sudo dnf install -y tlp tlp-rdw
  sudo systemctl enable --now tlp 
  ```
* **Thermal:**

  ```bash
  sudo dnf install -y thermald
  sudo systemctl enable --now thermald 
  ```
* **Firmware:**

  ```bash
  sudo fwupdmgr get-updates
  sudo fwupdmgr update 
  ```

## Phase 5: Tiling WM Configuration (Sway)

Copy your old config:

```bash
mkdir -p ~/.config/sway
cp ~/.config/i3/config ~/.config/sway/config 
```

**Essential Tweaks for** `**\~/.config/sway/config**`**:**


1. **Scaling:** `output eDP-1 scale 1.25`
2. **Waybar:** Replace bar block with `bar { swaybar_command waybar }`
3. **Launcher:** `bindsym $mod+d exec wofi --show run`

## Phase 6: Browser & Communication

For documentation and Yocto community interaction:

```bash
# Browser (Wayland Native)
sudo dnf install -y firefox
# Media/Fonts
sudo dnf install -y google-noto-sans-fonts \
  google-noto-serif-fonts google-noto-emoji-fonts 
```