# Grande Trading System - Improvement Monitor
# Tracks the effectiveness of recent fixes

Write-Host "`n=== GRANDE EA IMPROVEMENT MONITOR ===" -ForegroundColor Cyan
Write-Host "Monitoring for changes after EA reload..." -ForegroundColor Yellow

# Find the latest log file
$logPath = Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal\*\MQL5\Logs" -Directory | Select-Object -First 1
if (-not $logPath) {
    Write-Host "ERROR: Could not find MT5 logs directory" -ForegroundColor Red
    exit
}

$latestLog = Get-ChildItem "$($logPath.FullName)\*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-Host "`nLog File: $($latestLog.Name)" -ForegroundColor Gray
Write-Host "Last Modified: $(Get-Date $latestLog.LastWriteTime -Format 'HH:mm:ss')" -ForegroundColor Gray

# Monitor for key improvements
Write-Host "`n📊 MONITORING KEY METRICS:" -ForegroundColor Green

# 1. Check for Trend Follower override
Write-Host "`n1. TREND FOLLOWER OVERRIDE:" -ForegroundColor Yellow
$tfOverride = Get-Content $latestLog.FullName -Tail 500 | Where-Object {$_ -match "Trend Follower disagrees but local ADX|ALLOWING SIGNAL"}
if ($tfOverride) {
    Write-Host "   ✅ Override Active - Found $($tfOverride.Count) instances" -ForegroundColor Green
    $tfOverride | Select-Object -Last 2 | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
} else {
    Write-Host "   ⏳ No overrides yet (EA may need reload)" -ForegroundColor Yellow
}

# 2. Check RSI logic
Write-Host "`n2. RSI LOGIC STATUS:" -ForegroundColor Yellow
$rsiNew = Get-Content $latestLog.FullName -Tail 200 | Where-Object {$_ -match "RSI Valid Range.*not extreme"}
$rsiOld = Get-Content $latestLog.FullName -Tail 200 | Where-Object {$_ -match "RSI in Range \(40-60\)"}
if ($rsiNew) {
    Write-Host "   ✅ NEW RSI Logic Active" -ForegroundColor Green
} elseif ($rsiOld) {
    Write-Host "   ❌ OLD RSI Logic Still Active - EA NEEDS RELOAD" -ForegroundColor Red
} else {
    Write-Host "   ⚠️ No RSI checks found recently" -ForegroundColor Yellow
}

# 3. Check error 4203 status
Write-Host "`n3. ERROR 4203 STATUS:" -ForegroundColor Yellow
$error4203 = Get-Content $latestLog.FullName -Tail 300 | Where-Object {$_ -match "consecutive 4203 errors|error 4203"}
if ($error4203) {
    $lastError = $error4203 | Select-Object -Last 1
    if ($lastError -match "(\d+) consecutive 4203") {
        $count = [int]$Matches[1]
        if ($count -gt 10) {
            Write-Host "   ⚠️ Still accumulating: $count errors" -ForegroundColor Yellow
        } else {
            Write-Host "   ✅ Reset working: $count errors (below 10)" -ForegroundColor Green
        }
    }
    Write-Host "   Last: $lastError" -ForegroundColor Gray
} else {
    Write-Host "   ✅ No error 4203 issues detected" -ForegroundColor Green
}

# 4. Check trading activity
Write-Host "`n4. TRADING ACTIVITY:" -ForegroundColor Yellow
$signals = Get-Content $latestLog.FullName -Tail 500 | Where-Object {$_ -match "SIGNAL CONFIRMED|SIGNAL REJECTED|SIGNAL BLOCKED"}
$confirmed = $signals | Where-Object {$_ -match "CONFIRMED"}
$rejected = $signals | Where-Object {$_ -match "REJECTED|BLOCKED"}

if ($signals) {
    Write-Host "   Confirmed: $($confirmed.Count) signals" -ForegroundColor Green
    Write-Host "   Rejected: $($rejected.Count) signals" -ForegroundColor Yellow
    
    if ($confirmed.Count -gt 0) {
        Write-Host "   ✅ IMPROVEMENT DETECTED - Trades being confirmed!" -ForegroundColor Green
        $confirmed | Select-Object -Last 1 | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
    }
} else {
    Write-Host "   ⏳ No recent signal evaluations" -ForegroundColor Yellow
}

# 5. Check CSV data growth
Write-Host "`n5. DATA COLLECTION:" -ForegroundColor Yellow
$mt5Path = Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal\*" -Directory | Where-Object {Test-Path "$($_.FullName)\MQL5"} | Select-Object -First 1
if ($mt5Path) {
    $todayCSV = "$($mt5Path.FullName)\MQL5\Files\FinBERT_Data_EURUSD!_$(Get-Date -Format 'yyyy.MM.dd').csv"
    if (Test-Path $todayCSV) {
        $records = (Import-Csv $todayCSV).Count
        Write-Host "   CSV Records Today: $records" -ForegroundColor Cyan
        if ($records -gt 5) {
            Write-Host "   ✅ Good activity level" -ForegroundColor Green
        } elseif ($records -gt 1) {
            Write-Host "   ⚠️ Low activity" -ForegroundColor Yellow
        } else {
            Write-Host "   ❌ Very low activity - check if EA is working" -ForegroundColor Red
        }
    }
}

# Summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "After reloading the EA in MT5, you should see:" -ForegroundColor Yellow
Write-Host "• Trend Follower override messages when ADX > 35" -ForegroundColor White
Write-Host "• RSI Valid Range messages (not 40-60)" -ForegroundColor White
Write-Host "• Error 4203 count staying below 10" -ForegroundColor White
Write-Host "• More SIGNAL CONFIRMED messages" -ForegroundColor White
Write-Host "• Growing CSV record count" -ForegroundColor White

Write-Host "`n💡 TIP: Run this script periodically to track improvements!" -ForegroundColor Magenta
