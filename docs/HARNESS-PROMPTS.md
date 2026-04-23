# Harness Prompts — talking to your AI assistant

**This page is for people setting up Oraclaw with help from an AI coding assistant.** The three we recommend — in preference order — are **Antigravity**, **Cursor**, and **GitHub Copilot Chat in VS Code**. Rationale below.

You don't need to memorize any of the setup steps. You can paste the prompts below into your AI assistant and it'll walk you through each phase one step at a time, waiting for you to say "done" or "stuck" between steps.

Every prompt below assumes your AI assistant has read `AGENTS.md` at the repo root. Most harnesses auto-load that file. If yours doesn't, paste the contents of `AGENTS.md` into the chat first, before any prompt here.

---

## Which AI assistant should I use?

Short version: **Antigravity first. Cursor or GitHub Copilot Chat in VS Code are reasonable alternatives.**

### Why Antigravity (recommended)

- **Most generous free tier of the three** — you'll rarely run out of credits during a full Oraclaw setup.
- **You already have a Google account.** Antigravity is Google's agentic IDE — sign in with the account you use for Gmail / Drive / YouTube. No new billing relationship.
- **Runs shell commands on your machine by default.** This matters *a lot* for this kit. Cursor's default "sandbox" mode refuses to execute shell commands until you explicitly flip a setting — which leaves a lot of first-timers stuck, because the AI is reading the Field Manual to them but can't actually *run* any of it. Antigravity doesn't have that problem.
- Models are strong (Gemini 3.1 Pro, Claude Sonnet 4.6).

### Why Cursor (second choice)

Solid AI IDE. Main catch: the default sandbox refuses shell commands. **Before you start, go to Settings → Terminal → allow shell execution.** Free tier has tighter usage caps than Antigravity, but the included models (Composer 1.5) are capable. If you already use Cursor daily, it's a fine choice.

### Why GitHub Copilot Chat in VS Code (third choice)

Weakest free models of the three (Claude Haiku 4.5, GPT-5-mini) but the biggest free-tier usage cap, by a lot. Install: VS Code → Extensions → search "GitHub Copilot Chat". Good fallback if Antigravity or Cursor start rate-limiting you mid-setup.

### Why not Claude.ai?

Claude Code (the agentic CLI) requires a paid Claude Pro or Max subscription — noobs on the free tier can't use it. Claude.ai's free web chat can't execute shell commands either. Skip it for this setup.

---

## Don't run out of credits mid-setup — the model-switch trick

Free-tier quotas in all three tools split into two pools:

1. **Premium models** (Gemini 3.1 Pro, Sonnet 4.6, GPT-5, Composer 1.5) — small pool, burns fast.
2. **Cheap models** (Gemini 2.5 Flash, Haiku 4.5, GPT-5-mini) — much larger pool.

The trick: **use a premium model ONCE to ingest this whole repo, then switch to a cheap model for the step-by-step execution.** Premium model comprehension is what matters for building context; a cheap model is plenty for "paste the next command, read the output, paste it back."

Paste this FIRST (with your premium model selected):

```
Read this whole Oraclaw repo — every file in docs/, every script in
scripts/, plus AGENTS.md and README.md at the root. Then give me a short
summary: what is this kit, what will I end up with, and the three biggest
gotchas for first-timers. After you confirm you've read everything, I'll
switch you to a cheaper/faster model and we'll start the walkthrough.
```

After you've read the summary, switch to the cheapest model your harness offers, then paste the **"Starting fresh"** prompt below.

---

## Starting fresh — "just set up Oraclaw with me"

Paste this into your AI assistant's chat. It'll handle the whole walkthrough:

```
I want to set up Oraclaw — a personal AI assistant running on a free Oracle
Cloud VM, reachable only via Tailscale.  The repo I'm using is called
oraclaw and has a Field Manual at docs/FIELD-MANUAL.md.

You can find the repo's full context in AGENTS.md at the repo root.  Load it
if you haven't already.

Walk me through the setup from scratch, one section at a time.  After each
section, STOP and ask me to confirm it worked before moving to the next.

Assume I'm a complete beginner — if something in the Field Manual uses
jargon, translate it first.  If a command goes wrong, diagnose from the
error output I paste before suggesting a fix.  Never drop multi-line shell
commands on me without telling me what they do first.

Start with Section 1 (prerequisites).
```

---

## Mid-setup prompts — you already started, got stuck somewhere

### "I'm on the Oracle Cloud account-creation page and I'm confused"

```
I'm following Oraclaw's docs/FIELD-MANUAL.md Section 2 (Oracle Cloud account
creation).  I'm stuck at <describe the screen you're on, or paste a short
description of what the UI is asking>.  Walk me through the next step.
```

### "I'm at the SSH key step and I don't know what to do"

```
Oraclaw's Field Manual Section 1.5 says to generate an SSH key.  I've never
done that before.  I'm on <Mac or Windows 11>.  Walk me through running
scripts/generate-ssh-key.sh (or .ps1) end to end, including opening my
terminal.  When it prints the key, tell me exactly how to paste it into
Oracle Cloud's Section 3.3 step 9.
```

### "My Oracle VM got created but I can't SSH into it"

```
I just created my Oracle Cloud VM and finished the client bootstrap
(bootstrap-mac.sh / bootstrap-windows.ps1).  When I run `ssh my-oraclaw`
I see this error:

<paste the full error>

My Tailscale menu-bar icon says: <what it says>.
My guess is: <what you think went wrong, or "I don't know">.

Walk me through diagnosing this step by step.  Start with the simplest
checks (is Tailscale actually online?  is the VM reachable?) before
anything involving file edits.
```

### "The installer on the VM exited with an error"

```
I ran `bash /tmp/install-oraclaw.sh` on the VM (Oraclaw Field Manual
Section 6).  It failed partway through.  Here's the last 30 lines of
output:

<paste the output>

The script is idempotent, so I can re-run it — but before I do, can you
read the error and tell me what went wrong?
```

### "The dashboard loads but I can't log in"

Open `docs/WHEN-THINGS-GO-WRONG.md` and copy the section that matches your symptom. That file has dedicated prompts for dashboard errors — better than asking generally.

---

## Post-setup prompts — everyday operations

### "Is my Oraclaw healthy?"

```
Can you SSH into my-oraclaw and run a quick health check?  I want to know:
  1. Is the openclaw-gateway systemd service running?
  2. Does /health return 200?
  3. When was the last heartbeat?
  4. Any errors in the last hour of logs?

Summarize in a short status report at the end.  Don't change anything.
```

### "My dashboard shows 502 after I clicked Update"

```
I clicked Update in the Control UI and now my Oraclaw dashboard shows
502 Bad Gateway.  Oraclaw's docs/RECOVERY.md has a walkthrough for this.
Read that doc, then walk me through the recovery.  Start with the quickest
fix (the one-command restart) before anything more complex.
```

### "I want to swap my primary model"

```
Read docs/MODELS.md in this Oraclaw repo so you understand the three
model slots (primary / fallbacks / heartbeat) and the openrouter/ prefix
rule.  Then walk me through swapping my primary to <new model name>.
Show me the exact file I need to edit and the exact lines to change
before I do anything.
```

### "I want to rotate the gateway token"

```
Oraclaw's scripts/rotate-gateway-token.sh is a server-side script.  Walk
me through running it over SSH from my client, then updating the token in
my dashboard's Settings panel.
```

---

## Prompt templates you can keep forever

### "Explain what this command does before I run it"

```
I'm about to paste this command into my Oraclaw VM:

<command>

In one or two sentences, tell me what this does — in plain English, no
jargon.  Then I'll decide whether to run it.
```

### "Read this error and tell me what to do, don't fix it yet"

```
Something went wrong.  Here's what I did:

<command I ran>

Here's what came back:

<the output / error>

Read it carefully.  Tell me what it means before proposing any fix.
I want to understand the problem, not skip straight to a solution.
```

### "I want the 'why' too"

```
Before making this change, tell me:
  1. What exactly is broken right now?
  2. Why is the fix you're proposing the right one?
  3. What could go wrong if I apply it?

Only make the change after I say "go ahead".
```

---

## Red flags — when to ignore your AI's advice

Even good AI assistants sometimes suggest things that make this kit worse, not better. Stop and ask here if your AI ever suggests any of these:

- **"Let's set up nginx as a reverse proxy"** — No. Tailscale serve already handles HTTPS.
- **"You should open port X in the firewall"** — No. The kit's firewall is default-deny on WAN by design.
- **"Switch to Ollama / run the model locally"** — No. Your Oracle VM has no GPU; inference happens on OpenRouter.
- **"Disable SSH hardening because of Y"** — No. The hardening exists for specific reasons documented in `docs/FIELD-MANUAL.md`.
- **"Make the service run as root to fix permissions"** — No. Never run as root. There's always a user-mode fix.
- **"Edit /etc/sudoers directly"** — No. Only edit `/etc/sudoers.d/*` drop-ins via `visudo -cf` validation. Bad sudoers = no sudo = locked out.

If your AI ever suggests one of these, push back with:

```
Your suggestion conflicts with the security design in AGENTS.md
(section "Do NOT suggest").  Read that section again and propose a
different fix that respects those rules.
```

---

## When to give up and ask a human

If you've tried three AI-assisted fixes and something's still broken, open `docs/WHEN-THINGS-GO-WRONG.md` Section 12 ("I've tried everything") for the escalation path — usually Oracle Cloud's serial console as the break-glass.
