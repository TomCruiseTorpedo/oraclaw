# AGENTS.md

Context for AI coding assistants (Cursor, Copilot in VS Code, Antigravity,
Claude Code, Aider, etc.). Auto-loaded when the user opens this repo or
the target OpenClaw host. Keeps you grounded so weaker free-tier models
don't hallucinate paths, ports, or commands.

Pair with:

- `docs/FIELD-MANUAL.md` — full setup walkthrough (Sections 0–9)
- `docs/CHEATSHEET.md` — one-page daily-ops reference
- `docs/RECOVERY.md` — what to do if the dashboard's Update button leaves the gateway dead
- `docs/MODELS.md` — primary / fallbacks / heartbeat roles + how to swap any slot (every slug is `openrouter/`-prefixed; see file for why)
- `docs/WHEN-THINGS-GO-WRONG.md` — pre-written prompts for common failures; the user can paste a section straight into your chat if they're stuck

---

## Stack

- Host: Oracle Cloud "Always Free" VM — Ubuntu 24.04 Minimal, aarch64 (Ampere A1)
- Default sizing: 1 instance × 2 OCPU / 12 GB RAM / 100 GB boot / 120 VPUs / 8 GB swap (leaves ~50% of the Always-Free tier as headroom for re-deploys or a future second Claw)
- OpenClaw: `npm install -g openclaw@latest` under user `ubuntu`
- Node: 24.15.0 via nvm at `~/.nvm/versions/node/v24.15.0/`
- Service: systemd **USER** unit `openclaw-gateway.service` — use `systemctl --user`, NOT `sudo systemctl`
- Gateway: binds `127.0.0.1:18789` (loopback only, never public)
- Dashboard: `sudo tailscale serve --bg --https=443 http://127.0.0.1:18789` at `https://<vm>.<tailnet>.ts.net`
- Config: `~/.openclaw/openclaw.json` (auth token at `.gateway.auth.token`)
- API key: `~/.openclaw/.env` (`OPENROUTER_API_KEY=...`)
- Dashboard URL stored at `~/.openclaw/dashboard-url` (written by `install-oraclaw.sh` at end of install; read by `scripts/open-dashboard.sh` / `.ps1` helpers)
- Models: every slug is prefixed `openrouter/` so they route through the OpenRouter plugin (one API key). Primary: `openrouter/inclusionai/ling-2.6-flash:free`. 5 free fallbacks: `openrouter/google/gemma-4-31b-it:free`, `openrouter/nvidia/nemotron-3-super-120b-a12b:free`, `openrouter/minimax/minimax-m2.5:free`, `openrouter/z-ai/glm-4.5-air:free`, `openrouter/qwen/qwen3-coder:free`.
- Heartbeat model override: `openrouter/meta-llama/llama-3.2-3b-instruct:free` + `lightContext: true`. Much smaller than the main chain, because the recurring background check-ins fire far more often than user-initiated work.
- Heartbeat schedule: one cron job every 6 hours; `isolatedSession: true` keeps the Main and Heartbeat chats separate.
- Update-safety safety net: (A) systemd `Restart=always` drop-in, so the Control UI "Update" button's in-process restart can't leave the gateway dead. (B) user-level watchdog timer at `~/.config/systemd/user/openclaw-gateway-watchdog.timer` that probes `localhost:18789/health` every 60 s and restarts the service on two consecutive failures. See `docs/RECOVERY.md` for the one-command manual escape hatch.

## Security posture (applied by `scripts/install-oraclaw.sh`)

- UFW: default-deny incoming; allows `22/tcp` (SSH recovery) and all on `tailscale0`
- fail2ban sshd jail: `bantime=1h`, `maxretry=3`, `ignoreip = 127.0.0.1/8 ::1 100.64.0.0/10`
- SSH hardening via `/etc/ssh/sshd_config.d/99-hardening.conf`: `PermitRootLogin no`, `AllowUsers ubuntu`, `MaxAuthTries 3`, `ClientAliveInterval 300`, `X11Forwarding no`
- systemd user-unit hardening: `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=full`, `LockPersonality`, `RestrictRealtime`, `SystemCallArchitectures=native`, `RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_NETLINK`
- Unattended security upgrades (`/etc/apt/apt.conf.d/20auto-upgrades`)
- Runs as `ubuntu` user, never root. Passwordless sudo is the OCI default — do NOT treat sudo as a security boundary.

## Operations

| Task | Command |
|---|---|
| Start / stop / restart | `systemctl --user {start,stop,restart} openclaw-gateway` |
| Stream logs | `journalctl --user -u openclaw-gateway -f` |
| Status | `systemctl --user status openclaw-gateway` |
| Edit config (then restart) | edit `~/.openclaw/openclaw.json`, then `systemctl --user restart openclaw-gateway` |
| Firewall status | `sudo ufw status` |
| fail2ban status | `sudo fail2ban-client status sshd` |
| Rotate gateway token | `bash ~/oraclaw/scripts/rotate-gateway-token.sh` |
| Update OpenClaw (safe path) | `source ~/.nvm/nvm.sh && npm install -g openclaw@latest && systemctl --user restart openclaw-gateway` |
| Recover gateway after dashboard-Update hang | `bash ~/oraclaw/scripts/recover-gateway.sh my-oraclaw` (from client) or `systemctl --user restart openclaw-gateway` (on VM) |
| Watchdog state | `journalctl --user -t openclaw-watchdog --since "1 hour ago"` |

## Client-side helpers (run on Mac / Windows 11, NOT on the VM)

- `scripts/open-dashboard.sh` / `.ps1` — fetches dashboard URL + gateway token via SSH, copies token to clipboard (pbcopy / Set-Clipboard), opens URL in default browser.  Auto-detects the VM via the first `.ts.net` Host entry in `~/.ssh/config`, or takes an explicit hostname arg.
- `scripts/approve-pairing.sh` / `.ps1` — SSHes to VM, runs `openclaw devices list`, extracts UUID-format request-ids, auto-approves if exactly one pending, prompts otherwise.  Used after the user pastes the token into the dashboard for the first time ("Device pairing required" is EXPECTED — not an error; see §7 of the Field Manual).

## Rules when helping

1. Prefer **minimal, reversible** changes. Before editing config, back it up: `cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.pre-$(date +%s)`
2. **Never** recommend running as root. **Never** recommend opening additional UFW ports. The public attack surface is zero by design — do not widen it.
3. Always name the **exact file path** and the **exact `systemctl --user` restart command** in any change you propose.
4. The service is a **USER** systemd unit. `sudo systemctl status openclaw-gateway` will NOT find it.
5. The dashboard is reachable only over the user's tailnet. Do NOT propose nginx, public DNS, Certbot, Let's Encrypt, or buying a domain — that is a different architecture.
6. OpenRouter: free-tier API is 50 calls/day; a one-time $10 top-up raises the free-model cap to 1000/day. HTTP 429 responses are normal — the fallback chain handles them.
7. If uncertain which host you're on, check `hostname` and `tailscale status` before acting.
8. Do NOT run `apt upgrade` interactively — unattended-upgrades handles drift in the background.

## Do NOT suggest

- **Nginx + Certbot + public domain** → Tailscale serve already handles HTTPS and cert rotation with zero public surface.
- **Docker / Docker Compose migration** → native systemd + user account is ~90% of rootless-Podman isolation at ~20% of the ops cost for a single-operator setup.
- **Ollama / local model inference** → Ampere A1 has no GPU; CPU inference on ARM is too slow to be useful here.
- **Open WebUI env vars** (`WEBUI_SECRET_KEY`, `ENABLE_SIGNUP`, `DEFAULT_USER_ROLE`, `AUDIO_STT_ENGINE`, `OLLAMA_FLASH_ATTENTION`, `ENABLE_BASE_MODELS_CACHE`, etc.) → different product. OpenClaw uses `~/.openclaw/openclaw.json`, not env-var-driven config.
- **Unverified third-party audit tools** ("SecureClaw" and similar) → use built-in `openclaw security audit --deep` per `docs.openclaw.ai/gateway/security` if an audit is actually needed.

## See also

- `docs/FIELD-MANUAL.md` — the long walkthrough
- `docs/CHEATSHEET.md` — daily-ops refcard
- `docs/RECOVERY.md` — plain-English dashboard-update-broke-my-Oraclaw walkthrough + escalation path
- `docs/MODELS.md` — primary / fallbacks / heartbeat roles + `openrouter/` prefix rationale + swap guide
- `docs/WHEN-THINGS-GO-WRONG.md` — copy-paste-ready failure prompts
- `scripts/install-oraclaw.sh` — authoritative VM installer; read it first to see what's actually on the box
- `scripts/recover-gateway.sh` — one-shot "bring my dashboard back" lifeline
