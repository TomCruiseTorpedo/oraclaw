# When Things Go Wrong — Copy-Paste Help Prompts

When Oraclaw misbehaves, your AI coding assistant (Copilot, Cursor, Antigravity, Claude Code, etc.) can help you diagnose it — but only if you give it enough context.  Weaker free-tier models (Haiku 4.5, GPT-5-mini, etc.) especially benefit from a pre-formed prompt instead of a vague "it's broken".

This file is a collection of such prompts.  Find the section that matches your symptom, copy the whole block into your AI's chat, add any details the block asks for, and send.

Most harnesses (Cursor, Antigravity, Claude Code) will also auto-load `AGENTS.md` at the repo root, which gives the AI the technical stack context.  If yours doesn't (e.g. Copilot in VS Code when the repo isn't open), paste the contents of `AGENTS.md` into the chat first, before the symptom prompt.

---

## 1. I can't reach the dashboard URL in my browser

```
I'm running Oraclaw — an OpenClaw agentic harness deployed to an Oracle
Cloud Always-Free Ubuntu 24.04 aarch64 VM, reachable only via Tailscale.
The setup follows the Oraclaw Field Manual (see AGENTS.md for the stack).

Symptom: when I open the dashboard URL in my browser, the page won't
load.  The URL is:

    https://<paste your dashboard URL here>

My Tailscale tray/menu-bar app shows: <paste what it says — "Connected",
"Disconnected", hostname, etc.>

Can you walk me through diagnosing this one step at a time?  Start with
the simplest checks — don't change anything on the server yet.  I'd
rather understand the problem before fixing it.
```

---

## 2. The dashboard loads but shows "Unauthorized"

```
I'm running Oraclaw (see AGENTS.md).  The dashboard loads at my tailnet
URL, but instead of the chat interface I see "Unauthorized".

I think my login token may be wrong or stale.  Can you give me the exact
command to re-read my current token from the VM (I'm SSHed in as user
`ubuntu`), and then tell me how to paste it into the dashboard's
Settings panel?
```

---

## 3. The dashboard shows "Device pairing required"

**"Device pairing required" is expected on first visit — it is not an error.** Every new browser has to be explicitly approved server-side.  The fastest path is the helper script from your client machine:

```bash
bash ~/oraclaw/scripts/approve-pairing.sh                # Mac
& $env:USERPROFILE\oraclaw\scripts\approve-pairing.ps1   # Windows
```

If that doesn't work (helper can't reach the VM, unusual output, etc.), paste this prompt into your AI:

```
I'm running Oraclaw (see AGENTS.md).  The dashboard says "Device pairing
required" when I load it in my browser.  The approve-pairing helper
didn't complete successfully — here's its output:

<paste the helper's error output>

I'm SSHed into the VM as `ubuntu` now.  Walk me through listing pending
device-pairing requests and approving mine using the `openclaw devices`
CLI.
```

---

## 4. I send a message in the dashboard but nothing happens

```
I'm running Oraclaw (see AGENTS.md).  I type a message in the dashboard
chat, hit Send, and either nothing happens or the "thinking" indicator
never resolves.

Here are the last 30 lines of the gateway log (please explain any
errors you see):

<paste output of: ssh my-oraclaw 'journalctl --user -u openclaw-gateway -n 30 --no-pager'>

Walk me through diagnosing this one step at a time.  The most likely
causes are (a) OpenRouter rate-limited me, (b) my OpenRouter API key is
wrong, or (c) I hit the free-tier 50-calls-per-day cap.  But don't
assume — look at the logs first.
```

---

## 5. SSH to the VM fails with "Connection refused" or "Permission denied"

```
I'm running Oraclaw (see AGENTS.md).  I can't SSH into my VM.  The
exact error I'm seeing is:

<paste the full error message from your terminal / PowerShell>

Things I already know:
- I'm on <Mac Apple Silicon | Windows 11>
- My SSH key is at <~/.ssh/id_ed25519 | %USERPROFILE%\.ssh\id_ed25519>
- The VM shows as <Running | Stopped | Offline> in the OCI console
- The VM shows as <Online | Offline> in my Tailscale app

Can you walk me through diagnosing this step by step?  Don't suggest
reinstalling or destroying anything — I want to repair the connection,
not rebuild.
```

---

## 6. The Oraclaw installer (install-oraclaw.sh) failed partway through

```
I'm running the Oraclaw installer (`install-oraclaw.sh`) on a fresh
Oracle Cloud Ampere A1 Ubuntu 24.04 Minimal VM.  The script failed at
step <paste the step number from its output, e.g. "[6/13]">.

Here is the last 30 lines of output leading up to the failure:

<paste the last ~30 lines of the installer output>

The installer is designed to be idempotent — safe to re-run.  Before I
re-run it, can you explain what went wrong based on the output, and
whether I should fix anything manually first?
```

---

## 7. The VM is full (out of disk space)

```
I'm running Oraclaw (see AGENTS.md).  My VM appears to be out of disk
space.  The symptom is:

<describe: dashboard won't respond / SSH is very slow / got an
 out-of-space error somewhere>

Output of `df -h /` on the VM:

<paste output of: ssh my-oraclaw 'df -h /'>

Output of the top disk-using directories in my OpenClaw data:

<paste output of: ssh my-oraclaw 'du -sh ~/.openclaw/*' | sort -h>

What's the safest thing to delete first?  I don't want to lose chat
history or config accidentally.
```

---

## 8. I forgot my dashboard login token

```
I'm running Oraclaw (see AGENTS.md).  I forgot my dashboard login
token.  I'm SSHed into the VM as user `ubuntu`.

Give me the exact one-line command to re-read the token from the
OpenClaw config file, and remind me where to paste it in the dashboard.
```

---

## 9. Oracle Cloud says "Out of host capacity" when I try to create my VM

```
I'm trying to create an Ampere A1 Always-Free VM in Oracle Cloud for
the Oraclaw setup, and every time I click Create I get "Out of host
capacity".

Status of my account: <Pay As You Go (PAYG, approved) | Free Trial |
Free Tier Only | Pending upgrade>.

My region is: <ca-toronto-1 / us-ashburn-1 / etc.>

Is there anything I should do differently?  I already know that the
fix is usually to be on PAYG (not Free Trial) and to retry at a
different time of day.  Confirm or correct that, and tell me if there's
anything else to check before I just keep retrying.
```

---

## 10. I got locked out by fail2ban (too many failed SSH attempts)

```
I'm running Oraclaw (see AGENTS.md).  I think I got banned by fail2ban
on my own VM — SSH hangs or refuses from my current IP, but I know
nothing on the VM is actually broken.

I have OCI serial console access (Appendix B of the Field Manual).
Walk me through connecting via the serial console and unbanning my IP.
I do NOT want to disable fail2ban permanently — I just need to unban
myself so I can SSH again.
```

---

## 11. My OpenRouter account says I've hit a rate limit

```
I'm running Oraclaw (see AGENTS.md).  OpenRouter is returning rate-limit
errors (HTTP 429) and my dashboard responses are failing or very slow.

I'm on <the free tier with no credits | the $10 top-up plan>.

What are my options in order of best-to-worst?  I don't want to pay
per call — I want to stay on free models if possible.
```

---

## 12. I want to start over / nuke and redeploy

```
I'm running Oraclaw (see AGENTS.md).  I want to wipe this VM and start
over from scratch — either because I messed up the config badly, or
because I want to deploy a fresh one.

Walk me through the safest order to do this:
  1. What do I save first (chat history, config, etc.)?
  2. How do I cleanly remove the OCI instance?
  3. Do I need to remove anything from the OCI VCN / networking?
  4. Do I need to remove anything from my Tailscale admin console?
  5. What's the minimum I need to redo vs. reuse?

Be careful about anything that would charge my Oracle account — this is
supposed to stay on the Always Free tier.
```

---

## General tips for asking your AI for help

- **Paste AGENTS.md first** if your harness doesn't auto-load it.  It's short (~80 lines) but saves weaker models from hallucinating wrong paths.
- **Include actual error text.**  "It's broken" takes five rounds of back-and-forth; a pasted error gets you to the answer immediately.
- **Say what you already tried.**  Otherwise the AI will suggest the same thing again.
- **Ask for one small step at a time** when you're not sure — "walk me through this, one check at a time" — instead of "fix it".  You learn more, and you catch mistakes before they compound.
- **Never paste your tokens or API keys** into an AI chat.  If the symptom involves tokens, paste the command that reads the token, not the token itself.
