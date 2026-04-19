# oraclaw Cheatsheet

*One-page reference.  Print it, pin it, or paste a section at your AI assistant.*

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

```bash
source ~/.nvm/nvm.sh
npm install -g openclaw@latest
systemctl --user restart openclaw-gateway
```

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

## Rotate Gateway Token

```bash
bash ~/oraclaw/scripts/rotate-gateway-token.sh
# Script prints new token once — paste into dashboard ⚙ Settings → Save
```

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
| Dashboard shows "unauthorized" | `jq -r .gateway.auth.token ~/.openclaw/openclaw.json` |
| Dashboard won't load | `systemctl --user status openclaw-gateway` |
| Reply never comes | `journalctl --user -u openclaw-gateway -n 30` |
| VM unreachable | OCI console → Instance status |
| "Connection refused" | `curl -I http://127.0.0.1:18789/` on the VM |
| Disk full | `df -h; du -sh ~/.openclaw/*` |

## Asking an AI for help

1. Make sure your AI coding assistant has read `AGENTS.md` at the repo root (most harnesses auto-load it).
2. Open `docs/WHEN-THINGS-GO-WRONG.md` and copy the section that matches your symptom into the chat.
3. Add any error text or log output the symptom section asks for.
