#!/bin/bash
set -e

# ============================================================
# VPS entrypoint — runs on every container start
# Creates the user, sets the password, optionally adds a
# public key, optionally clones a git repo, then starts sshd.
# ============================================================

VPS_USERNAME="${VPS_USERNAME:-swiftpay}"
VPS_PASSWORD="${VPS_PASSWORD:-ChangeMe!2026}"
VPS_PUBLIC_KEY="${VPS_PUBLIC_KEY:-}"
VPS_GIT_REPO="${VPS_GIT_REPO:-}"
VPS_SSH_PORT="${VPS_SSH_PORT:-22}"

echo "================================================"
echo "  Ubuntu 24.04 VPS — Railway"
echo "  SSH User : $VPS_USERNAME"
echo "  SSH Port : $VPS_SSH_PORT (internal)"
echo "  Password : [set via VPS_PASSWORD env var]"
echo "================================================"

# 1) Create or update the user
if ! id "$VPS_USERNAME" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo "$VPS_USERNAME"
    echo "$VPS_USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    echo "[entrypoint] Created user: $VPS_USERNAME"
else
    echo "[entrypoint] User already exists: $VPS_USERNAME"
fi

# 2) Set the user's password
echo "$VPS_USERNAME:$VPS_PASSWORD" | chpasswd
echo "[entrypoint] Password updated for $VPS_USERNAME"

# 3) Restrict SSH to only this user
sed -i "/^AllowUsers/d" /etc/ssh/sshd_config
echo "AllowUsers $VPS_USERNAME" >> /etc/ssh/sshd_config

# 4) Optionally add a public key (so the user can use either password OR key auth)
HOME_DIR=$(getent passwd "$VPS_USERNAME" | cut -d: -f6)
if [ -n "$VPS_PUBLIC_KEY" ]; then
    mkdir -p "$HOME_DIR/.ssh"
    echo "$VPS_PUBLIC_KEY" > "$HOME_DIR/.ssh/authorized_keys"
    chmod 700 "$HOME_DIR/.ssh"
    chmod 600 "$HOME_DIR/.ssh/authorized_keys"
    chown -R "$VPS_USERNAME:$VPS_USERNAME" "$HOME_DIR/.ssh"
    echo "[entrypoint] Added public key from VPS_PUBLIC_KEY env var"
fi

# 5) Optionally clone a git repo into the user's home dir on first boot
if [ -n "$VPS_GIT_REPO" ] && [ ! -d "$HOME_DIR/$(basename "$VPS_GIT_REPO" .git)" ]; then
    echo "[entrypoint] Cloning $VPS_GIT_REPO ..."
    sudo -u "$VPS_USERNAME" git clone "$VPS_GIT_REPO" "$HOME_DIR/$(basename "$VPS_GIT_REPO" .git)" || echo "[entrypoint] clone failed, continuing"
fi

# 6) Generate SSH host keys if missing (sshd won't start without them)
ssh-keygen -A 2>/dev/null

# 7) Fix permissions on the user's home dir
chown -R "$VPS_USERNAME:$VPS_USERNAME" "$HOME_DIR"

echo "[entrypoint] Starting SSH daemon on port $VPS_SSH_PORT ..."
exec /usr/sbin/sshd -D -e
