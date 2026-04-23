#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  install-oraclaw.sh
#
#  One-stop installer for OpenClaw on an Oracle Cloud "Always Free" Ubuntu
#  24.04 Minimal VM (aarch64 / Ampere A1).  Sets up:
#
#    - base packages + apt upgrade for pending security patches
#    - swap (auto-sized to ~2/3 of detected RAM)
#    - nvm + Node.js 24.15.0
#    - Tailscale + tailscale serve (HTTPS dashboard, tailnet-only)
#    - OpenClaw via npm, running as user `ubuntu`
#    - systemd user service with hardening drop-in + Restart=always
#    - one heartbeat cron job every 6 hours (isolated session)
#    - update-safety watchdog: 60s /health probe, auto-restart on 2 fails
#    - SSH hardening, fail2ban, UFW default-deny, unattended-upgrades
#
#  Run AS THE ubuntu USER on a fresh OCI VM.
#
#    From your client machine (Mac or Windows 11 PowerShell):
#      scp ~/oraclaw/scripts/install-oraclaw.sh my-oraclaw:/tmp/
#      ssh my-oraclaw 'bash /tmp/install-oraclaw.sh'
#
#    Or, if the VM already has git + clone access:
#      git clone https://github.com/TomCruiseTorpedo/oraclaw.git ~/oraclaw
#      bash ~/oraclaw/scripts/install-oraclaw.sh
#
#  The script is idempotent.  Safe to re-run if it stops partway.
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Config — override any of these via environment variables ──────────────────
NODE_VERSION="${NODE_VERSION:-24.15.0}"
NVM_VERSION="${NVM_VERSION:-v0.40.4}"
ASSISTANT_NAME="${ASSISTANT_NAME:-}"
TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY:-}"
OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-}"
# TIMEZONE: override via env var, or leave unset to be prompted interactively.
# Default (on Enter): America/Edmonton.  Type your own — e.g. America/New_York,
# America/Toronto, America/Vancouver, America/Chicago, Europe/London, Asia/Tokyo.
TIMEZONE="${TIMEZONE:-}"
# SWAP_GB: if unset, auto-sized to ~2/3 of detected RAM in step [2/13].
# 6 GB RAM → 4 GB swap; 12 GB → 8 GB; 24 GB → 16 GB.  Override with SWAP_GB=<N>.
SWAP_GB="${SWAP_GB:-}"

# Model allowlist — primary + 5 free fallbacks.  Every slug is prefixed
# with "openrouter/" so it routes through the OpenRouter plugin (one API
# key) rather than per-provider plugins (which would each need their own
# key).  If you see "Unknown model: X" in the logs, a missing prefix is
# almost always the cause.
MODELS=(
  "openrouter/nvidia/nemotron-3-super-120b-a12b:free"
  "openrouter/google/gemma-4-31b-it:free"
  "openrouter/minimax/minimax-m2.5:free"
  "openrouter/z-ai/glm-4.5-air:free"
  "openrouter/qwen/qwen3-coder:free"
)
PRIMARY_MODEL="openrouter/nvidia/nemotron-3-super-120b-a12b:free"

# Heartbeat uses a smaller, faster model than the main chain.  Heartbeats
# fire far more often than user-initiated work; a 3B free model here vs.
# the 120B main-chain fallback is a ~100× cost difference.
HEARTBEAT_MODEL="openrouter/meta-llama/llama-3.2-3b-instruct:free"

# ── Pretty output ─────────────────────────────────────────────────────────────
BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
say()  { echo -e "${BOLD}${GREEN}▶${NC}${BOLD} $*${NC}"; }
warn() { echo -e "${BOLD}${YELLOW}⚠${NC}${BOLD} $*${NC}"; }
die()  { echo -e "${BOLD}${RED}✖${NC}${BOLD} $*${NC}" >&2; exit 1; }
ask()  { local prompt="$1" var="$2" silent="${3:-0}"; local val=""
  while [[ -z "$val" ]]; do
    if [[ "$silent" == "1" ]]; then read -r -s -p "  $prompt: " val; echo ""
    else                             read -r    -p "  $prompt: " val
    fi
  done
  printf -v "$var" '%s' "$val"
}

# Generate a UUIDv4-formatted string (no extra packages required)
uuid_v4() {
  openssl rand -hex 16 | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\).*/\1-\2-\3-\4-\5/'
}

# ── Preflight ────────────────────────────────────────────────────────────────
[[ $(whoami) == "ubuntu" ]] || die "Run as ubuntu (not root, not $USER)."
[[ $(uname -s) == "Linux" ]] || die "Linux only."
[[ -f /etc/os-release ]] && source /etc/os-release || die "/etc/os-release missing."
[[ "${ID:-}" == "ubuntu" ]] || warn "Not Ubuntu (got $ID) — continuing anyway."

say "Oraclaw installer — $(date -Iseconds)"
say "Host:   $(hostname)"
say "Arch:   $(uname -m)"
say "Ubuntu: ${VERSION_ID:-?}"

# ── Collect inputs (if not passed via env) ────────────────────────────────────
[[ -z "$ASSISTANT_NAME"     ]] && ask "Assistant name (e.g. Jarvis, Friday, Watson, or whatever you like)" ASSISTANT_NAME
[[ -z "$TAILSCALE_AUTH_KEY" ]] && ask "Tailscale auth key (tskey-auth-...)" TAILSCALE_AUTH_KEY 1
[[ -z "$OPENROUTER_API_KEY" ]] && ask "OpenRouter API key (sk-or-...)"      OPENROUTER_API_KEY 1
if [[ -z "$TIMEZONE" ]]; then
  read -r -p "  Timezone [America/Edmonton — press Enter to accept, or type e.g. America/New_York]: " TIMEZONE
  TIMEZONE="${TIMEZONE:-America/Edmonton}"
fi

# Strip whitespace from pasted values.  Browsers and copy buttons frequently
# pick up trailing newlines or leading spaces that break auth silently.
# ASSISTANT_NAME is left alone — "Mr Jarvis" / "Ada Lovelace" are valid.
TAILSCALE_AUTH_KEY=$(printf '%s' "$TAILSCALE_AUTH_KEY" | tr -d '[:space:]')
OPENROUTER_API_KEY=$(printf '%s' "$OPENROUTER_API_KEY" | tr -d '[:space:]')
TIMEZONE=$(printf '%s'            "$TIMEZONE"          | tr -d '[:space:]')

echo ""
say "Proceeding with:"
echo "    Assistant name:  $ASSISTANT_NAME"
echo "    Tailscale key:   ${TAILSCALE_AUTH_KEY:0:12}…(redacted)"
echo "    OpenRouter key:  ${OPENROUTER_API_KEY:0:10}…(redacted)"
echo "    Timezone:        $TIMEZONE"
echo "    Node version:    $NODE_VERSION"
echo "    Primary model:   $PRIMARY_MODEL"
echo ""

# ── 1. Apt baseline ───────────────────────────────────────────────────────────
say "[1/13] Updating system + installing base packages (a few minutes on a fresh minimal image)…"
sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
# Catch security patches that post-date the base image.  Unattended-upgrades
# (step 13) handles subsequent drift in the background.
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  git curl wget ca-certificates gnupg jq unzip build-essential htop \
  tmux mosh ufw fail2ban unattended-upgrades tzdata lsof \
  ripgrep fzf zoxide bat eza net-tools dnsutils sysstat \
  mtr-tiny fd-find ncdu tree iotop iperf3 glow pandoc btop procs

# Ubuntu/Debian rename fd → fdfind and bat → batcat to avoid package-name
# collisions. Add symlinks so the canonical names Just Work for people (and
# for the Claws themselves when they shell out).
for pair in "fdfind fd" "batcat bat"; do
  src=$(echo "$pair" | awk '{print $1}'); dst=$(echo "$pair" | awk '{print $2}')
  if command -v "$src" >/dev/null && ! command -v "$dst" >/dev/null; then
    sudo ln -sf "$(command -v "$src")" "/usr/local/bin/$dst"
  fi
done

# GitHub CLI (gh) — not in default Ubuntu apt repos; add GitHub's official repo.
if ! command -v gh >/dev/null 2>&1; then
  say "   installing GitHub CLI (gh) via GitHub's apt repo…"
  sudo mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gh
fi

# yq (mikefarah's Go-based YAML processor — NOT the python-yq in Ubuntu apt).
# Direct binary install from GitHub releases; cleaner than snap.
if ! command -v yq >/dev/null 2>&1; then
  say "   installing yq (mikefarah)…"
  YQ_ARCH=$(dpkg --print-architecture)
  sudo curl -fsSL -o /usr/local/bin/yq \
    "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${YQ_ARCH}"
  sudo chmod +x /usr/local/bin/yq
fi

sudo timedatectl set-timezone "$TIMEZONE" || warn "Couldn't set tz $TIMEZONE"

# ── 2. Swap ──────────────────────────────────────────────────────────────────
_RAM_GB=$(awk '/^MemTotal:/ { printf "%d\n", ($2 + 524288) / 1048576 }' /proc/meminfo)
if [[ -z "$SWAP_GB" ]]; then
  SWAP_GB=$(awk '/^MemTotal:/ { printf "%d\n", ($2 * 2 / 3 + 524288) / 1048576 }' /proc/meminfo)
  say "[2/13] Ensuring ${SWAP_GB}G swap (auto-sized to ~2/3 of detected ${_RAM_GB}G RAM)…"
else
  say "[2/13] Ensuring ${SWAP_GB}G swap (explicit override on ${_RAM_GB}G RAM)…"
fi
if swapon --show | grep -q /swapfile; then
  say "   swap already present: $(swapon --show | tail -n+2)"
else
  sudo fallocate -l "${SWAP_GB}G" /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile >/dev/null
  sudo swapon /swapfile
  grep -qE '^/swapfile\s' /etc/fstab || echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
  say "   swap created and mounted"
fi

# ── 3. NVM + Node ────────────────────────────────────────────────────────────
say "[3/13] Installing nvm ${NVM_VERSION} + Node ${NODE_VERSION}…"
if [[ ! -s "$HOME/.nvm/nvm.sh" ]]; then
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi
# shellcheck source=/dev/null
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"
if ! nvm ls "$NODE_VERSION" >/dev/null 2>&1; then
  nvm install "$NODE_VERSION"
fi
nvm alias default "$NODE_VERSION" >/dev/null
nvm use "$NODE_VERSION" >/dev/null
say "   node: $(node -v)  npm: $(npm -v)"

# ── 4. Tailscale ─────────────────────────────────────────────────────────────
say "[4/13] Installing Tailscale…"
if ! command -v tailscale >/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
if ! sudo tailscale status >/dev/null 2>&1; then
  sudo tailscale up --ssh --auth-key="$TAILSCALE_AUTH_KEY" --accept-routes=false
  say "   tailnet joined"
else
  say "   tailnet already joined: $(sudo tailscale status | head -1 | awk '{print $2}')"
fi
TAILNET_FQDN="$(sudo tailscale status --self --json 2>/dev/null | jq -r '.Self.DNSName // empty' | sed 's/\.$//')"
[[ -n "$TAILNET_FQDN" ]] || die "Could not determine tailnet FQDN."
say "   FQDN: https://${TAILNET_FQDN}"

# ── 5. OpenClaw install ──────────────────────────────────────────────────────
say "[5/13] Installing OpenClaw (npm -g openclaw@latest)…"
if ! command -v openclaw >/dev/null; then
  npm install -g openclaw@latest
fi
say "   openclaw $(openclaw --version 2>&1 | head -1) installed at $(which openclaw)"

# ── 6. Write openclaw.json ───────────────────────────────────────────────────
say "[6/13] Writing ~/.openclaw/openclaw.json…"
mkdir -p "$HOME/.openclaw/agents/main/agent" "$HOME/.openclaw/cron"
chmod 700 "$HOME/.openclaw"

# Secure token generation
GATEWAY_TOKEN="$(openssl rand -hex 24)"

# Build models JSON blocks via jq to avoid quoting hell.  The heartbeat
# model must appear in the registry (as a key) but NOT in the fallbacks
# chain — it's the primary for the heartbeat role, not a fallback.
ALL_MODELS=("${MODELS[@]}" "$HEARTBEAT_MODEL")
MODELS_JSON=$(printf '%s\n' "${ALL_MODELS[@]}" | jq -R . | jq -s 'map({(.): {}}) | add')
FALLBACKS_JSON=$(printf '%s\n' "${MODELS[@]}" | jq -R . | jq -s '.[1:]')

if [[ -f "$HOME/.openclaw/openclaw.json" ]]; then
  cp "$HOME/.openclaw/openclaw.json" "$HOME/.openclaw/openclaw.json.preinstall.$(date +%s)"
fi

cat > "$HOME/.openclaw/openclaw.json" <<JSON
{
  "agents": {
    "defaults": {
      "workspace": "$HOME/.openclaw/workspace",
      "models": $MODELS_JSON,
      "model": {
        "primary": "$PRIMARY_MODEL",
        "fallbacks": $FALLBACKS_JSON
      },
      "heartbeat": {
        "isolatedSession": true,
        "lightContext": true,
        "model": "$HEARTBEAT_MODEL"
      }
    }
  },
  "gateway": {
    "mode": "local",
    "auth": { "mode": "token", "token": "$GATEWAY_TOKEN", "allowTailscale": false },
    "port": 18789,
    "bind": "loopback",
    "controlUi": {
      "allowInsecureAuth": false,
      "allowedOrigins": [
        "https://${TAILNET_FQDN}",
        "http://127.0.0.1:18789",
        "http://localhost:18789"
      ]
    },
    "trustedProxies": ["127.0.0.1", "::1", "100.64.0.0/10"]
  },
  "tools": { "profile": "coding", "web": { "search": { "provider": "duckduckgo", "enabled": true } } },
  "auth": { "profiles": { "openrouter:default": { "provider": "openrouter", "mode": "api_key" } } },
  "plugins": { "entries": { "duckduckgo": {"enabled": true}, "openrouter": {"enabled": true} } },
  "update": { "auto": { "enabled": false }, "channel": "stable" },
  "ui": { "assistant": { "name": "$ASSISTANT_NAME" } }
}
JSON
chmod 600 "$HOME/.openclaw/openclaw.json"

# OpenRouter API key via env file (picked up by systemd unit)
echo "OPENROUTER_API_KEY=$OPENROUTER_API_KEY" > "$HOME/.openclaw/.env"
chmod 600 "$HOME/.openclaw/.env"


# ── 7. Heartbeat cron (one job, every 6 hours) ────────────────────────────────
say "[7/13] Configuring heartbeat cron (1 job, every 6 hours, tz $TIMEZONE)…"
JOBS_FILE="$HOME/.openclaw/cron/jobs.json"
if [[ -f "$JOBS_FILE" ]]; then
  say "   jobs.json already exists — leaving it alone"
else
  HEARTBEAT_ID="$(uuid_v4)"
  NOW_MS=$(( $(date +%s) * 1000 ))
  cat > "$JOBS_FILE" <<JOBS
{
  "version": 1,
  "jobs": [
    {
      "id": "$HEARTBEAT_ID",
      "name": "heartbeat",
      "enabled": true,
      "createdAtMs": $NOW_MS,
      "updatedAtMs": $NOW_MS,
      "schedule": { "kind": "cron", "expr": "0 */6 * * *", "tz": "$TIMEZONE" },
      "sessionTarget": "main",
      "wakeMode": "now",
      "payload": { "kind": "systemEvent", "text": "Heartbeat: quick check-in." },
      "state": {
        "nextRunAtMs": 0, "lastRunAtMs": 0,
        "lastRunStatus": "pending", "lastStatus": "pending",
        "lastDurationMs": 0, "lastDeliveryStatus": "not-requested",
        "consecutiveErrors": 0
      }
    }
  ]
}
JOBS
  chmod 600 "$JOBS_FILE"
  say "   default heartbeat written to $JOBS_FILE"
fi

# ── 8. systemd user service ──────────────────────────────────────────────────
say "[8/13] Installing systemd user service…"
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/openclaw-gateway.service" <<SVC
[Unit]
Description=OpenClaw Gateway
After=network-online.target tailscaled.service

[Service]
Type=simple
EnvironmentFile=%h/.openclaw/.env
ExecStart=%h/.nvm/versions/node/v${NODE_VERSION}/bin/node %h/.nvm/versions/node/v${NODE_VERSION}/lib/node_modules/openclaw/dist/entry.js gateway --port 18789

# Restart=always (not on-failure) so the in-process SIGUSR1 supervisor
# restart — triggered by the Control UI "Update" button — is caught by
# systemd even when the process exits code=0.  See docs/RECOVERY.md.
Restart=always
RestartSec=10s

# Hardening — safe subset for systemd USER services.  Do NOT add
# CapabilityBoundingSet / AmbientCapabilities (218/CAPABILITIES on start) or
# directives requiring CAP_SYS_ADMIN such as ProtectKernelTunables,
# ProtectKernelModules, RestrictNamespaces, PrivateDevices.
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=false
LockPersonality=true
RestrictRealtime=true
SystemCallArchitectures=native
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK

[Install]
WantedBy=default.target

[Unit]
# Absorb pathological update loops; the watchdog (installed next) catches
# the rare case where systemd still bails after burst exhaustion.
StartLimitIntervalSec=300
StartLimitBurst=20
SVC

# ── 8b. Update-safety watchdog (belt-and-suspenders to Restart=always) ──────
# If the gateway exits cleanly (exit code 0) and systemd then hits the
# StartLimitBurst ceiling, Restart=always alone isn't enough — we need a
# separate timer to probe /health and kick the service back up.  This is
# the defense-in-depth that makes the Control UI "Update" button safe.
say "   installing update-safety watchdog (60s /health probe)…"
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/openclaw-gateway-watchdog.sh" <<'WATCHDOG'
#!/usr/bin/env bash
# Probe openclaw-gateway /health.  On 2 consecutive failures, clear any
# StartLimit block and restart the service.
set -euo pipefail
HEALTH_URL="http://127.0.0.1:18789/health"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/openclaw-watchdog"
mkdir -p "$STATE_DIR"
COUNT_FILE="$STATE_DIR/fail-count"
code=$(curl -sS -m 4 -o /dev/null -w '%{http_code}' "$HEALTH_URL" 2>/dev/null || echo 000)
if [ "$code" = "200" ]; then rm -f "$COUNT_FILE"; exit 0; fi
n=$(cat "$COUNT_FILE" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > "$COUNT_FILE"
if [ "$n" -lt 2 ]; then
  logger -t openclaw-watchdog "gateway probe failed (http=$code) ${n}/2; will retry"
  exit 0
fi
logger -t openclaw-watchdog "gateway down ${n}x (http=$code); clearing start-limit and restarting"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
systemctl --user reset-failed openclaw-gateway || true
systemctl --user restart openclaw-gateway
rm -f "$COUNT_FILE"
WATCHDOG
chmod 0755 "$HOME/.local/bin/openclaw-gateway-watchdog.sh"

cat > "$HOME/.config/systemd/user/openclaw-gateway-watchdog.service" <<'SVC'
[Unit]
Description=OpenClaw gateway health watchdog (one-shot probe)
After=network.target
[Service]
Type=oneshot
ExecStart=%h/.local/bin/openclaw-gateway-watchdog.sh
SVC
cat > "$HOME/.config/systemd/user/openclaw-gateway-watchdog.timer" <<'TIMER'
[Unit]
Description=Probe openclaw-gateway /health every 60s
[Timer]
OnBootSec=2min
OnUnitActiveSec=60s
AccuracySec=10s
[Install]
WantedBy=timers.target
TIMER

systemctl --user daemon-reload
systemctl --user enable openclaw-gateway.service
systemctl --user enable --now openclaw-gateway-watchdog.timer
sudo loginctl enable-linger "$USER" >/dev/null || warn "loginctl enable-linger failed — service won't start without login"
systemctl --user restart openclaw-gateway.service

# Wait for readiness
say "   waiting for gateway…"
for i in $(seq 1 30); do
  sleep 2
  if curl -sf -o /dev/null http://127.0.0.1:18789/; then
    say "   gateway ready"
    break
  fi
  [[ $i -eq 30 ]] && die "gateway did not become ready after 60s — check 'journalctl --user -u openclaw-gateway'"
done

# ── 9. Tailscale serve (HTTPS 443 → localhost 18789) ─────────────────────────
say "[9/13] Configuring tailscale serve…"
sudo tailscale serve --bg --https=443 http://127.0.0.1:18789 2>&1 | tail -3 || true
sudo tailscale serve status | head -5

# ── 10. SSHD hardening ───────────────────────────────────────────────────────
say "[10/13] Hardening SSHD…"
sudo tee /etc/ssh/sshd_config.d/99-hardening.conf > /dev/null <<SSHD
# Installed by install-oraclaw.sh
PermitRootLogin no
MaxAuthTries 3
LoginGraceTime 20s
AllowUsers ubuntu
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowTcpForwarding yes
PermitUserEnvironment no
SSHD
sudo sshd -t || { sudo rm -f /etc/ssh/sshd_config.d/99-hardening.conf; die "sshd -t failed; rolled back"; }
sudo systemctl reload ssh

# ── 11. fail2ban ─────────────────────────────────────────────────────────────
say "[11/13] Configuring fail2ban…"
sudo tee /etc/fail2ban/jail.local > /dev/null <<F2B
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3
backend = systemd
ignoreip = 127.0.0.1/8 ::1 100.64.0.0/10

[sshd]
enabled = true
port = 22
F2B
sudo systemctl enable --now fail2ban
sudo systemctl restart fail2ban

# ── 12. UFW ──────────────────────────────────────────────────────────────────
say "[12/13] Configuring UFW…"
if ! sudo ufw status | grep -q "Status: active"; then
  sudo ufw --force reset >/dev/null
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow 22/tcp comment "SSH recovery"
  sudo ufw allow in on tailscale0 comment "Tailscale tailnet"
  sudo ufw logging low
  sudo ufw --force enable
else
  say "   ufw already active"
fi

# ── 13. Unattended-upgrades ──────────────────────────────────────────────────
say "[13/13] Enabling unattended security upgrades…"
echo 'APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null

# Persist the dashboard URL in a known location so client-side helpers
# (e.g. scripts/open-dashboard.sh) can find it without prompting.
echo "https://${TAILNET_FQDN}" > "$HOME/.openclaw/dashboard-url"
chmod 600 "$HOME/.openclaw/dashboard-url"

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  Oraclaw installed and hardened.${NC}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}Dashboard URL:${NC}  https://${TAILNET_FQDN}"
echo -e "${BOLD}Login token:${NC}    ${GATEWAY_TOKEN}"
echo ""
echo -e "${BOLD}${YELLOW}✎ Write the token down NOW.  It will not be shown again.${NC}"
echo -e "  (Lost it?  Either run ${BOLD}jq -r .gateway.auth.token ~/.openclaw/openclaw.json${NC} on the VM,"
echo -e "   or — easier — run ${BOLD}open-dashboard.sh${NC}/${BOLD}.ps1${NC} from your client: it re-fetches the"
echo -e "   token and auto-copies it to your clipboard every time.)"
echo ""
echo -e "${BOLD}Next steps (run these from your CLIENT machine, not this VM):${NC}"
echo ""
echo "  1. Open the dashboard and auto-copy the login token to your clipboard:"
echo -e "       ${BOLD}Mac:${NC}      bash ~/oraclaw/scripts/open-dashboard.sh"
echo -e "       ${BOLD}Windows:${NC}  & \$env:USERPROFILE\\oraclaw\\scripts\\open-dashboard.ps1"
echo ""
echo "  2. In the browser, click the ⚙ Settings gear → paste (⌘V / Ctrl+V) → Save."
echo ""
echo -e "  3. The dashboard will say ${BOLD}\"Device pairing required\"${NC} — this is NORMAL, not an error."
echo "     Approve this browser from your client:"
echo -e "       ${BOLD}Mac:${NC}      bash ~/oraclaw/scripts/approve-pairing.sh"
echo -e "       ${BOLD}Windows:${NC}  & \$env:USERPROFILE\\oraclaw\\scripts\\approve-pairing.ps1"
echo ""
echo "  4. Refresh the browser.  Send a test message like \"Hello! Say hi back.\""
echo "     (First reply may take 20-30 s while the model warms up — that's normal.)"
echo ""
echo -e "${BOLD}Useful ops commands (on this VM):${NC}"
echo "  status:   systemctl --user status openclaw-gateway"
echo "  logs:     journalctl --user -u openclaw-gateway -f"
echo "  restart:  systemctl --user restart openclaw-gateway"
echo "  ufw:      sudo ufw status"
echo "  f2b:      sudo fail2ban-client status sshd"
echo ""
