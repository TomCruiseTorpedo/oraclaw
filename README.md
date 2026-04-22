# Oraclaw

**Your always-on AI helper, running 24/7 on a free Oracle Cloud VM, reachable only from your own devices.**

No hosting fees.  No public-facing endpoint.  No domain name to buy.  No DNS to configure.

---

## What is this?

Oraclaw is a ready-to-use install kit for putting [OpenClaw](https://openclaw.ai) — a headless AI agent — onto an Oracle Cloud "Always Free" Ampere A1 VM, behind [Tailscale](https://tailscale.com) so only your own devices can reach it.

You get a browser dashboard you can open from any of your devices, and the agent runs 24/7 — ready when you have a question, or checking in on its own schedule to keep working on whatever you've asked it to track.

## Who is this for?

- Curious people who want their own agentic AI running in the cloud without paying for hosting
- Non-technical users who can copy and paste commands and follow a step-by-step guide — this kit is designed for first-time users and assumes nothing about your technical background
- You're on an **Apple Silicon Mac** (M1 / M2 / M3 / M4 / M5) or a **Windows 11 PC**

## What you'll need before starting

- **Oracle Cloud account** (free tier — gets upgraded to Pay As You Go during setup, but you will not be charged as long as you stay inside the free-tier limits)
- **Tailscale account** (free personal tier — you'll create it during client setup)
- **OpenRouter API key** (free models are the default; a one-time **$10 top-up is strongly recommended** to raise your daily limit from 50 calls to 1000 calls)
- About an hour of your time (most of it waiting on downloads and Oracle Cloud provisioning)
- A **credit card** — for Oracle verification and the OpenRouter top-up.  Neither will charge you as long as you follow the guide.

Full prerequisites list: [docs/FIELD-MANUAL.md § 1](docs/FIELD-MANUAL.md#1-what-you-need-before-starting).

---

## The setup, at a glance

The full setup has three phases.  **Start with the Field Manual — it walks you through every click.**  The one-liners below are convenience commands for the middle phase (preparing your client machine); they don't replace the Field Manual.

### Phase 1 — Oracle Cloud account + free VM

Follow **[docs/FIELD-MANUAL.md](docs/FIELD-MANUAL.md) Sections 1–3**.

The single biggest thing to know: **upgrade your Oracle account to Pay As You Go on day one**.  It can take up to 8 hours to approve, and you can't reliably create an Always-Free VM without it.  Start this first thing in the morning; come back after lunch.

### Phase 2 — Set up your client machine

Once the VM is running, prepare your Mac or Windows 11 PC to talk to it.  Each script below is idempotent (safe to re-run), installs the tools you need, generates an SSH key, clones this repo to `~/oraclaw`, walks you through Tailscale login, and adds an SSH shortcut for your VM.

**Mac (Apple Silicon):**

```bash
curl -fsSL https://raw.githubusercontent.com/TomCruiseTorpedo/oraclaw/main/scripts/bootstrap-mac.sh | bash
```

**Windows 11 (PowerShell running as Administrator):**

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
irm https://raw.githubusercontent.com/TomCruiseTorpedo/oraclaw/main/scripts/bootstrap-windows.ps1 | iex
```

More detail on what these do: [docs/FIELD-MANUAL.md § 4](docs/FIELD-MANUAL.md#4-set-up-your-client-machine-one-command).

### Phase 3 — Install Oraclaw on the VM

Follow **[docs/FIELD-MANUAL.md § 6](docs/FIELD-MANUAL.md#6-install-oraclaw-on-the-vm-one-command)**.  It's one `scp` + one `ssh` command from your client that copies the installer script to the VM and runs it.  About 5–10 minutes of script output, then you're done.

When it finishes, open the dashboard URL in your browser and paste the login token it printed.  That's the end of setup.

---

## What gets installed on your VM

- Node.js 24.15.0 (via nvm)
- OpenClaw, running as a `systemd` user service, bound to `127.0.0.1:18789` only — never exposed to the public internet
- Tailscale with `tailscale serve --https=443` (tailnet-only HTTPS dashboard, no public port)
- UFW firewall (default-deny incoming; allows only `22/tcp` for SSH and all traffic on `tailscale0`)
- fail2ban (sshd jail; 1 h ban after 3 failed logins)
- SSH hardening: `PermitRootLogin no`, `AllowUsers ubuntu`, `MaxAuthTries 3`
- Unattended security upgrades enabled
- Swap auto-sized to ~2/3 of detected RAM (6 GB RAM → 4 GB swap; 12 GB → 8 GB; 24 GB → 16 GB)
- 1 heartbeat cron job, every 6 hours, `isolatedSession: true` (keeps Main and Heartbeat chats separate)
- Model allowlist: `openrouter/inclusionai/ling-2.6-flash:free` primary + 5 free fallbacks — every slug routes through your OpenRouter API key (no extra per-provider keys needed)
- A dedicated tiny model for heartbeat check-ins (so the recurring background work is free and fast, even when your main model is bigger)
- **Auto-recovery safety net:** if the gateway ever dies — including the one failure mode where clicking the dashboard's Update button leaves it stuck — `systemd` relaunches it within 10 seconds, and a background health-probe timer kicks it again 60 seconds later if it's still not responding.  See [docs/RECOVERY.md](docs/RECOVERY.md) for the manual escape hatch if you ever need it (most people never will).

The security posture is intentionally low-maintenance.  No domain, no Nginx, no Certbot, no Docker — Tailscale replaces every one of those moving parts.  For the rationale, see [AGENTS.md](AGENTS.md) → "Do NOT suggest".

## Recommended sizing

Default (what Section 3.3 of the Field Manual recommends): **1 VM × 2 OCPU / 12 GB RAM / 100 GB boot volume / 120 VPUs / 8 GB swap.**  This gives you one responsive Oraclaw and leaves ~50% of the Always-Free tier unused as headroom, so you can spin up a second Oraclaw later or redeploy without deleting anything.

The full 1 / 2 / 4 sizing options are in [docs/FIELD-MANUAL.md § 3.3](docs/FIELD-MANUAL.md#33-create-the-instance-vm).

---

## Documentation

| File | What it's for |
|---|---|
| [docs/FIELD-MANUAL.md](docs/FIELD-MANUAL.md) | The full walkthrough — start here |
| [docs/CHEATSHEET.md](docs/CHEATSHEET.md) | One-page reference for daily operations |
| [docs/RECOVERY.md](docs/RECOVERY.md) | What to do if the dashboard breaks after you click "Update" |
| [docs/MODELS.md](docs/MODELS.md) | How the model chain works + how to swap a model safely |
| [docs/WHEN-THINGS-GO-WRONG.md](docs/WHEN-THINGS-GO-WRONG.md) | Copy-paste AI help prompts for common failures |
| [AGENTS.md](AGENTS.md) | Context file auto-loaded by AI coding assistants (Cursor, Claude Code, Antigravity, etc.) so they don't have to be taught the stack each time |

---

## File layout

```
oraclaw/
├── README.md                       ← you are here
├── AGENTS.md                       ← AI-assistant context file
├── LICENSE                         ← Apache License 2.0
├── docs/
│   ├── FIELD-MANUAL.md             ← full walkthrough
│   ├── CHEATSHEET.md               ← daily-ops reference
│   ├── RECOVERY.md                 ← dashboard-update-broke-my-Oraclaw walkthrough
│   ├── MODELS.md                   ← primary / fallbacks / heartbeat roles + how to swap
│   └── WHEN-THINGS-GO-WRONG.md     ← AI help prompts for common failures
└── scripts/
    ├── bootstrap-mac.sh            ← Mac (Apple Silicon) client setup
    ├── bootstrap-windows.ps1       ← Windows 11 client setup
    ├── install-oraclaw.sh          ← VM installer (runs on the Oracle Cloud VM)
    ├── open-dashboard.sh           ← Mac: open dashboard + copy token to clipboard
    ├── open-dashboard.ps1          ← Windows: same
    ├── approve-pairing.sh          ← Mac: one-command "approve this browser"
    ├── approve-pairing.ps1         ← Windows: same
    ├── recover-gateway.sh          ← one-shot "bring my dashboard back" command
    └── rotate-gateway-token.sh     ← rotate the gateway auth token
```

---

## License

Licensed under the [Apache License 2.0](LICENSE).  You're welcome to fork this and adapt it for your own audience — just carry the license text through and don't imply endorsement by the original authors.

## Acknowledgements

- [OpenClaw](https://openclaw.ai) — the agentic harness that actually runs on the VM
- [Oracle Cloud Always Free tier](https://www.oracle.com/cloud/free/) — the hosting that makes this free
- [Tailscale](https://tailscale.com) — the private network that makes public-IP-less hosting safe and easy
- [OpenRouter](https://openrouter.ai) — the unified LLM inference gateway
