#!/bin/bash
set -e

# ============================================================
# VPS entrypoint — runs on every container start
# Sets up the root user password, optional SSH key, then
# starts sshd (and tries to start Docker daemon).
# ============================================================

VPS_USERNAME="${VPS_USERNAME:-root}"
VPS_PASSWORD="${VPS_PASSWORD:-2026yobby}"
VPS_PUBLIC_KEY="${VPS_PUBLIC_KEY:-}"
VPS_SSH_PORT="${VPS_SSH_PORT:-22}"

echo "================================================"
echo "  Ubuntu 24.04 VPS — Railway"
echo "  SSH User : $VPS_USERNAME"
echo "  SSH Port : $VPS_SSH_PORT (internal)"
echo "  Password : [set via VPS_PASSWORD env var]"
echo "================================================"

# 1) Ensure the user exists (root always does; for custom users create it)
if [ "$VPS_USERNAME" != "root" ]; then
    if ! id "$VPS_USERNAME" &>/dev/null; then
        useradd -m -s /bin/bash -G sudo "$VPS_USERNAME"
        echo "$VPS_USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
        echo "[entrypoint] Created user: $VPS_USERNAME"
    fi
fi

# 2) Set the user's password
echo "$VPS_USERNAME:$VPS_PASSWORD" | chpasswd
echo "[entrypoint] Password updated for $VPS_USERNAME"

# 3) Allow this user via SSH
sed -i "/^AllowUsers/d" /etc/ssh/sshd_config
echo "AllowUsers $VPS_USERNAME" >> /etc/ssh/sshd_config

# 4) Optionally add a public key for key-based auth
HOME_DIR=$(getent passwd "$VPS_USERNAME" | cut -d: -f6)
if [ -n "$VPS_PUBLIC_KEY" ]; then
    mkdir -p "$HOME_DIR/.ssh"
    echo "$VPS_PUBLIC_KEY" > "$HOME_DIR/.ssh/authorized_keys"
    chmod 700 "$HOME_DIR/.ssh"
    chmod 600 "$HOME_DIR/.ssh/authorized_keys"
    chown -R "$VPS_USERNAME:$VPS_USERNAME" "$HOME_DIR/.ssh"
    echo "[entrypoint] Added public key from VPS_PUBLIC_KEY env var"
fi

# 5) Generate SSH host keys if missing
ssh-keygen -A 2>/dev/null

# 6) Try to start Docker daemon (will likely fail on Railway without privileged mode)
echo "[entrypoint] Attempting to start Docker daemon..."
if command -v dockerd &>/dev/null; then
    ( dockerd > /var/log/dockerd.log 2>&1 ) &
    DOCKERD_PID=$!
    sleep 3
    if ! kill -0 $DOCKERD_PID 2>/dev/null; then
        echo "[entrypoint] ⚠️  Docker daemon failed to start — see /var/log/dockerd.log"
        echo "[entrypoint]    This is normal on Railway (containers aren't privileged)."
        echo "[entrypoint]    For real Docker hosting, see README → recommended VPS providers."
    else
        echo "[entrypoint] ✅ Docker daemon started (PID $DOCKERD_PID)"
    fi
fi

# 7) Fix home dir permissions
chown -R "$VPS_USERNAME:$VPS_USERNAME" "$HOME_DIR"

echo "[entrypoint] Starting SSH daemon on port $VPS_SSH_PORT ..."
exec /usr/sbin/sshd -D -e
