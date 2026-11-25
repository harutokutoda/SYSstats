$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $dir 'sysinfo-windows.ps1'
if (-not (Test-Path $src)) { Write-Error "Missing $src"; exit 1 }

$code = Read-Host "Shortcut name (default: sysinfo)"
if ([string]::IsNullOrWhiteSpace($code)) { $code = 'sysinfo' }

# Ensure profile exists
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }

$line   = "function $code { & '$src' }"
$content = Get-Content $PROFILE -Raw
$content = ($content -split "`r?`n" | Where-Object { $_ -notmatch "^function $code " }) -join "`r`n"
$content += "`r`n# Terminal System Info Tool`r`n$line`r`n"
Set-Content -Path $PROFILE -Value $content -Encoding UTF8

Write-Host "✅ Installed '$code' into $PROFILE"
Write-Host "   Reload PowerShell, then run: $code"
