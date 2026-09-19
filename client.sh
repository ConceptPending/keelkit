#!/usr/bin/env bash
# keelkit client setup (macOS / Linux). One line on any new machine:
#   curl -fsSL https://raw.githubusercontent.com/ConceptPending/keelkit/main/client.sh | bash
# Then: open Tailscale, sign in, and type `keel`.
set -euo pipefail
say(){ printf '\033[1m%s\033[0m\n' "$*"; }
# 1. Tailscale
if ! command -v tailscale >/dev/null 2>&1 && [ ! -d "/Applications/Tailscale.app" ]; then
  if [ "$(uname)" = Darwin ]; then
    if command -v brew >/dev/null 2>&1; then brew install --cask tailscale >/dev/null && say "Tailscale installed (open it from Applications and sign in)"; else say "Install Tailscale from the App Store, then sign in"; fi
  else
    curl -fsSL https://tailscale.com/install.sh | sh >/dev/null && sudo tailscale up && say "Tailscale up"
  fi
else say "Tailscale already present"; fi
# 2. ssh config: `ssh keel` attaches straight to the session
mkdir -p ~/.ssh && chmod 700 ~/.ssh
if ! grep -q "^Host keel$" ~/.ssh/config 2>/dev/null; then cat >> ~/.ssh/config <<'CFG'

Host keel
  HostName keel
  User nick
  RequestTTY yes
  RemoteCommand tmux attach -d -t hub
  ServerAliveInterval 30
CFG
say "ssh config: Host keel added"; fi
# 3. the one-word command, in zsh and bash
for rc in ~/.zshrc ~/.bashrc; do
  [ -f "$rc" ] || touch "$rc"
  grep -q "alias keel=" "$rc" || printf '\n# keelkit\nalias keel='"'"'ssh keel'"'"'\n' >> "$rc"
done
say "alias keel added. Open a new terminal window, make sure Tailscale is signed in, and type: keel"
