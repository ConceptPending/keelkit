#!/usr/bin/env bash
# keelkit client setup (macOS / Linux / WSL). Safe to re-run: it brings the machine to the current setup.
#   curl -fsSL https://raw.githubusercontent.com/ConceptPending/keelkit/main/client.sh | bash
# Options: --no-install (skip Tailscale), --check (only test the connection).
#
# Result:
#   ssh keel           -> straight into the tmux session `hub`
#   ssh keel-cmd CMD   -> run one command on keel (no tmux), e.g. ssh -t keel-cmd 'keel-secret-set NAME'
#   keel               -> shortcut for `ssh keel` in zsh and bash
# Nothing secret is in this repository. Sign-in is Tailscale SSH (identity), approved once per device.
set -euo pipefail
say(){ printf '\033[1m%s\033[0m\n' "$*"; }
warn(){ printf '\033[33m%s\033[0m\n' "$*"; }

INSTALL=1; CHECK_ONLY=0
for a in "$@"; do case "$a" in --no-install) INSTALL=0;; --check) CHECK_ONLY=1;; esac; done

OS=$(uname -s); WSL=0
if [ "$OS" = Linux ] && grep -qi microsoft /proc/version 2>/dev/null; then WSL=1; fi

check(){
  if out=$(ssh -F ~/.ssh/config -o BatchMode=yes -o ConnectTimeout=8 keel-cmd hostname 2>&1); then
    say "connection OK: ssh keel-cmd reached '$out'"
  else
    warn "could not reach keel yet: $out"
    warn "sign in to Tailscale (and approve this device if asked), then run: ssh keel-cmd hostname"
    [ "$WSL" = 1 ] && warn "WSL: Tailscale runs on the Windows side. If 'keel' does not resolve here, run client.ps1 on Windows and use its terminal, or add 'HostName <keel tailnet name>' via ~/.ssh/config.d."
    return 1
  fi
}
[ "$CHECK_ONLY" = 1 ] && { check; exit $?; }

# 1. Tailscale
if [ "$INSTALL" = 1 ]; then
  if [ "$WSL" = 1 ]; then
    say "WSL detected: Tailscale belongs on Windows (run client.ps1 there); not installing it inside WSL"
  elif command -v tailscale >/dev/null 2>&1 || [ -d "/Applications/Tailscale.app" ]; then
    say "Tailscale already present"
  elif [ "$OS" = Darwin ]; then
    if command -v brew >/dev/null 2>&1; then brew install --cask tailscale >/dev/null && say "Tailscale installed: open it from Applications and sign in"
    else warn "Install Tailscale from the App Store, then sign in"; fi
  else
    curl -fsSL https://tailscale.com/install.sh | sh >/dev/null && sudo tailscale up && say "Tailscale up"
  fi
fi

# 2. ssh config: one managed block, replaced on every run. Old unmanaged `Host keel` / `Host keel-cmd`
#    blocks (from earlier kit versions or hand edits) are removed; a timestamped backup is kept.
mkdir -p ~/.ssh && chmod 700 ~/.ssh
CFG=~/.ssh/config; touch "$CFG"; chmod 600 "$CFG"
cp -p "$CFG" "$CFG.keelkit-backup-$(date +%Y%m%d-%H%M%S)"
# settings someone added by hand to an old keel block (e.g. IdentityFile, IdentityAgent) are carried over
extra=$(awk '
  /^# >>> keelkit >>>/ { m=1; next } /^# <<< keelkit <<</ { m=0; next }
  /^[Hh]ost[ \t]/ || /^[Mm]atch[ \t]/ { n=split($0, f, /[ \t]+/); inb=0; for (i=2; i<=n; i++) if (f[i]=="keel" || f[i]=="keel-cmd") inb=1; next }
  (inb || m) && NF && $1 !~ /^#/ {
    k=tolower($1)
    if (k!="hostname" && k!="user" && k!="requesttty" && k!="remotecommand" && k!="serveraliveinterval") { sub(/^[ \t]+/, ""); print "  " $0 }
  }' "$CFG" | awk '!seen[$0]++')
[ -n "$extra" ] && say "keeping your own settings for keel: $(echo "$extra" | awk '{print $1}' | sort -u | tr '\n' ' ')"
tmp=$(mktemp)
awk '
  /^# >>> keelkit >>>/ { skip_managed=1; next }
  /^# <<< keelkit <<</ { skip_managed=0; next }
  skip_managed { next }
  /^[Hh]ost[ \t]/ || /^[Mm]atch[ \t]/ {
    n=split($0, f, /[ \t]+/); drop=0
    for (i=2; i<=n; i++) if (f[i]=="keel" || f[i]=="keel-cmd") drop=1
    in_old=drop
    if (drop) next
  }
  in_old { next }
  { print }
' "$CFG" | awk 'NF || prev_nf { print } { prev_nf = NF }' > "$tmp"
{
  printf '\n# >>> keelkit >>> (managed by keelkit client.sh; re-run it instead of editing)\n'
  printf 'Host keel keel-cmd\n  HostName keel\n  User nick\n  ServerAliveInterval 30\n'
  [ -n "$extra" ] && printf '%s\n' "$extra"
  printf '\nHost keel\n  RequestTTY yes\n  RemoteCommand tmux attach -d -t hub\n# <<< keelkit <<<\n'
} >> "$tmp"
mv "$tmp" "$CFG"; chmod 600 "$CFG"
say "ssh config: keel (tmux) and keel-cmd (one-off commands) set"

# 3. the one-word command, in zsh and bash; stale keel aliases from older setups removed
for rc in ~/.zshrc ~/.bashrc; do
  [ -f "$rc" ] || continue
  cp -p "$rc" "$rc.keelkit-backup-$(date +%Y%m%d-%H%M%S)"
  tmp=$(mktemp)
  awk '
    /^# >>> keelkit >>>/ { skip=1; next }
    /^# <<< keelkit <<</ { skip=0; next }
    skip { next }
    /^# keelkit$/ { next }
    /^alias keel=/ { next }
    /^# keel: attach to the persistent tmux session/ { next }
    { print }
  ' "$rc" | awk '{ l[NR]=$0 } END { n=NR; while (n>0 && l[n] ~ /^[ \t]*$/) n--; for (i=1; i<=n; i++) print l[i] }' > "$tmp"
  printf '\n# >>> keelkit >>>\nalias keel='"'"'ssh keel'"'"'\n# <<< keelkit <<<\n' >> "$tmp"
  cat "$tmp" > "$rc"; rm -f "$tmp"
done
[ -f ~/.zshrc ] || [ -f ~/.bashrc ] || printf '\n# >>> keelkit >>>\nalias keel='"'"'ssh keel'"'"'\n# <<< keelkit <<<\n' >> ~/."$(basename "${SHELL:-bash}")"rc
say "shortcut: keel (open a new terminal to pick it up)"

# 4. prove it
check || true
