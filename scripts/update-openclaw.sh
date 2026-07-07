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
#   0. supply-chain soak gate — refuse an openclaw release younger than
#      SOAK_DAYS (unless --force), so a freshly-compromised release is not
#      installed at day-zero, before advisories / registry takedowns catch it
#   1. pause the user-level watchdog timer (so it doesn't fight us)
#   2. stop the gateway service cleanly
#   3. update npm to latest, then npm install -g openclaw@latest
#   4. start the gateway service
#   5. poll /health for up to 240 seconds (fresh-install cold start
#      stages bundled runtime deps — usually 60-90 s on Ampere A1)
#   6. post-install npm audit + signature check (advisory); on health
#      failure instead: AUTO-ROLLBACK to the pre-upgrade version and
#      re-poll (exit 1 either way — a rolled-back update still failed)
#   7. resume the watchdog timer (always, even if a step failed)
#
# Why npm@latest (not a pin): npm is first-party (npm Inc / GitHub), has no
# install scripts, and is heavily monitored — so it is kept current rather than
# frozen (a pin only goes stale and misses npm's own security fixes). The soak
# gate is reserved for the openclaw dependency tree, where day-zero risk lives.
#
# Run from your client (Mac or Linux). For Windows, use the manual
# steps in CHEATSHEET.md -> "Update OpenClaw" instead.
#
# Relation to upstream `openclaw update`: the upstream updater brings a staged
# npm install and `openclaw doctor` migrations, but no soak gate, no watchdog
# pause, no post-install audit, no auto-rollback. This script exists for those
# four safety nets.
#
# Usage: bash update-openclaw.sh [--force] <ssh-alias>
#   e.g. bash ~/oraclaw/scripts/update-openclaw.sh my-oraclaw
#   --force   bypass the soak gate (urgent, independently-vetted security release)

set -euo pipefail

SOAK_DAYS=5         # supply-chain soak window for openclaw@latest (days)

FORCE=0
NODE=""
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        -h|--help) echo "Usage: $0 [--force] <ssh-alias>"; exit 0 ;;
        -*) echo "unknown option: $arg" >&2; exit 2 ;;
        *) NODE="$arg" ;;
    esac
done
: "${NODE:?usage: $0 [--force] <ssh-alias>}"
echo "[update-oraclaw] target: $NODE  (npm=latest, soak=${SOAK_DAYS}d, force=$FORCE)"

PAYLOAD=$(mktemp -t oraclaw-update.XXXXXX)
REMOTE_PAYLOAD="/tmp/oraclaw-update.$$.sh"
trap 'rm -f "$PAYLOAD"' EXIT

cat > "$PAYLOAD" <<'PAYLOAD_EOF'
#!/usr/bin/env bash
set -euo pipefail

FORCE="${1:-0}"
SOAK_DAYS="${2:-5}"

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
OLD_VER=$(printf '%s' "$OLD" | grep -oE '[0-9]{4}\.[0-9]+\.[0-9]+' | head -1 || echo "")
echo "[inner] current openclaw: $OLD"

# [0] supply-chain soak gate — runs BEFORE any teardown.
LATEST=$(npm view openclaw version 2>/dev/null || echo "")
if [ -n "$LATEST" ] && [ "$LATEST" != "$OLD_VER" ]; then
    PUB=$(npm view openclaw time --json 2>/dev/null \
        | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{try{const t=JSON.parse(d);process.stdout.write(String(t[process.argv[1]]||""))}catch(e){process.stdout.write("")}})' "$LATEST" 2>/dev/null || echo "")
    if [ -n "$PUB" ]; then
        PUB_S=$(date -d "$PUB" +%s 2>/dev/null || echo "")
        if [ -n "$PUB_S" ]; then
            AGE_D=$(( ( $(date +%s) - PUB_S ) / 86400 ))
            if [ "$AGE_D" -lt "$SOAK_DAYS" ] && [ "$FORCE" != "1" ]; then
                echo "[soak] openclaw@$LATEST published $PUB (~${AGE_D}d ago) < ${SOAK_DAYS}d soak window." >&2
                echo "[soak] Refusing day-zero adoption (supply-chain soak). Re-run with --force for an urgent, independently-vetted security update." >&2
                exit 3
            fi
            echo "[soak] openclaw@$LATEST is ~${AGE_D}d old (soak ${SOAK_DAYS}d) — proceeding."
        fi
    else
        echo "[soak] WARNING: could not determine publish time for openclaw@$LATEST; proceeding." >&2
    fi
elif [ "$LATEST" = "$OLD_VER" ] && [ -n "$LATEST" ]; then
    echo "[soak] already on latest ($LATEST) — nothing new to adopt."
fi

CFG="$HOME/.openclaw/openclaw.json"
STAMP=$(date +%s)
if [ -f "$CFG" ]; then
    cp -a "$CFG" "${CFG}.pre-upgrade.${STAMP}"
    echo "[inner] config backup: ${CFG}.pre-upgrade.${STAMP}"
fi

# Ensure the configured web_search provider's plugin is enabled. OpenClaw 2026.6.x
# made web_search plugin-based: a provider named in tools.web.search.provider must
# have plugins.entries.<provider>.enabled=true, or the gateway refuses to boot
# ("unknown web_search provider"). Set it now on the current (pre-upgrade) version,
# where the config is still valid and the key is forward-compatible, so the
# upgraded gateway boots clean. Uses openclaw's own config writer (the config is
# JSON5 — do not hand-edit it with jq). Does not touch plugins.allow. Idempotent.
PROV=$(openclaw config get tools.web.search.provider 2>/dev/null | tr -dc 'a-z0-9_-' || true)
if [ -n "${PROV:-}" ] && [ "$PROV" != "null" ]; then
    openclaw config set "plugins.entries.${PROV}.enabled" true >/dev/null 2>&1 \
        && echo "[inner] ensured web_search plugin '${PROV}' enabled (2026.6.x plugin model)" \
        || echo "[inner] note: could not pre-enable web_search plugin '${PROV}' (older CLI?); continuing" >&2
fi

echo "[inner] pausing watchdog timer…"
if systemctl --user stop openclaw-gateway-watchdog.timer 2>/dev/null; then
    WATCHDOG_PAUSED=1
fi

echo "[inner] stopping gateway…"
systemctl --user stop openclaw-gateway

echo "[inner] updating npm → latest …"
npm install -g npm@latest 2>&1 | tail -2

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
HEALTHY=0
last_msg=""
for i in $(seq 1 48); do
    sleep 5
    code=$(curl -sS -m 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:18789/health 2>/dev/null || echo 000)
    if [ "$code" = "200" ]; then
        echo "  try $i: HTTP 200 ✓"
        HEALTHY=1
        break
    fi
    case "$code" in
        000) msg="no listener yet (gateway still bootstrapping)" ;;
        4*|5*) msg="HTTP $code (listener up, gateway not fully ready)" ;;
        *) msg="HTTP $code" ;;
    esac
    if [ "$msg" != "$last_msg" ]; then
        echo "  try $i: $msg"
        last_msg="$msg"
    fi
done

if [ "$HEALTHY" = "1" ]; then
    echo "[inner] ✓ gateway live"
    echo "[inner] post-install npm audit + signatures…"
    OCDIR="$(npm root -g)/openclaw"
    ( cd "$OCDIR" 2>/dev/null && npm audit --audit-level=high 2>&1 | tail -6 ) \
        || echo "[audit] WARNING: npm audit flagged high/critical (or errored) — review before relying on this update." >&2
    ( cd "$OCDIR" 2>/dev/null && npm audit signatures 2>&1 | tail -4 ) || true
    exit 0
fi

echo "[inner] ✗ gateway did not reach HTTP 200 within 240 s." >&2
echo "[inner] config backup is at ${CFG}.pre-upgrade.${STAMP}" >&2

# Auto-rollback: reinstall the pre-upgrade version and re-poll /health.
# ${OLD_VER} is the parsed bare version (${OLD} is the whole banner line and
# would break the npm spec). Every step is best-effort (|| true) — set -e
# must not abort before the final report; the poll decides.
if [ -z "$OLD_VER" ]; then
    echo "[inner] cannot auto-roll back — pre-upgrade version unknown." >&2
    echo "[inner] manual: source ~/.nvm/nvm.sh && npm install -g openclaw@<version> && systemctl --user restart openclaw-gateway" >&2
    exit 1
fi
echo "[inner] AUTO-ROLLBACK: reinstalling openclaw@${OLD_VER}…" >&2
systemctl --user stop openclaw-gateway 2>/dev/null || true
npm install -g "openclaw@${OLD_VER}" 2>&1 | tail -3 || echo "[inner] WARN: rollback npm install reported errors" >&2
systemctl --user start openclaw-gateway || true
echo "[inner] waiting for /health → 200 after rollback (budget 240 s)…" >&2
for i in $(seq 1 48); do
    sleep 5
    code=$(curl -sS -m 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:18789/health 2>/dev/null || echo 000)
    if [ "$code" = "200" ]; then
        echo "[inner] ✓ rolled back to ${OLD_VER} and healthy — the update FAILED and was reverted." >&2
        exit 1
    fi
done
echo "[inner] ✗ ROLLBACK ALSO UNHEALTHY — gateway is down." >&2
echo "[inner] inspect: journalctl --user -u openclaw-gateway -n 100 --no-pager" >&2
echo "[inner] config backup: ${CFG}.pre-upgrade.${STAMP}" >&2
exit 1
PAYLOAD_EOF

chmod +x "$PAYLOAD"
echo "[update-oraclaw] staging payload → $NODE:$REMOTE_PAYLOAD"
scp -q "$PAYLOAD" "$NODE:$REMOTE_PAYLOAD"
ssh -t "$NODE" "bash $REMOTE_PAYLOAD $FORCE $SOAK_DAYS"
