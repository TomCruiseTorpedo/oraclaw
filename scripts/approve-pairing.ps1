<#
  approve-pairing.ps1

  Approve a browser device-pairing request on your Oraclaw VM.

  When to run this: when the dashboard shows "Device pairing required" after
  you paste your login token for the first time.  **This is expected, not
  an error** - Oraclaw requires every new browser to be explicitly approved
  on the server side so a stolen token alone cannot let someone in.

  This script makes the approval a single command from your PC, so you
  don't have to SSH into the VM manually.

  Usage:
    & $env:USERPROFILE\oraclaw\scripts\approve-pairing.ps1
    & $env:USERPROFILE\oraclaw\scripts\approve-pairing.ps1 -VmHost my-oraclaw
#>

param(
    [string]$VmHost
)

$ErrorActionPreference = 'Stop'

# Auto-detect if no VM name was given
if (-not $VmHost) {
    $sshConfig = Join-Path $env:USERPROFILE '.ssh\config'
    if (-not (Test-Path $sshConfig)) {
        Write-Error "$sshConfig not found - run bootstrap-windows.ps1 first, or pass -VmHost <vm-name>."
        exit 1
    }
    $currentHost = $null
    foreach ($line in (Get-Content $sshConfig)) {
        if ($line -match '^\s*Host\s+(\S+)')                      { $currentHost = $matches[1] }
        elseif ($line -match '^\s*HostName\s+\S+\.ts\.net\b')      { $VmHost = $currentHost; break }
    }
    if (-not $VmHost) {
        Write-Error "No SSH config entry with a .ts.net HostName found. Run bootstrap-windows.ps1, or pass -VmHost <vm-name>."
        exit 1
    }
}

Write-Host "Checking $VmHost for device-pairing requests..." -ForegroundColor Cyan
Write-Host ""

$output = (ssh -o ConnectTimeout=5 $VmHost 'openclaw devices list' 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) {
    Write-Error "Could not reach $VmHost (check Tailscale + VM status)."
    exit 1
}

Write-Host $output
Write-Host ""

# Extract UUID-format request-ids from the output.
$uuids = [regex]::Matches($output, '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}') |
         ForEach-Object { $_.Value } |
         Select-Object -Unique

if ($uuids.Count -eq 0) {
    Write-Host "No device request-ids found in the output above." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "If you haven't opened the dashboard in a browser and pasted your login"
    Write-Host "token yet, do that first - a pending request only appears after the"
    Write-Host "browser tries to authenticate."
    exit 0
}

if ($uuids.Count -eq 1) {
    $reqId = $uuids[0]
    Write-Host "One request-id found: $reqId" -ForegroundColor Cyan
    Write-Host "Approving..." -ForegroundColor Cyan
} else {
    Write-Host "Multiple request-ids found. Copy the one you want to approve from the list above." -ForegroundColor Yellow
    $reqId = Read-Host "request-id to approve"
    if (-not $reqId) {
        Write-Error "No request-id entered."
        exit 1
    }
}

ssh $VmHost "openclaw devices approve '$reqId'"
Write-Host ""
Write-Host "[OK] Device approved. Refresh your browser now." -ForegroundColor Green
