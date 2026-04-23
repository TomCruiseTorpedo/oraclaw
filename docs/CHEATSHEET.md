# Oraclaw Cheatsheet

*One-page reference.  Print it, pin it, or paste a section at your AI assistant.*

---

## ⚠ If the dashboard breaks after clicking "Update"

Most of the time it fixes itself in 60–90 seconds (the auto-recovery safety net does its thing). If not, one command brings it back:

**Mac (Terminal):**

```bash
bash ~/oraclaw/scripts/recover-gateway.sh my-oraclaw
```

**Windows 11 (PowerShell):**

```powershell
& $env:USERPROFILE\oraclaw\scripts\recover-gateway.ps1 my-oraclaw
```

**Or, manually (either platform):**

```bash
ssh my-oraclaw 'systemctl --user restart openclaw-gateway'
```

Full walkthrough: **[docs/RECOVERY.md](RECOVERY.md)**.

---

## Connection

```bash
ssh <vm-name>                                   # SSH
mosh <vm-name> -- tmux new-session -A -s main   # Persistent (survives Wi-Fi / lid)
```

## Dashboard

```
URL:    https://<vm-name>.<tailnet>.ts.net
Token:  jq -r .gateway.auth.token ~/.openclaw/openclaw.json   # on the VM
```

```bash
# Open the dashboard in your default browser (auto-detects the VM from ~/.ssh/config)
bash ~/oraclaw/scripts/open-dashboard.sh                  # Mac
& $env:USERPROFILE\oraclaw\scripts\open-dashboard.ps1     # Windows
```

## Service Control

```bash
systemctl --user status   openclaw-gateway    # is it alive?
systemctl --user restart  openclaw-gateway
systemctl --user stop     openclaw-gateway
journalctl  --user -u openclaw-gateway -f     # live logs (Ctrl-C to stop)
journalctl  --user -u openclaw-gateway -n 50  # last 50 lines
```

## Update OpenClaw

Prefer this command-line path over the `Update` button inside the dashboard. The dashboard button occasionally leaves the service stuck (the auto-recovery safety net catches it within a minute or two, but this path avoids the round-trip).

**Run this on the VM** (one line — all three commands chained so you can't accidentally stop halfway):

```bash
source ~/.nvm/nvm.sh && npm install -g openclaw@latest && systemctl --user restart openclaw-gateway
```

If you'd rather see each step separately: `source ~/.nvm/nvm.sh` loads Node's version manager, `npm install -g openclaw@latest` pulls the newest release, and `systemctl --user restart openclaw-gateway` picks it up. The `&&` between them means "only run the next if the previous succeeded" — so an npm-install error stops you from restarting on a broken install.

If you pressed the dashboard button and it didn't come back, see the banner at the top of this sheet.

## Device Pairing

"Device pairing required" in the dashboard is **expected**, not an error — every new browser must be approved server-side.

```bash
# Easy way (auto-detects VM, auto-approves if there's only one pending request)
bash ~/oraclaw/scripts/approve-pairing.sh                # Mac
& $env:USERPROFILE\oraclaw\scripts\approve-pairing.ps1   # Windows

# Manual way (on the VM)
openclaw devices list                   # see pending requests
openclaw devices approve <request-id>   # approve a browser
```

## Config

```bash
~/.openclaw/openclaw.json                    # main config (restart after editing)
~/.openclaw/.env                             # OPENROUTER_API_KEY lives here
~/.openclaw/agents/main/agent/models.json    # model catalogue
~/.openclaw/cron/jobs.json                   # scheduled heartbeat(s)
```

## Health Checks

```bash
uptime                                  # VM load + uptime
free -h                                 # memory / swap
df -h /                                 # disk (bad if <10% free)
curl -I http://127.0.0.1:18789/         # gateway direct
tailscale status                        # tailnet health
sudo tailscale serve status             # HTTPS proxy mapping
```

## Security Status

```bash
sudo ufw status                               # firewall
sudo fail2ban-client status sshd              # ssh bans
sudo sshd -T | grep -iE 'permitroot|allow'    # sshd effective config
sudo cat /etc/apt/apt.conf.d/20auto-upgrades  # auto-upgrades
```

## Auto-Recovery Safety Net (installed by default)

```bash
# Is Restart=always active? (should show Restart=always, RestartUSec=10s)
systemctl --user show openclaw-gateway -p Restart -p RestartUSec

# Is the watchdog timer scheduled? (fires every 60 s)
systemctl --user list-timers openclaw-gateway-watchdog.timer

# Watchdog activity (only logs on failures — silent is good)
journalctl --user -t openclaw-watchdog --since "1 hour ago"
```

If either check above shows something unexpected, re-run `install-oraclaw.sh` on the VM — it's idempotent and will repair the safety net without touching your data.

## Model Chain

```bash
# Which model is primary?
jq -r '.agents.defaults.model.primary' ~/.openclaw/openclaw.json

# Full chain (primary + fallbacks in order)
jq '.agents.defaults.model' ~/.openclaw/openclaw.json

# Heartbeat model (what the background check-ins use)
jq '.agents.defaults.heartbeat' ~/.openclaw/openclaw.json
```

Full guide — what each slot is for, why every slug starts with `openrouter/`, and how to swap one safely: **[docs/MODELS.md](MODELS.md)**.

## Rotate Gateway Token

This script runs **on the VM**, not on your client PC — so there's no separate `.ps1` version for Windows. Windows users SSH into the VM and run the `.sh` script there (the VM is Ubuntu; bash is native).

```bash
# Mac (client) → one command
ssh my-oraclaw 'bash ~/oraclaw/scripts/rotate-gateway-token.sh'

# Windows (client) → same command in PowerShell
ssh my-oraclaw 'bash ~/oraclaw/scripts/rotate-gateway-token.sh'

# Or interactively on the VM after ssh'ing in
bash ~/oraclaw/scripts/rotate-gateway-token.sh
```

Script prints the new token once — paste into dashboard ⚙ Settings → Save.

## Rotate OpenRouter Key

```bash
# At https://openrouter.ai/keys — create new key, then on the VM:
sed -i "s|OPENROUTER_API_KEY=.*|OPENROUTER_API_KEY=sk-or-NEW_KEY|" ~/.openclaw/.env
systemctl --user restart openclaw-gateway
# Then delete the old key at https://openrouter.ai/keys
```

## Emergency

- Can't SSH → OCI console → Instances → your VM → **Console connection** (Field Manual Appendix B)
- Dashboard won't load → `systemctl --user restart openclaw-gateway`, wait 30 s
- Model stuck in rate limit → fallback chain runs automatically; check logs
- Locked out by fail2ban → wait 1 hour, or via OCI console: `sudo fail2ban-client set sshd unbanip <your-ip>`

## Symptoms → First Command to Run

| Symptom | Command |
|---------|---------|
| Dashboard shows 502 after clicking Update | `ssh my-oraclaw 'systemctl --user restart openclaw-gateway'` (or the `recover-gateway.sh`/`.ps1` helper) |
| Dashboard shows "unauthorized" | `jq -r .gateway.auth.token ~/.openclaw/openclaw.json` |
| Dashboard won't load | `systemctl --user status openclaw-gateway` |
| Reply never comes | `journalctl --user -u openclaw-gateway -n 30` |
| "Unknown model" / model not found | See [docs/MODELS.md](MODELS.md) — usually a missing `openrouter/` prefix |
| All heartbeats failing 404 | Heartbeat model likely retired upstream; swap per [docs/MODELS.md](MODELS.md) |
| VM unreachable | OCI console → Instance status |
| "Connection refused" | `curl -I http://127.0.0.1:18789/` on the VM |
| Disk full | `df -h; du -sh ~/.openclaw/*` |

## Asking an AI for help

1. Make sure your AI coding assistant has read `AGENTS.md` at the repo root (most harnesses auto-load it).
2. Open `docs/WHEN-THINGS-GO-WRONG.md` and copy the section that matches your symptom into the chat.
3. Add any error text or log output the symptom section asks for.
