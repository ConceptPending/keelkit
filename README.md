# keelkit

Client setup for attaching any machine to the persistent workspace on `keel`.

**macOS / Linux** (one line, then sign in to Tailscale, open a new terminal, type `keel`):

    curl -fsSL https://raw.githubusercontent.com/ConceptPending/keelkit/main/client.sh | bash

**Windows** (elevated PowerShell, same three steps):

    irm https://raw.githubusercontent.com/ConceptPending/keelkit/main/client.ps1 | iex

**iPhone / iPad:** install Tailscale and sign in; in Blink or Termius add a host `keel`, user `nick`, command `tmux attach -d -t hub`.

What it does: installs Tailscale, adds an SSH host entry `keel` that attaches straight to the tmux session `hub`, and adds the one-word command `keel`. No keys to copy: Tailscale SSH signs you in by identity, and approves each new device once in the browser. Nothing secret is in this repository.

Server side lives in the case repo under `infra/bootstrap_keel.sh`.

## keel-mic
Streams the Mac microphone to keel so Claude Code voice mode works inside the remote tmux session. Run it in a second tab and leave it. Needs ffmpeg.
