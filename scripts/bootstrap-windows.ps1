<#
  bootstrap-windows.ps1

  Prepares a fresh Windows 11 PC to connect to and manage an Oraclaw
  OpenClaw instance on Oracle Cloud.  Assumes only Windows 11 + winget
  (built-in).  The OpenSSH client that ships with Windows 11 handles ssh,
  scp, and ssh-keygen — no WSL, Cygwin, or MSYS needed.

  Usage (in PowerShell running as Administrator — right-click PowerShell
  in the Start menu, then "Run as administrator"):

      # Allow local scripts to run (one-time, per-user):
      Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

      # Install git enough to clone the repo (if not already installed):
      winget install --id Git.Git --exact --silent `
                     --accept-source-agreements --accept-package-agreements

      # Close and reopen PowerShell (as admin) so `git` is on PATH, then:
      git clone https://github.com/TomCruiseTorpedo/oraclaw.git `
                $env:USERPROFILE\oraclaw

      # Run this script:
      & $env:USERPROFILE\oraclaw\scripts\bootstrap-windows.ps1

  Idempotent.  Safe to re-run as many times as you want.
#>

$ErrorActionPreference = 'Stop'

function Say($msg)  { Write-Host ('> ' + $msg) -ForegroundColor Green }
function Info($msg) { Write-Host ('i ' + $msg) -ForegroundColor Cyan }
function Warn($msg) { Write-Host ('! ' + $msg) -ForegroundColor Yellow }
function Pause-Here { Read-Host '...press Enter to continue...' | Out-Null }

# -- Preflight ------------------------------------------------------------------

$osBuild = [int]((Get-CimInstance Win32_OperatingSystem).BuildNumber)
if ($osBuild -lt 22000) {
    Write-Error "This script targets Windows 11 (build 22000 or newer). Detected build $osBuild."
    exit 1
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
    exit 1
}

if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Error "ssh not found. Install OpenSSH Client: Settings -> Apps -> Optional Features -> Add -> OpenSSH Client."
    exit 1
}

Write-Host @'
+====================================================================+
|                                                                    |
|   Oraclaw Windows 11 bootstrap                                     |
|                                                                    |
|   What this does:                                                  |
|     1. Installs git, Tailscale, jq via winget                      |
|     2. Creates an SSH key (if you don't already have one)          |
|     3. Walks you through connecting to Tailscale                   |
|     4. Sets up a shortcut name for your VM                         |
|                                                                    |
|   Estimated time: 5-10 minutes, mostly waiting on downloads.       |
|                                                                    |
+====================================================================+
'@
Pause-Here

# -- 1. winget tools ------------------------------------------------------------

Say "[1/4] Installing git, Tailscale, jq via winget..."

function Install-IfMissing {
    param([string]$Id, [string]$Friendly)
    $installed = winget list --id $Id --exact --accept-source-agreements 2>$null |
                 Select-String -Pattern $Id -SimpleMatch -Quiet
    if ($installed) {
        Info "$Friendly already installed"
    } else {
        Info "Installing $Friendly..."
        winget install --id $Id --exact --silent `
                       --accept-source-agreements --accept-package-agreements | Out-Host
    }
}

Install-IfMissing -Id 'Git.Git'             -Friendly 'git'
Install-IfMissing -Id 'tailscale.tailscale' -Friendly 'Tailscale'
Install-IfMissing -Id 'jqlang.jq'           -Friendly 'jq'

# Refresh PATH so newly-installed tools are visible in this session
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path', 'User')

# Ensure the Oraclaw repo is cloned locally (covers the irm | iex install flow
# where the user hasn't run `git clone` yet).
$repoDir = Join-Path $env:USERPROFILE 'oraclaw'
if (-not (Test-Path $repoDir)) {
    Say "Cloning the Oraclaw repo into $repoDir..."
    git clone 'https://github.com/TomCruiseTorpedo/oraclaw.git' $repoDir | Out-Host
    Info 'repo cloned'
} else {
    Info "Oraclaw repo already at $repoDir"
}

# -- 2. SSH key -----------------------------------------------------------------

Say "[2/4] SSH key check..."
$sshDir = Join-Path $env:USERPROFILE '.ssh'
$sshKey = Join-Path $sshDir 'id_ed25519'

if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}

if (Test-Path $sshKey) {
    Info "SSH key already exists at $sshKey"
} else {
    Warn "Creating a new SSH key. Press Enter 3 times when prompted (blank passphrase, default location)."
    $comment = "$env:USERNAME@$env:COMPUTERNAME-$(Get-Date -Format 'yyyyMMdd')"
    # -N '""' passes a literal empty string to OpenSSH on Windows (skips passphrase)
    ssh-keygen -t ed25519 -f $sshKey -N '""' -C $comment
    Info "SSH key created"
}

Write-Host ''
Info 'Your PUBLIC SSH key (paste this into Oracle Cloud when creating your VM):'
Write-Host ''
Write-Host (Get-Content "$sshKey.pub") -ForegroundColor Cyan
Write-Host ''
Pause-Here

# -- 3. Tailscale connection ----------------------------------------------------

Say "[3/4] Connecting to Tailscale..."
$tailscaleCli = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
if (-not (Test-Path $tailscaleCli)) {
    Warn "Tailscale CLI not found at $tailscaleCli. Open Start menu -> Tailscale -> sign in -> re-run this script."
    exit 1
}

$statusOutput = & $tailscaleCli status 2>&1
$loggedOut = ($LASTEXITCODE -ne 0) -or ($statusOutput -match 'Logged out|NeedsLogin|stopped')
if ($loggedOut) {
    Warn 'Starting Tailscale login flow. A browser window will open.'
    Warn '  1. Sign in with Google, GitHub, Microsoft, or Apple (or create a'
    Warn '     new Tailscale account if you do not have one yet).'
    Warn '  2. Approve this device in the Tailscale admin console.'
    & $tailscaleCli up
    if ($LASTEXITCODE -ne 0) {
        Warn ''
        Warn 'Tailscale login did not complete (likely browser auth cancelled or timed out).'
        Warn 'Open the Tailscale app manually from the Start menu, sign in there, then'
        Warn "re-run this script. Alternatively, run ``& '$tailscaleCli' up`` by hand."
        exit 1
    }
    Info 'Tailscale online'
} else {
    Info 'Tailscale is already online.'
}

# -- 4. SSH config alias --------------------------------------------------------

Say "[4/4] Add an SSH shortcut for your OCI VM"
Write-Host ''
Info "If you haven't created your Oracle Cloud VM yet, stop here and go do it now."
Info "(Follow docs/FIELD-MANUAL.md, Section 3. Come back when the VM is running"
Info " and visible in the Tailscale app.)"
Write-Host ''
$tsHost = Read-Host '  Tailscale hostname of your VM (e.g. my-oraclaw)'
$tsNet  = Read-Host '  Your tailnet subdomain - find it in Tailscale app -> Network -> DNS (the part before .ts.net)'

# Strip whitespace and lowercase (Tailscale DNS names are always lowercase)
$tsHost = ($tsHost -replace '\s', '').ToLower()
$tsNet  = ($tsNet  -replace '\s', '').ToLower()

# Validate against the actual tailnet before writing anything.  Catches
# hostname / subdomain typos - by far the most common support issue.
$targetDns = "$tsHost.$tsNet.ts.net."
$tailscaleCli = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'

if (Test-Path $tailscaleCli) {
    $match = $null
    $allPeers = @()
    try {
        $statusJson = & $tailscaleCli status --json 2>$null | Out-String
        $status = $statusJson | ConvertFrom-Json
        if ($status.Self) { $allPeers += $status.Self }
        if ($status.Peer) {
            foreach ($peerId in $status.Peer.PSObject.Properties.Name) {
                $allPeers += $status.Peer.$peerId
            }
        }
        $match = $allPeers | Where-Object { $_.DNSName -eq $targetDns } | Select-Object -First 1
    } catch {
        # JSON parse failed - skip validation gracefully
    }

    if (-not $match -and $allPeers.Count -gt 0) {
        Write-Host ''
        Warn "Couldn't find a tailnet device at $tsHost.$tsNet.ts.net."
        Write-Host ''
        Info 'Here is what is currently on your tailnet:'
        foreach ($p in $allPeers) {
            $dns = if ($p.DNSName) { $p.DNSName.TrimEnd('.') } else { '?' }
            $h   = if ($p.HostName) { $p.HostName } else { '?' }
            Write-Host "    $h   ->   $dns"
        }
        Write-Host ''
        Write-Host 'Common causes:'
        Write-Host "  - Your VM hasn't joined Tailscale yet - have you run Section 5.1 of the Field Manual?"
        Write-Host '  - A typo in the hostname or the subdomain'
        Write-Host '  - You are logged into a different Tailscale account than the VM is on'
        Write-Host ''
        $confirm = Read-Host 'Continue anyway (the SSH test after this will likely fail)? [y/N]'
        if ($confirm -notmatch '^[Yy]') {
            Warn 'Aborted. Re-run this script with the correct hostname/subdomain.'
            exit 1
        }
    } elseif ($match) {
        Info "[OK] Found '$($match.HostName)' on your tailnet at $tsHost.$tsNet.ts.net"
    }
}

$sshConfig = Join-Path $sshDir 'config'
if (-not (Test-Path $sshConfig)) {
    New-Item -ItemType File -Path $sshConfig -Force | Out-Null
}

$existing = Get-Content $sshConfig -ErrorAction SilentlyContinue
$escapedHost = [regex]::Escape($tsHost)
if ($existing -and ($existing -match "^Host $escapedHost$")) {
    Info "SSH config already has '$tsHost' - leaving it alone."
} else {
    $entry = @"

Host $tsHost
    HostName $tsHost.$tsNet.ts.net
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
"@
    Add-Content -Path $sshConfig -Value $entry
    Info "added '$tsHost' alias to $sshConfig"
}

Write-Host ''
Say "Testing SSH connection to $tsHost..."
ssh -o ConnectTimeout=5 -o BatchMode=yes $tsHost 'echo SSH works: $(whoami)@$(hostname)'
if ($LASTEXITCODE -eq 0) {
    Info "SSH to $tsHost works!"
} else {
    Warn "SSH test failed. Likely reasons:"
    Warn "  - VM isn't running yet"
    Warn "  - Your SSH public key wasn't added to the VM during OCI setup"
    Warn "  - Tailscale on the VM hasn't connected yet"
    Warn "See docs/FIELD-MANUAL.md section 9 Troubleshooting -> 'SSH fails'"
}

Write-Host ''
Write-Host @"
+====================================================================+
|                                                                    |
|   Windows setup complete. You can now SSH into your VM with:       |
|                                                                    |
|       ssh $tsHost
|                                                                    |
|   Next: copy and run the Oraclaw installer on the VM:              |
|                                                                    |
|       scp `$env:USERPROFILE\oraclaw\scripts\install-oraclaw.sh ``
|           ${tsHost}:/tmp/
|       ssh $tsHost 'bash /tmp/install-oraclaw.sh'
|                                                                    |
|   Read docs\FIELD-MANUAL.md section 6 for the full walkthrough.    |
|                                                                    |
+====================================================================+
"@
