# Grande Trading System - FinBERT Quality Assessment
# Purpose: Verify FinBERT is functioning correctly and not using keyword fallback
#
# This script checks:
# 1. If FinBERT AI model is actually loaded (vs keyword fallback)
# 2. If confidence scores are well-calibrated (high confidence = better outcomes)
# 3. Quality and relevance of reasoning text
# 4. Consistency of signals over time

param(
    [Parameter(Mandatory=$false)]
    [string]$DatabasePath = "$env:APPDATA\MetaQuotes\Terminal\5C659F0E64BA794E712EE4C936BCFED5\MQL5\Files\Data\GrandeTradingData.db",
    [Parameter(Mandatory=$false)]
    [string]$CommonFilesPath = "$env:APPDATA\MetaQuotes\Terminal\Common\Files",
    [Parameter(Mandatory=$false)]
    [int]$DaysToAnalyze = 30
)

$ErrorActionPreference = "Stop"
$reportDate = Get-Date -Format "yyyyMMdd"
$scriptRoot = Split-Path -Parent $PSCommandPath
$workspaceRoot = Split-Path -Parent $scriptRoot
$reportPath = Join-Path $workspaceRoot "docs\FINBERT_QUALITY_REPORT_$reportDate.md"

Write-Host "=== FINBERT QUALITY ASSESSMENT ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
Write-Host "Report: $reportPath" -ForegroundColor Yellow
Write-Host ""

# Initialize report
$report = @"
# FinBERT Quality Assessment Report

**Generated**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Analysis Period**: Last $DaysToAnalyze days

This report assesses whether FinBERT is functioning correctly by checking for keyword fallback, confidence calibration, and reasoning quality.

---

"@

$qualityIssues = 0
$qualityScore = 100

# 1. Check FinBERT Output Files
Write-Host "Checking FinBERT output files..." -ForegroundColor Cyan

$enhancedOutput = Get-Item "$CommonFilesPath\enhanced_finbert_analysis.json" -ErrorAction SilentlyContinue
$integratedOutput = Get-Item "$CommonFilesPath\integrated_calendar_analysis.json" -ErrorAction SilentlyContinue

$report += @"
## 1. FinBERT Output Files

"@

$outputFileFound = $false

if ($enhancedOutput) {
    $outputFileFound = $true
    $ageMinutes = [math]::Round(((Get-Date) - $enhancedOutput.LastWriteTime).TotalMinutes, 1)
    $report += "- **enhanced_finbert_analysis.json**: Found`n"
    $report += "  - Last Modified: $($enhancedOutput.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))`n"
    $report += "  - Age: $ageMinutes minutes`n"
    
    Write-Host "  [OK] enhanced_finbert_analysis.json found (age: $ageMinutes min)" -ForegroundColor Green
    
    if ($ageMinutes -gt 60) {
        $qualityIssues++
        $qualityScore -= 10
        $report += "  - **WARNING**: File is stale (>60 minutes old)`n"
        Write-Host "  [WARN] File is stale" -ForegroundColor Yellow
    }
}

if ($integratedOutput) {
    $outputFileFound = $true
    $ageMinutes = [math]::Round(((Get-Date) - $integratedOutput.LastWriteTime).TotalMinutes, 1)
    $report += "- **integrated_calendar_analysis.json**: Found`n"
    $report += "  - Last Modified: $($integratedOutput.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))`n"
    $report += "  - Age: $ageMinutes minutes`n"
    
    Write-Host "  [OK] integrated_calendar_analysis.json found (age: $ageMinutes min)" -ForegroundColor Green
    
    if ($ageMinutes -gt 60) {
        $qualityIssues++
        $qualityScore -= 10
        $report += "  - **WARNING**: File is stale (>60 minutes old)`n"
        Write-Host "  [WARN] File is stale" -ForegroundColor Yellow
    }
}

if (-not $outputFileFound) {
    $qualityIssues++
    $qualityScore -= 30
    $report += "- **ERROR**: No FinBERT output files found`n"
    $report += "  - Expected: enhanced_finbert_analysis.json or integrated_calendar_analysis.json`n"
    $report += "  - Location: $CommonFilesPath`n"
    Write-Host "  [ERROR] No output files found" -ForegroundColor Red
}

$report += "`n"

# 2. Detect Keyword Fallback vs Real AI
Write-Host "`nDetecting AI model vs keyword fallback..." -ForegroundColor Cyan

$report += @"
## 2. AI Model Detection

"@

$usingRealAI = $false
$fallbackDetected = $false

# Check the most recent output file
$latestOutput = $null
if ($enhancedOutput -and $integratedOutput) {
    $latestOutput = if ($enhancedOutput.LastWriteTime -gt $integratedOutput.LastWriteTime) { $enhancedOutput } else { $integratedOutput }
} elseif ($enhancedOutput) {
    $latestOutput = $enhancedOutput
} elseif ($integratedOutput) {
    $latestOutput = $integratedOutput
}

if ($latestOutput) {
    try {
        $outputData = Get-Content $latestOutput.FullName -Raw | ConvertFrom-Json
        
        # Check reasoning for fallback indicators
        if ($outputData.reasoning) {
            $reasoning = $outputData.reasoning.ToLower()
            
            if ($reasoning -match "fallback|keyword|not real ai|not available") {
                $fallbackDetected = $true
                $qualityIssues++
                $qualityScore -= 40
                $report += "**Status**: KEYWORD FALLBACK DETECTED`n`n"
                $report += "The FinBERT analysis is using keyword-based fallback instead of the real AI model.`n`n"
                $report += "**Evidence**: Reasoning text contains fallback indicators: `"$($outputData.reasoning)`"`n`n"
                $report += "**Impact**: Analysis quality is significantly reduced. Keyword matching cannot understand market context.`n`n"
                $report += "**Resolution**:`n"
                $report += "1. Install FinBERT dependencies: ``python -m pip install torch transformers```n"
                $report += "2. Verify Python environment is accessible from MQL5`n"
                $report += "3. Check Python script logs for model loading errors`n`n"
                
                Write-Host "  [ERROR] Keyword fallback detected" -ForegroundColor Red
            } elseif ($reasoning -match "real finbert ai|✅.*finbert") {
                $usingRealAI = $true
                $report += "**Status**: REAL AI MODEL CONFIRMED`n`n"
                $report += "FinBERT is successfully using the actual AI model for analysis.`n`n"
                $report += "**Evidence**: Reasoning confirms real FinBERT: `"$($outputData.reasoning)`"`n`n"
                
                Write-Host "  [OK] Real AI model confirmed" -ForegroundColor Green
            } else {
                $report += "**Status**: UNCLEAR - Cannot determine AI vs fallback from reasoning text`n`n"
                $report += "**Reasoning**: `"$($outputData.reasoning)`"`n`n"
                
                Write-Host "  [WARN] Cannot confirm AI model status" -ForegroundColor Yellow
            }
        } else {
            $report += "**Status**: No reasoning text found in output`n`n"
            Write-Host "  [WARN] No reasoning text available" -ForegroundColor Yellow
        }
        
        # Check processing time (fallback is typically faster)
        if ($outputData.processing_time_ms) {
            $procTime = $outputData.processing_time_ms
            $report += "**Processing Time**: $([math]::Round($procTime, 0))ms`n`n"
            
            if ($procTime -lt 10) {
                $report += "**Note**: Very fast processing time (<10ms) may indicate keyword fallback or cached results.`n`n"
                Write-Host "  [INFO] Processing time: $([math]::Round($procTime, 0))ms (very fast)" -ForegroundColor Yellow
            } else {
                Write-Host "  [INFO] Processing time: $([math]::Round($procTime, 0))ms" -ForegroundColor White
            }
        }
        
    } catch {
        $report += "**ERROR**: Failed to parse output file: $($_.Exception.Message)`n`n"
        Write-Host "  [ERROR] Failed to parse output" -ForegroundColor Red
    }
} else {
    $report += "**ERROR**: No output files available for analysis`n`n"
}

# 3. Confidence Calibration Analysis (requires database)
Write-Host "`nAnalyzing confidence calibration..." -ForegroundColor Cyan

$report += @"
## 3. Confidence Calibration

This checks if FinBERT confidence scores are well-calibrated (high confidence should mean better outcomes).

"@

if (Test-Path $DatabasePath) {
    try {
        Import-Module PSSQLite -ErrorAction Stop
        
        # Check if high confidence signals perform better than low confidence
        $calibrationQuery = @"
SELECT 
    CASE 
        WHEN d.calendar_confidence >= 0.7 THEN 'HIGH'
        WHEN d.calendar_confidence >= 0.4 THEN 'MEDIUM'
        ELSE 'LOW'
    END as confidence_bucket,
    COUNT(*) as trades,
    SUM(CASE WHEN t.outcome IN ('TP_HIT','SL_HIT') THEN 1 ELSE 0 END) as closed,
    ROUND(100.0 * SUM(CASE WHEN t.pips_gained > 0 THEN 1 ELSE 0 END) / NULLIF(SUM(CASE WHEN t.outcome IN ('TP_HIT','SL_HIT') THEN 1 ELSE 0 END), 0), 2) as win_rate,
    ROUND(AVG(d.calendar_confidence), 3) as avg_confidence
FROM trades t
INNER JOIN decisions d ON t.timestamp = d.timestamp AND t.symbol = d.symbol
WHERE t.timestamp >= datetime('now', '-$DaysToAnalyze days')
    AND d.calendar_signal IS NOT NULL
    AND d.calendar_signal != ''
    AND d.decision = 'EXECUTED'
GROUP BY confidence_bucket
ORDER BY avg_confidence DESC;
"@

        $calibrationResults = Invoke-SqliteQuery -DataSource $DatabasePath -Query $calibrationQuery
        
        if ($calibrationResults -and $calibrationResults.Count -gt 0) {
            $report += "| Confidence | Trades | Closed | Win Rate | Avg Confidence |`n"
            $report += "|------------|--------|--------|----------|----------------|`n"
            
            $highConfWinRate = 0
            $lowConfWinRate = 0
            $calibrationGood = $false
            
            foreach ($cal in $calibrationResults) {
                $winRateDisplay = if ($cal.closed -gt 0) { "$($cal.win_rate)%" } else { "N/A" }
                $report += "| $($cal.confidence_bucket) | $($cal.trades) | $($cal.closed) | $winRateDisplay | $($cal.avg_confidence) |`n"
                
                if ($cal.confidence_bucket -eq 'HIGH' -and $cal.closed -ge 5) {
                    $highConfWinRate = $cal.win_rate
                }
                if ($cal.confidence_bucket -eq 'LOW' -and $cal.closed -ge 5) {
                    $lowConfWinRate = $cal.win_rate
                }
                
                Write-Host "  $($cal.confidence_bucket): Win Rate = $winRateDisplay ($($cal.closed) closed)" -ForegroundColor White
            }
            
            $report += "`n"
            
            # Check if high confidence outperforms low confidence
            if ($highConfWinRate -gt 0 -and $lowConfWinRate -gt 0) {
                $confDiff = $highConfWinRate - $lowConfWinRate
                
                if ($confDiff -gt 10) {
                    $calibrationGood = $true
                    $report += "**Assessment**: WELL CALIBRATED ✓`n`n"
                    $report += "High confidence signals outperform low confidence by +$([math]::Round($confDiff, 1))%.`n"
                    $report += "This indicates FinBERT confidence scores are meaningful and reliable.`n`n"
                    
                    Write-Host "  [OK] Confidence is well-calibrated (+$([math]::Round($confDiff, 1))%)" -ForegroundColor Green
                } elseif ($confDiff -gt 0) {
                    $report += "**Assessment**: MODERATELY CALIBRATED`n`n"
                    $report += "High confidence signals perform slightly better (+$([math]::Round($confDiff, 1))%).`n"
                    $report += "Calibration exists but could be stronger.`n`n"
                    
                    Write-Host "  [WARN] Moderate calibration (+$([math]::Round($confDiff, 1))%)" -ForegroundColor Yellow
                } else {
                    $qualityIssues++
                    $qualityScore -= 20
                    $report += "**Assessment**: POORLY CALIBRATED ✗`n`n"
                    $report += "High confidence signals do NOT outperform low confidence ($([math]::Round($confDiff, 1))%).`n"
                    $report += "This suggests confidence scores may not be meaningful.`n`n"
                    
                    Write-Host "  [ERROR] Poor calibration ($([math]::Round($confDiff, 1))%)" -ForegroundColor Red
                }
            } else {
                $report += "**Assessment**: INSUFFICIENT DATA`n`n"
                $report += "Need at least 5 closed trades in both HIGH and LOW confidence buckets.`n`n"
                
                Write-Host "  [INFO] Insufficient data for calibration analysis" -ForegroundColor Yellow
            }
        } else {
            $report += "No trades with FinBERT data found in database.`n`n"
            Write-Host "  [WARN] No data in database" -ForegroundColor Yellow
        }
        
    } catch {
        $report += "**ERROR**: Database analysis failed: $($_.Exception.Message)`n`n"
        Write-Host "  [ERROR] Database query failed" -ForegroundColor Red
    }
} else {
    $report += "**ERROR**: Database not found at $DatabasePath`n`n"
    $report += "Run .\scripts\SeedTradingDatabase.ps1 to create database.`n`n"
    Write-Host "  [ERROR] Database not found" -ForegroundColor Red
}

# 4. Reasoning Quality Check
Write-Host "`nAssessing reasoning quality..." -ForegroundColor Cyan

$report += @"
## 4. Reasoning Quality

"@

if ($latestOutput) {
    try {
        $outputData = Get-Content $latestOutput.FullName -Raw | ConvertFrom-Json
        
        if ($outputData.reasoning) {
            $reasoning = $outputData.reasoning
            $reasoningLength = $reasoning.Length
            
            $report += "**Latest Reasoning**:`n"
            $report += "```n$reasoning`n````n`n"
            $report += "**Length**: $reasoningLength characters`n`n"
            
            # Quality indicators
            $qualityIndicators = @()
            $lowQualityIndicators = @()
            
            # Good indicators
            if ($reasoning -match "technical|trend|momentum|volatility|support|resistance") {
                $qualityIndicators += "References technical analysis"
            }
            if ($reasoning -match "confidence|probability|likelihood") {
                $qualityIndicators += "Discusses confidence levels"
            }
            if ($reasoning -match "buy|sell|bullish|bearish") {
                $qualityIndicators += "Clear directional bias"
            }
            if ($reasoningLength -gt 50) {
                $qualityIndicators += "Adequate detail provided"
            }
            
            # Bad indicators
            if ($reasoning -match "keyword|simple matching|basic analysis") {
                $lowQualityIndicators += "Keyword-based analysis mentioned"
            }
            if ($reasoningLength -lt 20) {
                $lowQualityIndicators += "Very short reasoning (<20 chars)"
            }
            if ($reasoning -match "neutral" -and $reasoningLength -lt 30) {
                $lowQualityIndicators += "Generic neutral response"
            }
            
            if ($qualityIndicators.Count -gt 0) {
                $report += "**Quality Indicators** (✓):`n"
                foreach ($indicator in $qualityIndicators) {
                    $report += "- $indicator`n"
                }
                $report += "`n"
            }
            
            if ($lowQualityIndicators.Count -gt 0) {
                $qualityIssues += $lowQualityIndicators.Count
                $qualityScore -= ($lowQualityIndicators.Count * 5)
                $report += "**Quality Concerns** (⚠):`n"
                foreach ($indicator in $lowQualityIndicators) {
                    $report += "- $indicator`n"
                }
                $report += "`n"
            }
            
            Write-Host "  Quality indicators: $($qualityIndicators.Count)" -ForegroundColor White
            Write-Host "  Quality concerns: $($lowQualityIndicators.Count)" -ForegroundColor $(if ($lowQualityIndicators.Count -gt 0) { "Yellow" } else { "White" })
            
        } else {
            $qualityIssues++
            $qualityScore -= 15
            $report += "**WARNING**: No reasoning text provided in output`n`n"
            Write-Host "  [WARN] No reasoning text" -ForegroundColor Yellow
        }
        
    } catch {
        $report += "**ERROR**: Failed to analyze reasoning: $($_.Exception.Message)`n`n"
        Write-Host "  [ERROR] Failed to analyze reasoning" -ForegroundColor Red
    }
}

# 5. Signal Consistency Check
Write-Host "`nChecking signal consistency..." -ForegroundColor Cyan

$report += @"
## 5. Signal Consistency

Analyzing if FinBERT signals are consistent and not random.

"@

if (Test-Path $DatabasePath) {
    try {
        # Check signal distribution
        $signalDistQuery = @"
SELECT 
    calendar_signal,
    COUNT(*) as count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM decisions WHERE calendar_signal IS NOT NULL AND calendar_signal != '' AND timestamp >= datetime('now', '-$DaysToAnalyze days')), 2) as percentage
FROM decisions
WHERE calendar_signal IS NOT NULL 
    AND calendar_signal != ''
    AND timestamp >= datetime('now', '-$DaysToAnalyze days')
GROUP BY calendar_signal
ORDER BY count DESC;
"@

        $signalDist = Invoke-SqliteQuery -DataSource $DatabasePath -Query $signalDistQuery
        
        if ($signalDist -and $signalDist.Count -gt 0) {
            $report += "| Signal | Count | Percentage |`n"
            $report += "|--------|-------|------------|`n"
            
            $neutralPercentage = 0
            $hasStrongBias = $false
            
            foreach ($sig in $signalDist) {
                $report += "| $($sig.calendar_signal) | $($sig.count) | $($sig.percentage)% |`n"
                
                if ($sig.calendar_signal -eq 'NEUTRAL') {
                    $neutralPercentage = $sig.percentage
                }
                
                if ($sig.percentage -gt 70) {
                    $hasStrongBias = $true
                }
            }
            
            $report += "`n"
            
            # Assess distribution
            if ($neutralPercentage -gt 80) {
                $qualityIssues++
                $qualityScore -= 15
                $report += "**Concern**: Excessive neutral signals ($neutralPercentage%).`n"
                $report += "FinBERT may not be providing useful directional insights.`n`n"
                Write-Host "  [WARN] Too many neutral signals ($neutralPercentage%)" -ForegroundColor Yellow
            } elseif ($hasStrongBias) {
                $qualityIssues++
                $qualityScore -= 10
                $report += "**Concern**: Strong bias toward one signal type (>70%).`n"
                $report += "Check if FinBERT is properly analyzing varied market conditions.`n`n"
                Write-Host "  [WARN] Strong signal bias detected" -ForegroundColor Yellow
            } else {
                $report += "**Assessment**: Signal distribution appears reasonable.`n`n"
                Write-Host "  [OK] Signal distribution is reasonable" -ForegroundColor Green
            }
            
        } else {
            $report += "No signal data available in database.`n`n"
            Write-Host "  [WARN] No signal data" -ForegroundColor Yellow
        }
        
    } catch {
        $report += "**ERROR**: Signal consistency check failed: $($_.Exception.Message)`n`n"
        Write-Host "  [ERROR] Consistency check failed" -ForegroundColor Red
    }
}

# 6. Overall Quality Score
Write-Host "`nCalculating quality score..." -ForegroundColor Cyan

$qualityScore = [math]::Max(0, $qualityScore)

$report += @"

---

## Overall Quality Score

"@

$scoreColor = if ($qualityScore -ge 80) { "Green" } elseif ($qualityScore -ge 60) { "Yellow" } else { "Red" }
$scoreEmoji = if ($qualityScore -ge 80) { "✓" } elseif ($qualityScore -ge 60) { "⚠" } else { "✗" }

$report += "**Score**: $qualityScore/100 $scoreEmoji`n`n"

if ($qualityScore -ge 80) {
    $report += "**Assessment**: FinBERT is functioning correctly with high quality.`n`n"
    $report += "The AI model is loaded, confidence is calibrated, and reasoning is relevant.`n`n"
} elseif ($qualityScore -ge 60) {
    $report += "**Assessment**: FinBERT is functional but has quality concerns.`n`n"
    $report += "Review the issues identified above and consider improvements.`n`n"
} else {
    $report += "**Assessment**: FinBERT has significant quality issues.`n`n"
    $report += "Immediate action required - AI model may not be loaded or configured correctly.`n`n"
}

$report += "**Issues Found**: $qualityIssues`n`n"

# Recommendations
$report += @"
## Recommendations

"@

if ($fallbackDetected) {
    $report += @"
### CRITICAL: Install FinBERT AI Model

FinBERT is using keyword fallback. Install dependencies:

``````bash
python -m pip install torch transformers
``````

Then verify model loads correctly by checking Python logs.

"@
}

if ($qualityScore -lt 60) {
    $report += @"
### Actions Required

1. Verify Python environment and FinBERT dependencies
2. Check Python script logs for errors
3. Ensure EA parameter InpEnableCalendarAI is set to true
4. Review market_context_*.json files for data quality
5. Re-run this assessment after fixes

"@
}

$report += @"

---

**Last Updated**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@

# Save report
$report | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "`n=== ASSESSMENT COMPLETE ===" -ForegroundColor Cyan
Write-Host "Report saved: $reportPath" -ForegroundColor Green
Write-Host "`nQuality Score: $qualityScore/100" -ForegroundColor $scoreColor
Write-Host "Issues Found: $qualityIssues" -ForegroundColor $(if ($qualityIssues -gt 0) { "Yellow" } else { "Green" })

if ($fallbackDetected) {
    Write-Host "`n*** CRITICAL: Keyword fallback detected - Install FinBERT dependencies ***" -ForegroundColor Red
}

Write-Host ""

