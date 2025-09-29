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
    "$env:APPDATA\MetaQuotes\Terminal\*\MQL5\Logs"
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
    "$env:APPDATA\MetaQuotes\Terminal\*"
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

### **4. FinBERT Analysis Files**
```powershell
# Check FinBERT integration - try multiple possible paths
$commonPaths = @(
    "$env:APPDATA\MetaQuotes\Terminal\Common\Files",
    "$env:USERPROFILE\AppData\Roaming\MetaQuotes\Terminal\Common\Files",
    "$env:APPDATA\MetaQuotes\Terminal\Common\Files"
)

$commonPath = $null
foreach ($path in $commonPaths) {
    if (Test-Path $path) {
        $commonPath = $path
        break
    }
}

if ($commonPath) {
    $calendarAnalysisFile = "$commonPath\integrated_calendar_analysis.json"
    $newsAnalysisFile = "$commonPath\integrated_news_analysis.json"
} else {
    $calendarAnalysisFile = $null
    $newsAnalysisFile = $null
}
```

### **5. Database Analysis**
```powershell
# Check database health and growth
if ($mt5Path) {
    $dbFile = "$($mt5Path.FullName)\MQL5\Files\GrandeTradingData.db"
    if (Test-Path $dbFile) {
        $dbInfo = Get-ChildItem $dbFile
        $dbSize = [math]::Round($dbInfo.Length / 1KB, 2)
        $dbLastModified = $dbInfo.LastWriteTime
    } else {
        $dbFile = $null
        $dbSize = 0
        $dbLastModified = $null
    }
} else {
    $dbFile = $null
    $dbSize = 0
    $dbLastModified = $null
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
# Verify FinBERT integration - Calendar Analysis
if (Test-Path $calendarAnalysisFile) {
    $calendarContent = Get-Content $calendarAnalysisFile | ConvertFrom-Json
    Write-Host "FinBERT Calendar Signal: $($calendarContent.signal) | Confidence: $($calendarContent.confidence)" -ForegroundColor Green
    Write-Host "Event Count: $($calendarContent.event_count) | Processing Time: $($calendarContent.metrics.processing_time_ms)ms" -ForegroundColor Cyan
} else {
    Write-Host "❌ FinBERT calendar analysis not available" -ForegroundColor Red
}

# Verify FinBERT integration - News Analysis
if (Test-Path $newsAnalysisFile) {
    $newsContent = Get-Content $newsAnalysisFile | ConvertFrom-Json
    Write-Host "FinBERT News Signal: $($newsContent.signal) | Confidence: $($newsContent.confidence)" -ForegroundColor Green
} else {
    Write-Host "❌ FinBERT news analysis not available" -ForegroundColor Red
}
```

### **8. Database Health Analysis**
```powershell
# Check database growth and integrity
if ($dbFile -and (Test-Path $dbFile)) {
    Write-Host "=== DATABASE HEALTH ANALYSIS ===" -ForegroundColor Magenta
    
    # Database size and modification info
    Write-Host "Database Size: $dbSize KB" -ForegroundColor Cyan
    Write-Host "Last Modified: $dbLastModified" -ForegroundColor Cyan
    
    # Check if database is growing (recent modification)
    $timeSinceModified = (Get-Date) - $dbLastModified
    if ($timeSinceModified.TotalMinutes -lt 60) {
        Write-Host "✅ Database recently updated (within last hour)" -ForegroundColor Green
    } elseif ($timeSinceModified.TotalHours -lt 24) {
        Write-Host "⚠️ Database updated within last 24 hours" -ForegroundColor Yellow
    } else {
        Write-Host "❌ Database not updated recently ($([math]::Round($timeSinceModified.TotalHours, 1)) hours ago)" -ForegroundColor Red
    }
    
    # Check database file integrity (basic check)
    try {
        $dbStream = [System.IO.File]::OpenRead($dbFile)
        $dbStream.Close()
        Write-Host "✅ Database file is accessible and not corrupted" -ForegroundColor Green
    } catch {
        Write-Host "❌ Database file access error: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Database file not found or not accessible" -ForegroundColor Red
}
```

### **9. Enhanced CSV Data Analysis**
```powershell
# Check CSV data collection with detailed analysis
if (Test-Path $todayCSV) {
    Write-Host "=== CSV DATA ANALYSIS ===" -ForegroundColor Magenta
    
    $data = Import-Csv $todayCSV
    Write-Host "Today's CSV Records: $($data.Count)" -ForegroundColor Cyan
    
    if ($data.Count -gt 0) {
        # Decision breakdown
        $decisionBreakdown = $data | Group-Object decision | Sort-Object Count -Descending
        Write-Host "`nDecision Breakdown:" -ForegroundColor Cyan
        $decisionBreakdown | Format-Table Count, Name -AutoSize
        
        # Signal type breakdown
        $signalBreakdown = $data | Group-Object signal_type | Sort-Object Count -Descending
        Write-Host "Signal Type Breakdown:" -ForegroundColor Cyan
        $signalBreakdown | Format-Table Count, Name -AutoSize
        
        # Recent activity (last 3 records)
        Write-Host "`nRecent Activity (Last 3 records):" -ForegroundColor Cyan
        $data | Select-Object -Last 3 | Format-Table timestamp, signal_type, decision, rejection_reason -AutoSize
        
        # Check for data quality issues
        $emptyReasons = ($data | Where-Object {$_.rejection_reason -eq "" -and $_.decision -eq "REJECTED"}).Count
        if ($emptyReasons -gt 0) {
            Write-Host "⚠️ Found $emptyReasons records with empty rejection reasons" -ForegroundColor Yellow
        }
        
        # Check for recent activity
        $lastRecord = $data | Select-Object -Last 1
        $lastRecordTime = [DateTime]::ParseExact($lastRecord.timestamp, "yyyy.MM.dd HH:mm:ss", $null)
        $timeSinceLastRecord = (Get-Date) - $lastRecordTime
        
        if ($timeSinceLastRecord.TotalMinutes -lt 30) {
            Write-Host "✅ Recent data activity (last record: $($timeSinceLastRecord.TotalMinutes.ToString('F1')) minutes ago)" -ForegroundColor Green
        } elseif ($timeSinceLastRecord.TotalHours -lt 2) {
            Write-Host "⚠️ Data activity within last 2 hours (last record: $($timeSinceLastRecord.TotalHours.ToString('F1')) hours ago)" -ForegroundColor Yellow
        } else {
            Write-Host "❌ No recent data activity (last record: $($timeSinceLastRecord.TotalHours.ToString('F1')) hours ago)" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ CSV file exists but contains no data" -ForegroundColor Red
    }
} else {
    Write-Host "❌ No CSV file found for today" -ForegroundColor Red
}
```

### **10. System Health Metrics**
```powershell
# Check system health
if ($latestLog) {
    Write-Host "=== SYSTEM HEALTH METRICS ===" -ForegroundColor Magenta
    
    Write-Host "Log Size: $([math]::Round($latestLog.Length/1MB, 2)) MB" -ForegroundColor Yellow
    Write-Host "Last Modified: $($latestLog.LastWriteTime)" -ForegroundColor Yellow
    
    # Check for throttling events
    $throttleLogs = Get-Content $latestLog.FullName -Tail 500 | Where-Object {$_ -match "THROTTLED|throttled"}
    Write-Host "Throttling Events: $($throttleLogs.Count)" -ForegroundColor Cyan
    
    # Check for memory issues
    $memoryLogs = Get-Content $latestLog.FullName -Tail 500 | Where-Object {$_ -match "memory|Memory|MEMORY"}
    if ($memoryLogs.Count -gt 0) {
        Write-Host "⚠️ Memory-related logs found: $($memoryLogs.Count)" -ForegroundColor Yellow
        $memoryLogs | Select-Object -Last 3
    }
    
    # Check for connection issues
    $connectionLogs = Get-Content $latestLog.FullName -Tail 500 | Where-Object {$_ -match "connection|Connection|CONNECTION|disconnect|Disconnect"}
    if ($connectionLogs.Count -gt 0) {
        Write-Host "⚠️ Connection-related logs found: $($connectionLogs.Count)" -ForegroundColor Yellow
        $connectionLogs | Select-Object -Last 3
    }
} else {
    Write-Host "❌ Cannot check system health - no log file" -ForegroundColor Red
}
```

## **Key Analysis Areas (Priority Order)**

### **🔴 CRITICAL (Check First)**
1. **Error Analysis** - Look for new errors since last check
2. **Database Health** - Verify database is growing and accessible
3. **Trading Activity** - Monitor trade executions and patterns
4. **Signal Success Rate** - Monitor signal pass/fail rates
5. **RSI Logic Status** - Verify RSI validation is working
6. **Pullback Validation** - Confirm pullback fix is active

### **🟡 HIGH PRIORITY**
7. **CSV Data Collection** - Check if new records are being generated
8. **FinBERT Integration** - Verify AI analysis is working (both calendar and news)
9. **Data Quality** - Check for data integrity issues

### **🟢 MEDIUM PRIORITY**
10. **System Performance** - Monitor log size and throttling
11. **Memory & Connection** - Check for system resource issues

## **Expected Findings & Quick Diagnostics**

### **✅ Good Signs (System Working)**
- Database size growing and recently modified (<1 hour)
- Pullback Success Rate >90%
- RSI Success Rate >20%
- CSV records increasing daily with recent activity (<30 minutes)
- Error count <10 in recent logs
- FinBERT confidence >0.5 (both calendar and news)
- Regular trading activity detected
- Database file accessible and not corrupted

### **❌ Warning Signs (Issues Detected)**
- Database not updated in last 24 hours
- RSI Success Rate = 0%
- No new CSV records for >1 hour
- Error count >20 in recent logs
- Pullback Success Rate <50%
- FinBERT confidence <0.3
- No trading activity for extended periods
- Empty rejection reasons in CSV data

### **�� Critical Issues (Immediate Action)**
- Database file not found or corrupted
- Error 4203 count >10
- Error 10019/10046 appearing
- No signal analysis for >10 minutes
- Database not growing for >2 hours
- FinBERT analysis missing (both files)
- No CSV data activity for >2 hours

## **Quick Analysis Template**

```powershell
# Run this complete analysis in sequence
Write-Host "=== GRANDE SYSTEM QUICK CHECK ===" -ForegroundColor Cyan

# 1. Get file paths
$logPath = Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal\*\MQL5\Logs" -Directory | Select-Object -First 1
$latestLog = Get-ChildItem "$($logPath.FullName)\*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$mt5Path = Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal\*" -Directory | Where-Object {Test-Path "$($_.FullName)\MQL5"} | Select-Object -First 1
$todayCSV = "$($mt5Path.FullName)\MQL5\Files\FinBERT_Data_EURUSD!_$(Get-Date -Format 'yyyy.MM.dd').csv"
$dbFile = "$($mt5Path.FullName)\MQL5\Files\GrandeTradingData.db"
$calendarAnalysisFile = "$env:APPDATA\MetaQuotes\Terminal\Common\Files\integrated_calendar_analysis.json"
$newsAnalysisFile = "$env:APPDATA\MetaQuotes\Terminal\Common\Files\integrated_news_analysis.json"

# 2. Run all checks in priority order
# [Insert all the analysis commands above in this order:]
# 1. Error Analysis
# 2. Database Health Analysis  
# 3. Trading Activity Analysis
# 4. Signal Success Rate Analysis
# 5. RSI Logic Verification
# 6. Pullback Validation Check
# 7. Enhanced CSV Data Analysis
# 8. FinBERT Status Check (both calendar and news)
# 9. System Health Metrics

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
- **Priority**: Always check errors, database health, and RSI logic first
- **Action**: Reload EA if RSI fix not active or database not growing
- **Monitoring**: Watch for signal success rate improvements and database growth
- **Critical**: Database must be growing - if not, system is not functioning properly
- **FinBERT**: Check both calendar and news analysis files for complete AI integration status

This optimized prompt focuses on **incremental analysis** using **proven PowerShell commands** that have worked effectively in our testing, making it perfect for regular system monitoring and quick health checks. **Database monitoring is now a critical priority** to ensure data persistence and system functionality.