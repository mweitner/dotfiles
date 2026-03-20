# Git Server on UGREEN NAS (Gerrit + Bare Repos)

This guide covers setting up a git server on your UGREEN NAS for small team collaboration. We'll start with simple bare repos via SSH, then evolve to full Gerrit code review if needed.

**Hardware:** UGREEN NAS DXP480T Plus (Debian 12 Bookworm, ARM64)  
**Storage:** `/volume1/data/git` (on Btrfs volume)  
**Network:** 192.168.1.110 (home), 192.168.3.91 (company)  
**Team size:** 2-5 developers  

---

## Phase 1: Simple Bare Git Repos (Quick Start)

### 1. Prepare Git User and Storage

SSH into the NAS:

```bash
ssh michael@192.168.1.110
```

Create a dedicated `git` user and storage:

```bash
# Create git user (no shell, no home directory login)
sudo useradd -r -s /usr/bin/git-shell git

# Create git storage directory structure
sudo mkdir -p /volume1/data/git/{projects,backups}
sudo chown -R git:git /volume1/data/git
sudo chmod 750 /volume1/data/git

# Prepare for SSH key-based access
sudo mkdir -p /home/git/.ssh
sudo chmod 700 /home/git/.ssh
sudo touch /home/git/.ssh/authorized_keys
sudo chmod 600 /home/git/.ssh/authorized_keys
sudo chown -R git:git /home/git/.ssh
```

### 2. Add Developer SSH Keys

Collect public SSH keys from developers (usually `~/.ssh/id_rsa.pub`):

```bash
# On NAS, as root or with sudo:
# Append developer public keys to git user's authorized_keys
sudo tee -a /home/git/.ssh/authorized_keys << 'EOF'
ssh-rsa AAAA... developer1@laptop
ssh-rsa BBBB... developer2@macbook
EOF

sudo chmod 600 /home/git/.ssh/authorized_keys
```

### 3. Initialize First Bare Repository

```bash
# Create a bare repo (no working directory, only for pushing/pulling)
sudo -u git git init --bare /volume1/data/git/projects/myproject.git

# Set permissions
sudo chmod -R u+w /volume1/data/git/projects/myproject.git
sudo chown -R git:git /volume1/data/git/projects/myproject.git
```

### 4. Test Access from Developer Laptop

On your Fedora laptop:

```bash
# Clone the repo (should use git user / NAS alias)
git clone git@ugreen-nas:/volume1/data/git/projects/myproject.git

# Create initial commit
cd myproject
echo "# My Project" > README.md
git add README.md
git commit -m "Initial commit"
git push origin main
```

### 5. Configure Git to Remember Remote

On your laptop, `.gitconfig` or per-repo:

```bash
cd /path/to/myproject

# Set user credentials (used by gerrit later)
git config user.name "Your Name"
git config user.email "your@email.com"

# Optional: configure remote alias for UGreen NAS
git remote add nas git@ugreen-nas:/volume1/data/git/projects/myproject.git
git push nas main  # push to NAS
```

### NAS Network Notes

Your `/etc/hosts` already has both IPs mapped to `ugreen-nas`:

```text
192.168.1.110 ugreen-nas   # home office
192.168.3.91 ugreen-nas    # company dev network
```

Git will automatically try both if one fails (DNS round-robin behavior in some setups). If needed, explicitly alias:

```bash
# In ~/.ssh/config (on your laptop)
Host ugreen-nas
  HostName ugreen-nas
  User git
  IdentityFile ~/.ssh/id_rsa
  # Optional: force specific IP
  # HostName 192.168.1.110
```

---

## Phase 2: Gerrit Code Review (Optional, Later)

### Prerequisites

Gerrit requires:
- Java (OpenJDK 11+)
- Sufficient RAM (at least 2GB, preferably 4GB+)
- Git (already on NAS)

### 1. Install Java and Dependencies

On NAS:

```bash
ssh michael@192.168.1.110

# Install Java and dependencies
sudo apt update
sudo apt install -y openjdk-17-jdk-headless postgresql postgresql-contrib

# Enable PostgreSQL
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Check Java version
java -version
```

### 2. Download and Install Gerrit

```bash
# Create gerrit user (different from simple git user)
sudo useradd -r -m -s /bin/bash gerrit

# Create Gerrit home directory
sudo mkdir -p /var/gerrit
sudo chown gerrit:gerrit /var/gerrit

# Download Gerrit WAR (check latest version)
cd /tmp
wget https://gerrit-releases.storage.googleapis.com/gerrit-3.9.0.war

# Move to gerrit home
sudo mv /tmp/gerrit-3.9.0.war /var/gerrit/
sudo chown gerrit:gerrit /var/gerrit/gerrit-3.9.0.war

# Switch to gerrit user and initialize
sudo -u gerrit java -jar /var/gerrit/gerrit-3.9.0.war init -d /var/gerrit/review_site
```

During initialization, accept defaults or configure:
- Listen address: `0.0.0.0:8080` (or behind nginx)
- Database backend: PostgreSQL
- Email: optional
- Authentication: `development` (local users, simple)

### 3. Configure PostgreSQL for Gerrit

```bash
# As root on NAS
sudo -u postgres psql << 'EOF'
CREATE USER gerrit CREATEDB;
CREATE DATABASE gerritdb OWNER gerrit;
\quit
EOF
```

Then in Gerrit configuration (`/var/gerrit/review_site/etc/gerrit.config`):

```ini
[database]
    type = postgresql
    hostname = localhost
    database = gerritdb
    username = gerrit
```

### 4. Start Gerrit Service

```bash
# Manual start for testing
sudo -u gerrit /var/gerrit/review_site/bin/gerrit.sh start

# Or create systemd service for auto-start
sudo tee /etc/systemd/system/gerrit.service << 'EOF'
[Unit]
Description=Gerrit Code Review
After=network.target postgresql.service

[Service]
Type=forking
User=gerrit
ExecStart=/var/gerrit/review_site/bin/gerrit.sh start
ExecStop=/var/gerrit/review_site/bin/gerrit.sh stop
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable gerrit
sudo systemctl start gerrit
```

### 5. Access Gerrit Web UI

From your laptop, open browser:

```
http://192.168.1.110:8080  (home office)
or
http://192.168.3.91:8080   (company)
```

First login creates local admin account (development mode).

### Create Project in Gerrit

```bash
# Via Gerrit web UI: Admin → Projects → Create New
# Or CLI:
curl -X POST http://192.168.1.110:8080/a/projects/myproject-review \
  -H "Content-Type: application/json" \
  -d '{"create_empty_commit": true}'
```

---

## Client-Side Git Setup

### Configure SSH for NAS Repos

`~/.ssh/config` (on your laptop):

```
Host ugreen-nas
  HostName ugreen-nas
  User git
  IdentityFile ~/.ssh/id_rsa
  ServerAliveInterval 60
```

### Test SSH Access

```bash
ssh -v git@ugreen-nas
# Expected: successful login, then immediate disconnect (git-shell)
```

### Clone / Push Workflow

**Phase 1 (bare repos):**

```bash
git clone git@ugreen-nas:/volume1/data/git/projects/myproject.git
cd myproject
# ... make commits ...
git push origin main
```

**Phase 2 (gerrit):**

```bash
git clone ssh://git@ugreen-nas:29418/myproject-review
cd myproject-review
# ... make commits ...

# Submit for review (creates changeset in gerrit)
git push origin HEAD:refs/for/main

# After review approval, merge via web UI or:
git push origin HEAD:refs/heads/main
```

---

## Troubleshooting

### SSH Access Denied

1. Verify SSH key is added to NAS:
   ```bash
   ssh git@ugreen-nas  # should show git-shell prompt or error
   ```

2. Check NAS `/home/git/.ssh/authorized_keys`:
   ```bash
   ssh michael@ugreen-nas
   sudo cat /home/git/.ssh/authorized_keys
   ```

3. Verify key permissions:
   ```bash
   ssh michael@ugreen-nas
   sudo ls -la /home/git/.ssh/
   # Should see: drwx------ .ssh and -rw------- authorized_keys
   ```

### Bare Repo Permission Errors

```bash
ssh michael@ugreen-nas
sudo chown -R git:git /volume1/data/git/projects/
sudo chmod -R g+w /volume1/data/git/projects/
```

### Gerrit Won't Start

```bash
# Check logs
sudo tail -f /var/gerrit/review_site/logs/error_log
sudo tail -f /var/gerrit/review_site/logs/gerrit.log

# Check Java process
ps aux | grep gerrit

# Check ports
sudo netstat -tlnp | grep 8080
```

### PostgreSQL Connection Issue

```bash
# Test connection as gerrit user
sudo -u gerrit psql -h localhost -U gerrit -d gerritdb

# Check PG status
sudo systemctl status postgresql
```

---

## Backup Strategy

### NAS Git Storage Backup

Since `/volume1/data/git` is on Btrfs:

```bash
# Create snapshot (on NAS)
sudo btrfs subvolume snapshot /volume1/data/git /volume1/data/git-backup-$(date +%Y%m%d)

# Or use rsync to external drive (connected to NAS)
sudo rsync -avh --delete /volume1/data/git/ /mnt/@usb/git-backup/
```

### Automated Backup (Systemd Timer)

On NAS:

```bash
# Create backup service
sudo tee /etc/systemd/system/gerrit-backup.service << 'EOF'
[Unit]
Description=Backup Gerrit repositories
After=network.target

[Service]
Type=oneshot
User=root
ExecStart=rsync -avh --delete /volume1/data/git/ /mnt/@usb/git-backup/
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create timer (daily at 2 AM)
sudo tee /etc/systemd/system/gerrit-backup.timer << 'EOF'
[Unit]
Description=Daily backup of Gerrit repositories
Requires=gerrit-backup.service

[Timer]
OnCalendar=daily
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now gerrit-backup.timer
```

---

## Quick Reference

| Operation | Command |
|-----------|---------|
| List repos on NAS | `ssh git@ugreen-nas "cd /volume1/data/git/projects && ls -la"` |
| Clone bare repo | `git clone git@ugreen-nas:/volume1/data/git/projects/myproject.git` |
| Access Gerrit UI | `http://ugreen-nas:8080` |
| Submit for review (gerrit) | `git push origin HEAD:refs/for/main` |
| Check git user on NAS | `ssh michael@ugreen-nas "id git"` |
| Gerrit logs | `ssh michael@ugreen-nas "sudo tail -f /var/gerrit/review_site/logs/error_log"` |

---

## Summary

**Phase 1 (Now):** Start with bare repos + SSH keys. Zero overhead, works immediately.  
**Phase 2 (Later):** Upgrade to Gerrit when team needs code review workflows.

Both phases use the same underlying git storage on the NAS. Gerrit simply adds the web UI and review layer on top.

This gives you a flexible, reproducible git infrastructure that scales with your team.
