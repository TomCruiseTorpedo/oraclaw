<#
  generate-ssh-key.ps1

  The smallest possible "make me an SSH key" script for Oraclaw on Windows 11.

  What it does:
    1. Checks if you already have %USERPROFILE%\.ssh\id_ed25519. If so, prints
       the public half and exits.
    2. If not, creates one (no passphrase, safe defaults) and prints the public half.

  You need:  nothing.  Windows 11 ships with OpenSSH (including ssh-keygen)
             built in.  No WSL, no Cygwin, no winget needed.

  Usage (in PowerShell — any window, no admin needed):
      & $env:USERPROFILE\oraclaw\scripts\generate-ssh-key.ps1

  What to do with the output:
      Copy the green line (starts with `ssh-ed25519`) and paste it into
      Oracle Cloud when creating your VM — in the "Add SSH keys" section,
      choose "Paste public keys" and paste that line.

  Idempotent.  Run it as many times as you want.
#>

$ErrorActionPreference = 'Stop'

$sshDir = Join-Path $env:USERPROFILE '.ssh'
$sshKey = Join-Path $sshDir 'id_ed25519'

if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}

if (Test-Path $sshKey) {
    Write-Host "You already have an SSH key at: $sshKey" -ForegroundColor Cyan
    Write-Host "(That's fine - we'll use it. Here's the public half:)" -ForegroundColor Cyan
} else {
    Write-Host 'No SSH key found. Creating one now...' -ForegroundColor Yellow
    $comment = "$env:USERNAME@$env:COMPUTERNAME-$(Get-Date -Format 'yyyyMMdd')"
    # -N '""' is the canonical Windows PowerShell form for "empty passphrase"
    ssh-keygen -t ed25519 -f $sshKey -N '""' -C $comment | Out-Null
    Write-Host "[OK] Created at $sshKey" -ForegroundColor Green
}

Write-Host ''
Write-Host '+------------------------------------------------------------------+' -ForegroundColor White
Write-Host '|  YOUR PUBLIC SSH KEY - copy this whole green line                |' -ForegroundColor White
Write-Host '+------------------------------------------------------------------+' -ForegroundColor White
Write-Host ''
Write-Host (Get-Content "$sshKey.pub") -ForegroundColor Green
Write-Host ''
Write-Host 'What to do next:'
Write-Host "  1. Triple-click the green line above to select it, then Ctrl+C to copy."
Write-Host "  2. In Oracle Cloud's 'Create Compute Instance' page, scroll to the"
Write-Host "     'Add SSH keys' section."
Write-Host "  3. Select 'Paste public keys' and paste (Ctrl+V) there."
Write-Host "  4. Finish creating the VM."
Write-Host "  5. Come back here and continue to Section 4 of the Field Manual."
Write-Host ''
Write-Host "KEEP the *private* key safe (the file at $sshKey - no .pub)." -ForegroundColor Yellow
Write-Host 'Never share it. If it leaks, delete it and re-run this script.' -ForegroundColor Yellow
