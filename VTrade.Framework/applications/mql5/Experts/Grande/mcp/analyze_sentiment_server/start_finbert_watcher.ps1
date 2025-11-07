#
# Start FinBERT File Watcher Service
# This script starts the FinBERT file watcher service in the background
#

Write-Host "================================================================================================" -ForegroundColor Cyan
Write-Host "                         GRANDE FINBERT FILE WATCHER SERVICE" -ForegroundColor Cyan  
Write-Host "================================================================================================" -ForegroundColor Cyan
Write-Host ""

# Get the script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Check if Python is available
Write-Host "[1/5] Checking Python installation..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    Write-Host "      Found: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "      ERROR: Python not found!" -ForegroundColor Red
    Write-Host "      Please install Python from https://www.python.org/downloads/" -ForegroundColor Red
    Write-Host "      Make sure to check 'Add Python to PATH' during installation" -ForegroundColor Red
    pause
    exit 1
}

# Check if required packages are installed
Write-Host "[2/5] Checking required Python packages..." -ForegroundColor Yellow
$requiredPackages = @("torch", "transformers", "numpy")
$missingPackages = @()

foreach ($package in $requiredPackages) {
    $installed = python -c "import $package" 2>&1
    if ($LASTEXITCODE -ne 0) {
        $missingPackages += $package
        Write-Host "      Missing: $package" -ForegroundColor Red
    } else {
        Write-Host "      Found: $package" -ForegroundColor Green
    }
}

if ($missingPackages.Count -gt 0) {
    Write-Host ""
    Write-Host "      ERROR: Missing required packages!" -ForegroundColor Red
    Write-Host "      Please run install_finbert.ps1 or install_finbert.bat first" -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}

# Check if service is already running
Write-Host "[3/5] Checking if service is already running..." -ForegroundColor Yellow
$runningProcess = Get-Process -Name python -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*finbert_watcher_service.py*"
}

if ($runningProcess) {
    Write-Host "      Service is already running (PID: $($runningProcess.Id))" -ForegroundColor Yellow
    Write-Host ""
    $response = Read-Host "      Do you want to restart it? (y/n)"
    if ($response -eq "y" -or $response -eq "Y") {
        Write-Host "      Stopping existing service..." -ForegroundColor Yellow
        Stop-Process -Id $runningProcess.Id -Force
        Start-Sleep -Seconds 2
        Write-Host "      Service stopped" -ForegroundColor Green
    } else {
        Write-Host "      Keeping existing service running" -ForegroundColor Green
        Write-Host ""
        pause
        exit 0
    }
}

# Test the analyzer first
Write-Host "[4/5] Testing FinBERT analyzer..." -ForegroundColor Yellow
$testResult = python "$ScriptDir\finbert_watcher_service.py" --test 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "      WARNING: Test failed, but continuing anyway..." -ForegroundColor Yellow
    Write-Host "      You may see errors in the log if FinBERT packages are not installed" -ForegroundColor Yellow
} else {
    Write-Host "      Test passed successfully" -ForegroundColor Green
}

# Start the service
Write-Host "[5/5] Starting FinBERT File Watcher Service..." -ForegroundColor Yellow

# Create a new PowerShell window to run the service
$servicePath = Join-Path $ScriptDir "finbert_watcher_service.py"
$logPath = Join-Path $ScriptDir "finbert_watcher.log"

# Start the service in a new window
Start-Process powershell -ArgumentList "-NoExit", "-Command", "python '$servicePath'" -WindowStyle Normal

Start-Sleep -Seconds 2

# Verify the service started
$newProcess = Get-Process -Name python -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*finbert_watcher_service.py*"
}

if ($newProcess) {
    Write-Host "      Service started successfully (PID: $($newProcess.Id))" -ForegroundColor Green
    Write-Host ""
    Write-Host "================================================================================================" -ForegroundColor Cyan
    Write-Host "                                SERVICE STARTED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "================================================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "The FinBERT File Watcher Service is now running in a separate window." -ForegroundColor White
    Write-Host ""
    Write-Host "What it does:" -ForegroundColor Yellow
    Write-Host "  - Monitors MT5 Common Files for new market_context_*.json files" -ForegroundColor White
    Write-Host "  - Automatically runs FinBERT analysis on new files" -ForegroundColor White
    Write-Host "  - Outputs enhanced_finbert_analysis.json for Grande EA" -ForegroundColor White
    Write-Host ""
    Write-Host "Log file location:" -ForegroundColor Yellow
    Write-Host "  $logPath" -ForegroundColor White
    Write-Host ""
    Write-Host "To stop the service:" -ForegroundColor Yellow
    Write-Host "  - Close the service window, or" -ForegroundColor White
    Write-Host "  - Press Ctrl+C in the service window, or" -ForegroundColor White
    Write-Host "  - Run stop_finbert_watcher.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "================================================================================================" -ForegroundColor Cyan
} else {
    Write-Host "      ERROR: Failed to start service" -ForegroundColor Red
    Write-Host "      Check the log file for details: $logPath" -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}

Write-Host ""
Write-Host "Press any key to close this window (service will continue running)..." -ForegroundColor Gray
pause

