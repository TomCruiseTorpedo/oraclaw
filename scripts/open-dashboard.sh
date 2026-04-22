#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  open-dashboard.sh
#
#  Opens the Oraclaw Control UI dashboard in your default browser AND copies
#  the login token to your clipboard at the same time, so you can paste it
#  straight into the ⚙ Settings panel.
#
#  How it works:
#    1. Figures out which VM to contact (from the arg you pass, or by scanning
#       ~/.ssh/config for the first Host entry that has a .ts.net HostName).
#    2. SSHes to that VM once and pulls both the dashboard URL (from
#       ~/.openclaw/dashboard-url) and the gateway token (from openclaw.json).
#    3. Copies the token to your clipboard via `pbcopy`.
#    4. Opens the URL in your default browser via `open`.
#
#  Usage:
#    bash ~/oraclaw/scripts/open-dashboard.sh                 # auto-detect VM
#    bash ~/oraclaw/scripts/open-dashboard.sh my-oraclaw      # specify VM
#
#  Prerequisites:
#    - You've run bootstrap-mac.sh (sets up the SSH alias)
#    - You've run install-oraclaw.sh on the VM (writes dashboard-url + token)
#    - Your Tailscale is online
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

BOLD='\033[1m'; RED='\033[0;31m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'; NC='\033[0m'
die() { echo -e "${BOLD}${RED}✖${NC}${BOLD} $*${NC}" >&2; exit 1; }

VM_HOST="${1:-}"

# Auto-detect if no VM name was given
if [[ -z "$VM_HOST" ]]; then
  SSH_CONFIG="$HOME/.ssh/config"
  [[ -r "$SSH_CONFIG" ]] || die "~/.ssh/config not found — run bootstrap-mac.sh first, or pass a VM name explicitly: $0 <vm-name>"

  VM_HOST=$(awk '
    $1 == "Host"     { h = $2 }
    $1 == "HostName" && $2 ~ /\.ts\.net$/ { print h; exit }
  ' "$SSH_CONFIG")

  [[ -n "$VM_HOST" ]] || die "No SSH config entry with a .ts.net HostName found.  Run bootstrap-mac.sh, or pass a VM name explicitly: $0 <vm-name>"
fi

echo -e "${CYAN}Fetching dashboard URL + token from ${BOLD}$VM_HOST${NC}${CYAN}…${NC}"

# One SSH call fetches both URL and token, newline-separated.
INFO=$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$VM_HOST" '
URL=$(cat ~/.openclaw/dashboard-url 2>/dev/null || true)
TOKEN=$(jq -r .gateway.auth.token ~/.openclaw/openclaw.json 2>/dev/null || true)
printf "%s\n%s\n" "$URL" "$TOKEN"
' 2>/dev/null || true)

URL=$(printf '%s\n' "$INFO" | sed -n 1p)
TOKEN=$(printf '%s\n' "$INFO" | sed -n 2p)

if [[ -z "$URL" ]]; then
  echo "" >&2
  echo -e "${BOLD}${RED}✖${NC} Could not fetch the dashboard URL from $VM_HOST." >&2
  echo "" >&2
  echo "Likely causes:" >&2
  echo "  • The VM isn't reachable (check Tailscale is online on both your Mac and the VM)" >&2
  echo "  • install-oraclaw.sh hasn't run to completion on the VM yet (it writes" >&2
  echo "    ~/.openclaw/dashboard-url at the end)" >&2
  echo "  • The SSH alias '$VM_HOST' isn't set up in ~/.ssh/config — try: ssh $VM_HOST" >&2
  exit 1
fi

# Copy token to clipboard if we got one
if [[ -n "$TOKEN" && "$TOKEN" != "null" ]] && command -v pbcopy >/dev/null; then
  printf '%s' "$TOKEN" | pbcopy
  echo -e "${GREEN}✓${NC} Login token copied to clipboard — paste (⌘V) into the ⚙ Settings panel after the page loads."
fi

echo -e "${CYAN}Opening ${BOLD}$URL${NC}${CYAN}…${NC}"
open "$URL"
