#!/usr/bin/env bash
#
# update-openclaw.sh — safe OpenClaw upgrade on your Oraclaw VM.
#
# Why this exists: the dashboard's "Update" button uses an in-process
# restart that occasionally leaves the gateway dead. The safety net
# brings it back in 30-90 seconds, but the round-trip is annoying.
# Running `npm install -g openclaw@latest` directly works, but if the
# gateway is still running while npm overwrites its files, the gateway
# crashes mid-install — and the resulting cold restart can take 60-90
# seconds while looking like a failure. This script does it in the
# right order so that doesn't happen.
#
# Order of operations on the VM:
#   1. pause the user-level watchdog timer (so it doesn't fight us)
#   2. stop the gateway service cleanly
#   3. npm install -g openclaw@latest (no running process to crash)
#   4. start the gateway service
#   5. poll /health for up to 240 seconds (fresh-install cold start
#      stages bundled runtime deps — usually 60-90 s on Ampere A1)
#   6. resume the watchdog timer (always, even if step 5 failed)
#
# Run from your client (Mac or Linux). For Windows, use the manual
# steps in CHEATSHEET.md → "Update OpenClaw" instead.
#
# Usage: bash update-openclaw.sh <ssh-alias>
#   e.g. bash ~/oraclaw/scripts/update-openclaw.sh my-oraclaw

set -euo pipefail
NODE="${1:?usage: $0 <ssh-alias>}"
echo "[update-oraclaw] target: $NODE"

PAYLOAD=$(mktemp -t oraclaw-update.XXXXXX)
REMOTE_PAYLOAD="/tmp/oraclaw-update.$$.sh"
trap 'rm -f "$PAYLOAD"' EXIT

cat > "$PAYLOAD" <<'PAYLOAD_EOF'
#!/usr/bin/env bash
set -euo pipefail

export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"

# Always re-arm the watchdog before exiting, success or failure.
WATCHDOG_PAUSED=0
on_exit() {
    rc=$?
    if [ "$WATCHDOG_PAUSED" = "1" ]; then
        echo "[inner] resuming watchdog timer…"
        systemctl --user start openclaw-gateway-watchdog.timer 2>/dev/null \
            || echo "[inner] WARNING: failed to resume watchdog timer; run 'systemctl --user start openclaw-gateway-watchdog.timer' manually" >&2
    fi
    rm -f "$0"
    exit "$rc"
}
trap on_exit EXIT

OLD=$(openclaw --version 2>/dev/null | head -1 || echo "unknown")
echo "[inner] current openclaw: $OLD"

CFG="$HOME/.openclaw/openclaw.json"
STAMP=$(date +%s)
if [ -f "$CFG" ]; then
    cp -a "$CFG" "${CFG}.pre-upgrade.${STAMP}"
    echo "[inner] config backup: ${CFG}.pre-upgrade.${STAMP}"
fi

echo "[inner] pausing watchdog timer…"
if systemctl --user stop openclaw-gateway-watchdog.timer 2>/dev/null; then
    WATCHDOG_PAUSED=1
fi

echo "[inner] stopping gateway…"
systemctl --user stop openclaw-gateway

echo "[inner] npm install -g openclaw@latest …"
npm install -g openclaw@latest 2>&1 | tail -5

NEW=$(openclaw --version 2>/dev/null | head -1 || echo "unknown")
if [ "$OLD" = "$NEW" ]; then
    echo "[inner] (no version change: $NEW)"
else
    echo "[inner] version: $OLD → $NEW"
fi

echo "[inner] starting gateway…"
systemctl --user start openclaw-gateway

echo "[inner] waiting for /health → 200 (budget 240 s; fresh-install cold start usually 60-90 s)…"
last_msg=""
for i in $(seq 1 48); do
    sleep 5
    code=$(curl -sS -m 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:18789/health 2>/dev/null || echo 000)
    case "$code" in
        200)
            echo "  try $i: HTTP 200 ✓"
            echo "[inner] ✓ gateway live"
            exit 0
            ;;
        000)
            msg="no listener yet (gateway still bootstrapping)"
            ;;
        4*|5*)
            msg="HTTP $code (listener up, gateway not fully ready)"
            ;;
        *)
            msg="HTTP $code"
            ;;
    esac
    if [ "$msg" != "$last_msg" ]; then
        echo "  try $i: $msg"
        last_msg="$msg"
    fi
done

echo "[inner] ✗ gateway did not reach HTTP 200 within 240 s." >&2
echo "[inner] config backup is at ${CFG}.pre-upgrade.${STAMP}" >&2
echo "[inner] to roll back binaries: source ~/.nvm/nvm.sh && npm install -g openclaw@${OLD}" >&2
exit 1
PAYLOAD_EOF

chmod +x "$PAYLOAD"
echo "[update-oraclaw] staging payload → $NODE:$REMOTE_PAYLOAD"
scp -q "$PAYLOAD" "$NODE:$REMOTE_PAYLOAD"
ssh -t "$NODE" "bash $REMOTE_PAYLOAD"
