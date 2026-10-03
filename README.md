# Ubuntu 24.04 VPS on Railway (with Docker, for Pterodactyl Panel + Wings)

> A clean Ubuntu VPS you can SSH into as **root**, install any panel on (Pterodactyl, aaPanel, HestiaCP, CyberPanel), and run Docker containers for game servers.

## 🚀 Deploy on Railway (3 minutes)

### Step 1 — Create the Railway service

1. Go to https://railway.app → **New Project** → **Deploy from GitHub repo**
2. Pick this repo (`yobbyking/ubuntu-vps`)
3. Railway auto-detects the Dockerfile and starts building (~5 min for first build)

### Step 2 — Set environment variables

In Railway → your service → **Variables** tab, add:

| Variable | Value | Required? |
|----------|-------|-----------|
| `VPS_USERNAME` | `root` | ✅ |
| `VPS_PASSWORD` | `2026yobby` (or any strong password — change this!) | ✅ |
| `VPS_PUBLIC_KEY` | Your `~/.ssh/id_ed25519.pub` (optional, for SSH key auth) | ⬜ |
| `VPS_SSH_PORT` | `22` | ⬜ |

⚠️ **Change your password!** The default `2026yobby` is in the repo and anyone can see it. Set a unique strong password (16+ chars) like `Xy7$Pq2!mB9#wK4e` via Railway env vars.

### Step 3 — Expose SSH publicly (Public TCP)

1. Railway → your service → **Settings** → **Networking**
2. Click **"Public TCP"** and enable it for port `22`
3. Railway gives you an address like:
   ```
   tcp-abc123-xyz.up.railway.app:54321
   ```
   (port is random — Railway assigns one)

### Step 4 — Log in with Termius

#### A) Add a new host in Termius

1. Open **Termius** (download from https://termius.com — free tier works)
2. Click **"New Host"** (or `+` button → Host)
3. Fill in:

| Field | Value |
|-------|-------|
| **Label** | `My Ubuntu VPS` (any name) |
| **Hostname** | `tcp-abc123-xyz.up.railway.app` (from Railway) |
| **Port** | `54321` (from Railway — the random port, NOT 22) |
| **Username** | `root` |
| **Password** | `2026yobby` (or your custom password) |

4. Click **Save**
5. Click the host to connect — you'll be in your Ubuntu VPS!

#### B) See the welcome banner

After login, you'll see:
```
   ╔═══════════════════════════════════════════════════════╗
   ║   Your Ubuntu 24.04 VPS with Docker — ready for     ║
   ║   Pterodactyl Panel & Wings                          ║
   ╚═══════════════════════════════════════════════════════╝
```

## 🌐 Accessing the Panel from your browser (after install)

The Panel listens on port **80 inside the VPS**, but Railway only exposes SSH (port 22 → 10754) via Public TCP. To open the Panel in your browser, use **SSH port-forwarding**:

### Method 1: Termius Port Forwarding (recommended — keeps tunnel alive)

1. Open **Termius** → click your host → **Port Forwarding** tab
2. Click **+ Add Rule** and fill in:

| Field | Value |
|-------|-------|
| **Label** | `Pterodactyl Panel` |
| **Type** | `Local` |
| **Local Host** | `localhost` |
| **Local Port** | `8080` |
| **Remote Host** | `localhost` |
| **Remote Port** | `80` |
| **Use Host** | (select your Ubuntu VPS host) |

3. Click **Save** → toggle the rule **ON**
4. In your browser, open: **http://localhost:8080**
5. 🎉 The Pterodactyl login page appears!

### Method 2: Command-line SSH tunnel (one-liner)

From any terminal:
```bash
ssh -L 8080:localhost:80 -N root@altaria.proxy.rlwy.net -p 10754
# Then open http://localhost:8080 in your browser
# (Keep this terminal open while you use the Panel)
```

### Method 3: Expose publicly via another Railway Public TCP

Railway lets you add MULTIPLE Public TCP ports. Add another for port `80`:
1. Railway → your service → **Settings** → **Networking** → **Public TCP** → Add another port `80`
2. Railway gives you a second address like `tcp-xyz-abc.up.railway.app:32198`
3. Open `http://tcp-xyz-abc.up.railway.app:32198` in your browser

⚠️ **Public exposure warning**: Anyone with this URL can hit your Panel. Use HTTPS + a strong admin password if you go this route.

## 🐦 Installing Pterodactyl

### Quick install

```bash
install-ptero          # Interactive menu (Panel + Wings)
start-ptero-services   # Start MariaDB + Redis + PHP-FPM + Nginx + queue worker
```

### ⚠️ Important: Railway + Docker limitation

Pterodactyl Wings (the game-server daemon) needs Docker to spawn containers. On Railway:
- Docker **CLI** is installed and works
- Docker **daemon** will likely FAIL to start because Railway containers are not privileged by default

When you run `docker ps` you'll see:
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
```

### What this means for you

| Component | Works on Railway? |
|-----------|-------------------|
| SSH access as root | ✅ Yes |
| Install Pterodactyl Panel (web UI) | ✅ Yes (but needs port 80/443 public) |
| Install Pterodactyl Wings (game daemon) | ❌ No (Docker daemon won't start) |
| Run Minecraft / game servers | ❌ No (needs Wings + Docker) |

### Recommended: Real VPS for Pterodactyl

For actual game-server hosting with Pterodactyl Wings, deploy this same Dockerfile on a real VPS where Docker works natively:

| Provider | Min price | Free credit? | Notes |
|----------|-----------|---------------|-------|
| **Hetzner** | €4.59/mo | €20 sign-up | Best price/performance in EU/US |
| **DigitalOcean** | $4/mo | $200 credit 60 days | Referral credit easy to find |
| **Vultr** | $5/mo | $100 credit 30 days | Many regions |
| **Linode (Akamai)** | $5/mo | $100 credit 60 days | Solid, simple |
| **Contabo** | €4.50/mo | none | Best RAM/€ in EU |

For Railway: use it as your development/admin VPS, or for the Pterodactyl Panel only. Use a real VPS for Wings.

## 🧰 What's pre-installed

| Tool | Why |
|------|-----|
| **Ubuntu 24.04 LTS** | Latest LTS base |
| **Docker** (CLI + daemon) | Required by Pterodactyl Wings |
| **Node.js 20 LTS** | Pterodactyl Wings runtime |
| **Bun** | Modern JS runtime (faster than Node) |
| **PHP 8.2 + Composer** | Pterodactyl Panel backend |
| **Nginx** | Web server for Panel UI |
| **Certbot** | Free Let's Encrypt SSL certs |
| **MariaDB / PostgreSQL / Redis clients** | Talk to your DBs |
| **Git, vim, nano, tmux, btop, htop** | Dev workflow |
| **Python 3, build-essential** | Scripts + native module compilation |
| **UFW** | Firewall (be careful with SSH rules!) |
| **zsh, fish** | Alternative shells |

## 📋 Common commands

```bash
# After SSH in:
install-ptero                          # Pterodactyl installer menu
install-ptero panel                    # Install Panel
install-ptero wings                    # Install Wings
install-ptero status                   # Check what's installed

docker ps                              # Check Docker daemon
docker info                            # Detailed Docker info
btop                                   # Live system monitor
tmux new -s work                       # Persistent session (reattach: tmux a -t work)
df -h && free -h                      # Disk + memory check
sudo -i                                # Already root, but confirms
passwd                                 # Change root password
```

## 🔄 Persistence — IMPORTANT

⚠️ **Container filesystem is ephemeral** — without a volume, anything you install or save will be LOST on container restart.

To make `/root` persist across restarts:

1. Railway → your service → **Settings** → **Volumes** → **Add Volume**
2. Mount path: `/root` (or wherever you want persistence)
3. Click **Add Volume**

Now your home directory, installed packages (in `/root`), and Pterodactyl data persist across restarts and deploys.

For Pterodactyl specifically, you may also want to mount these paths:
- `/var/lib/pterodactyl` — Wings server data
- `/var/www/pterodactyl` — Panel files
- `/etc/pterodactyl` — Wings config
- `/var/lib/docker` — Docker images + containers (this gets HUGE)

## 🔌 Ports exposed

The Dockerfile exposes these ports. On Railway, only ONE port can be public per service (or one HTTP + one TCP). For full Pterodactyl you need multiple ports — that means **multiple Railway services** or a **real VPS**.

| Port | Service |
|------|---------|
| 22 | SSH |
| 80 / 443 | Panel web UI (HTTP/HTTPS) |
| 8080 / 8443 | Wings daemon API |
| 2022 | First game-server port (Pterodactyl allocates 2022-8222 by default) |
| 3306 / 5432 / 6379 | DBs (if you install them) |

## 🛠 Customize

Edit the Dockerfile to add packages. Common Pterodactyl additions:

```dockerfile
# MariaDB server (for Panel's local DB)
RUN apt-get update && apt-get install -y mariadb-server && rm -rf /var/lib/apt/lists/*

# Tailwind / CSS tools for themeing the Panel
RUN npm install -g tailwindcss

# Java 17 (for Minecraft servers via Wings)
RUN apt-get update && apt-get install -y openjdk-17-jre-headless && rm -rf /var/lib/apt/lists/*
```

After editing, push to your fork — Railway auto-redeploys.

## 🆘 Troubleshooting

**Can't SSH in with Termius**
- Double-check the Railway public TCP hostname and port (NOT 22 — Railway assigns a random port)
- Verify `VPS_PASSWORD` is set correctly in Railway env vars
- In Termius, enable "Use legacy KEX" if you see "key exchange failed"
- Try verbose: in Termius, toggle "SSH debug logging" in the host settings

**Permission denied (publickey)**
- If you set `VPS_PUBLIC_KEY`, ensure your private key has correct perms: `chmod 600 ~/.ssh/id_ed25519`
- Without `VPS_PUBLIC_KEY`, password auth should work by default

**Docker daemon won't start (Can't connect to docker.sock)**
- This is expected on Railway — containers aren't privileged
- For real Docker, deploy on Hetzner/DigitalOcean/Vultr (see "Recommended VPS" above)

**Container restarts and loses data**
- Add a Railway volume mounted at `/root` (see Persistence section)

**`install-ptero` says "Permission denied"**
- Run: `sudo install-ptero panel` (or log in as root directly)

## 📦 Repository structure

```
ubuntu-vps/
├── Dockerfile           # Ubuntu 24.04 + Docker + Pterodactyl prereqs
├── entrypoint.sh        # Sets root password, starts sshd, tries docker
├── install-ptero.sh     # Pterodactyl Panel + Wings installer
├── railway.json         # Railway deploy config
└── README.md            # This file
```

## 📝 License

MIT — do whatever you want with this template.
