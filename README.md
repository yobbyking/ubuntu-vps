# Ubuntu 24.04 VPS on Railway

> A clean Ubuntu VPS with SSH access (username + password) you can deploy on Railway and SSH into from anywhere. Pre-installed with Node 20, Bun, Docker CLI, and common dev tools.

## 🚀 Deploy on Railway (5 minutes)

### Step 1 — Create the Railway project

1. Go to https://railway.app → New Project → **Deploy from GitHub repo**
2. Select the `yobbyking/ubuntu-vps` repo (fork it to your account first if you want to customize)
3. Railway auto-detects the Dockerfile and starts building

### Step 2 — Set environment variables

In Railway → your service → **Variables** tab, add:

| Variable | Value | Required? |
|----------|-------|-----------|
| `VPS_USERNAME` | `swiftpay` (or any username you want) | ✅ Yes |
| `VPS_PASSWORD` | A strong password — e.g. `MyStr0ng!Pass2026` | ✅ Yes |
| `VPS_PUBLIC_KEY` | Your SSH public key (optional, enables key auth) | ⬜ Optional |
| `VPS_GIT_REPO` | A git repo to auto-clone on first boot (optional) | ⬜ Optional |
| `VPS_SSH_PORT` | `22` (default — Railway exposes this via Public TCP) | ⬜ Optional |

> **Generate a strong password**: `openssl rand -base64 18` (run in any terminal)

> **Generate an SSH key pair** (optional, more secure than password):
> ```bash
> ssh-keygen -t ed25519 -C "my-vps-key"
> # Then paste the contents of ~/.ssh/id_ed25519.pub into VPS_PUBLIC_KEY env var
> ```

### Step 3 — Expose SSH publicly (Public TCP)

1. In Railway → your service → **Settings** → **Networking**
2. Click **"Public TCP"** and enable it for port `22`
3. Railway gives you a public address like:
   ```
   tcp-abc123-xyz.up.railway.app:54321
   ```
   (the port is random — Railway assigns one)

### Step 4 — SSH into your VPS

```bash
ssh swiftpay@tcp-abc123-xyz.up.railway.app -p 54321
# Enter your VPS_PASSWORD when prompted
```

That's it — you have a full Ubuntu VPS you can SSH into and do anything with.

## 🧰 What's pre-installed

| Tool | Version | Why |
|------|---------|-----|
| **Ubuntu** | 24.04 LTS | Latest LTS base |
| **Node.js** | 20 LTS | For Next.js / Express / any Node app |
| **Bun** | latest | Faster JS runtime + package manager |
| **Docker CLI** | latest | Build & inspect images (no daemon) |
| **Git** | latest | Clone repos |
| **Python 3** | system | Scripts / data processing |
| **build-essential** | gcc, g++, make | Compile native modules (better-sqlite3, sharp, etc.) |
| **vim, nano** | — | Text editors |
| **tmux** | — | Persistent terminal sessions (keep apps running after SSH logout) |
| **htop, lsof, net-tools, dnsutils** | — | Diagnostics |
| **ufw, zsh** | — | Firewall + alternative shell |

## 📦 Quick deploy SwiftPay inside the VPS

Once you SSH in, just run the pre-installed helper:

```bash
swiftpay-deploy
```

This will:
1. Clone `https://github.com/yobbyking/swiftpay` to `~/swiftpay`
2. Print the next steps (set env vars, install deps, build, start)

Then to actually run SwiftPay in the background (survives SSH logout):

```bash
cd ~/swiftpay
cp .env.example .env
nano .env  # fill in DATABASE_URL, JWT_SECRET, SWIFTWALLET_API_KEY etc.
bun install
bun run db:push
bun run build

# Option A — nohup (simple)
nohup bun run start > swiftpay.log 2>&1 &
echo $! > swiftpay.pid

# Option B — tmux (recommended, can reattach to see live logs)
tmux new -d -s swiftpay 'bun run start'
# Reattach: tmux attach -t swiftpay
```

## 🌐 Expose SwiftPay on the internet

Railway gives you one **HTTP** service per project. To run both SSH (TCP) and HTTP (the app) you have two options:

**Option A — Two Railway services (recommended)**
- Service 1: this `ubuntu-vps` repo — exposes SSH on Public TCP
- Service 2: the `yobbyking/swiftpay` repo — exposes HTTP on Railway's default domain

**Option B — Tunnel from inside the VPS**
Use a free tunnel like Cloudflare Tunnel or ngrok to expose port 3000 from your VPS:
```bash
# Inside the VPS, after starting SwiftPay on port 3000:
# Using Cloudflare Tunnel (recommended, free, stable)
sudo apt install cloudflared -y
cloudflared tunnel --url http://localhost:3000

# Or using ngrok
sudo apt install ngrok -y
ngrok http 3000
```

## 🔒 Security tips

1. **Use a strong password** (≥16 chars, mixed case + numbers + symbols). Generate with `openssl rand -base64 18`.
2. **Better: use SSH keys** — set `VPS_PUBLIC_KEY` env var with your `~/.ssh/id_ed25519.pub` contents. Then disable password auth:
   ```bash
   # Once logged in via SSH key:
   sudo sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
   sudo systemctl restart ssh  # or: sudo service ssh restart
   ```
3. **Don't share your password** — rotate it via Railway env vars if compromised.
4. **Enable UFW firewall** (optional, restrictive but be careful not to lock yourself out):
   ```bash
   sudo ufw allow 22/tcp
   sudo ufw enable
   ```
5. **Railway automatically provides DDoS protection** for public endpoints.

## 💰 Railway cost

- **Free trial**: ~$5 credit / 500 hours of usage per month (good for testing)
- **Hobby plan**: $5/month — covers a small VPS + public TCP + custom domain

The Ubuntu VPS image is small (~500MB) and uses minimal CPU/RAM when idle (just sshd). Should fit comfortably in the Hobby plan.

## 🛠 Customize the image

Edit the Dockerfile to add packages. Common additions:

```dockerfile
# Add PostgreSQL client (for db management)
RUN apt-get update && apt-get install -y postgresql-client && rm -rf /var/lib/apt/lists/*

# Add Redis CLI
RUN apt-get update && apt-get install -y redis-tools && rm -rf /var/lib/apt/lists/*

# Add AWS CLI
RUN pip3 install awscli --break-system-packages
```

After editing, push to your fork — Railway auto-redeploys.

## 📋 Common SSH commands

| Action | Command |
|--------|---------|
| Connect | `ssh swiftpay@tcp-xxx.railway.app -p XXXX` |
| Run command without opening shell | `ssh swiftpay@HOST -p PORT "uptime"` |
| Copy file to VPS | `scp -P PORT file.txt swiftpay@HOST:~/` |
| Copy file from VPS | `scp -P PORT swiftpay@HOST:~/file.txt .` |
| Forward local port 8080 to VPS port 3000 | `ssh -L 8080:localhost:3000 swiftpay@HOST -p PORT` |
| Mount remote filesystem | `sshfs swiftpay@HOST:/ /mnt/vps -p PORT` |

## 🔄 Persistence

⚠️ **Container filesystem is ephemeral** — anything written outside `/home/$VPS_USERNAME` may not survive container restarts. Railway preserves the user's home directory if you enable a persistent volume:

1. Railway → your service → **Settings** → **Volumes** → Add Volume
2. Mount path: `/home/swiftpay` (or whatever your `VPS_USERNAME` is)
3. Now your home dir persists across restarts and deploys

Without a volume, you'll lose your `~/swiftpay` and any installed packages on every container restart.

## 📦 Repository structure

```
ubuntu-vps/
├── Dockerfile            # Ubuntu 24.04 + SSH + Node + Bun + dev tools
├── entrypoint.sh         # Creates user, sets password, starts sshd
├── swiftpay-deploy.sh    # Helper script (becomes `swiftpay-deploy` command)
├── railway.json          # Railway config
└── README.md             # This file
```

## 🆘 Troubleshooting

**Can't connect via SSH**
- Verify the public TCP address and port match what Railway shows in Settings → Networking
- Verify env vars `VPS_USERNAME` and `VPS_PASSWORD` are set correctly
- Check service logs in Railway → your service → **Logs** tab
- Try verbose: `ssh -v swiftpay@HOST -p PORT`

**Permission denied (publickey)**
- Make sure you're using password auth (password should work by default)
- If you set `VPS_PUBLIC_KEY`, ensure your private key (`~/.ssh/id_ed25519`) has correct perms: `chmod 600 ~/.ssh/id_ed25519`

**Container restarts/loses data**
- Add a Railway volume mounted at `/home/swiftpay` (see Persistence section)

## 📝 License

MIT — do whatever you want with this template.
