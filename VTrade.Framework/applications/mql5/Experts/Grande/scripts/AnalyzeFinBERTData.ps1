# Grande Trading System - FinBERT Data Flow Analyzer
# Purpose: View recent FinBERT input/output pairs to understand data flow
#
# This script displays what data is sent to FinBERT and what responses are received,
# helping you understand the integration and debug any issues.

param(
    [Parameter(Mandatory=$false)]
    [int]$Count = 5,
    [Parameter(Mandatory=$false)]
    [string]$CommonFilesPath = "$env:APPDATA\MetaQuotes\Terminal\Common\Files"
)

$ErrorActionPreference = "Stop"

Write-Host "=== FINBERT DATA FLOW ANALYZER ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
Write-Host "Common Files: $CommonFilesPath" -ForegroundColor Yellow
Write-Host ""

if (-not (Test-Path $CommonFilesPath)) {
    Write-Host "ERROR: Common Files directory not found: $CommonFilesPath" -ForegroundColor Red
    exit 1
}

# Find market context input files
$inputFiles = Get-ChildItem "$CommonFilesPath\market_context_*.json" -ErrorAction SilentlyContinue | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First $Count

# Find FinBERT output files
$outputFiles = @()
$enhancedOutput = Get-Item "$CommonFilesPath\enhanced_finbert_analysis.json" -ErrorAction SilentlyContinue
$integratedOutput = Get-Item "$CommonFilesPath\integrated_calendar_analysis.json" -ErrorAction SilentlyContinue

if ($enhancedOutput) { $outputFiles += $enhancedOutput }
if ($integratedOutput) { $outputFiles += $integratedOutput }

Write-Host "=== FINBERT FILES FOUND ===" -ForegroundColor Cyan
Write-Host "Input Files: $($inputFiles.Count)" -ForegroundColor White
Write-Host "Output Files: $($outputFiles.Count)" -ForegroundColor White
Write-Host ""

if ($inputFiles.Count -eq 0) {
    Write-Host "WARNING: No market context input files found" -ForegroundColor Yellow
    Write-Host "Expected pattern: market_context_*.json" -ForegroundColor Gray
    Write-Host ""
}

if ($outputFiles.Count -eq 0) {
    Write-Host "WARNING: No FinBERT output files found" -ForegroundColor Yellow
    Write-Host "Expected files: enhanced_finbert_analysis.json or integrated_calendar_analysis.json" -ForegroundColor Gray
    Write-Host ""
}

# Display FinBERT Outputs First (Most Recent Analysis)
Write-Host "=== FINBERT OUTPUT (LATEST ANALYSIS) ===" -ForegroundColor Cyan

foreach ($outputFile in $outputFiles) {
    Write-Host "`n--- $($outputFile.Name) ---" -ForegroundColor Green
    Write-Host "Last Modified: $($outputFile.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    
    try {
        $output = Get-Content $outputFile.FullName -Raw | ConvertFrom-Json
        
        # Display key output metrics
        Write-Host "`nFINBERT RESPONSE:" -ForegroundColor Yellow
        
        if ($output.signal) {
            Write-Host "  Signal:         " -NoNewline -ForegroundColor White
            $signalColor = switch ($output.signal) {
                "STRONG_BUY" { "Green" }
                "BUY" { "Green" }
                "STRONG_SELL" { "Red" }
                "SELL" { "Red" }
                default { "Yellow" }
            }
            Write-Host "$($output.signal)" -ForegroundColor $signalColor
        }
        
        if ($null -ne $output.confidence) {
            Write-Host "  Confidence:     $([math]::Round($output.confidence * 100, 1))%" -ForegroundColor White
        }
        
        if ($null -ne $output.score) {
            Write-Host "  Sentiment Score: $([math]::Round($output.score, 3))" -ForegroundColor White
        }
        
        if ($output.reasoning) {
            Write-Host "`n  Reasoning:" -ForegroundColor White
            Write-Host "    $($output.reasoning)" -ForegroundColor Gray
        }
        
        if ($output.confluence_score) {
            Write-Host "`n  Confluence Score: $([math]::Round($output.confluence_score, 2))" -ForegroundColor White
        }
        
        if ($output.processing_time_ms) {
            Write-Host "  Processing Time: $([math]::Round($output.processing_time_ms, 0))ms" -ForegroundColor Gray
        }
        
        # Show risk assessment if available
        if ($output.risk_assessment) {
            Write-Host "`n  RISK ASSESSMENT:" -ForegroundColor Yellow
            if ($output.risk_assessment.risk_level) {
                Write-Host "    Level: $($output.risk_assessment.risk_level)" -ForegroundColor White
            }
            if ($output.risk_assessment.position_size_recommendation) {
                Write-Host "    Position Size: $($output.risk_assessment.position_size_recommendation)" -ForegroundColor White
            }
            if ($output.risk_assessment.warnings) {
                Write-Host "    Warnings: $($output.risk_assessment.warnings -join ', ')" -ForegroundColor Yellow
            }
        }
        
        # Show component scores if available
        if ($output.component_scores) {
            Write-Host "`n  COMPONENT SCORES:" -ForegroundColor Yellow
            $output.component_scores.PSObject.Properties | ForEach-Object {
                Write-Host "    $($_.Name): $([math]::Round($_.Value, 2))" -ForegroundColor White
            }
        }
        
    } catch {
        Write-Host "  ERROR: Failed to parse JSON - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Display Recent Market Context Inputs
Write-Host "`n`n=== FINBERT INPUTS (MARKET CONTEXT) ===" -ForegroundColor Cyan

$inputIndex = 1
foreach ($inputFile in $inputFiles) {
    Write-Host "`n--- [$inputIndex/$($inputFiles.Count)] $($inputFile.Name) ---" -ForegroundColor Green
    Write-Host "Last Modified: $($inputFile.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    Write-Host "Age: $([math]::Round(((Get-Date) - $inputFile.LastWriteTime).TotalMinutes, 1)) minutes ago" -ForegroundColor Gray
    
    try {
        $input = Get-Content $inputFile.FullName -Raw | ConvertFrom-Json
        
        # Display key input metrics
        Write-Host "`nMARKET DATA SENT TO FINBERT:" -ForegroundColor Yellow
        
        if ($input.symbol) {
            Write-Host "  Symbol:         $($input.symbol)" -ForegroundColor White
        }
        
        if ($input.timestamp) {
            Write-Host "  Timestamp:      $($input.timestamp)" -ForegroundColor White
        }
        
        if ($input.timeframe) {
            Write-Host "  Timeframe:      $($input.timeframe)" -ForegroundColor White
        }
        
        # Price data
        if ($input.market_data -and $input.market_data.price) {
            Write-Host "`n  PRICE:" -ForegroundColor Yellow
            Write-Host "    Current:      $($input.market_data.price.current)" -ForegroundColor White
            if ($input.market_data.price.change_pips) {
                $pipColor = if ($input.market_data.price.change_pips -gt 0) { "Green" } else { "Red" }
                Write-Host "    Change:       $($input.market_data.price.change_pips) pips" -ForegroundColor $pipColor
            }
        }
        
        # Volume
        if ($input.market_data -and $input.market_data.volume) {
            Write-Host "`n  VOLUME:" -ForegroundColor Yellow
            Write-Host "    Current:      $($input.market_data.volume.current)" -ForegroundColor White
            if ($input.market_data.volume.ratio) {
                Write-Host "    Ratio (vs avg): $([math]::Round($input.market_data.volume.ratio, 2))x" -ForegroundColor White
            }
        }
        
        # Technical indicators
        if ($input.technical_indicators) {
            Write-Host "`n  TECHNICAL INDICATORS:" -ForegroundColor Yellow
            $tech = $input.technical_indicators
            
            # Trend
            if ($tech.trend_direction) {
                $trendColor = switch ($tech.trend_direction) {
                    "BULLISH" { "Green" }
                    "BEARISH" { "Red" }
                    default { "Yellow" }
                }
                Write-Host "    Trend:        " -NoNewline -ForegroundColor White
                Write-Host "$($tech.trend_direction)" -NoNewline -ForegroundColor $trendColor
                if ($tech.trend_strength) {
                    Write-Host " (Strength: $([math]::Round($tech.trend_strength, 2)))" -ForegroundColor Gray
                } else {
                    Write-Host ""
                }
            }
            
            # RSI / Momentum
            if ($tech.rsi_current) {
                Write-Host "    RSI Current:  $([math]::Round($tech.rsi_current, 1))" -ForegroundColor White
                if ($tech.rsi_h4) {
                    Write-Host "    RSI H4:       $([math]::Round($tech.rsi_h4, 1))" -ForegroundColor White
                }
                if ($tech.rsi_status) {
                    Write-Host "    RSI Status:   $($tech.rsi_status)" -ForegroundColor White
                }
            }
            
            # Volatility
            if ($tech.atr_current) {
                Write-Host "    ATR Current:  $($tech.atr_current)" -ForegroundColor White
                if ($tech.volatility_level) {
                    Write-Host "    Volatility:   $($tech.volatility_level)" -ForegroundColor White
                }
            }
            
            # Stochastic
            if ($tech.stoch_k) {
                Write-Host "    Stochastic K: $([math]::Round($tech.stoch_k, 1))" -ForegroundColor White
                if ($tech.stoch_signal) {
                    Write-Host "    Stoch Signal: $($tech.stoch_signal)" -ForegroundColor White
                }
            }
        }
        
        # Market regime
        if ($input.market_regime) {
            Write-Host "`n  MARKET REGIME:" -ForegroundColor Yellow
            Write-Host "    Current:      $($input.market_regime.current_regime)" -ForegroundColor White
            if ($input.market_regime.confidence) {
                Write-Host "    Confidence:   $([math]::Round($input.market_regime.confidence * 100, 1))%" -ForegroundColor White
            }
            if ($input.market_regime.adx_h1) {
                Write-Host "    ADX H1:       $([math]::Round($input.market_regime.adx_h1, 1))" -ForegroundColor White
            }
            if ($input.market_regime.adx_h4) {
                Write-Host "    ADX H4:       $([math]::Round($input.market_regime.adx_h4, 1))" -ForegroundColor White
            }
        }
        
        # Key levels
        if ($input.key_levels) {
            Write-Host "`n  KEY LEVELS:" -ForegroundColor Yellow
            if ($input.key_levels.support_levels -and $input.key_levels.support_levels.Count -gt 0) {
                Write-Host "    Supports:     $($input.key_levels.support_levels.Count) levels" -ForegroundColor White
            }
            if ($input.key_levels.resistance_levels -and $input.key_levels.resistance_levels.Count -gt 0) {
                Write-Host "    Resistances:  $($input.key_levels.resistance_levels.Count) levels" -ForegroundColor White
            }
        }
        
        # Economic calendar
        if ($input.economic_calendar) {
            Write-Host "`n  ECONOMIC CALENDAR:" -ForegroundColor Yellow
            if ($null -ne $input.economic_calendar.events_today) {
                Write-Host "    Events Today: $($input.economic_calendar.events_today)" -ForegroundColor White
            }
            if ($null -ne $input.economic_calendar.high_impact_events) {
                Write-Host "    High Impact:  $($input.economic_calendar.high_impact_events)" -ForegroundColor White
            }
        }
        
    } catch {
        Write-Host "  ERROR: Failed to parse JSON - $($_.Exception.Message)" -ForegroundColor Red
    }
    
    $inputIndex++
}

# Check File Watcher Service Status
Write-Host "`n`n=== FILE WATCHER SERVICE STATUS ===" -ForegroundColor Cyan

$watcherProcess = Get-Process -Name python -ErrorAction SilentlyContinue | Where-Object {
    try {
        $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)" -ErrorAction SilentlyContinue).CommandLine
        $cmdLine -like "*finbert_watcher_service.py*"
    } catch {
        $false
    }
}

if ($watcherProcess) {
    Write-Host "Status:           " -NoNewline -ForegroundColor White
    Write-Host "RUNNING" -NoNewline -ForegroundColor Green
    Write-Host " (PID: $($watcherProcess.Id))" -ForegroundColor Gray
    
    $logPath = Join-Path $PSScriptRoot "..\mcp\analyze_sentiment_server\finbert_watcher.log"
    if (Test-Path $logPath) {
        $logAge = ((Get-Date) - (Get-Item $logPath).LastWriteTime).TotalMinutes
        Write-Host "Log file:         Updated $([math]::Round($logAge, 1)) minutes ago" -ForegroundColor White
        Write-Host "Log location:     $logPath" -ForegroundColor Gray
    }
} else {
    Write-Host "Status:           " -NoNewline -ForegroundColor White
    Write-Host "NOT RUNNING" -ForegroundColor Red
    Write-Host ""
    Write-Host "ACTION REQUIRED:" -ForegroundColor Yellow
    Write-Host "  The FinBERT File Watcher Service is NOT running." -ForegroundColor White
    Write-Host "  This service automatically processes new market context files." -ForegroundColor White
    Write-Host ""
    Write-Host "To start the service:" -ForegroundColor Yellow
    Write-Host "  1. Navigate to: mcp\analyze_sentiment_server\" -ForegroundColor White
    Write-Host "  2. Double-click: start_finbert_watcher.bat" -ForegroundColor White
    Write-Host "  3. Keep the service window open while trading" -ForegroundColor White
    Write-Host ""
    Write-Host "For help: mcp\analyze_sentiment_server\README_FILE_WATCHER.md" -ForegroundColor Gray
}

# Summary
Write-Host "`n`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Analyzed $($inputFiles.Count) input file(s) and $($outputFiles.Count) output file(s)" -ForegroundColor White

if ($inputFiles.Count -gt 0 -and $outputFiles.Count -gt 0) {
    $latestInput = $inputFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $latestOutput = $outputFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $timeDiff = ($latestInput.LastWriteTime - $latestOutput.LastWriteTime).TotalMinutes
    
    if ($timeDiff -lt 60) {
        Write-Host "`nData flow appears to be working correctly." -ForegroundColor Green
        Write-Host "Use this script to verify what FinBERT receives and what it responds with." -ForegroundColor Gray
    } else {
        Write-Host "`nWARNING: Output is $([math]::Round($timeDiff, 1)) minutes older than newest input." -ForegroundColor Yellow
        Write-Host "FinBERT may not be processing new files." -ForegroundColor Yellow
        
        if (-not $watcherProcess) {
            Write-Host "`nLIKELY CAUSE: File Watcher Service is not running" -ForegroundColor Red
            Write-Host "SOLUTION: Start the service (see instructions above)" -ForegroundColor Yellow
        }
    }
} elseif ($inputFiles.Count -gt 0) {
    Write-Host "`nWARNING: Inputs found but no outputs detected." -ForegroundColor Yellow
    Write-Host "FinBERT has never run successfully." -ForegroundColor Gray
    
    if (-not $watcherProcess) {
        Write-Host "`nLIKELY CAUSE: File Watcher Service is not running" -ForegroundColor Red
        Write-Host "SOLUTION: Start the service (see instructions above)" -ForegroundColor Yellow
    } else {
        Write-Host "`nPossible cause: Service is running but encountering errors" -ForegroundColor Yellow
        $logPath = Join-Path $PSScriptRoot "..\mcp\analyze_sentiment_server\finbert_watcher.log"
        Write-Host "Check log: $logPath" -ForegroundColor Gray
    }
} elseif ($outputFiles.Count -gt 0) {
    Write-Host "`nWARNING: Outputs found but no recent inputs detected." -ForegroundColor Yellow
    Write-Host "Market context may not be collecting properly." -ForegroundColor Gray
} else {
    Write-Host "`nERROR: No FinBERT data found." -ForegroundColor Red
    Write-Host "Check if EA is running and FinBERT is enabled." -ForegroundColor Gray
}

Write-Host ""

