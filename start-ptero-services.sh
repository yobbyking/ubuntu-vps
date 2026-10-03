#!/bin/bash
# ============================================================
# start-ptero-services — start MariaDB, Redis, PHP-FPM, Nginx
# and the Pterodactyl queue worker (without systemd, which
# doesn't run inside containers).
# ============================================================
# SSH into the VPS and run this to start everything.

set -e

echo "🚀 Starting Pterodactyl Panel services..."

# 1) MariaDB
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
if ! pgrep -x mariadbd > /dev/null; then
    nohup /usr/bin/mysqld_safe --user=mysql --datadir=/var/lib/mysql > /var/log/mysql.log 2>&1 &
    echo "  ✅ MariaDB started"
else
    echo "  ✅ MariaDB already running"
fi

# 2) Redis
if ! pgrep -x redis-server > /dev/null; then
    /usr/bin/redis-server --bind 127.0.0.1 --port 6379 --daemonize yes
    echo "  ✅ Redis started"
else
    echo "  ✅ Redis already running"
fi

# 3) PHP-FPM 8.2
mkdir -p /run/php
if ! pgrep -f php-fpm > /dev/null; then
    nohup /usr/sbin/php-fpm8.2 --nodaemonize > /var/log/php-fpm.log 2>&1 &
    sleep 1
    echo "  ✅ PHP-FPM 8.2 started"
else
    echo "  ✅ PHP-FPM already running"
fi

# 4) Nginx
if ! pgrep -x nginx > /dev/null; then
    nginx
    echo "  ✅ Nginx started (port 80)"
else
    echo "  ✅ Nginx already running"
fi

# 5) Pterodactyl queue worker (in tmux for persistence)
if ! pgrep -f "queue:work" > /dev/null; then
    cd /var/www/pterodactyl
    tmux new -d -s queue 'php artisan queue:work --daemon --queue=high,standard,low'
    echo "  ✅ Queue worker started in tmux session 'queue'"
else
    echo "  ✅ Queue worker already running"
fi

echo ""
echo "📊 Service status:"
sleep 1
ss -tlnp 2>/dev/null | grep -E ':80|:443|:3306|:6379|:22' | head -10
echo ""
echo "🌐 Panel is live on http://localhost/ (inside the VPS)"
echo ""
echo "To access from outside, use SSH port-forwarding:"
echo "   ssh -L 8080:localhost:80 root@altaria.proxy.rlwy.net -p 10754"
echo "   # Then open http://localhost:8080 in your browser"
echo ""
echo "Or in Termius:"
echo "   Host → Port Forwarding → Add Rule:"
echo "     Type: Local"
echo "     Local Port: 8080"
echo "     Remote Host: localhost"
echo "     Remote Port: 80"
echo "   # Then open http://localhost:8080"
echo ""
echo "🛑 To stop everything: pkill nginx php-fpm8.2 mariadbd redis-server; tmux kill-session -t queue"
