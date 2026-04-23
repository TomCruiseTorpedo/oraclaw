#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  approve-pairing.sh
#
#  Approve a browser device-pairing request on your Oraclaw VM.
#
#  When to run this: when the dashboard shows "Device pairing required" after
#  you paste your login token for the first time.  **This is expected, not
#  an error** — Oraclaw requires every new browser to be explicitly approved
#  on the server side so a stolen token alone cannot let someone in.
#
#  This script makes the approval a single command from your client machine,
#  so you don't have to SSH into the VM manually.
#
#  Usage:
#    bash ~/oraclaw/scripts/approve-pairing.sh                 # auto-detect VM
#    bash ~/oraclaw/scripts/approve-pairing.sh my-oraclaw      # specify VM
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

BOLD='\033[1m'; RED='\033[0;31m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
die() { echo -e "${BOLD}${RED}✖${NC}${BOLD} $*${NC}" >&2; exit 1; }

VM_HOST="${1:-}"

# Auto-detect if no VM name was given
if [[ -z "$VM_HOST" ]]; then
  SSH_CONFIG="$HOME/.ssh/config"
  [[ -r "$SSH_CONFIG" ]] || die "~/.ssh/config not found — run bootstrap-mac.sh first, or pass a VM name: $0 <vm-name>"
  VM_HOST=$(awk '$1=="Host"{h=$2} $1=="HostName"&&$2~/\.ts\.net$/{print h; exit}' "$SSH_CONFIG")
  [[ -n "$VM_HOST" ]] || die "No SSH config entry with a .ts.net HostName found.  Run bootstrap-mac.sh, or pass a VM name: $0 <vm-name>"
fi

echo -e "${CYAN}Checking ${BOLD}$VM_HOST${NC}${CYAN} for device-pairing requests…${NC}"
echo ""

# Source nvm explicitly before running openclaw.  Default Ubuntu .bashrc has
# a non-interactive early-return at the top, so a plain `ssh host 'openclaw …'`
# finds openclaw missing from PATH (it lives under ~/.nvm/versions/node/v…/bin/).
# Sourcing nvm.sh sets NVM_DIR, prepends the active node's bin dir to PATH, and
# makes openclaw runnable.
OC_ENV='export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
OUTPUT=$(ssh -o ConnectTimeout=5 "$VM_HOST" "$OC_ENV; openclaw devices list" 2>&1) || die "Could not reach $VM_HOST (check Tailscale + VM status)."

echo "$OUTPUT"
echo ""

# Extract UUID-format request-ids from the output.
# Using a while-read loop so this runs on macOS's default bash 3.2 (no mapfile).
UUIDS=()
while IFS= read -r uuid; do
  UUIDS+=("$uuid")
done < <(echo "$OUTPUT" | grep -oE '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}' | sort -u)

if [[ ${#UUIDS[@]} -eq 0 ]]; then
  echo -e "${YELLOW}No device request-ids found in the output above.${NC}"
  echo ""
  echo "If you haven't opened the dashboard in a browser and pasted your login"
  echo "token yet, do that first — a pending request only appears after the"
  echo "browser tries to authenticate."
  exit 0
fi

if [[ ${#UUIDS[@]} -eq 1 ]]; then
  REQ_ID="${UUIDS[0]}"
  echo -e "${CYAN}One request-id found: ${BOLD}$REQ_ID${NC}"
  echo -e "${CYAN}Approving…${NC}"
else
  echo -e "${YELLOW}Multiple request-ids found.  Copy the one you want to approve from the list above.${NC}"
  read -r -p "request-id to approve: " REQ_ID
  [[ -n "$REQ_ID" ]] || die "No request-id entered."
fi

ssh "$VM_HOST" "$OC_ENV; openclaw devices approve '$REQ_ID'"
echo ""
echo -e "${GREEN}✓${NC} Device approved.  Refresh your browser now."
