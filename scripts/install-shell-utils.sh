#!/usr/bin/env bash
#
# install-shell-utils.sh — retrofit the shell QoL utilities onto an
# existing OCI OpenClaw VM. New installs already include these via
# install-openclaw-oci.sh; this script is for nodes that predate that
# change.
#
# Installs: ripgrep, fzf, zoxide, fd-find, eza, bat, tree, net-tools,
# dnsutils, mtr-tiny, iperf3, sysstat, iotop, btop, procs, ncdu, glow,
# pandoc, gh (GitHub CLI via apt repo), yq (mikefarah binary).
#
# Creates fdfind→fd and batcat→bat symlinks for Ubuntu-shipped binary
# names.
#
# Uses scp-then-execute pattern so one ssh -t session handles the
# single sudo prompt cleanly.
#
# Usage: install-shell-utils.sh <ssh-alias>

set -euo pipefail
NODE="${1:?usage: $0 <ssh-alias>}"

echo "[install-shell-utils] target: $NODE"

PAYLOAD=$(mktemp -t oc-shellutils.XXXXXX)
REMOTE_PAYLOAD="/tmp/oc-shellutils.$$.sh"
trap 'rm -f "$PAYLOAD"' EXIT

cat > "$PAYLOAD" <<'PAYLOAD_EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "[inner] apt update + install shell QoL utilities"
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y -q
# Note: procs + glow are NOT in Ubuntu noble apt repos — installed
# separately below from upstream (GitHub releases + charm apt repo).
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
    ripgrep fzf zoxide bat eza tree \
    net-tools dnsutils mtr-tiny iperf3 \
    sysstat iotop btop ncdu \
    pandoc fd-find curl ca-certificates

# Ubuntu ships fd as "fdfind" and bat as "batcat" — wire canonical names
# into /usr/local/bin (matches install-openclaw-oci.sh so PATH lookups
# resolve without extra profile plumbing).
for pair in "fdfind fd" "batcat bat"; do
    src=$(echo "$pair" | awk '{print $1}')
    dst=$(echo "$pair" | awk '{print $2}')
    if command -v "$src" >/dev/null && ! command -v "$dst" >/dev/null; then
        sudo ln -sf "$(command -v "$src")" "/usr/local/bin/$dst"
    fi
done

# GitHub CLI via official apt repo (not in Ubuntu 24.04 stock repos).
if ! command -v gh >/dev/null 2>&1; then
    echo "[inner] installing GitHub CLI via apt repo"
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -y -q
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q gh
fi

# glow (charmbracelet) via charm apt repo — not in Ubuntu stock repos.
if ! command -v glow >/dev/null 2>&1; then
    echo "[inner] installing glow via charm apt repo"
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key \
        | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
        | sudo tee /etc/apt/sources.list.d/charm.list >/dev/null
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -y -q
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q glow
fi

# yq (mikefarah) — single static binary; Ubuntu's is the wrong one.
if ! command -v yq >/dev/null 2>&1; then
    echo "[inner] installing yq (mikefarah) binary"
    ARCH=$(dpkg --print-architecture)  # arm64 on Ampere A1
    sudo curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH}" \
        -o /usr/local/bin/yq
    sudo chmod +x /usr/local/bin/yq
fi

# procs (dalance/procs) — single static binary from GitHub releases.
if ! command -v procs >/dev/null 2>&1; then
    echo "[inner] installing procs binary from GitHub releases"
    ARCH_UNAME=$(uname -m)  # aarch64 / x86_64
    case "$ARCH_UNAME" in
        aarch64) PROCS_ASSET="procs-v*-aarch64-linux.zip" ;;
        x86_64)  PROCS_ASSET="procs-v*-x86_64-linux.zip" ;;
        *) echo "[inner] skipping procs: unsupported arch $ARCH_UNAME" ;;
    esac
    if [ -n "${PROCS_ASSET:-}" ]; then
        TMPD=$(mktemp -d)
        URL=$(curl -fsSL https://api.github.com/repos/dalance/procs/releases/latest \
            | grep -oE "https://[^\"]+${PROCS_ASSET/\*/[^\"]+}" | head -1)
        if [ -n "$URL" ]; then
            curl -fsSL "$URL" -o "$TMPD/procs.zip"
            (cd "$TMPD" && unzip -qq procs.zip 2>/dev/null || sudo apt-get install -y -q unzip && unzip -qq procs.zip)
            sudo install -m 0755 "$TMPD/procs" /usr/local/bin/procs
            rm -rf "$TMPD"
        fi
    fi
fi

echo "[inner] done — installed versions:"
for t in rg fzf zoxide bat eza fd tree netstat dig mtr iperf3 iostat iotop btop procs ncdu glow pandoc gh yq; do
    v=$(command -v "$t" 2>/dev/null || echo "MISSING")
    echo "  $t: $v"
done

rm -f "$0"
PAYLOAD_EOF

chmod +x "$PAYLOAD"
echo "[install-shell-utils] staging payload → $NODE:$REMOTE_PAYLOAD"
scp -q "$PAYLOAD" "$NODE:$REMOTE_PAYLOAD"

ssh -t "$NODE" "bash $REMOTE_PAYLOAD"

echo "[install-shell-utils] ✓ done on $NODE"
