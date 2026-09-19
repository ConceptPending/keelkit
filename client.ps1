# keelkit client setup (Windows, PowerShell). One line in an elevated PowerShell:
#   irm https://raw.githubusercontent.com/ConceptPending/keelkit/main/client.ps1 | iex
# Then: open Tailscale, sign in, and type `keel` in a new PowerShell or Windows Terminal.
if (-not (Get-Command tailscale -ErrorAction SilentlyContinue)) { winget install --id Tailscale.Tailscale -e --accept-package-agreements --accept-source-agreements | Out-Null; Write-Host "Tailscale installed: open it and sign in" } else { Write-Host "Tailscale already present" }
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) { Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 | Out-Null }
$sshDir = "$HOME\.ssh"; New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
$cfg = "$sshDir\config"
if (-not (Test-Path $cfg) -or -not (Select-String -Path $cfg -Pattern "^Host keel$" -Quiet)) {
  Add-Content $cfg "`nHost keel`n  HostName keel`n  User nick`n  RequestTTY yes`n  RemoteCommand tmux attach -d -t hub`n  ServerAliveInterval 30`n"
  Write-Host "ssh config: Host keel added"
}
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Force -Path $PROFILE | Out-Null }
if (-not (Select-String -Path $PROFILE -Pattern "function keel" -Quiet)) { Add-Content $PROFILE "`n# keelkit`nfunction keel { ssh keel }`n"; Write-Host "keel function added to your PowerShell profile" }
Write-Host "Done. Sign in to Tailscale, open a new terminal, and type: keel"
