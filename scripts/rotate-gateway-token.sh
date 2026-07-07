#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  rotate-gateway-token.sh
#
#  Rotate the OpenClaw gateway auth token on this VM.
#
#  When to run this:
#    - You suspect the token leaked (you shared it, it ended up in a screenshot,
#      etc.)
#    - You've lost track of it and want a fresh one
#    - Routine rotation — every few months isn't a bad habit
#
#  Usage (on the VM, as the ubuntu user):
#    bash ~/oraclaw/scripts/rotate-gateway-token.sh
#
#  What it does:
#    1. Reads the current token via `openclaw config get` (shows first 8 chars
#       of the old token, for sanity)
#    2. Generates a new 48-character hex token via openssl
#    3. Updates the token via `openclaw config set` — openclaw.json is JSON5
#       (it may carry comments/trailing commas), so it must go through
#       openclaw's own writer; a jq rewrite can truncate or corrupt it
#    4. Restarts the gateway service
#    5. Waits for the gateway to come back up healthy (HTTP 200)
#    6. Prints the NEW token ONCE — save it to your password manager immediately
#
#  After rotation:
#    - Open the dashboard in your browser, click ⚙ Settings, paste the new
#      token, click Save
#    - Already-paired devices keep working — they use their own device tokens,
#      independent of the gateway auth token you just rotated
#
#  Re-run safe: each run gives a new token.
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
say()  { echo -e "${BOLD}${GREEN}▶${NC}${BOLD} $*${NC}"; }
warn() { echo -e "${BOLD}${YELLOW}⚠${NC}${BOLD} $*${NC}"; }
die()  { echo -e "${BOLD}${RED}✖${NC}${BOLD} $*${NC}" >&2; exit 1; }

CFG="$HOME/.openclaw/openclaw.json"

# ── Preflight ────────────────────────────────────────────────────────────────
command -v jq >/dev/null      || die "jq not installed (sudo apt install jq)"
command -v openssl >/dev/null || die "openssl not installed"
[[ -f "$CFG" ]]               || die "openclaw.json not found at $CFG — has the VM installer run yet?"

# The config file is JSON5 — jq cannot parse it, so all reads/writes below go
# through the openclaw CLI (jq only parses the CLI's clean `--json` output).
# nvm's PATH hook doesn't fire in non-interactive shells, so source it if needed.
if ! command -v openclaw >/dev/null 2>&1; then
  export NVM_DIR="$HOME/.nvm"
  [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
fi
command -v openclaw >/dev/null || die "openclaw CLI not found (checked PATH + nvm)"

# ── 1. Read current token (show first 8 chars as a sanity check) ─────────────
OLD=$(openclaw config get gateway.auth.token --json | jq -r '.')
[[ -n "$OLD" && "$OLD" != "null" ]] || die "could not read current token from $CFG"
say "Current token (first 8 chars): ${OLD:0:8}…  (full token hidden)"

# ── 2. Generate new token ────────────────────────────────────────────────────
NEW=$(openssl rand -hex 24)
[[ ${#NEW} -eq 48 ]] || die "token generation failed (got ${#NEW} chars, expected 48)"

# ── 3. Update via openclaw's own JSON5-safe writer ───────────────────────────
# The value is passed as an explicit JSON string ("--strict-json" + quotes) so
# a token that happens to be all digits can't be reinterpreted as a number.
say "Updating $CFG (via openclaw config set)"
openclaw config set gateway.auth.token "\"$NEW\"" --strict-json \
  || die "openclaw config set failed — token unchanged"

# ── 4. Restart service ───────────────────────────────────────────────────────
say "Restarting openclaw-gateway"
systemctl --user restart openclaw-gateway

# ── 5. Wait for ready ────────────────────────────────────────────────────────
say "Waiting for gateway HTTP 200…"
for i in $(seq 1 30); do
  sleep 2
  CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:18789/ 2>/dev/null || echo 000)
  if [[ "$CODE" == "200" ]]; then
    say "Gateway ready after $((i * 2))s"
    break
  fi
  [[ "$i" == "30" ]] && die "gateway did not come back up within 60s — check: journalctl --user -u openclaw-gateway -n 50"
done

# ── 6. Report ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  Token rotated.${NC}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}NEW TOKEN:${NC}  ${CYAN}$NEW${NC}"
echo ""
echo -e "${BOLD}${YELLOW}✎ Save this to your password manager NOW.  This script will not show it again.${NC}"
echo -e "   (If you lose it, re-read it with: ${BOLD}openclaw config get gateway.auth.token${NC})"
echo ""
echo -e "${BOLD}Next:${NC} in your browser, open the dashboard → click the ⚙ Settings gear → paste the new token → Save."
