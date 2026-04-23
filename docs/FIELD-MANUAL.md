# Oraclaw Field Manual

**Your always-on agentic harness, running 24/7 on a free Oracle Cloud server, reachable only from your own devices.**

Version: 1.0 · For Ubuntu 24.04 (aarch64 / Ampere A1)

---

## Table of Contents

0. [What This Is](#0-what-this-is)
1. [What You Need Before Starting](#1-what-you-need-before-starting)
1.5. [Generate your SSH key (2 minutes)](#15-generate-your-ssh-key-2-minutes-no-dependencies)
2. [Create Your Oracle Cloud Account](#2-create-your-oracle-cloud-account)
3. [Create the Free VM](#3-create-the-free-vm)
4. [Set Up Your Client Machine (One Command)](#4-set-up-your-client-machine-one-command)
5. [Connect Your Client to the VM](#5-connect-your-client-to-the-vm)
6. [Install Oraclaw on the VM (One Command)](#6-install-oraclaw-on-the-vm-one-command)
7. [Open the Dashboard](#7-open-the-dashboard)
8. [Daily Operations](#8-daily-operations)
9. [Troubleshooting (Symptom → Fix)](#9-troubleshooting-symptom--fix)
10. [Glossary](#10-glossary-plain-english)

Appendices:

- [A. File Locations](#appendix-a-file-locations)
- [B. Emergency Recovery (Console Connection)](#appendix-b-emergency-recovery-console-connection)
- [B2. Custom Avatar (Optional)](#appendix-b2-custom-avatar-optional)
- [C. Upgrading Node Version](#appendix-c-upgrading-node-version)

---

## 0. What This Is

OpenClaw is an AI "agentic harness" — think of it like Cursor or Claude Code, but headless, always-on, and reachable from your phone or any browser. This guide deploys one on a **free Oracle Cloud VM** so you have an always-on AI helper without paying for hosting.

**Architecture in one picture:**

```
   Your client                     Oracle Cloud VM
 ┌──────────┐                  ┌──────────────────┐
 │ Browser  │─── Tailscale ───▶│ OpenClaw Gateway │
 │  Tailnet │    (encrypted,   │  (port 18789,    │
 │  Client  │     private)     │   localhost only)│
 └──────────┘                  └─────────▲────────┘
                                         │
                               OpenRouter API (LLM inference)
```

**Key properties:**

- The VM is **invisible to the public internet**. Only you (via your Tailscale-authenticated devices) can reach it.
- OpenClaw **never binds to a public IP**. It listens on `localhost` only. Tailscale forwards traffic over its encrypted private network.
- You pay for LLM calls (OpenRouter API), not hosting. Hosting is free as long as you stay within Oracle's "Always Free" tier.

> **Asking your AI coding assistant (Copilot, Cursor, Antigravity, etc.) for help?** Point it at **`AGENTS.md`** at the repo root. It contains a pre-written context block of facts about this setup, so even weaker free-tier models won't hallucinate wrong paths or commands.

---

## 1. What You Need Before Starting

**You need:**

- A Mac (Apple Silicon, M1 / M2 / M3 / M4 / M5) running macOS 13 or newer, **or** a PC running Windows 11
- About an hour of time (most of it waiting on downloads)
- A **real email address** you check (for Oracle and Tailscale verification)
- A **real phone number** that can receive SMS (for Oracle verification)
- A **credit card** (Oracle verifies it but won't charge you as long as you stay in the Always Free tier)
- An **OpenRouter account + API key**. Sign up at [openrouter.ai](https://openrouter.ai). The free tier via API is capped at **50 calls/day** — fine for trying it, tight for daily use. A one-time **$10 top-up** raises the free-model cap to **1000 calls/day** and is **strongly recommended on day one** — you are already adding a credit card to Oracle, and OpenRouter will not charge you per call on free models. The $10 sits on your account until you actually burn it (which could take years on free models).
- A **Tailscale account** (free personal tier) at [tailscale.com](https://tailscale.com). **You do NOT need to install Tailscale itself yet.** By the end of setup, Tailscale will live in **two places under your single account**:
  - On your **client machine** (Mac or Windows 11 PC) — as a menu-bar app with a GUI. The client bootstrap in Section 4 installs this for you.
  - On the **Oracle Cloud VM** — as a background service (`tailscaled`). The installer in Section 6 sets this up for you.
  - Both show up on the same tailnet, so your client can SSH + reach the dashboard on the VM even though the VM has no public HTTPS port open.
- A **GitHub account** (free) at [github.com](https://github.com). You'll use this to clone this repo onto your client machine.

**You don't need:**

- Prior command-line experience. This guide assumes zero. If the idea of opening a terminal feels intimidating, read **[docs/TERMINAL-BASICS.md](TERMINAL-BASICS.md)** first — 5 minutes, demystifies the scariest parts.
- A static IP or a domain name. Tailscale handles that.

**A helpful extra:** an AI coding assistant you can ask questions when you get stuck. Any of these free tiers work well:

- **GitHub Copilot in VS Code** — generous free usage, weaker models (Claude Haiku 4.5, GPT-5-mini)
- **Cursor free tier** — tighter usage limits, stronger models (Composer 1.5)
- **Antigravity free tier** — tighter limits, strongest models (Gemini 3.1 Pro, Claude Sonnet 4.6)

**[docs/HARNESS-PROMPTS.md](HARNESS-PROMPTS.md)** has copy-pastable prompts you can feed to your AI assistant at each phase of setup — lets the AI walk you through step by step. For specific failures after setup, **[docs/WHEN-THINGS-GO-WRONG.md](WHEN-THINGS-GO-WRONG.md)** has symptom-matched prompts.

---

## 1.5 Generate your SSH key (2 minutes, no dependencies)

You'll need an SSH key **before you create your VM** in Section 3. Oracle Cloud locks the SSH key onto the VM at creation time, and changing it afterward means using the OCI serial console — tedious. Get the key ready first and Section 3 becomes a single uninterrupted pass.

Your SSH key lives on your client machine (Mac or Windows 11 PC). The *public* half gets pasted into Oracle Cloud in Section 3.3, step 9. The *private* half stays on your machine forever — if you ever share it, regenerate the pair immediately.

**Easiest path:** clone this repo first, then run the tiny `generate-ssh-key` script. The script detects if you already have a key (leaves it alone) or creates a new one, and prints the public half in a big green block with clear instructions for where to paste it.

### Mac (Apple Silicon) — Terminal

Open **Terminal** (Spotlight → "Terminal" → Enter). First time? Read [docs/TERMINAL-BASICS.md](TERMINAL-BASICS.md) — 5-minute primer.

```bash
# Clone the repo (triggers the Xcode Command Line Tools install the first time)
cd ~
git clone https://github.com/TomCruiseTorpedo/oraclaw.git

# Run the SSH-key generator
bash ~/oraclaw/scripts/generate-ssh-key.sh
```

### Windows 11 — PowerShell (any window, no admin needed)

Open **Windows Terminal** (Start → type "Terminal") or **PowerShell**.

```powershell
# Allow scripts to run (one-time per user)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Install git + clone the repo
winget install --id Git.Git --exact --silent `
               --accept-source-agreements --accept-package-agreements

# Close and reopen PowerShell so git is on PATH, then:
git clone https://github.com/TomCruiseTorpedo/oraclaw.git $env:USERPROFILE\oraclaw

# Run the SSH-key generator
& $env:USERPROFILE\oraclaw\scripts\generate-ssh-key.ps1
```

### What you should see

The script prints a big green block with a line starting `ssh-ed25519 AAAAC3...` and ending with your user/hostname comment. **That whole line** is your public key. Copy it — you'll paste it into Oracle Cloud in Section 3.3, step 9.

Don't worry about copying the terminal prompt or the filename or anything else around the line. Just the `ssh-ed25519 ... @...` part.

> **Security:** don't share the private key file (the one at `~/.ssh/id_ed25519` without the `.pub`). If it leaks, delete it and re-run the script — it'll generate a fresh pair.

> **I'd really rather not touch a terminal at all**, can I let Oracle make the key for me? Yes — in Section 3.3 step 9 you can pick "Generate a key pair for me" and Oracle will download both halves as files. You'll need to move the downloaded private key into `~/.ssh/` with the right name + permissions before the client bootstrap works. Ask your helper or an AI assistant to walk you through that when the time comes.

### Security note

- **Never share the private key** (the file with no `.pub` extension). If you accidentally share it or commit it somewhere public, generate a new pair right away and update Oracle Cloud.
- The `-N ""` flag in the command above creates the key with no passphrase. This is fine for a single-user personal server behind Tailscale. For shared or higher-stakes setups, omit `-N ""` and ssh-keygen will prompt you for a passphrase.

---

## 2. Create Your Oracle Cloud Account

1. Go to [oracle.com/cloud/free](https://www.oracle.com/cloud/free/)
2. Click **Start for free**.
3. Choose your country and pick the nearest data region. Common picks for North American users:

   | Where you live | Best Always-Free region |
   |---|---|
   | Toronto / Ottawa / Waterloo / Montreal | `ca-toronto-1` or `ca-montreal-1` |
   | NYC / NJ / Philly / DC | `us-ashburn-1` (Virginia) or `ca-montreal-1` — both ~15 ms |
   | Chicago / Midwest | `us-chicago-1` |
   | Calgary / Edmonton | `ca-toronto-1` (same country, ~45 ms) or `us-phoenix-1` (~30 ms) |
   | Vancouver / Seattle / Portland | `us-sanjose-1` or `us-phoenix-1` |
   | Other | Full list at [oracle.com/cloud/.../regions](https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm) — pick the geographically closest one that offers **Always Free** tier |

   > **⚠️ Your home region is PERMANENT.** Oracle does not let you change it after signup. Pick the region physically closest to you — it sets latency for everything you ever run in this account.
4. Fill out the form. Use your real name and address (Oracle verifies).
5. Verify your email → verify your phone number (SMS code) → add a credit card. Oracle does a small pre-authorisation (usually $1, refunded). You won't be charged as long as you stay in the Always Free tier (more on that in Section 2.1).
6. Wait for account provisioning (2–10 minutes). You'll get an email when ready.
7. Log in at [cloud.oracle.com](https://cloud.oracle.com).

> **Tip:** Put a calendar reminder for **day 30** and **day 60** from now: "Check Oracle bill is $0." OCI has a paid tier right next to the free tier — easy to accidentally spin something up that costs money.

### 2.1 Upgrade to Pay As You Go — DO THIS FIRST (Takes Hours)

**Read this before moving to Section 3. If you skip it, Section 3.3 will almost certainly fail with "Out of host capacity".**

Oracle Cloud's Always Free tier is real — you will never be charged for resources inside the free limits (4 Ampere A1 OCPUs / 24 GB RAM / 200 GB block storage total). **But** on a plain free-trial account, OCI rarely has enough Ampere A1 capacity to actually let you reserve a VM. You'll click **Create Instance** and see **"Out of host capacity"** — sometimes for weeks.

**The fix:** upgrade the account to **Pay As You Go (PAYG)**. Your credit card is already on file from signup; the upgrade just changes your account class so OCI prioritises your capacity requests. As long as you stay inside the Always Free limits, **you are never charged a cent**.

**Why do this FIRST:** unlike most upgrades, PAYG approval can take **several hours** (sometimes overnight). It is the single biggest blocker on the whole setup. Kick it off early in the morning; come back after lunch. Everything downstream depends on this landing.

**Steps:**

1. OCI console → top-right **profile icon** → **Payment Methods** (or search "Upgrade" in the top bar).
2. Click **Upgrade to Paid Account** / **Upgrade and manage payments**.
3. Pick **Pay As You Go** — **NOT** *Universal Credits*, *Monthly Flex*, or *Committed Use* (those all charge you up front).
4. Confirm the card on file and submit. You'll see **Pending**.
5. **Wait.** You'll get an email when it's active — anywhere from 15 minutes to 8 hours. Do not keep refreshing. Go do something else.
6. When the email arrives, verify: **profile icon** → **My Services** (or **Subscriptions**) — should show **Pay As You Go**.

**How to stay at $0 forever:**

- Only create resources tagged **"Always Free-eligible"**. Every shape picker in OCI shows this badge explicitly — if a resource doesn't show it, don't pick it.
- On day 30 and day 60, check **Billing** → **Cost Analysis**. If the total is anything other than **$0.00**, you accidentally spun up something paid — find it and delete it.
- If a paid resource slips in and stays under 24 hours, you'll owe pennies on the pro-rated daily bill. Catch it fast.

---

## 3. Create the Free VM

> **Before you start Section 3:** confirm your account is **Pay As You Go** (Section 2.1). If it still says **Free Trial** or **Always Free Only**, go back and wait for the PAYG email — creating an instance before PAYG is approved wastes your time.

### 3.1 Create a compartment (required)

A compartment is an OCI folder that isolates your resources. Think of it like a home directory on a computer: you don't do your everyday work as `root`, you do it in a user account whose scope is limited. Same idea here — you don't create VMs and VCNs directly in the root compartment, you create a **subcompartment** and put them in there.

When you open the Compartments page, you'll see at least one entry with `(root)` next to its name — that's the root compartment Oracle created for your tenancy. Do NOT put your Claws directly in root. Always create a subcompartment first.

1. In the OCI console, click the **hamburger menu** (☰, top-left) → **Identity & Security** → **Compartments**.
2. You'll see your root compartment at the top (the one with `(root)` after its name). This was created automatically when you signed up.
3. Click **Create Compartment**.
4. Fill in:
   - **Name:** `claws` (or `oraclaws`, or whatever you like — this is the folder all your Oraclaw VMs will live in)
   - **Description:** `Oraclaw VM environment`
   - **Parent compartment:** pick your **root compartment** from the dropdown (it's the default).
5. Click **Create compartment**.

Status should turn **Active** within a few seconds. You now have:

```
your-tenancy-root   (root)
   └── claws        ← you'll create VMs, VCNs, etc. in here
```

> **Gotcha that costs hours:** every page in OCI has a **Compartment** dropdown filter at the top-left of the page content. OCI defaults to showing resources in the root compartment. If you ever "can't find" a VM or VCN you just created, it's almost certainly because your filter is set to root and the resource is in your subcompartment (or vice versa). Always glance at the compartment filter before assuming something is missing.

### 3.2 Create the network (VCN) — BEFORE the instance, and use the Wizard

**⚠️ Two gotchas that cost hours apiece:**

1. **Skip this step entirely** and let the instance-creation form auto-create a VCN for you → the **public IP field can get greyed out** and you won't be able to SSH in.
2. **Click the big "Create VCN" button** at the top of the VCN list page → you'll land in a manual form where you have to enter CIDR blocks, subnets, internet gateways, route tables, and security rules by hand. Forget any one piece and nothing works.

The fix for both: use **"Start VCN Wizard"** instead. It's hidden in the **Actions dropdown** right next to the Create VCN button, not on the button itself. The Wizard pre-fills sane defaults for every field — one click and you have a working VCN with public subnet, internet gateway, route tables, and default security rules.

1. Hamburger menu (☰) → **Networking** → **Virtual Cloud Networks**.
2. **Compartment dropdown** at the top-left of the page content → select your `claws` compartment (NOT root).
3. Click the **Actions** dropdown (right next to the big black "Create VCN" button — do **not** click "Create VCN" itself) → **Start VCN Wizard**.
4. On the first screen, select **"VCN with Internet Connectivity"** → **Start VCN Wizard**.
5. Fill in:
   - **VCN name:** `claws-vcn` (or whatever — this is the network all your Claws will live on)
   - **Compartment:** `claws` (should be pre-filled from your selection in step 2)
   - **IPv4 CIDR blocks:** leave the defaults (Wizard pre-populates `10.0.0.0/16` for the VCN, `10.0.0.0/24` for the public subnet, `10.0.1.0/24` for the private subnet — all sane).
6. Click **Next** → review the summary → **Create**.
7. Wait for the **"Virtual Cloud Network creation complete"** banner (~30 seconds).

Verify: back on the **Virtual Cloud Networks** list (with the `claws` compartment still selected), your new VCN should appear with status **Available**. Click into it; you should see **2 subnets** (one public, one private), an **Internet Gateway**, a **Default Route Table**, and a **Default Security List**.

> **Why the Wizard and not the manual form:** the Wizard bakes in the correct CIDRs, gateways, route table entries, and security rules for the "VM needs public SSH access" pattern. Doing it manually means remembering to: (a) pick non-overlapping CIDRs, (b) create the subnet, (c) attach an internet gateway, (d) add a 0.0.0.0/0 route pointing at the gateway, (e) open port 22 in the security list. Miss any one of those and your VM can't be reached. The Wizard handles all of it; the manual form is a five-footgun minefield.

### 3.3 Create the instance (VM)

1. Hamburger menu → **Compute** → **Instances**.
2. Compartment dropdown → `oraclaw`.
3. Click **Create Instance**.
4. **Name:** pick something memorable — e.g. `my-oraclaw`, `jarvis`, `friday`. *This becomes your Tailscale hostname. Remember it.*
5. **Image:** click **Edit** next to Image → **Change image** → search `Ubuntu` → pick **Canonical Ubuntu 24.04 Minimal** → **aarch64** variant.
   - Why these? Ubuntu: best community docs for Node.js. 24.04: LTS through April 2029. Minimal: smaller attack surface, faster boot, no desktop junk. aarch64: required for Always Free Ampere A1.
6. **Shape:** click **Edit** next to Shape → **Change shape** → select **Ampere** → pick `VM.Standard.A1.Flex` (look for the **"Always Free-eligible"** badge).
   - **⚠️ Expand the ▶ triangle** next to `VM.Standard.A1.Flex`. The OCPU and RAM sliders are hidden until you click that triangle — the single easiest thing to miss on this page.
   - **Recommended default:** **2 OCPUs / 12 GB RAM**. This gives you one responsive Oraclaw now and leaves ~50% of the Always Free tier unused as headroom — so if you want to spin up a second Oraclaw later, or redeploy, you can do it without deleting anything.
   - Full sizing options (Always Free tier gives you **4 OCPUs / 24 GB RAM / 200 GB block storage** total across all your Ampere A1 VMs — split however you like):

   | How many Oraclaws total? | OCPUs each | RAM each | Boot volume each |
   |---|:-:|:-:|:-:|
   | 1 (recommended default)    | 2 | 12 GB | 100 GB |
   | 1 (maximum power)          | 4 | 24 GB | 200 GB |
   | 2 (one each for work / home) | 2 | 12 GB | 100 GB |
   | 4 (maximum fleet)          | 1 | 6 GB  | 50 GB  |

7. **Shielded instance** and **Use in-transit encryption:** leave **BOTH off** for first-time setups. They're collapsed sections further down the page.
   - These add boot-time overhead and have caused install-time friction on Ampere A1. Your VM will already be behind Tailscale (no public dashboard at all), UFW (default-deny), fail2ban, and SSH hardening once `install-oraclaw.sh` finishes — that is more than enough for a single-operator agentic harness.
8. **Networking:**
   - **Compartment:** pick your `claws` compartment (from Section 3.1).
   - **Virtual cloud network:** pick `claws-vcn` (the one from Section 3.2).
   - **Subnet:** pick the **public** subnet (named `Public Subnet-claws-vcn` or similar — the Wizard creates both public and private; you want public so Tailscale can reach out).
   - Confirm **"Assign a public IPv4 address"** is **checked**. (If it's greyed out, you skipped Section 3.2 — back up and create the VCN via the Wizard first.)
9. **SSH keys:**
   - Select **Paste public keys**.
   - Paste the line that starts with `ssh-ed25519 …` — from Section **§1.5** (if you haven't printed it recently, re-run `cat ~/.ssh/id_ed25519.pub` on Mac or `Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"` on Windows).
   - If you skipped §1.5 and haven't generated a key yet, stop here and go back — the bootstrap in Section 4 also generates a key, but once the VM is created without one (or with the wrong one) you're locked out and must recover via the OCI serial console (Appendix B).
   - **If you skipped ahead:** leave this tab open and run Section 4 now; come back with the key.
10. **Boot volume:** size per the table in Step 6 (50 / 100 / 200 GB). **Boot volume VPUs: 120** regardless of size — that's the speed tier, and it's still free.
11. Click **Create**. Wait 2–3 minutes for **Running** state.
12. Note the **Public IP address** — you won't use it often after Tailscale is up, but record it for emergencies.

> **Lost the IP later?** Hamburger menu → **Compute** → **Instances** → click the instance name → **Instance Access** panel on the right shows the **Public IP address** and a copy button.

> **"Out of host capacity" at step 11?** The PAYG upgrade hasn't gone through yet (or you picked a region that's been slammed recently). Wait for the PAYG email from Section 2.1; if it's been more than 12 hours, try again at a different time of day — A1 capacity cycles through the day. Do NOT switch to a paid shape to "fix" it — that will charge your card.

---

## 4. Set Up Your Client Machine (One Command)

Two supported clients: **Mac (Apple Silicon)** and **Windows 11 PC**. Follow whichever matches your machine — 4.1 for Mac, 4.2 for Windows.

### 4.1 Mac (Apple Silicon)

This installs: Xcode Command Line Tools → Homebrew → git, mosh, tmux, jq → Tailscale → generates an SSH key → adds an SSH shortcut.

1. Open **Terminal.app** (press ⌘+Space → type `Terminal` → Enter).
2. Clone the kit. If this is the FIRST time you've ever used `git` on this Mac, paste this and enter your password when macOS asks:

   ```bash
   # First-time Mac users: install just enough to clone
   if ! command -v git >/dev/null; then xcode-select --install; fi

   # Clone the kit into ~/oraclaw
   git clone https://github.com/TomCruiseTorpedo/oraclaw.git ~/oraclaw
   ```

3. Run the bootstrap:

   ```bash
   bash ~/oraclaw/scripts/bootstrap-mac.sh
   ```

4. Follow the prompts. When it shows your SSH public key, **that's what you paste into Oracle Cloud in §3.3 step 9** if you haven't already.
5. When it asks for the Tailscale hostname and subdomain — leave the script open in one Terminal window and do Section 5 first.

**Don't have a Tailscale account yet?** No problem — the bootstrap opens the Tailscale app and prompts you to log in. On the login screen, click **Sign up** (or just log in with Google, GitHub, Microsoft, or Apple — Tailscale will create your account automatically on first login). Free personal tier supports up to 100 devices, which is way more than you'll ever need.

### 4.2 Windows 11

This installs: git, Tailscale, jq via **winget** → generates an SSH key → adds an SSH shortcut. Windows 11's built-in OpenSSH client + PowerShell do the rest — no WSL, no Cygwin, no MSYS.

1. Open **PowerShell as Administrator** (press ⊞ Win → type `PowerShell` → right-click **Windows PowerShell** → **Run as administrator**).
2. Allow local scripts to run (one-time, per-user):

   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
   ```

3. Install git, then clone the kit:

   ```powershell
   # If git isn't installed yet:
   winget install --id Git.Git --exact --silent --accept-source-agreements --accept-package-agreements

   # Close and reopen PowerShell (as admin) so `git` is on PATH, then:
   git clone https://github.com/TomCruiseTorpedo/oraclaw.git $env:USERPROFILE\oraclaw
   ```

4. Run the bootstrap:

   ```powershell
   & $env:USERPROFILE\oraclaw\scripts\bootstrap-windows.ps1
   ```

5. Follow the prompts. When it shows your SSH public key, **that's what you paste into Oracle Cloud in §3.3 step 9** if you haven't already.
6. When it asks for the Tailscale hostname and subdomain — leave the PowerShell window open and do Section 5 first.

**Don't have a Tailscale account yet?** The bootstrap opens a browser window for Tailscale login. On that screen, click **Sign up** (or log in with Google, GitHub, Microsoft, or Apple — Tailscale creates the account automatically on first login). Free personal tier supports up to 100 devices.

---

## 5. Connect Your Client to the VM

**How Tailscale bridges your client and the VM:** Tailscale is a zero-config private network (a "tailnet"). Every device you install Tailscale on, logged in under your account, can talk to every other device on that tailnet by hostname — no public IPs, no port forwarding, no DNS setup.

In this kit, Tailscale lives in **two places** under your single Tailscale account:

- **On your client** (Mac / Windows 11) — the bootstrap in Section 4 installed the Tailscale menu-bar/tray app and walked you through logging in. Your client is already on the tailnet.
- **On the Oracle Cloud VM** — NOT installed yet. You'll install it in §5.1 below.

Both will sit on the same tailnet. Once that's true, you can SSH to the VM using just its Tailscale hostname (no IP needed), and the dashboard is reachable at a `.ts.net` URL that only your authenticated devices can open.

> **Why bother?** Because without Tailscale the VM either needs a public SSH port (attack-surface headache) or a VPN (much more setup). Tailscale gives you the "public access from my own devices, invisible to everyone else" flavor with zero networking config.

### 5.1 Install Tailscale on the VM

SSH into the VM using its public IP (one-time — we'll switch to Tailscale after):

```bash
ssh ubuntu@<public-ip-from-§3.3-step-12>
```

First connection will print a fingerprint warning (`The authenticity of host … can't be established`). Type `yes` and press Enter — that pins the host key so future connects are silent. If you ever see this warning on a *later* connection without having rebuilt the VM, stop and investigate: it means either a man-in-the-middle attempt, or the VM was recreated and legitimately has a new host key.

Once in, install Tailscale:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh
```

Follow the URL it prints. Log in to Tailscale with the same account as your client.

Check the VM's Tailscale name:

```bash
tailscale status
# Note the name on your VM's line, e.g. "my-oraclaw"
```

Check your tailnet subdomain:

- **Mac:** click the Tailscale icon in the menu bar → **Network** → **DNS** → your subdomain is shown there (it's the part *before* `.ts.net` — Tailscale auto-generates it from `tail` + 8 random hex characters, e.g. `tailAAAAAAAA`, though every account's is different).
- **Windows:** right-click the Tailscale tray icon → **Admin Console** → the subdomain is in the URL (e.g. `login.tailscale.com/admin/machines/<subdomain>`).

### 5.2 Finish the client bootstrap

Go back to the Terminal / PowerShell window running the bootstrap:

- **Tailscale hostname:** `my-oraclaw` (or whatever yours is)
- **Tailnet subdomain:** whatever Tailscale assigned you — the `tail`-prefixed string you just looked up above

The script will test the SSH connection. If it works, you'll see `SSH works: ubuntu@my-oraclaw`.

From now on, you connect to the VM with just:

```bash
ssh my-oraclaw
```

---

## 6. Install Oraclaw on the VM (One Command)

SSH into the VM:

```bash
ssh my-oraclaw
```

Copy the installer script onto the VM and run it:

```bash
# From your client — copy the script to the VM
scp ~/oraclaw/scripts/install-oraclaw.sh my-oraclaw:/tmp/   # Mac
# or (Windows):
#   scp $env:USERPROFILE\oraclaw\scripts\install-oraclaw.sh my-oraclaw:/tmp/

# SSH in and run it
ssh my-oraclaw 'bash /tmp/install-oraclaw.sh'
```

The script asks four things:

| Prompt | What to enter |
|--------|---------------|
| **Assistant name** | A name for your AI. Examples: `Jarvis`, `Friday`, `Watson`, `Penny`, `Claude`, or anything you like. |
| **Tailscale auth key** | Go to [login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys) → **Generate auth key** → **Reusable**: No, **Ephemeral**: No, **Tags**: (leave blank). Copy the `tskey-auth-…` string. |
| **OpenRouter API key** | See the callout below. |
| **Timezone** | Press Enter for `America/Edmonton`, or type your own — e.g. `America/New_York` (NYC), `America/Toronto` (Toronto/Montreal/Ottawa), `America/Vancouver` (Vancouver/Seattle), `America/Chicago` (Winnipeg/Regina/Saskatoon/Chicago), `Europe/London`, `Asia/Tokyo`. Find yours in the [IANA tz list](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones). |

### OpenRouter setup (strongly recommended before you run the installer)

If you don't have an OpenRouter account yet, do this now so you have the API key ready when the prompt asks for it:

1. Go to [openrouter.ai](https://openrouter.ai).
2. Sign in — Google, GitHub, Apple, or email all work.
3. **Add $10 in credits first** — click your avatar (top-right) → **Credits** → **Add Credits** → **$10**. This is the single most useful thing you can do here: it raises your free-tier limit from **50 calls/day** to **1000 calls/day**. You will NOT be charged per call on free models (the default configuration) — the $10 just sits on your account and unlocks the higher limit. Most people never burn through it.
4. Click **Keys** (left sidebar) → **Create Key** → name it `oraclaw` → copy the `sk-or-…` string somewhere safe (you won't see it again).

If you skip the top-up, the installer still works — you'll just hit the 50-call ceiling sooner than you'd like.

---

The script runs for ~5–10 minutes. **When it finishes, write down the dashboard URL and the login token.** You will not see the token again (well, you can re-read it from `~/.openclaw/openclaw.json`, but having it written down is easier).

---

## 7. Open the Dashboard

### Step 1 — Open it (one command)

The quickest path is one command from your client.  It opens the dashboard in your default browser AND copies your login token straight to your clipboard, so there's no copy-paste fumbling:

```bash
bash ~/oraclaw/scripts/open-dashboard.sh                 # Mac
```

```powershell
& $env:USERPROFILE\oraclaw\scripts\open-dashboard.ps1    # Windows
```

**Bookmark the URL now** (it's in your browser's address bar) — this is the URL you'll open every time you want to chat with your Oraclaw.

- *On iPhone/iPad:* open the URL in Safari → **Share** → **Add to Home Screen** for a one-tap launcher.
- *On Android:* open the URL in Chrome → **⋮** menu → **Add to Home screen**.

### Step 2 — Paste the token

In the dashboard, click the **⚙ Settings gear** (top-right) → paste with **⌘V** (Mac) or **Ctrl+V** (Windows) → **Save**.  The token is already on your clipboard from Step 1.

### Step 3 — Approve this browser ("Device pairing required" is EXPECTED)

After you save the token, the dashboard will say **"Device pairing required"**.

**This is not an error — it's part of how Oraclaw stays secure.** Even with a valid token, every new browser has to be explicitly approved on the server side.  A stolen token alone cannot get into your Oraclaw.

Approve this browser with one command from your client:

```bash
bash ~/oraclaw/scripts/approve-pairing.sh                # Mac
```

```powershell
& $env:USERPROFILE\oraclaw\scripts\approve-pairing.ps1   # Windows
```

The script SSHes to the VM, lists the pending request(s), and — if there's exactly one — approves it automatically.  If there are multiple, it shows them and asks you to paste the right one.

*Manual alternative* (if the helper can't reach the VM for some reason):

```bash
ssh my-oraclaw
openclaw devices list                   # shows pending requests
openclaw devices approve <request-id>
```

### Step 4 — Test the chat

Refresh the browser.  You should see your assistant (the name you picked during install) with a chat input.

Send a test message: `Hello! Say hi back.`

You should get a reply in a few seconds.  **If the first reply takes 20–30 seconds, that is normal** — OpenRouter is cold-starting the model.  Subsequent replies will be faster.

### A heads-up about heartbeats

Every six hours, your Oraclaw "wakes itself up" with a short system message — that's the heartbeat cron job running.  You'll see `Heartbeat: quick check-in.` entries in your chat history.  **This is working as intended** — it keeps the agent aware of time passing, and is the hook for future scheduled reminders or status updates.  If you don't want them, edit `~/.openclaw/cron/jobs.json` on the VM and set `"enabled": false` on the heartbeat entry, then restart the gateway.

---

## 8. Daily Operations

You rarely need to SSH in. But here's what to do when you do.

### Is it alive?

```bash
ssh my-oraclaw 'systemctl --user is-active openclaw-gateway'
# Expected: active
```

### Restart it

```bash
ssh my-oraclaw 'systemctl --user restart openclaw-gateway'
```

Wait ~30 seconds after restart before reconnecting in the browser.

### Read logs

```bash
ssh my-oraclaw 'journalctl --user -u openclaw-gateway -n 50 --no-pager'
# Or stream live:
ssh my-oraclaw 'journalctl --user -u openclaw-gateway -f'
# (press Ctrl-C to stop streaming)
```

### Update OpenClaw (the safe way)

**Prefer this command-line path over the `Update` button in the dashboard.** The dashboard button uses an in-process restart that occasionally leaves the gateway stuck. Your Oraclaw has an auto-recovery safety net that catches this within a minute or two, but the command-line path avoids it entirely. Keep a terminal open either way — it's your escape hatch if anything goes sideways.

```bash
ssh my-oraclaw
source ~/.nvm/nvm.sh
npm install -g openclaw@latest
systemctl --user restart openclaw-gateway
exit
```

### If you did click the dashboard Update button and it broke

In most cases your Oraclaw heals itself within 30–90 seconds — wait a beat before reaching for a terminal. If it's been longer than two minutes and the dashboard is still showing `502`:

```bash
bash ~/oraclaw/scripts/recover-gateway.sh my-oraclaw    # from your client
# or, on the VM:
ssh my-oraclaw 'systemctl --user restart openclaw-gateway'
```

Full recovery walkthrough with escalation steps: **[docs/RECOVERY.md](RECOVERY.md)**.

### What the auto-recovery safety net does

Installed by default when you ran `install-oraclaw.sh`; you mostly never think about it:

- If the gateway ever exits for any reason, `systemd` relaunches it after 10 seconds.
- A background probe checks the gateway's `/health` every 60 seconds. After two consecutive misses, it restarts the gateway automatically — even if the usual restart-on-exit rule somehow didn't fire.

You don't need to do anything to enable this. The installer sets it up. If you ever want to verify it's still healthy:

```bash
ssh my-oraclaw 'systemctl --user show openclaw-gateway -p Restart'
# Should print:  Restart=always

ssh my-oraclaw 'systemctl --user list-timers openclaw-gateway-watchdog.timer'
# Should show a row with a next-fire time within the next minute
```

If either check shows something unexpected, re-running `install-oraclaw.sh` on the VM fixes it (the script is idempotent — it won't touch your data).

### Back up your Oraclaw data

Everything important lives in `~/.openclaw/` on the VM. To back it up to your client:

```bash
rsync -av --delete my-oraclaw:/home/ubuntu/.openclaw/ ~/oraclaw-backup/
```

Run this weekly or before updates.

### Rotate your gateway token

If you ever suspect the token leaked (it ended up in a screenshot, you shared it, etc.):

```bash
ssh my-oraclaw 'bash ~/oraclaw/scripts/rotate-gateway-token.sh'
```

The script prints a new token once. Paste it into the dashboard ⚙ Settings → Save.

### Attach a persistent terminal (for long-running commands)

On your Mac (requires `mosh` from the bootstrap):

```bash
mosh my-oraclaw -- tmux new-session -A -s main
```

Mosh survives Wi-Fi changes and lid-close. Tmux keeps your work going even if the SSH connection drops. To detach: press **Ctrl-b** then **d**. Re-attach with the same command.

*(Windows 11 doesn't have a good mosh client — just use `ssh my-oraclaw` and accept that long commands need a stable network.)*

---

## 9. Troubleshooting (Symptom → Fix)

> **Before deep-diving:** if your AI coding assistant can help (Copilot, Cursor, Antigravity, etc.), open **`docs/WHEN-THINGS-GO-WRONG.md`** — it has copy-paste-ready prompts for the common failures below, plus instructions for how to feed the AI enough context to actually help you.

### "I can't reach the dashboard URL"

- **Check Tailscale is connected on your client:** click the Tailscale icon; it should say **Connected** (green).
- **Check the VM is up on Tailscale:** open the Tailscale app → **Network** — your VM should show **Online**. If it says **Offline**, the VM may have stopped. OCI console → Instances → check **Running**.
- **Check the hostname spelling:** `<vm-name>.<subdomain>.ts.net`. Both parts are visible in the Tailscale app.

### "The dashboard loads but shows 'Unauthorized'"

- Token wrong or missing. Click ⚙ → paste the token from when you installed (if lost: `ssh my-oraclaw 'jq -r .gateway.auth.token ~/.openclaw/openclaw.json'`).

### "The dashboard shows 'Device pairing required'"

- You skipped Step 7.4. SSH in and run `openclaw devices approve <request-id>`.

### "I send a message and nothing happens"

- Check logs: `ssh my-oraclaw 'journalctl --user -u openclaw-gateway -n 30 --no-pager'`
- Common causes:
  - **Rate limit:** free OpenRouter models rate-limit heavily. Wait a minute. The fallback chain should kick in automatically.
  - **No API key:** `ssh my-oraclaw 'grep OPENROUTER_API_KEY ~/.openclaw/.env'` — should show your key.
  - **OpenRouter daily cap hit:** the free-tier API is 50 calls/day; a one-time $10 top-up raises it to 1000/day on free models. Check [openrouter.ai/account](https://openrouter.ai/account).

### "SSH fails with 'Connection refused' or 'Permission denied'"

- SSH from your client to the VM should use your ed25519 key. Verify: `ls -la ~/.ssh/id_ed25519*` (Mac) or `dir $env:USERPROFILE\.ssh\id_ed25519*` (Windows) — should show both the private and `.pub` file.
- The VM needs to have your public key in `/home/ubuntu/.ssh/authorized_keys`. If you created the VM without pasting the key: reset it via OCI console's serial console (Appendix B).
- If fail2ban is blocking you: `ssh my-oraclaw 'sudo fail2ban-client status sshd'` — if your IP is banned, wait 1 hour or `sudo fail2ban-client set sshd unbanip <your-ip>` (via OCI console).

### "It was working yesterday, now nothing responds"

Check in order:

```bash
ssh my-oraclaw 'uptime'                                        # VM alive?
ssh my-oraclaw 'systemctl --user is-active openclaw-gateway'   # Service alive?
ssh my-oraclaw 'curl -I http://127.0.0.1:18789/'               # Gateway responding?
ssh my-oraclaw 'df -h /'                                       # Disk full? (<10% free = bad)
ssh my-oraclaw 'free -h'                                       # Swap exhausted?
```

If the VM itself is unreachable: OCI console → Instances → check status. Restart if stopped.

### "I forgot the dashboard token"

```bash
ssh my-oraclaw 'jq -r .gateway.auth.token ~/.openclaw/openclaw.json'
```

### "I want to rotate the dashboard token (suspect it leaked)"

```bash
ssh my-oraclaw 'bash ~/oraclaw/scripts/rotate-gateway-token.sh'
```

### "OpenRouter says 'model not found'" or "Unknown model"

Nine times out of ten this means the slug is missing its `openrouter/` prefix. `openrouter/google/gemma-4-31b-it:free` routes through your one OpenRouter API key — which is all you have. `google/gemma-4-31b-it:free` tries to route to a different provider plugin that expects its own Google API key (which you don't have). Add the prefix, save, restart the service.

The fallback chain automatically tries the next model when one fails. Full guide to how the chain works + how to swap any slot: **[docs/MODELS.md](MODELS.md)**.

### "Dashboard shows 502 after clicking Update"

Wait a beat — auto-recovery usually kicks in within 60–90 seconds. If it doesn't:

```bash
bash ~/oraclaw/scripts/recover-gateway.sh my-oraclaw    # from your client
# or, on the VM:
ssh my-oraclaw 'systemctl --user restart openclaw-gateway'
```

Full walkthrough: **[docs/RECOVERY.md](RECOVERY.md)**.

---

## 10. Glossary (Plain English)

| Term | What it actually means |
|------|------------------------|
| **Agentic harness** | A program that can call an LLM and run tools (read files, run commands) in a loop. Cursor is one; OpenClaw is another. |
| **Ampere A1** | Oracle's ARM-based server family. Free on OCI. Equivalent to a modern phone CPU × 4 cores. |
| **Compartment** | An Oracle Cloud folder for isolating resources. |
| **Gateway** | The OpenClaw process that serves the web UI. Runs on port 18789 inside the VM. |
| **Heartbeat** | Scheduled check-ins that keep your assistant "alive" between your own messages. |
| **Tailnet** | Your personal Tailscale network. Every device you install Tailscale on joins it. |
| **tailscale serve** | The Tailscale feature that exposes a local port (18789) at an HTTPS URL only reachable on your tailnet. |
| **UFW** | A friendly wrapper around iptables (Linux firewall). Default-deny incoming. |
| **fail2ban** | A daemon that watches SSH login failures and temporarily blocks attackers. |
| **systemd user service** | A background program that starts at login and restarts if it crashes. OpenClaw runs as one of these. |
| **OpenRouter** | A service that lets you call many LLMs (OpenAI, Anthropic, Meta, etc.) with one API key. Also offers some free models. |

---

## Appendix A: File Locations

On the VM (`my-oraclaw`):

| Path | What's there |
|------|--------------|
| `~/.openclaw/openclaw.json` | Main config (models, auth token, origins) |
| `~/.openclaw/.env` | OpenRouter API key (secret!) |
| `~/.openclaw/agents/main/agent/models.json` | Model catalogue (add custom models here) |
| `~/.openclaw/cron/jobs.json` | Scheduled heartbeat jobs |
| `~/.openclaw/workspace/` | Working files your assistant can access |
| `~/.openclaw/agents/main/sessions/` | Chat history (one `.jsonl` file per conversation) |
| `~/.openclaw/logs/` | Older logs (systemd logs are primary) |
| `~/.config/systemd/user/openclaw-gateway.service` | The systemd unit |
| `/etc/ssh/sshd_config.d/99-hardening.conf` | SSH hardening rules |
| `/etc/fail2ban/jail.local` | fail2ban SSH jail config |

On your client:

| Path (Mac) | Path (Windows) | What's there |
|------|------|--------------|
| `~/.ssh/id_ed25519` / `.pub` | `%USERPROFILE%\.ssh\id_ed25519` / `.pub` | Your SSH keypair |
| `~/.ssh/config` | `%USERPROFILE%\.ssh\config` | SSH host aliases |
| `~/.zprofile` | (n/a) | Shell init (adds Homebrew to PATH) |
| `/Applications/Tailscale.app` | `C:\Program Files\Tailscale\` | Tailscale app |

---

## Appendix B: Emergency Recovery (Console Connection)

If SSH is completely broken (e.g. you misconfigured sshd and locked yourself out), you can still reach the VM via OCI's serial console:

1. OCI console → **Compute** → **Instances** → click your VM.
2. Left sidebar → **Console connection** → **Create local connection**.
3. Follow the SSH command OCI provides. (Requires your SSH private key; uses OCI's bastion.)
4. Once in, you can edit `/etc/ssh/sshd_config.d/99-hardening.conf`, disable UFW with `sudo ufw disable`, etc.
5. Reboot from the OCI console (**⋮** menu → **Reboot**) if needed.

---

## Appendix B2: Custom Avatar (Optional)

The dashboard shows an avatar next to each message. By default, it's a generic star. You can set a custom image.

**Steps:**

1. Pick a square PNG or JPG on your client (100–500 KB is plenty). Place it at, say, `~/Desktop/my-avatar.png`.

2. Copy it to the VM:

   ```bash
   ssh my-oraclaw 'mkdir -p ~/.openclaw/workspace/avatars'
   scp ~/Desktop/my-avatar.png my-oraclaw:/home/ubuntu/.openclaw/workspace/avatars/myavatar.png
   ```

3. Edit `~/.openclaw/workspace/IDENTITY.md` on the VM. Find the `**Avatar:**` line and set it to:

   ```
   - **Avatar:** avatars/myavatar.png
   ```

   (Workspace-relative path — the `avatars/` folder lives inside `workspace/`.)

4. Restart the gateway: `ssh my-oraclaw 'systemctl --user restart openclaw-gateway'`

5. Hard-refresh the browser dashboard (⌘+Shift+R on Mac, Ctrl+Shift+R on Windows) to bust the image cache.

You can also fill in the other fields in `IDENTITY.md` (Name, Vibe, Emoji) — these shape how your assistant introduces itself.

---

## Appendix C: Upgrading Node Version

```bash
ssh my-oraclaw
source ~/.nvm/nvm.sh
nvm install 24.15.0             # Or a newer LTS — check https://nodejs.org/en/
nvm alias default 24.15.0
nvm use 24.15.0

# Update the systemd unit to point to the new node binary:
sed -i "s|/node/v[0-9.]*/bin/openclaw-gateway|/node/v24.15.0/bin/openclaw-gateway|" \
    ~/.config/systemd/user/openclaw-gateway.service

systemctl --user daemon-reload
systemctl --user restart openclaw-gateway
```

---

*End of Field Manual.*
