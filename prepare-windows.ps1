# ==============================================================================
# Windows Sysprep Script
# Purpose: Clean system logs, temp files, reset network and run Sysprep
# ==============================================================================

# Check for Administrator privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Error: Run this script as Administrator!"
    exit
}

Write-Host "--- Windows Gold Image Preparation ---" -ForegroundColor Green

# 1. Clear Event Logs
Write-Host "[1/5] Clearing Event Logs..." -ForegroundColor Cyan
Get-EventLog -LogName * | ForEach-Object { 
    try { Clear-EventLog $_.Log } catch { Write-Warning "Skipped log: $($_.Log)" }
}

# 2. Clear Temp & Recycle Bin
Write-Host "[2/5] Cleaning Temp folders and Recycle Bin..." -ForegroundColor Cyan
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:windir\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Clear-RecycleBin -Confirm:$false -ErrorAction SilentlyContinue

# 3. Reset Network
Write-Host "[3/5] Resetting Network Stack (TCP/IP, DNS)..." -ForegroundColor Cyan
netsh winsock reset | Out-Null
netsh int ip reset | Out-Null
ipconfig /flushdns | Out-Null

# 4. Clear PowerShell History
Write-Host "[4/5] Clearing PowerShell History..." -ForegroundColor Cyan
$historyPath = (Get-PSReadLineOption).HistorySavePath
if (Test-Path $historyPath) {
    Clear-Content $historyPath
}

# 5. Run Sysprep
$sysprepPath = "$env:windir\System32\Sysprep\sysprep.exe"

if (Test-Path $sysprepPath) {
    Write-Host "[5/5] Starting Sysprep..." -ForegroundColor Magenta
    Write-Host "WARNING: System will shutdown automatically." -ForegroundColor Yellow
    
    # /generalize - Reset SID
    # /oobe - First run experience
    # /shutdown - Shutdown VM
    # /mode:vm - VM optimization
    Start-Process -FilePath $sysprepPath -ArgumentList "/generalize /oobe /shutdown /mode:vm" -Wait
} else {
    Write-Error "CRITICAL: Sysprep not found at $sysprepPath"
}
