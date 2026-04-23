# Oraclaw

**Your always-on AI helper, running 24/7 on a free Oracle Cloud VM, reachable only from your own devices.**

No hosting fees.  No public-facing endpoint.  No domain name to buy.  No DNS to configure.

---

## Pre-flight checklist

Please confirm all six of these before you start, no matter which path you pick below. Most setup pain we've seen is because one of these was skipped. They're free and take ~20 minutes combined.

- [ ] **Oracle Cloud account** — create at [oracle.com/cloud/free](https://www.oracle.com/cloud/free/), then **immediately upgrade to Pay-As-You-Go**. Upgrade approval can take up to 8 hours; **start it first thing in the morning**. You will NOT be charged — PAYG just tells Oracle to prioritize your VM creation. See [docs/ORACLE-CLOUD-SETUP.md § Step 2](docs/ORACLE-CLOUD-SETUP.md#step-2--upgrade-to-pay-as-you-go-payg).
- [ ] **Tailscale account** — sign up free at [tailscale.com](https://tailscale.com). Tailscale lives in **two places** under this one account: (1) your Mac or Windows 11 computer (the Tailscale app), and (2) the Oracle Cloud VM (a background service). **Both installs are automated** — the Section 4 client bootstrap handles your computer, the Section 6 VM installer handles the server. Optional shortcut: while you're on tailscale.com making the account, download the client app for your computer too (the download link is right there, 30 seconds) — saves a step later.
- [ ] **OpenRouter account + $10 top-up** — sign up at [openrouter.ai](https://openrouter.ai). The $10 raises your daily cap from 50 to 1000 calls on free models. Your card isn't charged per call.
- [ ] **GitHub account** — free at [github.com](https://github.com). Needed to clone this repo onto your client machine.
- [ ] **SSH keypair generated BEFORE you create the VM.** Do this in your client's terminal using [docs/FIELD-MANUAL.md § 1.5](docs/FIELD-MANUAL.md#15-generate-your-ssh-key-2-minutes-no-dependencies) or [docs/ORACLE-CLOUD-SETUP.md § Step 3](docs/ORACLE-CLOUD-SETUP.md#step-3--generate-your-ssh-key-2-minutes). ⚠ **Whatever public key you paste into Oracle at VM-creation time is permanently bound to that instance** — Oracle won't let you change it after, and if you lose the matching private key your only fix is to destroy the VM and start over (and the Ampere A1 capacity queue can eat hours). Get the key ready FIRST, pick it deliberately in Section 3.3 Step 9.
- [ ] **A Mac (Apple Silicon) or Windows 11 PC.** Intel Macs aren't supported. Linux clients work fine but aren't officially documented — open an issue if you want that path.

If any of the above aren't ready, stop and knock them out first.

---

## Pick your path

Setup has two main flows depending on how much help you have. Both cover the same ground; they just start differently.

### 🧑‍🏫 Path A — With help (recommended)

Choose this if someone is walking you through — in person, over screen-share, or via an AI coding assistant. For the AI-assistant case we recommend **Antigravity** first (most generous free tier, uses your existing Google account, runs shell commands by default), with **Cursor** or **GitHub Copilot Chat in VS Code** as alternatives. Full rationale + credit-saving tips in [docs/HARNESS-PROMPTS.md § Which assistant](docs/HARNESS-PROMPTS.md#which-ai-assistant-should-i-use).

1. Your helper walks you through [**docs/ORACLE-CLOUD-SETUP.md**](docs/ORACLE-CLOUD-SETUP.md) — a standalone walkthrough for account creation, PAYG upgrade, SSH key generation, and VM creation. ~1 hour, most of it waiting on Oracle.
2. When your VM is running, your helper hands you off to [**docs/FIELD-MANUAL.md**](docs/FIELD-MANUAL.md) **Section 4** (client setup → connect → install Oraclaw → open dashboard). ~20 minutes.
3. If you're using an AI assistant rather than a person, start by pasting the "Starting fresh" prompt from [**docs/HARNESS-PROMPTS.md**](docs/HARNESS-PROMPTS.md). The AI reads [AGENTS.md](AGENTS.md) for context and walks you through, one step at a time, waiting for your confirmation between steps.
4. **If you've never used a terminal**, read [**docs/TERMINAL-BASICS.md**](docs/TERMINAL-BASICS.md) first — 5 minutes, demystifies the thing that scares most first-timers.

### 🚶 Path B — Solo, self-paced

Choose this if you're doing it alone with no helper.

Read [**docs/FIELD-MANUAL.md**](docs/FIELD-MANUAL.md) start to finish. It's long but every step is copy-paste; no improvisation required. Budget 1.5–2 hours.

Quick reference when you need it: [**docs/CHEATSHEET.md**](docs/CHEATSHEET.md).

When something breaks: [**docs/WHEN-THINGS-GO-WRONG.md**](docs/WHEN-THINGS-GO-WRONG.md) has copy-paste prompts for common failures you can paste into any AI assistant.

If you get stuck and the AI's advice doesn't help, [**docs/RECOVERY.md**](docs/RECOVERY.md) covers the most common broken state (dashboard breaks after clicking "Update").

---

## The bootstrap one-liners

These go **after** you've created your Oracle Cloud VM (Path A Step 1 or Field Manual Section 3). They prepare your client machine.

**Mac (Apple Silicon):**

```bash
curl -fsSL https://raw.githubusercontent.com/TomCruiseTorpedo/oraclaw/main/scripts/bootstrap-mac.sh | bash
```

**Windows 11 (PowerShell running as Administrator):**

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
irm https://raw.githubusercontent.com/TomCruiseTorpedo/oraclaw/main/scripts/bootstrap-windows.ps1 | iex
```

Each script is **idempotent** (safe to re-run). It installs tools (git, Tailscale, jq, mosh/tmux on Mac), creates an SSH key if you don't have one, walks you through Tailscale login, and adds an SSH shortcut for your VM.

**If you want to generate just the SSH key first** (before creating your VM in Oracle), use the tiny standalone script:

- Mac: `bash ~/oraclaw/scripts/generate-ssh-key.sh`
- Windows 11: `& $env:USERPROFILE\oraclaw\scripts\generate-ssh-key.ps1`

More detail: [docs/FIELD-MANUAL.md § 4](docs/FIELD-MANUAL.md#4-set-up-your-client-machine-one-command).

### Phase 3 — Install Oraclaw on the VM

Follow **[docs/FIELD-MANUAL.md § 6](docs/FIELD-MANUAL.md#6-install-oraclaw-on-the-vm-one-command)**. One `scp` + one `ssh` command from your client copies the installer script to the VM and runs it. 5–10 minutes of output, then you're done.

When it finishes, open the dashboard URL in your browser and paste the login token it printed. That's the end of setup.

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
- Model allowlist: **1 primary + 4 free fallbacks = 5 total.** Primary is `openrouter/nvidia/nemotron-3-super-120b-a12b:free`. Every slug routes through your OpenRouter API key — no extra per-provider keys needed.
- Shell quality-of-life utilities baked in (ripgrep, fzf, zoxide, bat, eza, fd, tree, btop, glow, yq, gh, and more) — so when your AI assistant SSHes into the VM, it has modern tools to work with
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
| [docs/ORACLE-CLOUD-SETUP.md](docs/ORACLE-CLOUD-SETUP.md) | Standalone walkthrough for the Oracle Cloud phase — account → PAYG → SSH key → VM. Best for in-person or screen-share help. |
| [docs/FIELD-MANUAL.md](docs/FIELD-MANUAL.md) | The full walkthrough from scratch to a working dashboard. Best for solo self-paced. |
| [docs/CHEATSHEET.md](docs/CHEATSHEET.md) | One-page reference for daily operations after setup. |
| [docs/TERMINAL-BASICS.md](docs/TERMINAL-BASICS.md) | If you've never used a terminal — 5-minute primer covering open, paste, Enter, what red text means. |
| [docs/HARNESS-PROMPTS.md](docs/HARNESS-PROMPTS.md) | Copy-paste prompts for AI coding assistants. Lets the AI walk you through setup step-by-step. |
| [docs/RECOVERY.md](docs/RECOVERY.md) | What to do if the dashboard breaks after you click "Update" |
| [docs/MODELS.md](docs/MODELS.md) | How the model chain works + how to swap a model safely |
| [docs/WHEN-THINGS-GO-WRONG.md](docs/WHEN-THINGS-GO-WRONG.md) | Copy-paste AI help prompts for common post-setup failures |
| [AGENTS.md](AGENTS.md) | Context file auto-loaded by AI coding assistants (Antigravity, Cursor, GitHub Copilot Chat in VS Code) so they don't have to be taught the stack each time |

---

## File layout

```
oraclaw/
├── README.md                       ← you are here
├── AGENTS.md                       ← AI-assistant context file
├── LICENSE                         ← Apache License 2.0
├── docs/
│   ├── ORACLE-CLOUD-SETUP.md       ← standalone walkthrough for the OCI phase (best for guided flows)
│   ├── FIELD-MANUAL.md             ← full walkthrough start to finish (best for self-paced)
│   ├── CHEATSHEET.md               ← daily-ops reference
│   ├── TERMINAL-BASICS.md          ← 5-min primer for first-time terminal users
│   ├── HARNESS-PROMPTS.md          ← copy-paste prompts for AI coding assistants
│   ├── RECOVERY.md                 ← dashboard-update-broke-my-Oraclaw walkthrough
│   ├── MODELS.md                   ← primary / fallbacks / heartbeat roles + how to swap
│   └── WHEN-THINGS-GO-WRONG.md     ← AI help prompts for post-setup failures
└── scripts/
    ├── generate-ssh-key.sh         ← Mac: minimal SSH-key-only helper (for the OCI step)
    ├── generate-ssh-key.ps1        ← Windows 11: same
    ├── bootstrap-mac.sh            ← Mac (Apple Silicon) full client setup
    ├── bootstrap-windows.ps1       ← Windows 11 full client setup
    ├── install-oraclaw.sh          ← VM installer (runs on the Oracle Cloud VM)
    ├── open-dashboard.sh           ← Mac: open dashboard + copy token to clipboard
    ├── open-dashboard.ps1          ← Windows 11: same
    ├── approve-pairing.sh          ← Mac: one-command "approve this browser"
    ├── approve-pairing.ps1         ← Windows 11: same
    ├── recover-gateway.sh          ← Mac: one-shot "bring my dashboard back" command
    ├── recover-gateway.ps1         ← Windows 11: same
    ├── install-shell-utils.sh      ← retrofit shell QoL utilities onto existing VMs (ripgrep/fzf/zoxide/bat/…)
    └── rotate-gateway-token.sh     ← rotate the gateway auth token (runs on the VM; no .ps1 needed)
```

---

## License

Licensed under the [Apache License 2.0](LICENSE).  You're welcome to fork this and adapt it for your own audience — just carry the license text through and don't imply endorsement by the original authors.

## Acknowledgements

- [OpenClaw](https://openclaw.ai) — the agentic harness that actually runs on the VM
- [Oracle Cloud Always Free tier](https://www.oracle.com/cloud/free/) — the hosting that makes this free
- [Tailscale](https://tailscale.com) — the private network that makes public-IP-less hosting safe and easy
- [OpenRouter](https://openrouter.ai) — the unified LLM inference gateway
