# Private LAN IPv4 for phone API (basla-telefon.bat).
$ErrorActionPreference = 'SilentlyContinue'

function Rank([string]$ip) {
  if ($ip -like '192.168.*') { return 0 }
  if ($ip -like '10.*') { return 1 }
  if ($ip -match '^172\.(1[6-9]|2[0-9]|3[0-1])\.') { return 2 }
  return 9
}

function PickBest([string[]]$list) {
  $valid = @($list | Where-Object {
    $_ -and
    $_ -notlike '127.*' -and
    $_ -notlike '169.254.*'
  } | Sort-Object { Rank $_ })
  $pref = @($valid | Where-Object { (Rank $_) -lt 9 })
  if ($pref.Count -gt 0) { return $pref[0] }
  if ($valid.Count -gt 0) { return $valid[0] }
  return $null
}

# 1) Get-NetIPAddress
$ips = @()
try {
  $ips = @(Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
      $_.IPAddress -notlike '127.*' -and
      $_.IPAddress -notlike '169.254.*' -and
      $_.PrefixOrigin -ne 'WellKnown'
    } |
    ForEach-Object { $_.IPAddress })
} catch {}

$best = PickBest $ips
if ($best) {
  Write-Output $best
  exit 0
}

# 2) Fallback: ipconfig IPv4 lines (works when Get-NetIPAddress fails)
$fromCfg = @()
$cfg = ipconfig 2>$null | Out-String
foreach ($m in [regex]::Matches($cfg, 'IPv4[^:]*:\s*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)')) {
  $fromCfg += $m.Groups[1].Value
}
$best = PickBest $fromCfg
if ($best) {
  Write-Output $best
  exit 0
}

exit 1
