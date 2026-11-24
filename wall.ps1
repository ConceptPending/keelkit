# keelkit wall: the command center (https://home.nickw.info/now) full screen on each portrait monitor of this PC.
#   powershell -ExecutionPolicy Bypass -File wall.ps1              open the wall now
#   powershell -ExecutionPolicy Bypass -File wall.ps1 -Install     open it at every logon (a Startup shortcut), and now
#   powershell -ExecutionPolicy Bypass -File wall.ps1 -Uninstall   stop opening it at logon
# Portrait = taller than wide. Left to right: the first is "left" (ambient: health, projects, fleet), the last is "right"
# (you: needs you, sessions). Nothing goes on landscape screens. Each window gets its own Edge profile folder, or the
# second window would ignore its position. Only Nick's devices can open /now: on its first run each window pairs its
# profile with keel over Tailscale (Tailscale must be on), and keeps that for a year. If a window lands on the wrong screen (mixed scaling): click it,
# Win+Shift+Left/Right to move it, then F11.
param([switch]$Install, [switch]$Uninstall, [string]$Url = "https://home.nickw.info/now",
      [string]$PairUrl = "http://keel.tail4e6546.ts.net/now/pair")

$startup = Join-Path ([Environment]::GetFolderPath("Startup")) "keel wall.lnk"
if ($Uninstall) { Remove-Item $startup -ErrorAction SilentlyContinue; Write-Host "keel wall will no longer open at logon"; return }
if ($Install) {
  $dest = Join-Path $env:LOCALAPPDATA "keel-wall\wall.ps1"
  New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
  if ($PSCommandPath) { Copy-Item $PSCommandPath $dest -Force }
  else { Invoke-RestMethod https://raw.githubusercontent.com/ConceptPending/keelkit/main/wall.ps1 | Set-Content $dest }
  $ws = New-Object -ComObject WScript.Shell; $lnk = $ws.CreateShortcut($startup)
  $lnk.TargetPath = "powershell.exe"
  $lnk.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$dest`""
  $lnk.Save(); Write-Host "keel wall will open at every logon ($startup)"
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System; using System.Runtime.InteropServices;
public static class KeelWin {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int ht, bool repaint);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
}
"@
[KeelWin]::SetProcessDPIAware() | Out-Null     # real pixels, whatever each screen's scaling

$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") |
  Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { Write-Host "Microsoft Edge not found"; exit 1 }

# at logon the network and Tailscale may not be up yet: wait up to two minutes for keel's open page to answer
for ($i = 0; $i -lt 24; $i++) {
  try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 -Uri "https://home.nickw.info/" | Out-Null; break } catch { Start-Sleep 5 }
}

$portraits = [System.Windows.Forms.Screen]::AllScreens | Where-Object { $_.Bounds.Height -gt $_.Bounds.Width } |
  Sort-Object { $_.Bounds.X }
if (-not $portraits) { Write-Host "No portrait screen found; nothing opened"; exit 0 }
$names = if (@($portraits).Count -eq 1) { @("right") } else { @("left") + @("left") * (@($portraits).Count - 2) + @("right") }

$i = 0
foreach ($s in $portraits) {
  $name = $names[$i]; $i++
  $b = $s.Bounds
  $dataDir = Join-Path $env:LOCALAPPDATA "keel-wall\$name"
  $before = @(Get-Process msedge -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | ForEach-Object { $_.MainWindowHandle })
  # first run of each window: pair its browser profile with keel over Tailscale (keel sets a cookie for a year; the
  # window then lands on /now). After that it opens /now directly. Unpaired later? The page shows the pairing link.
  $marker = Join-Path $dataDir "keel-paired"
  $start = if (Test-Path $marker) { "${Url}?screen=$name" } else { "$PairUrl`?screen=$name" }
  New-Item -ItemType Directory -Force -Path $dataDir | Out-Null; Set-Content $marker (Get-Date -Format s)
  Start-Process $edge -ArgumentList @("--app=$start", "--user-data-dir=`"$dataDir`"", "--no-first-run",
    "--window-position=$($b.X),$($b.Y)", "--window-size=$($b.Width),$($b.Height)")
  # find the new window, put it exactly on its screen, then full screen (F11)
  $h = 0
  for ($t = 0; $t -lt 40 -and -not $h; $t++) {
    Start-Sleep -Milliseconds 250
    $h = Get-Process msedge -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 -and $before -notcontains $_.MainWindowHandle } |
      Select-Object -First 1 -ExpandProperty MainWindowHandle
  }
  if ($h) {
    [KeelWin]::MoveWindow($h, $b.X, $b.Y, $b.Width, $b.Height, $true) | Out-Null
    [KeelWin]::SetForegroundWindow($h) | Out-Null
    Start-Sleep -Milliseconds 600
    [System.Windows.Forms.SendKeys]::SendWait("{F11}")
    Write-Host "$name -> screen at $($b.X),$($b.Y) ($($b.Width)x$($b.Height))"
  } else { Write-Host "$name opened, but its window was not found to place it: move it with Win+Shift+arrow, then F11" }
}
