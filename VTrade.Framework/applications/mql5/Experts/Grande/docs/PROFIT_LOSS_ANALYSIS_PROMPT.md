# 📊 **GRANDE TRADING SYSTEM PROFIT/LOSS ANALYSIS PROMPT**

## **System Overview**
You are analyzing the Grande Trading System's profit/loss performance against decision conditions and market data to identify optimization opportunities. This prompt focuses on **incremental analysis** - only examining trades and data **since the last optimization** to track improvement effectiveness and avoid re-analyzing old data.

## **Last Analysis Tracking**
**CRITICAL**: Always check and update the last analysis timestamp to ensure incremental analysis.

### **Last Analysis Timestamp File**
```powershell
# Check when analysis was last run
$timestampFile = ".\docs\LAST_PL_ANALYSIS_TIMESTAMP.txt"
$lastAnalysisTime = if (Test-Path $timestampFile) { Get-Content $timestampFile } else { "Never" }
Write-Host "Last P/L Analysis: $lastAnalysisTime" -ForegroundColor Cyan

# Update timestamp after analysis
$currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$currentTime | Out-File $timestampFile -Encoding UTF8
```

### **Data Filtering for Incremental Analysis**
```powershell
# Filter data since last analysis
$filterTime = if ($lastAnalysisTime -ne "Never") { [datetime]$lastAnalysisTime } else { (Get-Date).AddDays(-7) }
Write-Host "Analyzing data since: $filterTime" -ForegroundColor Yellow
```

## **Analysis Objectives**
1. **Trade Outcome Correlation**: Match executed trades with their profit/loss results
2. **Decision Parameter Analysis**: Identify which conditions lead to profitable vs losing trades
3. **Signal Type Performance**: Compare performance across TREND, BREAKOUT, TRIANGLE signals
4. **Market Regime Effectiveness**: Analyze performance by market regime (trending, ranging, breakout)
5. **Parameter Optimization**: Find optimal thresholds for RSI, ADX, ATR, and other indicators
6. **Risk/Reward Analysis**: Evaluate actual vs expected risk/reward ratios

## **Critical Data Sources & File Paths**

### **1. Trade History Data (Primary)**
```powershell
# Get MT5 trade history
$mt5Path = Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal\*" -Directory | Where-Object {Test-Path "$($_.FullName)\MQL5"} | Select-Object -First 1
$historyFile = "$($mt5Path.FullName)\MQL5\Files\history.csv"

# Alternative: Get from account history
$accountHistory = "$($mt5Path.FullName)\MQL5\Files\account_history.csv"
```

### **2. Decision Log Data (CSV)**
```powershell
# Get today's decision data
$todayCSV = "$($mt5Path.FullName)\MQL5\Files\FinBERT_Data_EURUSD!_$(Get-Date -Format 'yyyy.MM.dd').csv"

# Get historical CSV files
$csvFiles = Get-ChildItem "$($mt5Path.FullName)\MQL5\Files\FinBERT_Data_*.csv" | Sort-Object LastWriteTime -Descending
```

### **3. Trade Execution Logs**
```powershell
# Get latest log file for execution details
$logPath = Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal\*\MQL5\Logs" -Directory | Select-Object -First 1
$latestLog = Get-ChildItem "$($logPath.FullName)\*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
```

### **4. Database Records**
```powershell
# Check database for additional trade data
$dbFile = "$($mt5Path.FullName)\MQL5\Files\GrandeTradingData.db"
```

## **Proven PowerShell Analysis Commands**

### **1. Extract Executed Trades from Logs (Since Last Analysis)**
```powershell
# Find all executed trades with details since last analysis
$executedTrades = Get-Content $latestLog.FullName | Where-Object {$_ -match "FILLED.*@.*SL=.*TP=.*lot=.*rr="} | ForEach-Object {
    # Extract timestamp from log line
    $logTimestamp = if ($_ -match "^(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})") { [datetime]$matches[1] } else { [datetime]::MinValue }
    
    # Only process trades since last analysis
    if ($logTimestamp -gt $filterTime) {
        if($_ -match "\[(TREND|BREAKOUT|TRIANGLE)\] (FILLED|FAILED) (BUY|SELL) @([0-9.]+) SL=([0-9.]+) TP=([0-9.]+) lot=([0-9.]+) rr=([0-9.]+)")
        {
            [PSCustomObject]@{
                SignalType = $matches[1]
                Status = $matches[2]
                Direction = $matches[3]
                EntryPrice = [double]$matches[4]
                StopLoss = [double]$matches[5]
                TakeProfit = [double]$matches[6]
                LotSize = [double]$matches[7]
                RiskReward = [double]$matches[8]
                Timestamp = $logTimestamp
                LogLine = $_
            }
        }
    }
} | Where-Object { $_ -ne $null }

Write-Host "New Executed Trades Since Last Analysis: $($executedTrades.Count)" -ForegroundColor Cyan
if ($executedTrades.Count -gt 0) {
    $executedTrades | Format-Table SignalType, Status, Direction, EntryPrice, LotSize, RiskReward, Timestamp -AutoSize
} else {
    Write-Host "No new executed trades found since last analysis" -ForegroundColor Yellow
}
```

### **2. Analyze Trade Performance by Signal Type**
```powershell
# Group trades by signal type and calculate performance
$signalPerformance = $executedTrades | Where-Object {$_.Status -eq "FILLED"} | Group-Object SignalType | ForEach-Object {
    $signalType = $_.Name
    $trades = $_.Group
    
    [PSCustomObject]@{
        SignalType = $signalType
        TotalTrades = $trades.Count
        AvgLotSize = ($trades | Measure-Object -Property LotSize -Average).Average
        AvgRiskReward = ($trades | Measure-Object -Property RiskReward -Average).Average
        AvgEntryPrice = ($trades | Measure-Object -Property EntryPrice -Average).Average
        BuyTrades = ($trades | Where-Object {$_.Direction -eq "BUY"}).Count
        SellTrades = ($trades | Where-Object {$_.Direction -eq "SELL"}).Count
    }
}

Write-Host "Signal Type Performance Summary:" -ForegroundColor Yellow
$signalPerformance | Format-Table -AutoSize
```

### **3. Extract Decision Parameters from CSV (Since Last Analysis)**
```powershell
# Analyze decision data from CSV files since last analysis
if (Test-Path $todayCSV) {
    $decisionData = Import-Csv $todayCSV
    
    # Filter executed trades only and since last analysis
    $executedDecisions = $decisionData | Where-Object {
        $_.decision -eq "EXECUTED" -and 
        $_.timestamp -ne "" -and 
        [datetime]$_.timestamp -gt $filterTime
    }
    
    Write-Host "New Executed Decisions Since Last Analysis: $($executedDecisions.Count)" -ForegroundColor Green
    
    # Analyze by regime
    $regimeAnalysis = $executedDecisions | Group-Object regime | ForEach-Object {
        [PSCustomObject]@{
            Regime = $_.Name
            Count = $_.Count
            AvgRSI_H4 = [math]::Round(($_.Group | Where-Object {$_.rsi_h4 -ne ""} | ForEach-Object {[double]$_.rsi_h4} | Measure-Object -Average).Average, 2)
            AvgADX_H4 = [math]::Round(($_.Group | Where-Object {$_.adx_h4 -ne ""} | ForEach-Object {[double]$_.adx_h4} | Measure-Object -Average).Average, 2)
            AvgATR = [math]::Round(($_.Group | Where-Object {$_.atr -ne ""} | ForEach-Object {[double]$_.atr} | Measure-Object -Average).Average, 5)
            AvgRiskPercent = [math]::Round(($_.Group | Where-Object {$_.risk_percent -ne ""} | ForEach-Object {[double]$_.risk_percent} | Measure-Object -Average).Average, 2)
        }
    }
    
    Write-Host "Regime Analysis for Executed Trades:" -ForegroundColor Yellow
    $regimeAnalysis | Format-Table -AutoSize
} else {
    Write-Host "❌ No CSV decision data found for today" -ForegroundColor Red
}
```

### **4. Correlate Trades with Market Conditions (Since Last Analysis)**
```powershell
# Find trades that hit TP vs SL from logs since last analysis
$tpHits = Get-Content $latestLog.FullName | Where-Object {
    $_ -match "TAKE PROFIT|TP HIT|TAKE PROFIT HIT" -and
    ($_ -match "^(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})") -and
    [datetime]$matches[1] -gt $filterTime
}
$slHits = Get-Content $latestLog.FullName | Where-Object {
    $_ -match "STOP LOSS|SL HIT|STOP LOSS HIT" -and
    ($_ -match "^(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})") -and
    [datetime]$matches[1] -gt $filterTime
}

$tpCount = $tpHits.Count
$slCount = $slHits.Count
$totalOutcomes = $tpCount + $slCount

if ($totalOutcomes -gt 0) {
    $tpRate = [math]::Round(($tpCount / $totalOutcomes) * 100, 1)
    $slRate = [math]::Round(($slCount / $totalOutcomes) * 100, 1)
    
    Write-Host "Trade Outcome Analysis (Since Last Analysis):" -ForegroundColor Cyan
    Write-Host "Take Profit Hits: $tpCount ($tpRate%)" -ForegroundColor Green
    Write-Host "Stop Loss Hits: $slCount ($slRate%)" -ForegroundColor Red
    Write-Host "Total Closed Trades: $totalOutcomes" -ForegroundColor Yellow
} else {
    Write-Host "No trade outcomes found since last analysis" -ForegroundColor Yellow
}
```

### **5. Analyze Rejection Reasons for Missed Opportunities (Since Last Analysis)**
```powershell
# Analyze why trades were rejected since last analysis
$rejectedTrades = Get-Content $latestLog.FullName | Where-Object {
    $_ -match "REJECTED|BLOCKED" -and
    ($_ -match "^(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})") -and
    [datetime]$matches[1] -gt $filterTime
} | ForEach-Object {
    if($_ -match "REJECTED.*reason.*: (.+)")
    {
        $_.Trim()
    }
} | Where-Object {$_ -ne ""}

$rejectionAnalysis = $rejectedTrades | Group-Object | Sort-Object Count -Descending | Select-Object -First 10

Write-Host "Top Rejection Reasons:" -ForegroundColor Red
$rejectionAnalysis | Format-Table Count, Name -AutoSize
```

### **6. RSI Performance Analysis (Since Last Analysis)**
```powershell
# Analyze RSI conditions for successful vs failed trades since last analysis
$rsiAnalysis = Get-Content $latestLog.FullName | Where-Object {
    $_ -match "RSI.*CONFIRMED|RSI.*REJECTED" -and
    ($_ -match "^(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})") -and
    [datetime]$matches[1] -gt $filterTime
} | ForEach-Object {
    if($_ -match "RSI.*(\d+\.?\d*).*(CONFIRMED|REJECTED)")
    {
        [PSCustomObject]@{
            RSIValue = [double]$matches[1]
            Decision = $matches[2]
            Timestamp = ($_ -split '\s+')[0,1] -join ' '
        }
    }
}

if ($rsiAnalysis.Count -gt 0) {
    $rsiStats = $rsiAnalysis | Group-Object Decision | ForEach-Object {
        $decision = $_.Name
        $values = $_.Group | ForEach-Object {[double]$_.RSIValue}
        $stats = $values | Measure-Object -Average -Minimum -Maximum
        
        [PSCustomObject]@{
            Decision = $decision
            Count = $_.Count
            AvgRSI = [math]::Round($stats.Average, 2)
            MinRSI = [math]::Round($stats.Minimum, 2)
            MaxRSI = [math]::Round($stats.Maximum, 2)
        }
    }
    
    Write-Host "RSI Performance Analysis:" -ForegroundColor Yellow
    $rsiStats | Format-Table -AutoSize
}
```

### **7. Pullback Tolerance Effectiveness (Since Last Analysis)**
```powershell
# Analyze pullback validation effectiveness since last analysis
$pullbackLogs = Get-Content $latestLog.FullName | Where-Object {
    $_ -match "Pullback.*VALID|Pullback.*TOO FAR|WITHIN LIMIT" -and
    ($_ -match "^(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})") -and
    [datetime]$matches[1] -gt $filterTime
}
$pullbackAnalysis = $pullbackLogs | Group-Object {($_ -split '\s+')[-1]} | Sort-Object Count -Descending

Write-Host "Pullback Validation Results:" -ForegroundColor Cyan
$pullbackAnalysis | Format-Table Count, Name -AutoSize

# Calculate pullback success rate
$validPullbacks = ($pullbackAnalysis | Where-Object {$_.Name -match "WITHIN LIMIT|VALID"}).Count
$totalPullbacks = ($pullbackAnalysis | Measure-Object Count -Sum).Sum

if ($totalPullbacks -gt 0) {
    $pullbackSuccessRate = [math]::Round(($validPullbacks / $totalPullbacks) * 100, 1)
    Write-Host "Pullback Success Rate: $pullbackSuccessRate% ($validPullbacks/$totalPullbacks)" -ForegroundColor Green
}
```

### **8. Risk/Reward Analysis**
```powershell
# Analyze actual vs expected risk/reward
$riskRewardData = $executedTrades | Where-Object {$_.Status -eq "FILLED"} | ForEach-Object {
    $expectedRR = $_.RiskReward
    $entryPrice = $_.EntryPrice
    $sl = $_.StopLoss
    $tp = $_.TakeProfit
    
    # Calculate actual risk in pips
    $riskPips = [math]::Abs($entryPrice - $sl) / 0.0001
    $rewardPips = [math]::Abs($tp - $entryPrice) / 0.0001
    $actualRR = if ($riskPips -gt 0) { $rewardPips / $riskPips } else { 0 }
    
    [PSCustomObject]@{
        SignalType = $_.SignalType
        Direction = $_.Direction
        ExpectedRR = $expectedRR
        ActualRR = [math]::Round($actualRR, 2)
        RiskPips = [math]::Round($riskPips, 1)
        RewardPips = [math]::Round($rewardPips, 1)
        EntryPrice = $entryPrice
    }
}

Write-Host "Risk/Reward Analysis:" -ForegroundColor Yellow
$riskRewardData | Sort-Object ActualRR -Descending | Format-Table -AutoSize
```

## **Key Analysis Areas (Priority Order)**

### **🔴 CRITICAL (Analyze First)**
1. **Trade Execution vs Outcomes** - Match executed trades with their final results
2. **Signal Type Performance** - Compare TREND vs BREAKOUT vs TRIANGLE success rates
3. **Risk/Reward Effectiveness** - Analyze actual vs expected risk/reward ratios
4. **RSI Threshold Optimization** - Find optimal RSI levels for different regimes

### **🟡 HIGH PRIORITY**
5. **Market Regime Performance** - Analyze success rates by regime type
6. **Pullback Tolerance Tuning** - Optimize pullback validation parameters
7. **ADX Threshold Analysis** - Find optimal ADX levels for signal confirmation
8. **ATR-Based Stop Loss Effectiveness** - Analyze ATR multiplier performance

### **🟢 MEDIUM PRIORITY**
9. **Time-of-Day Performance** - Analyze performance by trading session
10. **Volume Ratio Impact** - Correlate volume conditions with trade success
11. **Calendar Event Influence** - Analyze FinBERT sentiment impact on trades
12. **Position Sizing Optimization** - Analyze lot size vs performance correlation

## **Expected Findings & Optimization Opportunities**

### **✅ Good Performance Indicators**
- TP Hit Rate >60%
- Risk/Reward ratio consistently >1.5
- RSI Success Rate >25%
- Pullback Success Rate >85%
- Signal type balance (not over-reliant on one type)

### **❌ Performance Issues to Address**
- TP Hit Rate <40%
- High SL Hit Rate (>60%)
- RSI Success Rate <15%
- Pullback Success Rate <70%
- Risk/Reward consistently <1.0

### **🔧 Optimization Opportunities**
- Adjust RSI thresholds by regime (currently 70/30 for trending, 65/35 for ranging)
- Optimize pullback tolerance (currently 30% of ATR)
- Fine-tune ADX thresholds (currently 25 for confirmation)
- Adjust ATR multipliers for SL/TP (currently 1.5/2.0)
- Optimize risk percentage per trade (currently 2%)

## **Quick Analysis Template**

```powershell
# Run complete profit/loss analysis
Write-Host "=== GRANDE PROFIT/LOSS ANALYSIS (INCREMENTAL) ===" -ForegroundColor Cyan

# 1. Initialize timestamp tracking
$timestampFile = ".\docs\LAST_PL_ANALYSIS_TIMESTAMP.txt"
$lastAnalysisTime = if (Test-Path $timestampFile) { Get-Content $timestampFile } else { "Never" }
Write-Host "Last P/L Analysis: $lastAnalysisTime" -ForegroundColor Cyan

# 2. Set up incremental filtering
$filterTime = if ($lastAnalysisTime -ne "Never") { [datetime]$lastAnalysisTime } else { (Get-Date).AddDays(-7) }
Write-Host "Analyzing data since: $filterTime" -ForegroundColor Yellow

# 3. Get file paths
$logPath = Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal\*\MQL5\Logs" -Directory | Select-Object -First 1
$latestLog = Get-ChildItem "$($logPath.FullName)\*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$mt5Path = Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal\*" -Directory | Where-Object {Test-Path "$($_.FullName)\MQL5"} | Select-Object -First 1
$todayCSV = "$($mt5Path.FullName)\MQL5\Files\FinBERT_Data_EURUSD!_$(Get-Date -Format 'yyyy.MM.dd').csv"

# 4. Run all incremental analysis commands above
# [Insert all the analysis commands with timestamp filtering]

# 5. Update analysis timestamp
$currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$currentTime | Out-File $timestampFile -Encoding UTF8
Write-Host "Analysis timestamp updated: $currentTime" -ForegroundColor Green

# 6. Generate optimization recommendations based on new data only
Write-Host "`n=== OPTIMIZATION RECOMMENDATIONS (Based on New Data) ===" -ForegroundColor Green
```

## **Output Format**
Provide analysis in this structure:
1. **Performance Summary**: Overall trade success metrics
2. **Signal Type Analysis**: Performance breakdown by signal type
3. **Parameter Optimization**: Specific threshold adjustments needed
4. **Risk Management**: Risk/reward analysis and recommendations
5. **Market Regime Insights**: Performance by market conditions
6. **Action Items**: Specific code changes to implement

## **Usage Notes**
- **Frequency**: Run daily after trading session
- **Focus**: **INCREMENTAL ANALYSIS ONLY** - Only analyze data since last optimization
- **Priority**: Always check trade outcomes first, then update timestamp
- **Action**: Implement parameter adjustments based on findings, then update timestamp
- **Monitoring**: Track improvements after each optimization by comparing new vs old data
- **Timestamp Management**: Always update timestamp after analysis to avoid re-analyzing same data
- **Optimization Tracking**: Compare performance metrics before/after each optimization

## **Incremental Analysis Benefits**
- **Avoids Duplicate Work**: Never re-analyzes data already processed
- **Tracks Optimization Effectiveness**: Shows if recent changes improved performance
- **Efficient Resource Usage**: Focuses only on new trading data
- **Clear Progress Tracking**: Timestamp shows when last analysis was performed
- **Optimization Validation**: Can determine if parameter changes are working

This analysis prompt enables systematic performance tuning by correlating trade outcomes with the decision parameters that generated them, providing data-driven insights for EA optimization while maintaining efficient incremental analysis.
