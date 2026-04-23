#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  generate-ssh-key.sh
#
#  The smallest possible "make me an SSH key" script for Oraclaw.
#
#  What it does:
#    1. Checks if you already have ~/.ssh/id_ed25519.  If you do, prints the
#       public half and exits.  No drama.
#    2. If you don't, creates one (no passphrase, safe defaults) and prints
#       the public half.
#
#  You need:  nothing.  Not Homebrew, not Xcode, not Tailscale, not anything.
#             Just a Mac (or Linux) that ships with `ssh-keygen` — which is
#             every Mac ever.
#
#  Usage (from a Mac Terminal):
#      bash ~/oraclaw/scripts/generate-ssh-key.sh
#
#  What to do with the output:
#      Copy the green line (starts with `ssh-ed25519`) and paste it into
#      Oracle Cloud when creating your VM — in the "Add SSH keys" section,
#      choose "Paste public keys" and paste that line.
#
#  This script is idempotent.  Run it as many times as you want.
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[0;33m'; NC='\033[0m'

SSH_KEY="$HOME/.ssh/id_ed25519"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [[ -f "$SSH_KEY" ]]; then
  echo -e "${CYAN}You already have an SSH key at:${NC} ${BOLD}$SSH_KEY${NC}"
  echo -e "${CYAN}(That's fine — we'll use it.  Here's the public half:)${NC}"
else
  echo -e "${YELLOW}No SSH key found.  Creating one now…${NC}"
  ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "$(whoami)@$(hostname -s)-$(date +%Y%m%d)" >/dev/null
  echo -e "${GREEN}✓ Created at $SSH_KEY${NC}"
fi

echo ""
echo -e "${BOLD}┌──────────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BOLD}│  YOUR PUBLIC SSH KEY — copy this whole green line                    │${NC}"
echo -e "${BOLD}└──────────────────────────────────────────────────────────────────────┘${NC}"
echo ""
echo -e "${GREEN}$(cat "${SSH_KEY}.pub")${NC}"
echo ""
echo -e "${BOLD}What to do next:${NC}"
echo "  1. Triple-click the green line above to select it, then Cmd+C to copy."
echo "  2. In Oracle Cloud's 'Create Compute Instance' page, scroll to the"
echo "     'Add SSH keys' section."
echo "  3. Select 'Paste public keys' and paste (Cmd+V) there."
echo "  4. Finish creating the VM."
echo "  5. Come back here and continue to Section 4 of the Field Manual."
echo ""
echo -e "${YELLOW}KEEP the *private* key safe${NC} (the file at $SSH_KEY — no .pub)."
echo -e "${YELLOW}Never share it.  If it leaks, delete it and re-run this script.${NC}"
