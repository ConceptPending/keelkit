# keelkit

Client setup for attaching any machine to the persistent workspace on `keel`. Every script is safe to re-run: it brings the machine to the current setup, so re-running it is also how you update or repair one.

**macOS / Linux** (then sign in to Tailscale and open a new terminal):

    curl -fsSL https://raw.githubusercontent.com/ConceptPending/keelkit/main/client.sh | bash

**Windows** (elevated PowerShell the first time; also sets up WSL if it is installed):

    irm https://raw.githubusercontent.com/ConceptPending/keelkit/main/client.ps1 | iex

**WSL on its own** (Tailscale stays on the Windows side):

    curl -fsSL https://raw.githubusercontent.com/ConceptPending/keelkit/main/client.sh | bash -s -- --no-install

**Check a machine:** `client.sh --check`, or just `ssh keel-cmd hostname` (prints `keel`).

**iPhone / iPad:** install Tailscale and sign in; in Blink or Termius add a host `keel`, user `nick`, command `tmux attach -d -t hub`.

## What you get

| Command | Does |
|---|---|
| `keel` or `ssh keel` | straight into the tmux session `hub` |
| `ssh keel-cmd <command>` | runs one command on keel, no tmux (add `-t` if it asks for input) |

## What the scripts do

1. Install Tailscale (not inside WSL) and, on Windows, the OpenSSH client.
2. Write one managed block to `~/.ssh/config`, between `# >>> keelkit >>>` and `# <<< keelkit <<<`, replacing any earlier `Host keel` / `Host keel-cmd` entries. Settings you added by hand to those entries (for example `IdentityFile` or `IdentityAgent`) are carried into the block. A timestamped backup of the old file is kept beside it.
3. Add the `keel` shortcut (zsh and bash, or the PowerShell profile) in a managed block, removing older keel shortcuts.
4. Test the connection with `ssh keel-cmd hostname`.

No keys to copy: Tailscale SSH signs you in by identity and asks you to approve each new device once in the browser. Nothing secret is in this repository.

Server side lives in the private `keel` repo.

## keel-mic
Streams the Mac microphone to keel so Claude Code voice mode works inside the remote tmux session. Run it in a second tab and leave it. Needs ffmpeg.
