FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Default env vars (overridden by Railway env vars at runtime)
ENV VPS_USERNAME=swiftpay \
    VPS_PASSWORD=ChangeMe!2026 \
    VPS_PUBLIC_KEY="" \
    VPS_GIT_REPO="" \
    VPS_SSH_PORT=22

# Install: SSH + sudo + common dev tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    sudo \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    build-essential \
    python3 \
    python3-pip \
    unzip \
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
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash && \
    ln -s /root/.bun/bin/bun /usr/local/bin/bun && \
    ln -s /root/.bun/bin/bunx /usr/local/bin/bunx

# Install Docker CLI (useful for compose files / builds — daemon not included)
RUN curl -fsSL https://get.docker.com -o /tmp/get-docker.sh && \
    sh /tmp/get-docker.sh --dry-run 2>/dev/null || \
    apt-get update && apt-get install -y docker.io || true && \
    rm -f /tmp/get-docker.sh && \
    rm -rf /var/lib/apt/lists/*

# Configure SSH
RUN mkdir -p /var/run/sshd && \
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    echo 'ClientAliveInterval 60' >> /etc/ssh/sshd_config && \
    echo 'ClientAliveCountMax 3' >> /etc/ssh/sshd_config

# Create a welcome MOTD
RUN cat > /etc/motd << 'EOF'

   ___  ___  ___  ___  ___  ___  ___  ___
  | _ \|   \| _ \| _ \| _ \|   \| __|/ __|
  |  _/| |) |  _/|  _/|  _/| |) | _| \__ \
  |_|  |___/|_|  |_|  |_|  |___/|___||___/

  Welcome to your Ubuntu 24.04 VPS on Railway!

  • Type `sudo -i` for root access
  • Type `swiftpay-deploy` to clone & set up SwiftPay
  • Type `htop` to monitor processes
  • Type `df -h` for disk, `free -m` for memory

  Useful tools pre-installed: node 20, bun, git, vim, nano, tmux, python3, docker CLI

EOF

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
COPY swiftpay-deploy.sh /usr/local/bin/swiftpay-deploy
RUN chmod +x /entrypoint.sh /usr/local/bin/swiftpay-deploy

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
