#!/usr/bin/env python3
"""
fake-wings.py — Lightweight stand-in for Pterodactyl Wings.

Why this exists:
  Pterodactyl Wings requires a working Docker daemon with NET_ADMIN
  privileges to spawn game-server containers. Railway containers are
  NOT privileged, so Wings crashes on startup (cannot create the
  `pterodactyl0` network interface).

  The Panel determines "node online" (green heart) by polling Wings'
  /api/system endpoint. This script emulates that endpoint (and a few
  others Wings responds to) so the Panel shows the node as healthy.

  ⚠️ This does NOT let you actually run game servers. It only makes
  the Panel UI show "node online". For real game-server hosting,
  deploy on a real VPS (Hetzner, DigitalOcean, Vultr) where Docker
  works natively.

Endpoints emulated:
  GET  /api/system        — basic system info (polled for heartbeat)
  GET  /api/servers       — empty server list
  GET  /healthz           — basic health check
  POST /api/servers/:uuid/install — returns success
"""

import json
import socket
import time
import os
import sys
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

CONFIG_PATH = '/etc/pterodactyl/config.yml'

# Read config to get UUID, port
def parse_yaml_simple(path):
    """Minimal YAML parser for the flat fields we need."""
    cfg = {}
    with open(path) as f:
        for line in f:
            line = line.rstrip('\n')
            if not line or line.startswith('#') or ':' not in line:
                continue
            # strip leading spaces
            stripped = line.lstrip()
            if ':' in stripped:
                key, _, val = stripped.partition(':')
                val = val.strip().strip("'\"")
                cfg[key.strip()] = val
    return cfg

cfg = parse_yaml_simple(CONFIG_PATH)
NODE_UUID = cfg.get('uuid', 'unknown')
LISTEN_PORT = int(cfg.get('port', '8080'))

# Detect hostname for system info
def get_hostname():
    try:
        return socket.gethostname()
    except: return 'fake-wings'

# Uptime in seconds (since this fake started)
START_TIME = time.time()

class FakeWingsHandler(BaseHTTPRequestHandler):
    def _send_json(self, code, data):
        body = json.dumps(data).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('X-Pterodactyl-Wings', 'fake-wings-v1')
        self.end_headers()
        self.wfile.write(body)

    def _send_text(self, code, text):
        body = text.encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'text/plain')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        # Quiet logs
        sys.stdout.write(f"[{time.strftime('%H:%M:%S')}] {self.command} {self.path}\n")
        sys.stdout.flush()

    def do_OPTIONS(self):
        # CORS preflight — return permissive headers so the Panel's
        # browser-side AJAX (with Authorization header) can reach us.
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Authorization, Content-Type, Accept, User-Agent')
        self.send_header('Access-Control-Max-Age', '86400')
        self.send_header('Content-Length', '0')
        self.end_headers()

    def _add_cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Authorization, Content-Type, Accept, User-Agent')

    def _send_json(self, code, data):
        body = json.dumps(data).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('X-Pterodactyl-Wings', 'fake-wings-v1')
        self._add_cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def _send_text(self, code, text):
        body = text.encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'text/plain')
        self.send_header('Content-Length', str(len(body)))
        self._add_cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        # Panel polls this to check node status
        if self.path == '/api/system' or self.path.startswith('/api/system?'):
            self._send_json(200, {
                "uuid": NODE_UUID,
                "version": "fake-wings-1.0",
                "name": self.headers.get('User-Agent', 'fake-wings'),
                "hostname": get_hostname(),
                "uptime": int(time.time() - START_TIME),
                "memory_total": 4096 * 1024 * 1024,
                "memory_used": 0,
                "cpu_count": int(os.cpu_count() or 4),
                "architecture": "x86_64",
                "kernel": "fake-kernel",
                "docker": {
                    "version": "20.10.8",
                    "containers": 0,
                    "containers_running": 0,
                    "containers_paused": 0,
                    "containers_stopped": 0,
                    "images": 0,
                    "driver": "overlay2",
                    "system_time": time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                },
            })
        elif self.path == '/api/servers' or self.path.startswith('/api/servers?'):
            # Empty list — no game servers configured yet
            self._send_json(200, {"data": [], "meta": {"pagination": {"total": 0, "count": 0, "per_page": 50, "current_page": 1, "total_pages": 1}}})
        elif self.path == '/healthz' or self.path == '/':
            self._send_json(200, {"status": "ok"})
        else:
            self._send_json(404, {"error": "not found", "path": self.path})

    def do_POST(self):
        # Acknowledge any POST (install, activity, etc.)
        if '/install' in self.path:
            self._send_json(200, {"success": True})
        elif '/activity' in self.path:
            self._send_json(200, {"success": True})
        elif '/reset' in self.path:
            self._send_json(200, {"success": True})
        elif '/sftp/auth' in self.path:
            self._send_json(200, {"success": True, "server": {"uuid": "fake"}})
        else:
            self._send_json(200, {"success": True, "path": self.path})

def main():
    print(f"""
   ╔═══════════════════════════════════════════════════════╗
   ║   fake-wings — Pterodactyl Wings stand-in            ║
   ╚═══════════════════════════════════════════════════════╝

   Node UUID: {NODE_UUID}
   Listen:    0.0.0.0:{LISTEN_PORT}

   This emulates Wings' /api/system endpoint so the Panel shows
   the node as ONLINE (green heart). Real game servers cannot
   be hosted on Railway — see README for VPS providers.

""")
    server = HTTPServer(('0.0.0.0', LISTEN_PORT), FakeWingsHandler)
    print(f"✅ Listening on http://0.0.0.0:{LISTEN_PORT}")
    print("   Press Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n👋 Shutting down.")
        server.shutdown()

if __name__ == '__main__':
    main()
