# 📋 **OPTIMIZED GRANDE TRADING SYSTEM ANALYSIS PROMPT**

## **System Overview**
You are analyzing the Grande Trading System, an MQL5 Expert Advisor with FinBERT integration. This prompt is designed for **incremental analysis** - only examining logs and data **since the last check** to identify new issues, track improvements, and monitor system health efficiently.

## **Analysis Objectives**
1. **Incremental Error Detection**: Find new errors since last check
2. **Performance Tracking**: Monitor signal success rates and trading activity
3. **Data Quality Monitoring**: Check for data integrity issues
4. **System Health Assessment**: Verify all components are operational
5. **Improvement Validation**: Confirm fixes are working as expected

## **Critical Data Sources & File Paths**

### **1. Primary Log Files (Most Important)**
```powershell
# Get latest log file - try multiple possible paths
$logPaths = @(
    "$env:APPDATA\MetaQuotes\Terminal\*\MQL5\Logs",
    "$env:USERPROFILE\AppData\Roaming\MetaQuotes\Terminal\*\MQL5\Logs",
    "C:\Users\$env:USERNAME\AppData\Roaming\MetaQuotes\Terminal\*\MQL5\Logs"
)

$logPath = $null
foreach ($path in $logPaths) {
    $dirs = Get-ChildItem $path -Directory -ErrorAction SilentlyContinue
    if ($dirs) {
        $logPath = $dirs | Select-Object -First 1
        break
    }
}

if ($logPath) {
    $latestLog = Get-ChildItem "$($logPath.FullName)\*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
} else {
    $latestLog = $null
}
```

### **2. CSV Trading Data**
```powershell
# Get today's CSV file - try multiple possible paths
$mt5Paths = @(
    "$env:APPDATA\MetaQuotes\Terminal\*",
    "$env:USERPROFILE\AppData\Roaming\MetaQuotes\Terminal\*",
    "C:\Users\$env:USERNAME\AppData\Roaming\MetaQuotes\Terminal\*"
)

$mt5Path = $null
foreach ($basePath in $mt5Paths) {
    $dirs = Get-ChildItem $basePath -Directory -ErrorAction SilentlyContinue | Where-Object {Test-Path "$($_.FullName)\MQL5"}
    if ($dirs) {
        $mt5Path = $dirs | Select-Object -First 1
        break
    }
}

if ($mt5Path) {
    $todayCSV = "$($mt5Path.FullName)\MQL5\Files\FinBERT_Data_EURUSD!_$(Get-Date -Format 'yyyy.MM.dd').csv"
} else {
    $todayCSV = $null
}
```

### **3. Database Status**
```powershell
# Check database health
if ($mt5Path) {
    $dbFile = "$($mt5Path.FullName)\MQL5\Files\GrandeTradingData.db"
} else {
    $dbFile = $null
}
```

### **4. FinBERT Analysis**
```powershell
# Check FinBERT integration - try multiple possible paths
$commonPaths = @(
    "$env:APPDATA\MetaQuotes\Terminal\Common\Files",
    "$env:USERPROFILE\AppData\Roaming\MetaQuotes\Terminal\Common\Files",
    "C:\Users\$env:USERNAME\AppData\Roaming\MetaQuotes\Terminal\Common\Files"
)

$commonPath = $null
foreach ($path in $commonPaths) {
    if (Test-Path $path) {
        $commonPath = $path
        break
    }
}

if ($commonPath) {
    $analysisFile = "$commonPath\integrated_calendar_analysis.json"
} else {
    $analysisFile = $null
}
```

## **Proven PowerShell Analysis Commands**

### **1. Error Analysis (Most Critical)**
```powershell
# Check for new errors since last check
if ($latestLog) {
    $errors = Get-Content $latestLog.FullName -Tail 1000 | Where-Object {$_ -match "ERROR|error|Error|WARNING|warning|Failed|failed|FAIL|Exception|exception"}
    Write-Host "Recent errors: $($errors.Count)" -ForegroundColor Cyan
    if ($errors.Count -gt 0) {
        $errors | Group-Object {($_ -split '\s+')[4]} | Sort-Object Count -Descending | Select-Object -First 3 | Format-Table Count, Name -AutoSize
        $errors | Select-Object -Last 5
    }
} else {
    Write-Host "❌ No log file found" -ForegroundColor Red
}
```

### **2. Trading Performance Analysis**
```powershell
# Analyze signal performance
if ($latestLog) {
    $signals = Get-Content $latestLog.FullName -Tail 1000 | Where-Object {$_ -match "SIGNAL.*CONFIRMED|SIGNAL.*REJECTED|RSI.*CONFIRMED|RSI.*REJECTED"}
    $confirmed = ($signals | Where-Object {$_ -match "CONFIRMED"}).Count
    $rejected = ($signals | Where-Object {$_ -match "REJECTED"}).Count
    $total = $confirmed + $rejected
    if ($total -gt 0) {
        $successRate = [math]::Round(($confirmed / $total) * 100, 1)
        Write-Host "Signal Success Rate: $successRate% ($confirmed/$total)" -ForegroundColor Cyan
    }
} else {
    Write-Host "❌ Cannot analyze signals - no log file" -ForegroundColor Red
}
```

### **3. Pullback Validation Check**
```powershell
# Verify pullback tolerance fix
if ($latestLog) {
    $pullbackLogs = Get-Content $latestLog.FullName -Tail 500 | Where-Object {$_ -match "Pullback.*VALID|Pullback.*TOO FAR|WITHIN LIMIT"}
    $valid = ($pullbackLogs | Where-Object {$_ -match "WITHIN LIMIT"}).Count
    $invalid = ($pullbackLogs | Where-Object {$_ -match "TOO FAR"}).Count
    $totalPullback = $valid + $invalid
    if ($totalPullback -gt 0) {
        $pullbackRate = [math]::Round(($valid / $totalPullback) * 100, 1)
        Write-Host "Pullback Success Rate: $pullbackRate% ($valid/$totalPullback)" -ForegroundColor Green
    }
} else {
    Write-Host "❌ Cannot check pullback validation - no log file" -ForegroundColor Red
}
```

### **4. RSI Logic Verification**
```powershell
# Check RSI validation status
if ($latestLog) {
    $rsiLogs = Get-Content $latestLog.FullName -Tail 500 | Where-Object {$_ -match "RSI.*REJECTED|RSI.*CONFIRMED|RSI Current|RSI Previous"}
    $rsiConfirmed = ($rsiLogs | Where-Object {$_ -match "RSI.*CONFIRMED"}).Count
    $rsiRejected = ($rsiLogs | Where-Object {$_ -match "RSI.*REJECTED"}).Count
    $totalRsi = $rsiConfirmed + $rsiRejected
    if ($totalRsi -gt 0) {
        $rsiRate = [math]::Round(($rsiConfirmed / $totalRsi) * 100, 1)
        Write-Host "RSI Success Rate: $rsiRate% ($rsiConfirmed/$totalRsi)" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Cannot check RSI logic - no log file" -ForegroundColor Red
}
```

### **5. Trading Activity Analysis**
```powershell
# Analyze recent trading activity
if ($latestLog) {
    Write-Host "=== TRADING ACTIVITY ANALYSIS ===" -ForegroundColor Magenta
    
    # Find all trade executions in recent logs
    $tradeExecutions = Get-Content $latestLog.FullName -Tail 1000 | Where-Object {$_ -match "FILLED.*BUY|FILLED.*SELL|\[TREND\].*FILLED|\[BREAKOUT\].*FILLED|\[TRIANGLE\].*FILLED"}
    
    if ($tradeExecutions.Count -gt 0) {
        Write-Host "Recent Trade Executions: $($tradeExecutions.Count)" -ForegroundColor Cyan
        
        # Show last 5 trades
        Write-Host "`nLast 5 trades:" -ForegroundColor Cyan
        $tradeExecutions | Select-Object -Last 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    } else {
        Write-Host "No recent trade executions found" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Cannot analyze trading activity - no log file" -ForegroundColor Red
}
```

### **6. CSV Data Analysis**
```powershell
# Check CSV data collection
if (Test-Path $todayCSV) {
    $data = Import-Csv $todayCSV
    Write-Host "Today's CSV Records: $($data.Count)" -ForegroundColor Cyan
    $data | Group-Object decision | Sort-Object Count -Descending | Format-Table Count, Name -AutoSize
    $data | Select-Object -Last 3 | Format-Table timestamp, signal_type, decision, rejection_reason -AutoSize
} else {
    Write-Host "❌ No CSV file found for today" -ForegroundColor Red
}
```

### **7. FinBERT Status Check**
```powershell
# Verify FinBERT integration
if (Test-Path $analysisFile) {
    $content = Get-Content $analysisFile | ConvertFrom-Json
    Write-Host "FinBERT Signal: $($content.signal) | Confidence: $($content.confidence)" -ForegroundColor Green
} else {
    Write-Host "❌ FinBERT analysis not available" -ForegroundColor Red
}
```

### **8. System Health Metrics**
```powershell
# Check system health
if ($latestLog) {
    Write-Host "Log Size: $([math]::Round($latestLog.Length/1MB, 2)) MB" -ForegroundColor Yellow
    Write-Host "Last Modified: $($latestLog.LastWriteTime)" -ForegroundColor Yellow
    $throttleLogs = Get-Content $latestLog.FullName -Tail 500 | Where-Object {$_ -match "THROTTLED|throttled"}
    Write-Host "Throttling Events: $($throttleLogs.Count)" -ForegroundColor Cyan
} else {
    Write-Host "❌ Cannot check system health - no log file" -ForegroundColor Red
}
```

## **Key Analysis Areas (Priority Order)**

### **🔴 CRITICAL (Check First)**
1. **Error Analysis** - Look for new errors since last check
2. **Trading Activity** - Monitor trade executions and patterns
3. **Signal Success Rate** - Monitor signal pass/fail rates
4. **RSI Logic Status** - Verify RSI validation is working
5. **Pullback Validation** - Confirm pullback fix is active

### **🟡 HIGH PRIORITY**
6. **CSV Data Collection** - Check if new records are being generated
7. **FinBERT Integration** - Verify AI analysis is working
8. **Database Health** - Check database growth and integrity

### **🟢 MEDIUM PRIORITY**
9. **System Performance** - Monitor log size and throttling
10. **Data Quality** - Check for data integrity issues

## **Expected Findings & Quick Diagnostics**

### **✅ Good Signs (System Working)**
- Pullback Success Rate >90%
- RSI Success Rate >20%
- CSV records increasing daily
- Error count <10 in recent logs
- FinBERT confidence >0.5
- Regular trading activity detected

### **❌ Warning Signs (Issues Detected)**
- RSI Success Rate = 0%
- No new CSV records for >1 hour
- Error count >20 in recent logs
- Pullback Success Rate <50%
- FinBERT confidence <0.3
- No trading activity for extended periods

### **�� Critical Issues (Immediate Action)**
- Error 4203 count >10
- Error 10019/10046 appearing
- No signal analysis for >10 minutes
- Database not growing
- FinBERT analysis missing

## **Quick Analysis Template**

```powershell
# Run this complete analysis in sequence
Write-Host "=== GRANDE SYSTEM QUICK CHECK ===" -ForegroundColor Cyan

# 1. Get file paths
$logPath = Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal\*\MQL5\Logs" -Directory | Select-Object -First 1
$latestLog = Get-ChildItem "$($logPath.FullName)\*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$mt5Path = Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal\*" -Directory | Where-Object {Test-Path "$($_.FullName)\MQL5"} | Select-Object -First 1
$todayCSV = "$($mt5Path.FullName)\MQL5\Files\FinBERT_Data_EURUSD!_$(Get-Date -Format 'yyyy.MM.dd').csv"

# 2. Run all checks
# [Insert all the analysis commands above]

# 3. Summary
Write-Host "`n=== ANALYSIS COMPLETE ===" -ForegroundColor Green
```

## **Output Format**
Provide analysis in this structure:
1. **Quick Status**: Overall system health (��/🟡/🔴)
2. **Critical Issues**: Any blocking problems found
3. **Performance Metrics**: Key success rates and counts
4. **Recent Activity**: What's happening in the last hour
5. **Recommendations**: Immediate actions needed
6. **Next Check**: When to run analysis again

## **Usage Notes**
- **Frequency**: Run every 1-2 hours during active trading
- **Focus**: Only analyze data since last check
- **Priority**: Always check errors and RSI logic first
- **Action**: Reload EA if RSI fix not active
- **Monitoring**: Watch for signal success rate improvements

This optimized prompt focuses on **incremental analysis** using **proven PowerShell commands** that have worked effectively in our testing, making it perfect for regular system monitoring and quick health checks.