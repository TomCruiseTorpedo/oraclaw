<#
  open-dashboard.ps1

  Opens the oraclaw Control UI dashboard in your default browser AND copies
  the login token to your clipboard at the same time, so you can paste it
  straight into the Settings panel.

  How it works:
    1. Figures out which VM to contact (from the -VmHost argument you pass,
       or by scanning %USERPROFILE%\.ssh\config for the first Host entry that
       has a .ts.net HostName).
    2. SSHes to that VM once and pulls both the dashboard URL and the
       gateway token.
    3. Copies the token to your clipboard via Set-Clipboard.
    4. Opens the URL in your default browser via Start-Process.

  Usage:
    & $env:USERPROFILE\oraclaw\scripts\open-dashboard.ps1
    & $env:USERPROFILE\oraclaw\scripts\open-dashboard.ps1 -VmHost my-oraclaw

  Prerequisites:
    - You've run bootstrap-windows.ps1 (sets up the SSH alias)
    - You've run install-oraclaw.sh on the VM (writes dashboard-url + token)
    - Your Tailscale is online
#>

param(
    [string]$VmHost
)

$ErrorActionPreference = 'Stop'

# Auto-detect if no VM name was given
if (-not $VmHost) {
    $sshConfig = Join-Path $env:USERPROFILE '.ssh\config'
    if (-not (Test-Path $sshConfig)) {
        Write-Error "$sshConfig not found — run bootstrap-windows.ps1 first, or pass a VM name explicitly: .\open-dashboard.ps1 -VmHost <vm-name>"
        exit 1
    }

    $currentHost = $null
    foreach ($line in (Get-Content $sshConfig)) {
        if ($line -match '^\s*Host\s+(\S+)') {
            $currentHost = $matches[1]
        }
        elseif ($line -match '^\s*HostName\s+\S+\.ts\.net\b') {
            $VmHost = $currentHost
            break
        }
    }

    if (-not $VmHost) {
        Write-Error "No SSH config entry with a .ts.net HostName found. Run bootstrap-windows.ps1, or pass a VM name explicitly: .\open-dashboard.ps1 -VmHost <vm-name>"
        exit 1
    }
}

Write-Host "Fetching dashboard URL + token from $VmHost..." -ForegroundColor Cyan

$remote = @'
URL=$(cat ~/.openclaw/dashboard-url 2>/dev/null || true)
TOKEN=$(jq -r .gateway.auth.token ~/.openclaw/openclaw.json 2>/dev/null || true)
printf "%s\n%s\n" "$URL" "$TOKEN"
'@

$infoRaw = ssh -o BatchMode=yes -o ConnectTimeout=5 $VmHost $remote 2>$null
$lines = @($infoRaw)
$url = if ($lines.Count -gt 0) { $lines[0].Trim() } else { '' }
$token = if ($lines.Count -gt 1) { $lines[1].Trim() } else { '' }

if (-not $url) {
    Write-Host ""
    Write-Host "Could not fetch the dashboard URL from $VmHost." -ForegroundColor Red
    Write-Host ""
    Write-Host "Likely causes:"
    Write-Host "  - The VM isn't reachable (check Tailscale is online on both your PC and the VM)"
    Write-Host "  - install-oraclaw.sh hasn't run to completion on the VM yet (it writes"
    Write-Host "    ~/.openclaw/dashboard-url at the end)"
    Write-Host "  - The SSH alias '$VmHost' isn't set up in ~\.ssh\config - try: ssh $VmHost"
    exit 1
}

if ($token -and $token -ne 'null') {
    Set-Clipboard -Value $token
    Write-Host "[OK] Login token copied to clipboard - paste (Ctrl+V) into the Settings panel after the page loads." -ForegroundColor Green
}

Write-Host "Opening $url..." -ForegroundColor Cyan
Start-Process $url
