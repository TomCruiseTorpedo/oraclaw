#!/usr/bin/env bash
#
# recover-gateway.sh — restart the openclaw-gateway user service on a remote
# node and wait for /health to return 200. Use this when the Control UI's
# "Update" button (or any other path) left the gateway unresponsive.
#
# Idempotent. Safe to run when the gateway is healthy (asks before restarting).
# Auto-detects sysuser mode (openclaw) vs default mode (ubuntu).
#
# Usage: recover-gateway.sh <ssh-alias>
#   e.g. recover-gateway.sh my-oraclaw
#
# Pattern: scp-then-execute. No heredocs fed over ssh (that pattern caused
# sudo-TTY state corruption; see docs/RECOVERY.md).
#
# Health probing is done via SSH against localhost on the VM — the gateway
# always binds 127.0.0.1:18789 regardless of your tailnet name. No assumption
# about your tailnet FQDN in this script.

set -euo pipefail
NODE="${1:?usage: $0 <ssh-alias>}"

if ssh -o BatchMode=yes -o ConnectTimeout=5 "$NODE" 'test -d /home/openclaw' 2>/dev/null; then
  OC_USER=openclaw
  NEEDS_SUDO=1
else
  OC_USER=ubuntu
  NEEDS_SUDO=0
fi
echo "[recover] target: $NODE  user: $OC_USER"

# Probe /health via SSH to the VM, hitting localhost:18789 on the VM.
probe() {
  ssh -o ConnectTimeout=3 "$NODE" "curl -sS -m 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:18789/health 2>/dev/null || echo 000" 2>/dev/null || echo 000
}

pre=$(probe)
echo "[recover] current /health: HTTP $pre"
if [ "$pre" = "200" ]; then
  read -r -p "[recover] gateway is already healthy. Restart anyway? [y/N] " ans
  case "${ans:-N}" in
    y|Y|yes|YES) ;;
    *) echo "[recover] aborted."; exit 0 ;;
  esac
fi

PAYLOAD=$(mktemp -t oc-recover.XXXXXX)
REMOTE_PAYLOAD="/tmp/oc-recover.$$.sh"
trap 'rm -f "$PAYLOAD"' EXIT

cat > "$PAYLOAD" <<'PAYLOAD_EOF'
#!/usr/bin/env bash
set -euo pipefail
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
systemctl --user restart openclaw-gateway
echo "[inner] systemctl --user restart openclaw-gateway issued"
rm -f "$0"
PAYLOAD_EOF
chmod +x "$PAYLOAD"

scp -q "$PAYLOAD" "$NODE:$REMOTE_PAYLOAD"

if [ "$NEEDS_SUDO" = "1" ]; then
  ssh -t "$NODE" "sudo chown $OC_USER:$OC_USER $REMOTE_PAYLOAD && sudo -u $OC_USER bash $REMOTE_PAYLOAD"
else
  ssh -t "$NODE" "bash $REMOTE_PAYLOAD"
fi

echo "[recover] polling /health (budget 120s)…"
for i in $(seq 1 24); do
  sleep 5
  code=$(probe)
  echo "  try $i: HTTP $code"
  if [ "$code" = "200" ]; then
    echo "[recover] ✓ gateway live on $NODE"
    exit 0
  fi
done

cat >&2 <<ESC_EOF
[recover] ✗ gateway did not reach HTTP 200 within 120s.

Escalation steps:
  1) Journal (last 5 min for the service user):
       ssh $NODE 'OC_UID=\$(id -u $OC_USER); sudo -n journalctl _UID=\$OC_UID --since "5 minutes ago" --no-pager | tail -60'

  2) Service status:
       ssh $NODE 'OC_UID=\$(id -u $OC_USER); sudo -H -u $OC_USER env XDG_RUNTIME_DIR=/run/user/\$OC_UID systemctl --user status openclaw-gateway --no-pager -l'

  3) If SSH itself is unreachable, break-glass via the OCI serial console
     (see docs/FIELD-MANUAL.md → "Emergency Recovery").
ESC_EOF
exit 1
