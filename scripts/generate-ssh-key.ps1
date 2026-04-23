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
Write-Host '|  YOUR PUBLIC SSH KEY - copy the ENTIRE line in green below       |' -ForegroundColor White
Write-Host '|  All THREE parts together: algorithm, key material, AND comment. |' -ForegroundColor White
Write-Host '+------------------------------------------------------------------+' -ForegroundColor White
Write-Host ''
Write-Host (Get-Content "$sshKey.pub") -ForegroundColor Green
Write-Host ''
Write-Host 'The line above has three parts - all required:'
Write-Host ''
Write-Host "   ssh-ed25519        AAAAC3... (long base64 string)        $env:USERNAME@$env:COMPUTERNAME-..."
Write-Host "   ^^^^^^^^^^^        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^   ^^^^^^^^^^^^^^^^^^^^^^^^^"
Write-Host "   PART 1:            PART 2:                               PART 3:"
Write-Host "   algorithm name     the actual key (long, don't shorten)  your label/comment"
Write-Host ''
Write-Host 'Copy ALL three parts as one single line.' -ForegroundColor Yellow
Write-Host 'Oracle Cloud rejects the key if any part is missing - including the comment'
Write-Host "at the end. The comment isn't decoration, it's part of the key identity."
Write-Host ''
Write-Host 'What to do next:'
Write-Host "  1. Triple-click the green line above to select the whole thing, then Ctrl+C."
Write-Host "     (Triple-click selects the entire line by default in Windows Terminal.)"
Write-Host "  2. Optional but safer: scroll back up and compare what you copied to the"
Write-Host "     green line - the comment (your user@computer-date) should be included."
Write-Host "  3. In Oracle Cloud's 'Create Compute Instance' page, scroll to the"
Write-Host "     'Add SSH keys' section."
Write-Host "  4. Select 'Paste public keys' and paste (Ctrl+V) there."
Write-Host "  5. Finish creating the VM."
Write-Host "  6. Come back here and continue to Section 4 of the Field Manual."
Write-Host ''
Write-Host "KEEP the *private* key safe (the file at $sshKey - no .pub)." -ForegroundColor Yellow
Write-Host 'Never share it. If it leaks, delete it and re-run this script.' -ForegroundColor Yellow
