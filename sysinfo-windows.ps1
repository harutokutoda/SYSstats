#Requires -Version 5
$ErrorActionPreference = 'SilentlyContinue'

function ColorFor($p){ if($p -lt 50){'Green'}elseif($p -lt 80){'Yellow'}else{'Red'} }
function Bar($p, $w = 22){
  $p   = [Math]::Max(0, [Math]::Min(100, [int]$p))
  $f   = [int]($p * $w / 100); $e = $w - $f
  $col = ColorFor $p
  Write-Host -NoNewline "  " -ForegroundColor DarkGray
  Write-Host -NoNewline ('#' * $f) -ForegroundColor $col
  Write-Host -NoNewline ('-' * $e) -ForegroundColor DarkGray
  Write-Host ""
}
function Row($label, $value){
  Write-Host ("  {0,-11}" -f $label) -NoNewline -ForegroundColor Cyan
  Write-Host $value
}
function RowBar($label, $value, $pct){
  Write-Host ("  {0,-11}" -f $label) -NoNewline -ForegroundColor Cyan
  Write-Host ("{0}  {1,3}%" -f $value, $pct)
  Bar $pct
}

$os  = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$bat = Get-CimInstance Win32_Battery   | Select-Object -First 1
$up  = (Get-Date) - $os.LastBootUpTime

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║        TERMINAL SYSTEM INFO TOOL             ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Row "OS"       ("{0} (build {1})" -f $os.Caption, $os.BuildNumber)
Row "Kernel"   ("{0}.{1}.{2}" -f $os.Version.Major, $os.Version.Minor, $os.Version.Build)
Row "Hostname" $env:COMPUTERNAME
Row "Uptime"   ("{0}d {1}h {2}m" -f $up.Days, $up.Hours, $up.Minutes)
Write-Host ""

try {
  $s = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 2
  $cpuPct = [int]$s.CounterSamples[-1].CookedValue
} catch { $cpuPct = 0 }
RowBar "CPU" $cpu.Name.Trim() $cpuPct
Write-Host ""

$totalMB = [int]($os.TotalVisibleMemorySize / 1KB)
$freeMB  = [int]($os.FreePhysicalMemory     / 1KB)
$usedMB  = $totalMB - $freeMB
$ramPct  = if ($totalMB -gt 0) { [int]($usedMB * 100 / $totalMB) } else { 0 }
RowBar "RAM" ("{0} / {1} MB" -f $usedMB, $totalMB) $ramPct
Write-Host ""

Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
  $usedGB  = [math]::Round(($_.Size - $_.FreeSpace) / 1GB, 1)
  $totalGB = [math]::Round($_.Size / 1GB, 1)
  $pct     = if ($_.Size -gt 0) { [int](($_.Size - $_.FreeSpace) * 100 / $_.Size) } else { 0 }
  RowBar ("Disk " + $_.DeviceID) ("{0} / {1} GB" -f $usedGB, $totalGB) $pct
}
Write-Host ""

if ($bat) {
  $status = switch ($bat.BatteryStatus) {
    1 {'Discharging'}; 2 {'AC'}; 3 {'Charging'}; 4 {'Low'}
    5 {'Critical'};    6 {'Charging'}; 7 {'Charging'}
    8 {'Charging'};    9 {'Charging'}; default {'Unknown'}
  }
  Row "Battery" ("{0}% ({1})" -f $bat.EstimatedChargeRemaining, $status)
} else {
  Row "Battery" "N/A (no battery)"
}
Write-Host ""
Write-Host ("  " + ("─" * 46)) -ForegroundColor DarkGray
Write-Host ""
