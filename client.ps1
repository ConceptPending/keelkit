# keelkit client setup (Windows, PowerShell). Safe to re-run: it brings the machine to the current setup.
#   irm https://raw.githubusercontent.com/ConceptPending/keelkit/main/client.ps1 | iex
# Run in an elevated PowerShell the first time (Tailscale and the OpenSSH client may need installing).
#
# Result (Windows Terminal / PowerShell, and inside WSL if it is installed):
#   ssh keel           -> straight into the tmux session `hub`
#   ssh keel-cmd CMD   -> run one command on keel (no tmux)
#   keel               -> shortcut for `ssh keel`
# Nothing secret is in this repository. Sign-in is Tailscale SSH (identity), approved once per device.
$ErrorActionPreference = "Stop"
function Say($m) { Write-Host $m -ForegroundColor White }
function Warn($m) { Write-Host $m -ForegroundColor Yellow }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"

# 1. Tailscale + OpenSSH client
if (-not (Get-Command tailscale -ErrorAction SilentlyContinue) -and -not (Test-Path "$env:ProgramFiles\Tailscale\tailscale.exe")) {
  winget install --id Tailscale.Tailscale -e --accept-package-agreements --accept-source-agreements | Out-Null
  Say "Tailscale installed: open it and sign in"
} else { Say "Tailscale already present" }
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
  Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 | Out-Null
  Say "OpenSSH client installed"
}

# 2. ssh config: one managed block, replaced on every run; old keel / keel-cmd blocks removed,
#    hand-added settings in them (IdentityFile, IdentityAgent...) carried over; backup kept.
$sshDir = Join-Path $HOME ".ssh"; New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
$cfg = Join-Path $sshDir "config"
if (-not (Test-Path $cfg)) { New-Item -ItemType File -Path $cfg | Out-Null }
Copy-Item $cfg "$cfg.keelkit-backup-$stamp"
$known = @("hostname", "user", "requesttty", "remotecommand", "serveraliveinterval")
$keep = New-Object System.Collections.Generic.List[string]
$extra = New-Object System.Collections.Generic.List[string]
$inManaged = $false; $inOld = $false
foreach ($line in (Get-Content $cfg)) {
  if ($line -match '^# >>> keelkit >>>') { $inManaged = $true; continue }
  if ($line -match '^# <<< keelkit <<<') { $inManaged = $false; continue }
  if ($line -match '^\s*(Host|Match)\s') {
    $names = ($line.Trim() -split '\s+') | Select-Object -Skip 1
    $inOld = ($names -contains "keel") -or ($names -contains "keel-cmd")
    if ($inOld -or $inManaged) { continue }
  }
  if ($inManaged -or $inOld) {
    $t = $line.Trim()
    if ($t -and -not $t.StartsWith("#")) {
      $k = ($t -split '\s+')[0].ToLower()
      if ($known -notcontains $k -and -not $extra.Contains("  $t")) { $extra.Add("  $t") }
    }
    continue
  }
  if ($line.Trim() -eq "" -and $keep.Count -gt 0 -and $keep[$keep.Count - 1].Trim() -eq "") { continue }
  $keep.Add($line)
}
while ($keep.Count -gt 0 -and $keep[$keep.Count - 1].Trim() -eq "") { $keep.RemoveAt($keep.Count - 1) }
if ($extra.Count -gt 0) { Say ("keeping your own settings for keel: " + (($extra | ForEach-Object { ($_.Trim() -split '\s+')[0] } | Sort-Object -Unique) -join " ")) }
$block = @("", "# >>> keelkit >>> (managed by keelkit client.ps1; re-run it instead of editing)",
  "Host keel keel-cmd", "  HostName keel", "  User nick", "  ServerAliveInterval 30") + $extra +
  @("", "Host keel", "  RequestTTY yes", "  RemoteCommand tmux attach -d -t hub", "# <<< keelkit <<<")
# ASCII, no BOM: Windows OpenSSH reads it reliably
[System.IO.File]::WriteAllLines($cfg, [string[]]($keep + $block), (New-Object System.Text.UTF8Encoding($false)))
Say "ssh config: keel (tmux) and keel-cmd (one-off commands) set"

# 3. the one-word command in the PowerShell profile; older keelkit lines replaced
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Force -Path $PROFILE | Out-Null }
Copy-Item $PROFILE "$PROFILE.keelkit-backup-$stamp"
$p = New-Object System.Collections.Generic.List[string]; $skip = $false
foreach ($line in (Get-Content $PROFILE)) {
  if ($line -match '^# >>> keelkit >>>') { $skip = $true; continue }
  if ($line -match '^# <<< keelkit <<<') { $skip = $false; continue }
  if ($skip -or $line -match '^# keelkit$' -or $line -match '^function keel\b') { continue }
  $p.Add($line)
}
while ($p.Count -gt 0 -and $p[$p.Count - 1].Trim() -eq "") { $p.RemoveAt($p.Count - 1) }
$p.AddRange([string[]]@("", "# >>> keelkit >>>", "function keel { ssh keel }", "# <<< keelkit <<<"))
Set-Content -Path $PROFILE -Value $p
Say "shortcut: keel (open a new PowerShell / Windows Terminal tab to pick it up)"

# 4. WSL, if installed: same setup inside it (Tailscale stays on the Windows side)
if (Get-Command wsl -ErrorAction SilentlyContinue) {
  $distros = (wsl -l -q 2>$null) -replace "`0", "" | Where-Object { $_.Trim() }
  if ($distros) {
    Say "WSL found: configuring the default distribution"
    wsl -e bash -lc "curl -fsSL https://raw.githubusercontent.com/ConceptPending/keelkit/main/client.sh | bash -s -- --no-install"
  }
}

# 5. prove it
$out = & ssh -o BatchMode=yes -o ConnectTimeout=8 keel-cmd hostname 2>&1
if ($LASTEXITCODE -eq 0) { Say "connection OK: ssh keel-cmd reached '$out'" }
else { Warn "could not reach keel yet: $out"; Warn "sign in to Tailscale (approve this device if asked), then run: ssh keel-cmd hostname" }
