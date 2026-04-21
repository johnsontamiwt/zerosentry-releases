# ============================================================
#  ZeroMaster Admin Tools Installer
#  Downloads diagnostic scripts from zerosentry-releases into
#  the local ZeroMaster admin_tools/ directory.
#
#  USAGE (one-liner — paste into PowerShell):
#    iwr -UseBasicParsing https://raw.githubusercontent.com/johnsontamiwt/zerosentry-releases/main/tools/install_tools.ps1 | iex
# ============================================================

$ErrorActionPreference = 'Stop'

# --- Auto-detect ZeroMaster install dir ---
$candidates = @(
    'C:\ZeroSentry\ZeroMaster',
    'C:\zeromaster\ZeroMaster',
    'C:\ZeroMaster'
)
$installDir = $null
foreach ($c in $candidates) {
    if (Test-Path (Join-Path $c 'app.py')) { $installDir = $c; break }
    if (Test-Path (Join-Path $c 'app.cp311-win_amd64.pyd')) { $installDir = $c; break }
}

if (-not $installDir) {
    Write-Host "ERROR: Could not find ZeroMaster install dir." -ForegroundColor Red
    Write-Host "Checked: $($candidates -join ', ')"
    $installDir = Read-Host "Please enter full path to ZeroMaster directory"
    if (-not (Test-Path $installDir)) { throw "Path not found: $installDir" }
}

Write-Host "ZeroMaster install dir: $installDir" -ForegroundColor Green

$toolsDir = Join-Path $installDir 'admin_tools'
if (-not (Test-Path $toolsDir)) {
    New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
}

# --- Files to download ---
$baseUrl = 'https://raw.githubusercontent.com/johnsontamiwt/zerosentry-releases/main/tools'
$files = @(
    'forensics_snapshot.bat'
)

foreach ($f in $files) {
    $url = "$baseUrl/$f"
    $dest = Join-Path $toolsDir $f
    Write-Host "Downloading $f ..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $dest
        Write-Host "  -> $dest" -ForegroundColor Green
    } catch {
        Write-Host "  FAILED: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Admin tools installed." -ForegroundColor Green
Write-Host "  Run: $toolsDir\forensics_snapshot.bat" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
