FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Default VPS credentials — override in Railway env vars for security
ENV VPS_USERNAME=root \
    VPS_PASSWORD=2026yobby \
    VPS_PUBLIC_KEY="" \
    VPS_SSH_PORT=22

# ============================================================
# 1) Core system + SSH + sudo + dev tools
# ============================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    sudo \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    btop \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    unzip \
    zip \
    ca-certificates \
    tmux \
    man-db \
    less \
    lsof \
    net-tools \
    dnsutils \
    iproute2 \
    software-properties-common \
    ufw \
    zsh \
    jq \
    tree \
    tldr \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# 2) Languages + runtimes (Pterodactyl needs Node + PHP + Composer)
# ============================================================
# Node.js 20 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Bun
RUN curl -fsSL https://bun.sh/install | bash && \
    ln -s /root/.bun/bin/bun /usr/local/bin/bun && \
    ln -s /root/.bun/bin/bunx /usr/local/bin/bunx

# PHP 8.2 + extensions (Pterodactyl Panel requires PHP 8.1+; 8.2 is the safe pick)
RUN add-apt-repository -y ppa:ondrej/php && \
    apt-get update && apt-get install -y --no-install-recommends \
    php8.2-fpm php8.2-cli php8.2-gd php8.2-mysql php8.2-pgsql php8.2-mbstring \
    php8.2-tokenizer php8.2-bcmath php8.2-xml php8.2-fpm php8.2-curl \
    php8.2-zip php8.2-intl php8.2-redis php8.2-sqlite3 \
    composer \
    && rm -rf /var/lib/apt/lists/*

# Database clients (so Pterodactyl Panel can talk to its DB)
RUN apt-get update && apt-get install -y --no-install-recommends \
    mariadb-client \
    postgresql-client \
    redis-tools \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Web server (Pterodactyl Panel front-end)
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    certbot \
    python3-certbot-nginx \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# 3) Docker (CLI + daemon) — required by Pterodactyl Wings
# ⚠️  The Docker daemon needs privileged mode to start inside a
# container. Railway does NOT enable this by default, so:
#   • Docker CLI works (manage remote hosts via DOCKER_HOST)
#   • Docker daemon may fail to start on Railway
# For real Pterodactyl Wings hosting, use a real VPS (Hetzner,
# DigitalOcean, Vultr) — see README for recommended providers.
# ============================================================
RUN curl -fsSL https://get.docker.com -o /tmp/get-docker.sh && \
    sh /tmp/get-docker.sh && \
    rm -f /tmp/get-docker.sh

# Pre-pull the Wings runtime image (so first server boots faster)
# Pulled at first Wings startup, not here, to keep image smaller.

# ============================================================
# 4) SSH configuration — allow root login (user wants root access)
# ============================================================
RUN mkdir -p /var/run/sshd && \
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    echo 'ClientAliveInterval 60' >> /etc/ssh/sshd_config && \
    echo 'ClientAliveCountMax 3' >> /etc/ssh/sshd_config && \
    echo 'PrintMotd yes' >> /etc/ssh/sshd_config

# Welcome MOTD
RUN cat > /etc/motd << 'EOF'

   ╔═══════════════════════════════════════════════════════╗
   ║   Your Ubuntu 24.04 VPS with Docker — ready for     ║
   ║   Pterodactyl Panel & Wings                          ║
   ╚═══════════════════════════════════════════════════════╝

   SSH user: root
   Password: see VPS_PASSWORD env var (default: 2026yobby)

   Pre-installed:
   • Docker (CLI + daemon)
   • Node.js 20 LTS + Bun  • PHP 8.2 + Composer
   • Nginx + Certbot  • MariaDB/PostgreSQL/Redis clients
   • tmux, btop, vim, nano, htop

   Quick commands:
   • install-ptero panel   → install Pterodactyl Panel (web UI)
   • install-ptero wings   → install Pterodactyl Wings (game daemon)
   • install-ptero all     → install both
   • docker ps             → check Docker is running
   • btop                  → live system monitor

   ⚠️  Docker daemon needs privileged mode to run inside a
       container. Railway does NOT enable this by default.
       For real Wings hosting, see README for VPS providers.

EOF

# ============================================================
# 5) Entrypoint + helper scripts
# ============================================================
COPY entrypoint.sh /entrypoint.sh
COPY install-ptero.sh /usr/local/bin/install-ptero
RUN chmod +x /entrypoint.sh /usr/local/bin/install-ptero

ENV PATH="/root/.bun/bin:/usr/local/bin:${PATH}"

# Expose SSH (22), Pterodactyl Panel web (80/443),
# Pterodactyl Wings daemon (8080), and game-server port range (2022+)
EXPOSE 22 80 443 8080 8443 2022 3306 5432 6379

ENTRYPOINT ["/entrypoint.sh"]
