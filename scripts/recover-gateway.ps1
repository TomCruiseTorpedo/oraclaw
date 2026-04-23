<#
  recover-gateway.ps1

  Restart the openclaw-gateway user service on your Oraclaw VM and wait for
  /health to come back green.  Use this when the Control UI's "Update"
  button (or any other path) left the dashboard showing 502.

  Idempotent.  Safe to run when the gateway is already healthy (asks before
  restarting).  Auto-detects sysuser mode (openclaw) vs default mode (ubuntu).

  Usage:
    & $env:USERPROFILE\oraclaw\scripts\recover-gateway.ps1 my-oraclaw
    & $env:USERPROFILE\oraclaw\scripts\recover-gateway.ps1 -VmHost my-oraclaw

  Health probing is done via SSH against localhost on the VM — the gateway
  always binds 127.0.0.1:18789 regardless of your tailnet name.  No
  assumption about your tailnet FQDN in this script.
#>

param(
    [Parameter(Position=0)]
    [string]$VmHost
)

$ErrorActionPreference = 'Stop'

if (-not $VmHost) {
    Write-Error "Usage: recover-gateway.ps1 <ssh-alias>   (or -VmHost <ssh-alias>)"
    exit 2
}

# ── Detect sysuser vs default mode ─────────────────────────────────────────
# If /home/openclaw exists on the VM, we're in sysuser mode and must go through
# `sudo -u openclaw` to manage the service.  Otherwise the service runs as the
# `ubuntu` user we SSH in as.
$modeProbe = ssh -o BatchMode=yes -o ConnectTimeout=5 $VmHost 'test -d /home/openclaw && echo sysuser || echo default' 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Could not reach $VmHost (check Tailscale + VM status)."
    exit 1
}

$ocUser = 'ubuntu'
$needsSudo = $false
if ($modeProbe -match '^\s*sysuser\s*$') {
    $ocUser = 'openclaw'
    $needsSudo = $true
}

Write-Host "[recover] target: $VmHost  user: $ocUser" -ForegroundColor Cyan

# ── Probe /health via SSH to the VM, hitting localhost:18789 ───────────────
function Probe {
    $code = ssh -o ConnectTimeout=3 $VmHost 'curl -sS -m 3 -o /dev/null -w "%{http_code}" http://127.0.0.1:18789/health 2>/dev/null || echo 000' 2>$null
    if (-not $code) { $code = '000' }
    return $code.Trim()
}

$pre = Probe
Write-Host "[recover] current /health: HTTP $pre"
if ($pre -eq '200') {
    $ans = Read-Host '[recover] gateway is already healthy. Restart anyway? [y/N]'
    if ($ans -notmatch '^(y|Y|yes|YES)$') {
        Write-Host '[recover] aborted.'
        exit 0
    }
}

# ── Stage payload to /tmp on the VM ────────────────────────────────────────
$payloadContent = @'
#!/usr/bin/env bash
set -euo pipefail
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
systemctl --user restart openclaw-gateway
echo "[inner] systemctl --user restart openclaw-gateway issued"
rm -f "$0"
'@

$localPayload = [System.IO.Path]::GetTempFileName()
# Write LF line endings (bash on remote rejects CRLF `\r`).
[System.IO.File]::WriteAllText($localPayload, ($payloadContent -replace "`r`n", "`n"))

$rand = -join ((1..6) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
$remotePayload = "/tmp/oc-recover.$rand.sh"

try {
    Write-Host "[recover] staging payload -> ${VmHost}:$remotePayload" -ForegroundColor Cyan
    & scp -q $localPayload "${VmHost}:$remotePayload"
    if ($LASTEXITCODE -ne 0) { throw "scp failed" }

    if ($needsSudo) {
        # /tmp has fs.protected_regular on Ubuntu — hand ownership over before
        # sudo -u openclaw tries to read.  Single ssh -t = single TTY =
        # sudo credential cached across both calls.
        & ssh -t $VmHost "sudo chown ${ocUser}:${ocUser} $remotePayload && sudo -u $ocUser bash $remotePayload"
    } else {
        & ssh -t $VmHost "bash $remotePayload"
    }
    if ($LASTEXITCODE -ne 0) { throw "remote restart command failed (exit $LASTEXITCODE)" }
}
finally {
    Remove-Item -Force -ErrorAction SilentlyContinue $localPayload
}

# ── Poll until live or budget exhausted ────────────────────────────────────
Write-Host '[recover] polling /health (budget 120s)...' -ForegroundColor Cyan
for ($i = 1; $i -le 24; $i++) {
    Start-Sleep -Seconds 5
    $code = Probe
    Write-Host "  try ${i}: HTTP $code"
    if ($code -eq '200') {
        Write-Host "[recover] [OK] gateway live on $VmHost" -ForegroundColor Green
        exit 0
    }
}

Write-Host ''
Write-Host '[recover] [FAIL] gateway did not reach HTTP 200 within 120s.' -ForegroundColor Red
Write-Host ''
Write-Host 'Escalation steps:'
Write-Host "  1) Journal (last 5 min for the service user):"
Write-Host "       ssh $VmHost 'OC_UID=`$(id -u $ocUser); sudo -n journalctl _UID=`$OC_UID --since `"5 minutes ago`" --no-pager | tail -60'"
Write-Host ''
Write-Host "  2) Service status:"
Write-Host "       ssh $VmHost 'OC_UID=`$(id -u $ocUser); sudo -H -u $ocUser env XDG_RUNTIME_DIR=/run/user/`$OC_UID systemctl --user status openclaw-gateway --no-pager -l'"
Write-Host ''
Write-Host '  3) If SSH itself is unreachable, break-glass via the OCI serial'
Write-Host '     console (see docs/FIELD-MANUAL.md -> "Emergency Recovery").'
exit 1
