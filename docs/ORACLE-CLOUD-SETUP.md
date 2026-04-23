# Oracle Cloud Setup — Standalone Walkthrough

**If a friend is helping you in person (or over screen-share), start here.** This doc covers *only* the Oracle Cloud portion of setting up Oraclaw — creating your account, upgrading to Pay-As-You-Go, generating an SSH key, and creating the VM. Everything else (connecting your client, installing Oraclaw on the VM, opening the dashboard) comes after, in the Field Manual.

**If you're setting Oraclaw up alone, without help**, you can skip this and read `docs/FIELD-MANUAL.md` cover to cover — same content, just not broken out for the in-person flow.

**Before you start**, make sure you have:

- A **Mac (Apple Silicon)** or a **Windows 11 PC**. Intel Macs won't work.
- A **real credit card** you're willing to give Oracle for verification (you won't be charged if you stay in Always Free tier — and this guide keeps you there).
- A **real phone number** that can receive SMS (Oracle verifies it).
- A **GitHub account** — sign up free at [github.com](https://github.com). You'll need this later for cloning the repo.
- A **Tailscale account** — sign up free at [tailscale.com](https://tailscale.com). You can make it right now; you do NOT need to install Tailscale yet (the bootstrap script does that for you later).
- (Recommended, $10 one-time) An **OpenRouter account** with a $10 top-up — sign up at [openrouter.ai](https://openrouter.ai). The $10 raises your daily call cap from 50 to 1000 on free models. Your card doesn't get charged per call; the $10 just unlocks the higher limit.

Estimated time: **1 hour** from account creation to a running VM. Most of it waiting on Oracle provisioning and the PAYG upgrade.

---

## Step 1 — Create your Oracle Cloud account

1. Go to [oracle.com/cloud/free](https://www.oracle.com/cloud/free/).
2. Click **Start for free**.
3. **Home region:** pick the one physically closest to you. **This is permanent — you cannot change it later.** Common picks:

   | You live in | Pick |
   |---|---|
   | Toronto / Ottawa / Waterloo / Montreal | `ca-toronto-1` or `ca-montreal-1` |
   | NYC / NJ / Philly / DC | `us-ashburn-1` (Virginia) or `ca-montreal-1` |
   | Chicago / Midwest | `us-chicago-1` |
   | Calgary / Edmonton | `ca-toronto-1` or `us-phoenix-1` |
   | Vancouver / Seattle / Portland | `us-sanjose-1` or `us-phoenix-1` |
   | Elsewhere | closest Always-Free region at [oracle.com/cloud/.../regions](https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm) |

4. Fill out the form with your real name and address. Oracle cross-checks.
5. Verify email → verify phone (SMS code) → add credit card (they do a $1 pre-auth that refunds).
6. Wait for account provisioning. Usually 2–10 minutes. You'll get an email.
7. Log in at [cloud.oracle.com](https://cloud.oracle.com).

---

## Step 2 — Upgrade to Pay-As-You-Go (PAYG)

**DO THIS FIRST, RIGHT AFTER ACCOUNT CREATION.** This is the single biggest blocker in the whole setup. If you skip it, your VM creation in Step 4 will almost always fail with "Out of host capacity" — sometimes for weeks.

Why this matters: Always Free is real (you'll never be charged inside the free limits), but on a pure free-trial account, Oracle rarely has enough Ampere A1 capacity to reserve a VM for you. Upgrading to **Pay-As-You-Go** doesn't cost you anything (your card is already on file, and you stay in the Always Free tier as long as you follow this guide) — it just changes your account class so Oracle prioritizes your capacity requests.

1. In the Oracle Cloud console, click the **profile icon** (top-right) → **Payment Methods**, or search "Upgrade" in the top bar.
2. Click **Upgrade to Paid Account** / **Upgrade and manage payments**.
3. Pick **Pay As You Go**. **NOT** Universal Credits, Monthly Flex, or Committed Use — those charge you up front.
4. Confirm your card and submit. Status: **Pending**.
5. **Wait.** Approval can take **minutes to ~8 hours**. You'll get an email. This is a great time to do Step 3 (generate your SSH key) and Step 5 (create Tailscale/OpenRouter accounts) in parallel.
6. When the email arrives, confirm the upgrade: profile icon → **My Services** / **Subscriptions** → should show **Pay As You Go**.

> **How to stay at $0 forever:**
> - Only create resources tagged **Always Free-eligible**. Every OCI shape picker explicitly shows this badge.
> - On day 30 and day 60, check **Billing** → **Cost Analysis**. If total ≠ $0.00, find the paid resource you accidentally spun up and delete it.
> - Set a calendar reminder now for both check-in dates.

---

## Step 3 — Generate your SSH key (2 minutes)

**Do this while Oracle's PAYG upgrade is pending.** You'll need this key ready in Step 4 when Oracle asks you to paste a "public key" into the VM creation form.

The script below creates an SSH keypair and prints the public half. Zero dependencies — no Homebrew, no WSL, nothing — just the `ssh-keygen` command that ships with every Mac and every Windows 11 PC.

### Mac (Apple Silicon)

1. Open **Terminal** (Cmd+Space → type `Terminal` → Enter). [Never used one before?](TERMINAL-BASICS.md)
2. First, clone the Oraclaw repo so you have access to the scripts:

   ```bash
   cd ~
   git clone https://github.com/TomCruiseTorpedo/oraclaw.git
   ```

   If `git` isn't installed yet, running `git` once will trigger the Xcode Command Line Tools installer — click "Install" and wait a few minutes, then re-run the `git clone` command.

3. Run the SSH-key script:

   ```bash
   bash ~/oraclaw/scripts/generate-ssh-key.sh
   ```

4. It prints a big green line starting with `ssh-ed25519`. **That whole line is your public key.** Keep this terminal window open — you'll paste this line into Oracle Cloud in the next step.

### Windows 11

1. Open **PowerShell** (Windows key → type `Terminal` → Enter). [Never used one before?](TERMINAL-BASICS.md)
2. First, install git + clone the Oraclaw repo:

   ```powershell
   # Allow scripts to run (one-time)
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

   # Install git via winget (built into Windows 11)
   winget install --id Git.Git --exact --silent `
                  --accept-source-agreements --accept-package-agreements

   # Close and reopen PowerShell so `git` is on PATH, then:
   git clone https://github.com/TomCruiseTorpedo/oraclaw.git $env:USERPROFILE\oraclaw
   ```

3. Run the SSH-key script:

   ```powershell
   & $env:USERPROFILE\oraclaw\scripts\generate-ssh-key.ps1
   ```

4. It prints a big green line starting with `ssh-ed25519`. **That whole line is your public key.** Keep this PowerShell window open — you'll paste this line into Oracle Cloud in the next step.

> **If you'd really rather not touch a terminal**, Oracle Cloud's VM creation page can also generate a keypair for you and download both halves as files. If you want to go that route, skip ahead to Step 4, pick **"Generate a key pair for me"** when you reach the SSH keys section, and save the downloaded `.key` file somewhere you can find it. Your client setup in Step 8 (the bootstrap script) will need that file to SSH in later. Ask your helper (or your AI assistant) to show you where to put it.

---

## Step 4 — Create the Compute Instance (your VM)

You can start this as soon as PAYG is active (check your profile → My Services → Pay As You Go).

> **If the UI feels overwhelming**, the goal of this step is: click "Create Instance", fill in 4–5 fields (name, shape, OS image, SSH key, subnet), click Create. Everything else is fine at default.

1. In the Oracle Cloud console, click the top-left **hamburger menu** → **Compute** → **Instances**.
2. Click **Create instance**.
3. **Name:** something memorable, like `my-oraclaw` (lowercase, no spaces). This becomes your SSH alias later.
4. **Placement:** leave the defaults (your home region, any availability domain).
5. **Image and shape:** click **Change image** → pick **Canonical Ubuntu** → **Ubuntu 24.04 Minimal** → **aarch64 (ARM)**. Click **Select image**. Then click **Change shape** → **Ampere** → **VM.Standard.A1.Flex** → set **OCPUs: 2** and **Memory: 12 GB**. Click **Select shape**.

   This is the Always Free Ampere shape. 2 OCPUs + 12 GB RAM leaves half of your free-tier quota available for a second VM later if you want.

6. **Networking:** leave all defaults. (If this is your first instance, Oracle auto-creates a Virtual Cloud Network and public subnet for you.)
7. **Boot volume:** the default 47 GB is fine. If you want more (up to 200 GB shared across all instances in the free tier), click **Specify a custom boot volume size** and bump it to 100 GB.
8. **SSH keys:**
   - Select **Paste public keys**.
   - Paste the green line from Step 3 (starts with `ssh-ed25519`).
   - **If you went the "let Oracle generate a key pair" route** instead: pick that option here, and make sure you click **Save private key** AND **Save public key** — you'll need both files.

9. Click **Create**.

The VM takes about 2 minutes to provision. The **State** badge moves from Provisioning → Running. You now have a Linux server running 24/7 in Oracle's data center, reachable only over Tailscale once you connect your client in the next step.

**Write down** (or screenshot) the public IP that Oracle shows on the instance detail page. You won't need it often (Tailscale handles hostnames), but if Tailscale ever breaks this is the backup.

---

## Step 5 — Hand off to the Field Manual

Everything from here is in **[docs/FIELD-MANUAL.md](FIELD-MANUAL.md)**, starting at **Section 4** (Set Up Your Client Machine).

If someone is helping you in person:
- You've done Sections 1–3 of the Field Manual via this doc.
- Hand the Field Manual to your helper (or paste a harness prompt from `docs/HARNESS-PROMPTS.md`).
- They'll walk you through Sections 4–7 (client setup → connect → install Oraclaw → open dashboard).

**Estimated remaining time:** 15–20 minutes, mostly downloads.

---

## Troubleshooting during Oracle Cloud setup

### "Out of host capacity" when I click Create

Your PAYG upgrade hasn't been approved yet. Wait for the email and try again. If it's been more than 24 hours, Oracle customer support can look into it.

### "My credit card was declined"

Oracle is strict about matching the address on the card with the account address. Double-check both match exactly. If they do and it still fails, try a different card.

### "I clicked 'Generate a key pair for me' but don't know what to do with the files"

Keep both files (`.key` and `.pub`) somewhere you'll remember. Your client bootstrap script (Step 8) will ask for the `.key` file and import it into your `~/.ssh/` folder with the right name and permissions. Or ask your AI assistant: *"Oracle Cloud gave me a .key file. Walk me through moving it to my `~/.ssh/` folder and renaming it to `id_ed25519` with chmod 600."*

### "My instance is stuck on 'Provisioning' for more than 10 minutes"

Click the instance, scroll to **Work requests**, click the running request, check the log. If it says resource/capacity issues, terminate and try creating again (sometimes it's a transient Oracle issue). If you see something else, paste the log into your AI assistant.

### "I finished VM creation but my friend/helper isn't here. What do I do next?"

Your VM is running and waiting for you. The next phase (Section 4 of the Field Manual) is safe to do whenever. It walks through installing the tools on your client PC, connecting to Tailscale, and SSHing into the VM for the first time. Take your time. Come back later if you're tired.

---

## Checklist before continuing

Confirm all of these before moving on to Field Manual Section 4:

- [ ] Oracle Cloud account created and confirmed via email
- [ ] **Pay As You Go upgrade approved** (profile → My Services shows "Pay As You Go")
- [ ] SSH key generated (or Oracle-generated keypair saved)
- [ ] VM created, state shows **Running**
- [ ] Tailscale account ready (even if app not yet installed)
- [ ] OpenRouter account + API key copied somewhere safe
- [ ] GitHub account exists (for cloning the repo on your client)

If you can tick all 7, you're ready. Continue to [`docs/FIELD-MANUAL.md`](FIELD-MANUAL.md) Section 4.
