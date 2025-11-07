#
# Stop FinBERT File Watcher Service
# This script stops the running FinBERT file watcher service
#

Write-Host "================================================================================================" -ForegroundColor Cyan
Write-Host "                      STOPPING GRANDE FINBERT FILE WATCHER SERVICE" -ForegroundColor Cyan  
Write-Host "================================================================================================" -ForegroundColor Cyan
Write-Host ""

# Find the running service process
Write-Host "Searching for running FinBERT service..." -ForegroundColor Yellow

$runningProcess = Get-Process -Name python -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*finbert_watcher_service.py*"
}

if (-not $runningProcess) {
    Write-Host "  No running FinBERT service found" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "The service is not currently running." -ForegroundColor White
    Write-Host ""
    pause
    exit 0
}

# Stop the process
Write-Host "  Found service (PID: $($runningProcess.Id))" -ForegroundColor Green
Write-Host ""
Write-Host "Stopping service..." -ForegroundColor Yellow

try {
    Stop-Process -Id $runningProcess.Id -Force
    Start-Sleep -Seconds 1
    
    # Verify it stopped
    $stillRunning = Get-Process -Id $runningProcess.Id -ErrorAction SilentlyContinue
    if ($stillRunning) {
        Write-Host "  WARNING: Process may still be running" -ForegroundColor Yellow
    } else {
        Write-Host "  Service stopped successfully" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "================================================================================================" -ForegroundColor Cyan
    Write-Host "                              SERVICE STOPPED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "================================================================================================" -ForegroundColor Cyan
    Write-Host ""
    
} catch {
    Write-Host "  ERROR: Failed to stop service" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    pause
    exit 1
}

Write-Host ""
Write-Host "Press any key to close this window..." -ForegroundColor Gray
pause

