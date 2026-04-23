# Terminal Basics — if you've never used one before

**Read this if seeing a "terminal" feels scary.** It's a 5-minute read and it'll make the rest of the Field Manual much less intimidating.

---

## What the terminal is

A terminal is a window where you type commands and your computer runs them. It looks like this:

- Your Mac calls its terminal **Terminal.app** (or iTerm2 if you installed that).
- Your Windows 11 PC calls it **PowerShell** (or Windows Terminal, which is the same thing with better colours).

It's the same computer, same files, same everything — just without buttons and menus. Instead you type.

**You do not need to memorize anything.** In this guide, every command is copy-pasteable. Your job is to paste and press Enter.

---

## How to open the terminal

### On a Mac

**Easy way:** Press **Cmd+Space** (opens Spotlight search) → type `Terminal` → press Enter.

**Other way:** Open **Finder** → **Applications** → **Utilities** → double-click **Terminal**.

A window with white-on-black (or black-on-white) text appears. It shows something like `MacBook-Pro:~ yourname$ ` or `yourname@MacBook-Pro ~ %`. That trailing `$` or `%` is the **prompt** — it's waiting for you to type a command.

### On Windows 11

**Easy way:** Press the **Windows key** → type `Terminal` → press Enter. (If you don't see "Terminal", type `PowerShell` instead — same thing.)

A window appears with something like `PS C:\Users\YourName>`. The `>` is the prompt.

> If a guide ever says "run this **as Administrator**" — right-click the Terminal icon in the Start menu, pick **Run as administrator**. For *this* kit you only need admin mode when winget is installing things for the first time.

---

## How to run a command

1. **Copy the command** from the guide (usually a block like `cat ~/.ssh/id_ed25519.pub`).
2. **Switch to the terminal window.**
3. **Paste the command.** Same shortcut as everywhere else:
   - Mac: **Cmd+V**
   - Windows 11: **Ctrl+V** (or right-click the terminal window — some terminals paste on right-click)
4. **Press Enter.**

That's it. The command runs, you see output, the prompt comes back, and you're ready for the next command.

---

## What the output looks like

**Normal output** is just regular text. Sometimes it's a lot of text. That's fine — scroll up to read if needed.

**Green text** in this kit's scripts usually means success or "the thing you want".

**Yellow text** is a warning — read it but don't panic.

**Red text** is an error — something didn't work. Read what it says; it usually tells you what's wrong. Common reasons:
- **"command not found"** — you're missing a tool. The bootstrap script installs the tools you need; if you haven't run it yet, that's why.
- **"Permission denied"** — you don't have access to do that. Sometimes needs `sudo` (which asks for your password), sometimes the guide just forgot to tell you.
- **"No such file or directory"** — you typed a filename that doesn't exist. Check the spelling.

If red text appears and you're stuck, copy the full error into `WHEN-THINGS-GO-WRONG.md` style prompt, give it to your AI assistant, and paste back whatever it says to try.

---

## Things that *look* weird but are normal

- **Typing your password and nothing shows up** — that's on purpose. Terminals hide password input so someone looking over your shoulder can't read it. Just type it and press Enter.
- **The cursor just sits there for a long time** — something is working in the background. `brew install`, `winget install`, and `npm install` can take minutes.
- **The terminal freezes** — it's probably just waiting for you. Check if there's a prompt asking you to type `y` or press Enter.
- **`Permission denied (publickey).`** when trying to SSH — your SSH key wasn't added to the VM (or was added wrong). See Field Manual § 9.
- **A huge `BOTTOM` at the bottom of the screen when paging through `less`** — press `q` to quit.

---

## How to close the terminal

- **Mac:** `Cmd+Q` or just close the window with the red button.
- **Windows 11:** close the window or type `exit` and press Enter.

Everything you did stays done — you don't lose anything by closing the terminal.

---

## You don't need to know more than this

Seriously. Everything this kit needs you to do is in the Field Manual as a copy-paste command. You don't need to learn bash, PowerShell, scripting, or anything else — unless you want to.

If you ever feel lost, **ask your AI assistant** (Copilot / Cursor / Claude / Antigravity) with a prompt like:

> I'm following the Oraclaw Field Manual and I'm stuck at Section X step Y. Here's what I pasted into the terminal: `<the command>`. Here's what it said back: `<the output>`. What do I do?

Your AI assistant has access to this repo (AGENTS.md tells it the setup) and will walk you through.
