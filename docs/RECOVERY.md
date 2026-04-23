# Recovery — when the dashboard Update breaks your Claw

**Read this page if:** you clicked the `Update` button in the OpenClaw Control UI, and now the dashboard won't load or shows a `502` error.

**The short version:** your gateway process died during the update and didn't come back. One SSH command brings it back. If you installed this kit from `install-oraclaw.sh` version 1.1 or later, your VM already has auto-recovery safeguards — most of the time you won't have to do anything; the gateway comes back on its own within about a minute. This page covers what to do when you need to help it along.

---

## How to tell your Claw is broken

Any of these symptoms after pressing `Update`:

- Dashboard URL returns `502 Bad Gateway` instead of loading.
- Dashboard loads but says "Gateway unreachable" or never connects.
- Dashboard just spins indefinitely on a white page.
- The in-page update progress bar hangs past 2 minutes.

If the dashboard comes back on its own after 30–90 seconds, the auto-recovery already did its job — carry on. If it's still broken after 2 minutes, use the command below.

---

## The one command that fixes it

From your Mac **Terminal** or Windows **PowerShell**, run:

`ssh my-oraclaw 'systemctl --user restart openclaw-gateway'`

(The `ssh` command is identical on both platforms — Windows 11 ships OpenSSH built-in.) Replace `my-oraclaw` with whatever SSH alias you gave your VM (the same alias you used during `bootstrap-mac.sh` on Mac or `bootstrap-windows.ps1` on Windows). Wait 30–60 seconds, then reload the dashboard in your browser.

---

## The even shorter command (if you have the kit scripts)

This script does the restart for you, then polls the `/health` endpoint until it comes back green (or gives up with next-step guidance after 2 minutes). Same end result as the one-liner above, with a clearer pass/fail signal.

**Mac (Terminal):**

```bash
bash ~/oraclaw/scripts/recover-gateway.sh my-oraclaw
```

**Windows 11 (PowerShell):**

```powershell
& $env:USERPROFILE\oraclaw\scripts\recover-gateway.ps1 my-oraclaw
```

---

## If the command doesn't work

Try these, in order. Stop as soon as one works.

**1. Wait longer.** On a cold gateway with many plugins (first restart after a VM reboot), recovery can take 60–90 seconds. Watch the dashboard URL rather than typing another command.

**2. Check the service is actually running.** `ssh my-oraclaw 'systemctl --user status openclaw-gateway'`. If it says `failed`, look at the tail of the logs for a clue: `ssh my-oraclaw 'journalctl --user -u openclaw-gateway -n 80 --no-pager'`.

**3. Clear any systemd "start limit hit" block.** If systemd gave up because the service restarted too many times in a short window, it needs a manual nudge: `ssh my-oraclaw 'systemctl --user reset-failed openclaw-gateway && systemctl --user restart openclaw-gateway'`.

**4. Reboot the VM.** Last resort over SSH: `ssh my-oraclaw 'sudo reboot'`. Wait 90 seconds, reload the dashboard. This is safe — everything restarts automatically.

**5. SSH itself is broken.** Use the OCI serial console. See the "Emergency Recovery (Console Connection)" appendix in `docs/FIELD-MANUAL.md`. You always have this escape hatch — Oracle gives every VM a serial console that bypasses SSH entirely.

---

## Why this happens

When you click `Update` in the dashboard, OpenClaw does an in-process restart by sending its supervisor a `SIGUSR1` signal. The supervisor is supposed to re-exec the gateway cleanly. Sometimes it doesn't — the process exits with a clean exit code `0`, and the service management layer (systemd) sees "clean exit, nothing to do" and leaves the gateway down.

The fix this kit installs is a tiny config change (`Restart=always`) that tells systemd to relaunch the gateway no matter how it exited. Plus a user-level watchdog timer that probes `/health` every 60 seconds and restarts the gateway if it's been unresponsive for 2 minutes. These two layers together catch this failure mode automatically in the vast majority of cases.

You didn't do anything wrong. It's a known edge case, and the safeguards are designed to handle it without you noticing.

---

## How to avoid needing this page

A few habits reduce the odds of ever coming back here:

- **Keep an SSH terminal open** on your VM before clicking `Update` in the dashboard. If anything goes wrong, you already have the access you need.
- **Update during quiet hours**, not when someone needs the assistant. Recovery takes 60–90 seconds even in the happy case.
- **Skip updates that promise only "minor improvements".** Wait for changelog entries that matter. Every update is a chance for this failure mode; fewer updates = fewer chances.
- **Rerun `install-oraclaw.sh` or the Ansible role** after a major OpenClaw version bump. The safeguards are idempotent — re-running costs nothing and picks up any improvements in the kit.

---

## Related docs

- `docs/FIELD-MANUAL.md` — full installation and daily-ops guide
- `docs/CHEATSHEET.md` — one-page ops reference
- `docs/MODELS.md` — how the model chain works, how to swap primary vs heartbeat models
- `scripts/recover-gateway.sh` — the scripted one-liner
- `scripts/verify-self-heal.sh` — proves the auto-recovery is working without you having to wait for a real incident

---

## For support / copy-paste debug info

If you need to ask for help, paste the output of these two commands into your message:

- `ssh my-oraclaw 'journalctl --user -u openclaw-gateway --since "10 minutes ago" --no-pager | tail -60'`
- `ssh my-oraclaw 'systemctl --user status openclaw-gateway --no-pager -l'`

That usually contains the exact error. Redact any lines containing `token=`, `api_key=`, or `authorization:` before sharing.
