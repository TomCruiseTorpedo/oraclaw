# Oracle Cloud Setup — Standalone Walkthrough

**If a friend is helping you in person (or over screen-share), start here.** This doc covers *only* the Oracle Cloud portion of setting up Oraclaw — creating your account, upgrading to Pay-As-You-Go, generating an SSH key, and creating the VM. Everything else (connecting your client, installing Oraclaw on the VM, opening the dashboard) comes after, in the Field Manual.

**If you're setting Oraclaw up alone, without help**, you can skip this and read `docs/FIELD-MANUAL.md` cover to cover — same content, just not broken out for the in-person flow.

**Before you start**, make sure you have:

- A **Mac (Apple Silicon)** or a **Windows 11 PC**. Intel Macs won't work.
- A **real credit card** you're willing to give Oracle for verification (you won't be charged if you stay in Always Free tier — and this guide keeps you there).
- A **real phone number** that can receive SMS (Oracle verifies it).
- A **GitHub account** — sign up free at [github.com](https://github.com). You'll need this later for cloning the repo.
- A **Tailscale account** — sign up free at [tailscale.com](https://tailscale.com). **While you're on the Tailscale site, also download the Tailscale app for your Mac or Windows 11 PC** — the download button is right there. Takes 30 seconds, saves time later. Do NOT try to install Tailscale on the Oracle Cloud VM yourself; the `install-oraclaw.sh` installer does that for you later. (Background reading: [OpenClaw's Tailscale docs](https://docs.openclaw.ai/gateway/tailscale) + [Tailscale's blog on the integration](https://tailscale.com/blog/openclaw-tailscale-aperture-serve). The blog also mentions Aperture — that's a separate Tailscale AI-gateway product **not** used by this kit; skip the Aperture sections.)
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

4. It prints a big green line starting with `ssh-ed25519`. **That whole line is your public key.** See the "three parts" note below before copying.

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

4. It prints a big green line starting with `ssh-ed25519`. **That whole line is your public key.** See the "three parts" note below before copying.

### The three parts of your public key — copy ALL of them

The green line the script prints looks like this:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5...long-base64-stuff...xEiKz7 yourname@your-computer-20260422
└─ part 1 ─┘└─────────── part 2 ────────────────────┘ └───────────── part 3 ─────────────┘
 algorithm       the actual key material (base64)              your label/comment
```

| Part | What it is |
|---|---|
| 1. Algorithm | `ssh-ed25519` |
| 2. Key material | ~68 characters of base64 (`AAAAC3...xEiKz7`) |
| 3. Comment | Your label, e.g. `yourname@your-computer-20260422` |

**Copy ALL three parts as a single line.** If you only grab the middle (the long base64 goo), Oracle Cloud will reject the key silently. The comment at the end — the email-looking thing — is **not** decoration; it's part of the key identity and must be included.

The easy way: **triple-click** the line in the terminal → Cmd+C / Ctrl+C. Most terminals (Terminal.app, iTerm2, Windows Terminal) interpret triple-click as "select the whole line". Then paste into Oracle Cloud.

**Sanity check after pasting:** Oracle Cloud's "Paste public keys" box should now show one line starting with `ssh-ed25519 ` and ending with today's date (`-20260422` or similar). If either end looks wrong, you missed part of the line — go back and triple-click more deliberately.

> **If you'd really rather not touch a terminal**, Oracle Cloud's VM creation page can also generate a keypair for you and download both halves as files. If you want to go that route, skip ahead to Step 6, pick **"Generate a key pair for me"** when you reach the SSH keys section, and save the downloaded `.key` file somewhere you can find it. Your client setup later (the bootstrap script) will need that file to SSH in. Ask your helper (or your AI assistant) to show you where to put it.

---

## Step 4 — Create a compartment (required, 2 minutes)

A **compartment** is an Oracle Cloud folder that holds your resources (VMs, networks, storage, etc.). When you signed up, Oracle gave you one at the top of the tree called the **root compartment**. **Don't put your Oraclaw directly in root.** Create a subcompartment for it and work there. Same principle as using a user account on your Mac/PC instead of the admin account — you keep your everyday work in a sandbox.

1. In the Oracle Cloud console, click the **hamburger menu** (☰, top-left) → **Identity & Security** → **Compartments**.
2. You'll see at least one entry with `(root)` next to its name — that's your root. Don't create anything there.
3. Click the black **Create compartment** button.
4. Fill in:
   - **Name:** `claws` (or `oraclaws`, or whatever you like — this is the folder your Oraclaw VMs will live in)
   - **Description:** `Oraclaw VM environment`
   - **Parent compartment:** leave the default (your root compartment).
5. Click **Create compartment**.

Status should turn **Active** in a few seconds. You now have:

```
your-tenancy-root    (root)   ← don't put stuff here
   └── claws                   ← VMs, VCNs, etc. go here
```

> **Gotcha that costs hours:** every OCI page has a **Compartment** filter at the top-left of the page content. If you ever "can't find" a VM or VCN you just created, it's almost certainly because the filter is showing root while your resource is in `claws` (or vice versa). Before you create anything new OR hunt for something existing, **glance at the compartment filter first**.

---

## Step 5 — Create the network (VCN) using the Wizard

Oracle Cloud networks (VCNs) have a lot of moving parts: CIDR blocks, subnets, internet gateways, route tables, and security lists. Setting them up by hand is a minefield — forgetting any one piece means your VM can't be reached. The **VCN Wizard** sets all of this up correctly for you in one shot with sane defaults.

**⚠️ The Wizard button is hidden.** The big obvious **Create VCN** button on the VCN list page puts you in the manual form (the minefield). You want the Wizard, which is buried in the **Actions** dropdown to the right of the Create VCN button.

1. Hamburger menu (☰) → **Networking** → **Virtual Cloud Networks**.
2. At the top of the page content, click the **Compartment** filter dropdown and pick your `claws` compartment (NOT root — this is where the gotcha from Step 4 shows up).
3. Click the **Actions** dropdown button — it's to the **right of the big black "Create VCN" button**, with a little ▼ on it. A small menu drops down.
4. Click **Start VCN Wizard** in that dropdown menu.
5. On the Wizard's first screen, select **"VCN with Internet Connectivity"** → click **Start VCN Wizard**.
6. Fill in:
   - **VCN name:** `claws-vcn` (or whatever — this is the network your Oraclaws will share)
   - **Compartment:** should pre-fill to `claws`. If not, set it.
   - **IPv4 CIDR blocks:** leave the defaults. The Wizard pre-populates sensible values (`10.0.0.0/16` for the VCN, `10.0.0.0/24` for public subnet, `10.0.1.0/24` for private subnet). Do NOT change these unless you have a specific reason.
7. Click **Next** → review → **Create**.
8. Wait for the **"Virtual Cloud Network creation complete"** banner (~30 seconds).

Verify on the VCN list: `claws-vcn` appears with status **Available**. Click into it; you should see **2 subnets** (one public, one private), an **Internet Gateway**, a **Default Route Table**, and a **Default Security List**. Those are the pieces the Wizard made for you — don't touch them.

> **Why not the manual Create VCN?** Because creating a working VCN by hand requires: (a) picking non-overlapping CIDRs; (b) creating a subnet; (c) attaching an internet gateway; (d) adding a route pointing at the gateway; (e) opening port 22 in the security list. Forget any one and nothing works. The Wizard does all five. The manual button is for advanced users who need something non-standard.

---

## Step 6 — Create the Compute Instance (your VM)

You can start this as soon as PAYG is active **and** you've done Steps 4 + 5 above.

> **If the UI feels overwhelming**, the goal of this step is: click "Create Instance", fill in 5–6 fields (compartment, name, shape, OS image, VCN, SSH key), click Create. Everything else is fine at default.

1. Hamburger menu → **Compute** → **Instances**.
2. At the top of the page content, click the **Compartment** filter and pick your `claws` compartment.
3. Click **Create instance**.
4. **Name:** something memorable, like `my-oraclaw` (lowercase, no spaces). This becomes your SSH alias later.
5. **Placement:** leave the defaults (your home region, any availability domain).
6. **Image and shape:**
   - Click **Change image** → **Canonical Ubuntu** → **Ubuntu 24.04 Minimal** → **aarch64 (ARM)**. Click **Select image**.
   - Click **Change shape** → **Ampere** → **VM.Standard.A1.Flex** → set **OCPUs: 2** and **Memory: 12 GB**. Click **Select shape**.

   This is the Always Free Ampere shape. 2 OCPUs + 12 GB RAM leaves half your free-tier quota for a second VM later.

7. **Networking:**
   - **Virtual cloud network:** pick `claws-vcn` (the one from Step 5).
   - **Subnet:** pick the **public** subnet (named `Public Subnet-claws-vcn` or similar). Public means your VM can reach the internet (Tailscale needs this to call home during install). It does NOT mean your VM is publicly reachable — inbound is still gated by the security list you didn't touch.
   - Confirm **"Assign a public IPv4 address"** is **checked**. If it's greyed out, you skipped Step 5 — back up and create the VCN via the Wizard first.
8. **Boot volume:** 47 GB default is fine. Bump to 100 GB if you want headroom (up to 200 GB shared across all free-tier instances).
9. **SSH keys:**
   - Select **Paste public keys**.
   - Paste the line from Step 3. Confirm it starts with `ssh-ed25519 ` and ends with your user/date comment (the "three parts" rule from Step 3 — if your paste is missing the algorithm name or the comment, Oracle will silently reject it).
   - **If you went the "let Oracle generate a key pair" route** instead: pick that option here, and make sure you click **Save private key** AND **Save public key** — you'll need both files.

10. Click **Create**.

The VM takes about 2 minutes. The **State** badge goes Provisioning → Running. You now have a Linux server running 24/7 in Oracle's data center, reachable only via Tailscale once your client connects in Step 7.

**Write down** (or screenshot) the public IP that Oracle shows on the instance detail page. You won't need it often (Tailscale handles hostnames), but if Tailscale ever breaks this is the backup.

---

## Step 7 — Hand off to the Field Manual

Everything from here is in **[docs/FIELD-MANUAL.md](FIELD-MANUAL.md)**, starting at **Section 4** (Set Up Your Client Machine).

If someone is helping you in person:
- You've done Sections 1–3 of the Field Manual via this doc (plus the compartment + VCN extras).
- Hand the Field Manual to your helper (or paste a harness prompt from `docs/HARNESS-PROMPTS.md`).
- They'll walk you through Sections 4–7 (client setup → connect → install Oraclaw → open dashboard).

**Estimated remaining time:** 15–20 minutes, mostly downloads.

> **How Tailscale fits in:** Tailscale lives in **two places** by the end of Section 7 — on your client machine (Mac/Windows) as a menu-bar/tray app, installed by the Section 4 bootstrap script, and on the VM as a background service, installed by `install-oraclaw.sh` in Section 6. Both connect to the same tailnet under your single Tailscale account. Your client can then SSH + open the dashboard on the VM using Tailscale hostnames, with no public ports exposed to the internet.

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
- [ ] **Compartment created** (e.g. `claws`) — NOT using root directly
- [ ] **VCN created via the Wizard** (e.g. `claws-vcn`) inside that compartment, status **Available**, with 2 subnets visible
- [ ] VM created inside your `claws` compartment + `claws-vcn` network, state shows **Running**, public IP shown
- [ ] Tailscale account ready (the Tailscale **app itself** is NOT installed yet — that happens in Field Manual Section 4 for your client and Section 6 for the VM)
- [ ] OpenRouter account + API key copied somewhere safe
- [ ] GitHub account exists (for cloning the repo on your client)

If you can tick all 9, you're ready. Continue to [`docs/FIELD-MANUAL.md`](FIELD-MANUAL.md) Section 4.
