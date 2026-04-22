#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  bootstrap-mac.sh
#
#  Prepares a fresh Mac (Apple Silicon, macOS 13+) to connect to and manage an
#  Oraclaw OpenClaw instance on Oracle Cloud.  Assumes NOTHING is installed —
#  not even Homebrew.
#
#  Usage:
#
#      # If git isn't installed yet, this triggers the Xcode Command Line
#      # Tools installer popup. Click "Install" and wait a few minutes.
#      if ! command -v git >/dev/null; then xcode-select --install; fi
#
#      # Clone the kit into ~/oraclaw:
#      git clone https://github.com/TomCruiseTorpedo/oraclaw.git ~/oraclaw
#
#      # Run this script:
#      bash ~/oraclaw/scripts/bootstrap-mac.sh
#
#  Idempotent.  Safe to re-run as many times as you want.
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
say()   { echo -e "${BOLD}${GREEN}▶${NC}${BOLD} $*${NC}"; }
info()  { echo -e "${CYAN}ℹ${NC} $*"; }
warn()  { echo -e "${BOLD}${YELLOW}⚠${NC}${BOLD} $*${NC}"; }
pause() { echo -e "${BOLD}${CYAN}…press Enter to continue…${NC}"; read -r _; }

# ── Preflight ────────────────────────────────────────────────────────────────
[[ "$(uname -s)" == "Darwin" ]] || { echo "This script is macOS only." >&2; exit 1; }
if [[ "$(uname -m)" != "arm64" ]]; then
  echo "This kit targets Apple Silicon Macs (M1 / M2 / M3 / M4 / M5) only." >&2
  echo "Detected architecture: $(uname -m)." >&2
  echo "Intel Macs are not supported — consider running the Windows 11 client" >&2
  echo "path on a Windows PC, or ask the maintainer about adding Intel support." >&2
  exit 1
fi

cat <<'BANNER'
╔════════════════════════════════════════════════════════════════════╗
║                                                                    ║
║   Oraclaw Mac bootstrap — preparing this Mac to manage your        ║
║   OpenClaw VM on Oracle Cloud.                                     ║
║                                                                    ║
║   What this does:                                                  ║
║     1. Installs Xcode Command Line Tools (~300 MB, one-time)       ║
║     2. Installs Homebrew (package manager for developer tools)     ║
║     3. Installs: git, mosh, tmux, jq, Tailscale                    ║
║     4. Creates an SSH key (if you don't already have one)          ║
║     5. Walks you through connecting to Tailscale                   ║
║     6. Sets up a shortcut name for your VM                         ║
║                                                                    ║
║   Estimated time: 10-15 minutes, mostly waiting on downloads.      ║
║                                                                    ║
╚════════════════════════════════════════════════════════════════════╝
BANNER
echo ""
pause

# ── 1. Xcode Command Line Tools ──────────────────────────────────────────────
say "[1/6] Checking for Xcode Command Line Tools…"
if xcode-select -p >/dev/null 2>&1; then
  info "already installed at $(xcode-select -p)"
else
  warn "A popup will appear.  Click 'Install' (NOT 'Get Xcode' — we don't need full Xcode)."
  warn "It takes 5-10 minutes.  Wait until it says 'Software was installed'."
  xcode-select --install || true
  echo ""
  info "Waiting for installation to complete…"
  while ! xcode-select -p >/dev/null 2>&1; do sleep 5; done
  info "Command Line Tools installed"
fi

# ── 2. Homebrew ──────────────────────────────────────────────────────────────
say "[2/6] Checking for Homebrew…"
if command -v brew >/dev/null 2>&1; then
  info "already installed: $(brew --version | head -1)"
else
  warn "Installing Homebrew.  It may ask for your Mac password."
  warn "When you type your password, nothing shows on screen — that's normal and intentional."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Ensure brew is in PATH for this script + future shells (Apple Silicon only)
if [[ -x /opt/homebrew/bin/brew ]]; then
  BREW_BIN=/opt/homebrew/bin/brew
else
  warn "Homebrew install didn't complete — check the output above."
  exit 1
fi

# Add to ~/.zprofile for future terminal sessions
ZPROFILE="$HOME/.zprofile"
if ! grep -q 'brew shellenv' "$ZPROFILE" 2>/dev/null; then
  echo "eval \"\$($BREW_BIN shellenv)\"" >> "$ZPROFILE"
  info "added Homebrew to $ZPROFILE"
fi
eval "$($BREW_BIN shellenv)"

# ── 3. Required tools ─────────────────────────────────────────────────────────
say "[3/6] Installing git, mosh, tmux, jq…"
brew install git mosh tmux jq

say "Installing Tailscale (menu-bar app)…"
if ! brew list --cask tailscale >/dev/null 2>&1; then
  brew install --cask tailscale
  info "Tailscale.app installed in /Applications"
else
  info "Tailscale.app already installed"
fi

# Ensure the Oraclaw repo is cloned locally (covers the curl | bash install
# flow where the user hasn't run `git clone` yet).
REPO_DIR="$HOME/oraclaw"
if [[ ! -d "$REPO_DIR" ]]; then
  say "Cloning the Oraclaw repo into $REPO_DIR…"
  git clone https://github.com/TomCruiseTorpedo/oraclaw.git "$REPO_DIR"
  info "repo cloned"
else
  info "Oraclaw repo already at $REPO_DIR"
fi

# ── 4. SSH key ───────────────────────────────────────────────────────────────
say "[4/6] SSH key check…"
SSH_KEY="$HOME/.ssh/id_ed25519"
if [[ -f "$SSH_KEY" ]]; then
  info "SSH key already exists at $SSH_KEY"
else
  warn "Creating a new SSH key.  Press Enter 3 times when prompted (accept all defaults)."
  ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "$(whoami)@$(hostname -s)-$(date +%Y%m%d)"
  info "SSH key created"
fi

echo ""
info "Your PUBLIC SSH key (paste this into Oracle Cloud when creating your VM):"
echo ""
echo -e "${BOLD}${CYAN}$(cat "${SSH_KEY}.pub")${NC}"
echo ""
pause

# ── 5. Tailscale connection ──────────────────────────────────────────────────
say "[5/6] Connecting to Tailscale…"
if pgrep -q Tailscale; then
  info "Tailscale app is already running."
else
  warn "Opening the Tailscale app now.  When it opens:"
  warn "  1. Click the Tailscale icon in your menu bar (top-right of your screen)."
  warn "  2. Click 'Log in' and sign in with Google, GitHub, Microsoft, or"
  warn "     Apple — whichever account you want to use (or create a new"
  warn "     Tailscale account if you don't have one yet)."
  warn "  3. Approve this device."
  open -a Tailscale || true
  echo ""
  info "Waiting for Tailscale to come online…"
  while ! /opt/homebrew/bin/tailscale status >/dev/null 2>&1 \
     && ! /Applications/Tailscale.app/Contents/MacOS/Tailscale status >/dev/null 2>&1; do
    sleep 3
  done
  info "Tailscale online"
fi

# ── 6. SSH config alias ──────────────────────────────────────────────────────
say "[6/6] Add an SSH shortcut for your OCI VM"
echo ""
info "If you haven't created your Oracle Cloud VM yet, stop here and go do it now."
info "(Follow docs/FIELD-MANUAL.md, Section 3.  Come back when the VM is running"
info " and visible in the Tailscale app.)"
echo ""
read -r -p "  Tailscale hostname of your VM (e.g. my-oraclaw): " TS_HOST
read -r -p "  Your tailnet subdomain — find it in Tailscale app → Network → DNS (the part before .ts.net): " TS_NET

# Strip whitespace from pasted/typed values
TS_HOST=$(printf '%s' "$TS_HOST" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
TS_NET=$(printf '%s'  "$TS_NET"  | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')

# Validate against the actual tailnet before writing anything.  Catches
# hostname / subdomain typos — by far the most common support issue.
TARGET_DNS="${TS_HOST}.${TS_NET}.ts.net."
TS_CLI=""
for cand in /opt/homebrew/bin/tailscale /Applications/Tailscale.app/Contents/MacOS/Tailscale; do
  if [[ -x "$cand" ]]; then TS_CLI="$cand"; break; fi
done

if [[ -n "$TS_CLI" ]]; then
  MATCH=$("$TS_CLI" status --json 2>/dev/null | jq -r --arg fqdn "$TARGET_DNS" '
    [.Self] + (.Peer // {} | to_entries | map(.value))
    | .[]
    | select(.DNSName == $fqdn)
    | .HostName
  ' | head -1)

  if [[ -z "$MATCH" ]]; then
    echo ""
    warn "Couldn't find a tailnet device at ${TS_HOST}.${TS_NET}.ts.net."
    echo ""
    info "Here's what is currently on your tailnet:"
    "$TS_CLI" status --json 2>/dev/null | jq -r '
      [.Self] + (.Peer // {} | to_entries | map(.value))
      | .[]
      | "    " + (.HostName // "?") + "   →   " + ((.DNSName // "?") | sub("\\.$"; ""))
    '
    echo ""
    echo "Common causes:"
    echo "  • Your VM hasn't joined Tailscale yet — have you run Section 5.1 of the Field Manual?"
    echo "  • A typo in the hostname or the subdomain"
    echo "  • You're logged into a different Tailscale account than the VM is on"
    echo ""
    read -r -p "Continue anyway (the SSH test after this will likely fail)? [y/N] " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy] ]]; then
      warn "Aborted.  Re-run $0 with the correct hostname/subdomain."
      exit 1
    fi
  else
    info "✓ Found '$MATCH' on your tailnet at ${TS_HOST}.${TS_NET}.ts.net"
  fi
fi

SSH_CONFIG="$HOME/.ssh/config"
mkdir -p "$HOME/.ssh"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

if grep -q "^Host ${TS_HOST}$" "$SSH_CONFIG"; then
  info "SSH config already has '$TS_HOST' — leaving it alone."
else
  cat >> "$SSH_CONFIG" <<EOF

Host ${TS_HOST}
    HostName ${TS_HOST}.${TS_NET}.ts.net
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
EOF
  info "added '$TS_HOST' alias to $SSH_CONFIG"
fi

echo ""
say "Testing SSH connection to ${TS_HOST}…"
if ssh -o ConnectTimeout=5 -o BatchMode=yes "${TS_HOST}" "echo 'SSH works: \$(whoami)@\$(hostname)'" 2>&1; then
  info "SSH to ${TS_HOST} works!"
else
  warn "SSH test failed.  Likely reasons:"
  warn "  • VM isn't running yet"
  warn "  • Your SSH public key wasn't added to the VM during OCI setup"
  warn "  • Tailscale on the VM hasn't connected yet"
  warn "See docs/FIELD-MANUAL.md § 9 Troubleshooting → 'SSH fails'"
fi

echo ""
cat <<BANNER
╔════════════════════════════════════════════════════════════════════╗
║                                                                    ║
║   Mac setup complete.  You can now SSH into your VM with:          ║
║                                                                    ║
║       ssh ${TS_HOST}
║                                                                    ║
║   Next: copy and run the Oraclaw installer on the VM:              ║
║                                                                    ║
║       scp ~/oraclaw/scripts/install-oraclaw.sh \
║           ${TS_HOST}:/tmp/
║       ssh ${TS_HOST} 'bash /tmp/install-oraclaw.sh'
║                                                                    ║
║   Read docs/FIELD-MANUAL.md § 6 for the full walkthrough.          ║
║                                                                    ║
╚════════════════════════════════════════════════════════════════════╝
BANNER
