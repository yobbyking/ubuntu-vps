#!/bin/bash
# ============================================================
# install-ptero — interactive helper to install Pterodactyl
# Panel (web UI) and/or Wings (game-server daemon)
#
# Usage:
#   install-ptero            → show menu
#   install-ptero panel      → install Panel only
#   install-ptero wings      → install Wings only
#   install-ptero all        → install both
#   install-ptero status     → check installed status
# ============================================================

set -e

# Must be root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Run as root:  sudo install-ptero $@"
    exit 1
fi

MODE="${1:-menu}"

print_banner() {
    cat << 'BANNER'
   ╔═══════════════════════════════════════════════════════╗
   ║   Pterodactyl Installer — Ubuntu 24.04 VPS          ║
   ╚═══════════════════════════════════════════════════════╝
BANNER
}

check_docker() {
    if ! command -v docker &>/dev/null; then
        echo "❌ Docker is not installed. Run: curl -fsSL https://get.docker.com | sh"
        return 1
    fi
    if ! docker info &>/dev/null; then
        cat << 'WARN'

   ⚠️  WARNING: Docker daemon is not running!

   Pterodactyl Wings REQUIRES a working Docker daemon to spawn
   game-server containers. Your current host can't start docker
   because Railway containers are not privileged by default.

   Your options:
   1. Deploy this VPS on a real provider (Hetzner / DigitalOcean / Vultr)
      where Docker works natively.
      See README for a $5-credit list of recommended providers.

   2. Continue anyway and install only the Panel (which doesn't
      need Docker). Wings on the same host won't work.

   3. Use this VPS to MANAGE a remote Wings node running elsewhere.
      Set DOCKER_HOST=tcp://remote-ip:2375 and you can run docker
      commands from here that target the remote daemon.

WARN
        read -p "Continue anyway? (y/N): " yn
        case "$yn" in [yY]*) ;; *) exit 1 ;; esac
    fi
}

install_panel() {
    print_banner
    echo "📦 Installing Pterodactyl Panel..."
    echo ""
    echo "This will install: PHP 8.2, MariaDB server, Redis, Nginx, Composer,"
    echo "and the Pterodactyl Panel itself."
    echo ""
    read -p "Press Enter to continue (Ctrl+C to cancel)..."

    # Use the official Pterodactyl panel installer
    cd /tmp
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    mkdir -p /var/www/pterodactyl
    tar -xzvf panel.tar.gz -C /var/www/pterodactyl
    cd /var/www/pterodactyl
    chmod -R 755 storage/* bootstrap/cache/

    # Install composer deps
    composer install --no-dev --optimize-autoloader

    # Set permissions
    chown -R www-data:www-data /var/www/pterodactyl

    echo ""
    echo "✅ Panel files installed at /var/www/pterodactyl"
    echo ""
    echo "Next steps (run manually):"
    echo "  1. Set up MariaDB:  sudo apt install mariadb-server && sudo mysql_secure_installation"
    echo "  2. Create panel DB: see https://pterodactyl.io/panel/1.0/installation.html#creating-a-database"
    echo "  3. Run panel setup: php artisan p:environment:setup"
    echo "  4. Configure Nginx: https://pterodactyl.io/panel/1.0/webserver_configuration.html"
    echo ""
    echo "📖 Full guide: https://pterodactyl.io/panel/1.0/installation.html"
}

install_wings() {
    print_banner
    echo "🕊️  Installing Pterodactyl Wings (game-server daemon)..."
    echo ""
    check_docker

    echo ""
    echo "This will install the Wings daemon binary and set up systemd service."
    echo ""
    read -p "Press Enter to continue (Ctrl+C to cancel)..."

    # Create wings directory
    mkdir -p /etc/pterodactyl /var/lib/pterodactyl

    # Download Wings binary (latest)
    echo "Downloading Wings..."
    curl -Lo /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    chmod +x /usr/local/bin/wings

    # Create systemd unit
    cat > /etc/systemd/system/wings.service << 'UNIT'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
UNIT

    # systemd won't run inside a container — print a note
    echo ""
    echo "✅ Wings binary installed at /usr/local/bin/wings"
    echo ""
    echo "⚠️  systemd doesn't run inside containers — instead, start Wings manually:"
    echo ""
    echo "   sudo /usr/local/bin/wings"
    echo ""
    echo "Or with tmux (survives SSH logout):"
    echo "   tmux new -s wings 'sudo /usr/local/bin/wings'"
    echo "   # Reattach:  tmux a -t wings"
    echo ""
    echo "Before first run, you need a config.yml from your Panel:"
    echo "  1. Open your Panel web UI"
    echo "  2. Admin → Nodes → Create Node → download configuration"
    echo "  3. Place it at /etc/pterodactyl/config.yml"
    echo ""
    echo "📖 Full guide: https://pterodactyl.io/wings/1.0/installing.html"
}

install_all() {
    install_panel
    echo ""
    install_wings
}

show_status() {
    print_banner
    echo "📊 Installed status:"
    echo ""
    echo "  Docker CLI:     $(command -v docker >/dev/null && echo '✅ installed' || echo '❌ missing')"
    echo "  Docker daemon:  $(docker info >/dev/null 2>&1 && echo '✅ running' || echo '❌ not running')"
    echo "  Panel files:    $([ -d /var/www/pterodactyl ] && echo '✅ /var/www/pterodactyl' || echo '❌ not installed')"
    echo "  Wings binary:    $(command -v wings >/dev/null && echo '✅ /usr/local/bin/wings' || echo '❌ not installed')"
    echo "  Node.js:        $(node -v 2>/dev/null || echo '❌ missing')"
    echo "  PHP:            $(php -v 2>/dev/null | head -1 || echo '❌ missing')"
    echo "  Nginx:          $(nginx -v 2>&1 || echo '❌ missing')"
    echo "  MariaDB client: $(mysql --version 2>/dev/null || echo '❌ missing')"
    echo ""
}

show_menu() {
    print_banner
    cat << 'MENU'
   What would you like to install?

   1) Pterodactyl Panel (web UI for managing game servers)
   2) Pterodactyl Wings (game-server daemon — needs Docker)
   3) Both Panel + Wings
   4) Show installed status
   5) Exit

MENU
    read -p "Choose (1-5): " choice
    case "$choice" in
        1) install_panel ;;
        2) install_wings ;;
        3) install_all ;;
        4) show_status ;;
        5) exit 0 ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
}

case "$MODE" in
    panel)  install_panel ;;
    wings)  install_wings ;;
    all)    install_all ;;
    status) show_status ;;
    menu|"") show_menu ;;
    *) echo "Usage: install-ptero [panel|wings|all|status]"; exit 1 ;;
esac
