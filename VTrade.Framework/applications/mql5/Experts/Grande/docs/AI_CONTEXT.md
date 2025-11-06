# Grande Trading System - AI Context

**Purpose**: Reference for AI agents working on this MQL5 trading system.
**Updated**: 2025-11-05

## System Overview

Grande is an MQL5 Expert Advisor combining technical analysis with AI sentiment (FinBERT). It trades EURUSD, GBPUSD, NZDUSD using trend, breakout, range, and triangle signals.

**Current State**: Production system with database-driven optimization pipeline.

## Architecture

```
MQL5 EA (GrandeTradingSystem.mq5)
├── Market Analysis (regime, levels, indicators)
├── Signal Generation (4 types: TREND, BREAKOUT, RANGE, TRIANGLE)
├── FinBERT Integration (economic calendar sentiment)
├── Trade Execution (risk management, position sizing)
└── Data Export (CSV, SQLite, reports)

Python FinBERT (finbert_calendar_analyzer.py)
├── Reads: economic_events.json
├── Analyzes: Economic calendar events with FinBERT
└── Outputs: integrated_calendar_analysis.json

PowerShell Analysis Scripts
├── SeedTradingDatabase.ps1 (import historical logs)
├── RunDailyAnalysis.ps1 (generate optimization recommendations)
└── GrandeBuild.ps1 (compile and deploy)
```

## File Locations

```
Grande/                                          # Workspace root
├── GrandeTradingSystem.mq5                      # Main EA
├── Grande*.mqh                                  # Component modules
├── GrandeBuild.ps1                             # Build script
├── scripts/
│   ├── SeedTradingDatabase.ps1                 # Historical data import
│   └── RunDailyAnalysis.ps1                    # Daily analysis
├── docs/
│   ├── AI_CONTEXT.md                           # This file
│   └── daily_analysis/                         # Analysis reports
├── mcp/analyze_sentiment_server/
│   └── finbert_calendar_analyzer.py            # FinBERT analyzer
└── Build/                                       # Compiled outputs

MT5 Terminal Paths (auto-detected):
%APPDATA%\MetaQuotes\Terminal\{ID}\MQL5\
├── Experts\Grande\                              # Deployed EA
├── Files\
│   ├── FinBERT_Data_*.csv                      # Daily trading logs
│   └── GrandeTradingData.db                    # SQLite database
└── Logs\                                        # MT5 logs

Common Files:
%APPDATA%\MetaQuotes\Terminal\Common\Files\
├── economic_events.json                         # Calendar data (MT5 → Python)
└── integrated_calendar_analysis.json            # FinBERT output (Python → EA)
```

## Key Components

### MQL5 Modules (.mqh files)

| File | Purpose |
|------|---------|
| GrandeMarketRegimeDetector.mqh | Classifies market: BULL_TREND, BEAR_TREND, RANGING, TRANSITION |
| GrandeKeyLevelDetector.mqh | Support/resistance detection (11-15 levels) |
| GrandeMT5CalendarReader.mqh | Exports MT5 calendar to JSON every 15 minutes |
| GrandeNewsSentimentIntegration.mqh | Loads FinBERT analysis, applies to trades |
| GrandeTrianglePatternDetector.mqh | Ascending/descending/symmetrical triangles |
| GrandeDatabaseManager.mqh | SQLite operations |
| GrandeIntelligentReporter.mqh | CSV/report generation |

### Signal Types

**TREND**: Multi-timeframe ADX + pullback validation
- Best performer historically (check daily_analysis/)
- Requires H4 ADX > 25 or local override (H1 ADX > 40)
- RSI filter: SELL if RSI > 20 and falling, BUY if RSI < 80 and rising

**BREAKOUT**: Key level breaks with volume confirmation
- Higher risk/reward (3:1 target)
- Requires strong ADX on entry

**RANGE**: Mean reversion in ranging markets
- Uses Stochastic overbought/oversold
- Lower frequency

**TRIANGLE**: Pattern breakout trades
- Currently disabled by default (low historical win rate)

### Market Regimes

System detects 5 regimes:
1. **BULL_TREND**: +DI > -DI, ADX > 25
2. **BEAR_TREND**: -DI > +DI, ADX > 25
3. **BREAKOUT_SETUP**: ADX rising, range contraction
4. **RANGING**: ADX < 20, sideways price action
5. **HIGH_VOLATILITY**: ATR spike > 150% average

Each regime gets confidence score 0.0-1.0 based on indicator alignment.

## Database Schema

**Primary Tables**:

```sql
trades
├── trade_id, ticket_number, timestamp
├── symbol, signal_type, direction
├── entry_price, stop_loss, take_profit, lot_size
├── outcome (PENDING|TP_HIT|SL_HIT|MANUAL_CLOSE)
├── profit_loss, pips_gained, duration_minutes
└── FKs: market_conditions, indicators

market_conditions (1:1 with trades)
├── regime, regime_confidence
├── atr, spread, volume_ratio
└── resistance_level, support_level

indicators (1:1 with trades)
├── rsi_current, rsi_h4, rsi_d1, rsi_direction
├── adx_h1, adx_h4, adx_d1
├── ema20_distance_pips, pullback_valid
└── finbert_multiplier

decisions (all decisions including rejected)
├── decision (EXECUTED|REJECTED|BLOCKED)
├── rejection_reason, rejection_category
└── Used for analyzing why trades are blocked

optimization_history
├── parameter_name, old_value, new_value
├── win_rate_before, win_rate_after
└── Tracks parameter changes and effectiveness
```

## Analysis Workflow

### Daily Analysis (most common task)

```powershell
# 1. Seed database from logs (first time or after gap)
.\scripts\SeedTradingDatabase.ps1

# 2. Run daily analysis
.\scripts\RunDailyAnalysis.ps1

# 3. Review report
code docs\daily_analysis\DAILY_ANALYSIS_REPORT_$(Get-Date -Format "yyyyMMdd").md
```

**Analysis Output**:
- Signal type performance (win rates)
- Regime-specific win rates
- Optimal RSI/ADX thresholds
- Stop loss hit patterns
- Rejection reason analysis
- EA parameter recommendations

**Statistical Requirements**:
- Need 20+ trades per signal type for HIGH confidence
- 10-19 trades = MEDIUM confidence
- <10 trades = LOW confidence (wait for more data)

### Key SQL Queries

```sql
-- Overall performance
SELECT signal_type, COUNT(*) trades,
       ROUND(100.0 * SUM(CASE WHEN outcome='TP_HIT' THEN 1 ELSE 0 END)/COUNT(*), 2) win_rate
FROM trades WHERE outcome IN ('TP_HIT','SL_HIT')
GROUP BY signal_type ORDER BY win_rate DESC;

-- Regime performance
SELECT mc.regime, t.signal_type, COUNT(*) trades,
       ROUND(100.0*SUM(CASE WHEN t.outcome='TP_HIT' THEN 1 ELSE 0 END)/COUNT(*),2) win_rate
FROM trades t JOIN market_conditions mc ON t.trade_id=mc.trade_id
WHERE t.outcome IN ('TP_HIT','SL_HIT')
GROUP BY mc.regime, t.signal_type HAVING COUNT(*)>=5;

-- Recent trades (since last analysis)
SELECT * FROM trades 
WHERE timestamp > (SELECT MAX(period_end) FROM performance_metrics WHERE period_type='DAILY')
ORDER BY timestamp DESC;
```

## Build System

```powershell
# Compile EA and deploy to MT5
.\GrandeBuild.ps1

# Build specific component
.\GrandeBuild.ps1 -ComponentName "GrandeTradingSystem"

# Set specific MT5 terminal (if multiple)
$env:MT5_TERMINAL_ID = "5C659F0E64BA794E712EE4C936BCFED5"
.\GrandeBuild.ps1
```

**Build Process**:
1. Auto-detects MT5 terminal directory
2. Compiles .mq5 to .ex5
3. Copies to Experts\Grande\
4. Creates Build\ folder with dependencies

## FinBERT Integration

**Status**: Calendar analysis ACTIVE, news analysis DISABLED

### Calendar Analysis (ACTIVE)
- Runs every 15 minutes
- Input: economic_events.json (exported by EA)
- Output: integrated_calendar_analysis.json
- Provides: signal, confidence, sentiment_multiplier
- EA applies multiplier to position sizes (0.5x to 1.5x)

### Integration Points
```cpp
// In EA OnTimer() - every 15 minutes
ExportCalendarToFile();  // MT5 calendar → economic_events.json
RunFinBERTAnalysis();    // Calls Python script via ShellExecuteW

// In signal processing
string finbert_signal = LoadFinBERTSignal();
double multiplier = GetSentimentMultiplier(finbert_signal, confidence);
adjusted_lot_size = base_lot_size * multiplier;
```

### File-Based Communication
- EA writes JSON → Python reads
- Python writes JSON → EA reads
- No network/Docker dependencies
- Cached results used if Python fails

## Common Tasks

### 1. Fix Compilation Errors
- Read error from MetaEditor output
- Check includes are present
- Verify function signatures match usage
- Recompile with F7

### 2. Analyze Trading Performance
- Run `.\scripts\SeedTradingDatabase.ps1`
- Run `.\scripts\RunDailyAnalysis.ps1`
- Check docs\daily_analysis\ for latest report
- Apply HIGH confidence recommendations only

### 3. Adjust EA Parameters
- Open GrandeTradingSystem.mq5
- Find `input` section at top
- Modify values based on analysis recommendations
- Document change in code comment
- Recompile and reload EA

### 4. Debug Trading Logic
- Check MT5 logs in %APPDATA%\MetaQuotes\Terminal\{ID}\MQL5\Logs\
- Search for ERROR or WARNING
- Check FinBERT_Data_*.csv for rejection reasons
- Query database for recent decisions

### 5. Update FinBERT Analysis
- Check Common\Files\integrated_calendar_analysis.json exists
- Verify timestamp is recent (<1 hour)
- If stale, check economic_events.json was created
- Test Python script: `python mcp\analyze_sentiment_server\finbert_calendar_analyzer.py`

## EA Parameters Reference

### Signal Enablement
```cpp
input bool InpEnableTrendSignals = true;
input bool InpEnableBreakoutSignals = true;
input bool InpEnableRangeSignals = true;
input bool InpEnableTriangleSignals = false;  // Disabled - low win rate
```

### Risk Management
```cpp
input double InpRiskPercentTrend = 2.0;      // % equity per TREND trade
input double InpRiskPercentBreakout = 1.5;   // % equity per BREAKOUT
input double InpRiskPercentRange = 0.8;      // % equity per RANGE
```

### Technical Thresholds
```cpp
input double InpADX_Strong_Threshold = 25.0;     // Strong trend minimum
input double InpADX_Range_Threshold = 20.0;      // Range maximum
input double InpRSI_Overbought_Trending = 80.0;  // RSI filter trending
input double InpRSI_Oversold_Trending = 20.0;
input double InpPullbackToleranceATR = 2.0;      // Max pullback distance
```

### Stop Loss / Take Profit
```cpp
input double InpATR_SL_Multiplier = 1.5;         // SL distance in ATR
input double InpATR_TP_Multiplier_Trend = 3.0;   // TP distance TREND
input double InpATR_TP_Multiplier_Breakout = 2.5;
input double InpATR_TP_Multiplier_Range = 2.0;
```

## Known Issues & Solutions

### Issue: Database not growing
**Symptom**: GrandeTradingData.db size unchanged for >2 hours
**Solution**: 
1. Check if EA is running (check MT5 Experts tab)
2. Verify database logging enabled in EA
3. Check for file permission errors in logs
4. Reload EA on chart

### Issue: High rejection rate (>40%)
**Symptom**: Most signals rejected, few trades executed
**Solution**:
1. Run daily analysis to see rejection categories
2. If PULLBACK_TOO_FAR high: increase InpPullbackToleranceATR
3. If RSI_EXTREME high: adjust RSI thresholds
4. If MARGIN_LOW: reduce risk percentages

### Issue: FinBERT analysis stale
**Symptom**: integrated_calendar_analysis.json timestamp >1 hour old
**Solution**:
1. Check economic_events.json was created
2. Test Python script manually
3. Check Python/transformers installed
4. Review EA logs for Python execution errors

### Issue: Compilation errors
**Symptom**: Build fails with "undeclared identifier"
**Solution**:
1. Check all .mqh files present in workspace
2. Verify #include statements match file names
3. Check function declarations before usage
4. Use Context7 MQL5 docs for uncertain syntax

## Optimization Process

**User Intent**: Improve EA performance using data-driven analysis

### Step 1: Collect Data
- Need minimum 20 closed trades for statistical significance
- Run EA on demo/live for 1-2 weeks
- Database auto-populates during trading

### Step 2: Analyze
```powershell
.\scripts\RunDailyAnalysis.ps1
```
Generates report with:
- Signal type win rates
- Optimal parameter values
- Rejection analysis
- Recommendations with confidence levels

### Step 3: Apply Changes
- Review HIGH confidence recommendations
- Modify EA parameters
- Document changes
- Recompile

### Step 4: Measure
- Continue trading for another 10-20 trades
- Re-run analysis
- Compare win_rate_before vs win_rate_after
- Keep change if improved, revert if worse

### Step 5: Iterate
- Make 1-2 changes per cycle
- Wait for statistical significance
- Don't change too much at once

## Path Configuration

**Auto-Detection**: Build system finds MT5 terminal automatically
**Override**: Set `$env:MT5_TERMINAL_ID` to specify terminal
**Common Paths**:
- EA code: `.\GrandeTradingSystem.mq5` (workspace)
- Deployed: `%APPDATA%\MetaQuotes\Terminal\{ID}\MQL5\Experts\Grande\`
- Database: `%APPDATA%\MetaQuotes\Terminal\{ID}\MQL5\Files\GrandeTradingData.db`
- Logs: `%APPDATA%\MetaQuotes\Terminal\{ID}\MQL5\Logs\YYYYMMDD.log`
- FinBERT: `%APPDATA%\MetaQuotes\Terminal\Common\Files\`

## Decision Framework for AI

When asked to:

**"Improve trading performance"** → Run analysis, apply HIGH confidence recommendations
**"Fix compilation error"** → Read error, check includes, verify syntax with Context7
**"Analyze recent trades"** → Query database, check logs, generate summary
**"Adjust parameters"** → Need justification from analysis data, don't guess
**"Debug FinBERT"** → Check JSON files exist/fresh, test Python script
**"Optimize [signal type]"** → Filter analysis by signal_type, recommend specific changes
**"Why are trades rejected?"** → Query decisions table, group by rejection_category
**"Build and deploy"** → Run GrandeBuild.ps1, verify compilation successful

## Critical Rules

1. **Never guess parameters** - use data from analysis
2. **Check statistical significance** - need 20+ trades for confidence
3. **One change at a time** - can't measure impact of simultaneous changes
4. **Always document changes** - add comments explaining why
5. **Use Context7 for MQL5** - don't invent syntax
6. **Verify before applying** - test compilation before recommending
7. **Database is critical** - if not growing, system isn't working

## Quick Reference Commands

```powershell
# Build
.\GrandeBuild.ps1

# Analysis
.\scripts\SeedTradingDatabase.ps1
.\scripts\RunDailyAnalysis.ps1

# Check EA status
Get-Content "$env:APPDATA\MetaQuotes\Terminal\*\MQL5\Logs\$(Get-Date -Format 'yyyyMMdd').log" -Tail 50

# Check FinBERT status
Get-Content "$env:APPDATA\MetaQuotes\Terminal\Common\Files\integrated_calendar_analysis.json" | ConvertFrom-Json

# Database query
# (Install SQLite first, use PowerShell SQLite module or DB Browser)
```

## Success Metrics

**Target Performance**:
- Overall win rate: >60%
- Profit factor: >1.5
- TP hit rate: >60%
- SL hit rate: <40%
- Rejection rate: <30%

**Monitor Weekly**:
- Total trades executed
- Win rate by signal type
- Database growth (should increase daily)
- FinBERT integration health
- Rejection pattern changes

## Additional Resources

- Daily analysis reports: `docs/daily_analysis/`
- Build logs: `Build/build_log.txt`
- MT5 logs: `%APPDATA%\MetaQuotes\Terminal\{ID}\MQL5\Logs\`
- Database: Query with DB Browser for SQLite
- Context7: Use for MQL5/MT5 documentation

---

**Remember**: This system continuously improves based on real trading data. Analysis → Recommendations → Apply → Measure → Iterate.

