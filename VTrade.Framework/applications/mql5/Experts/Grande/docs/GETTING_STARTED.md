# Grande Trading System - Data-Driven Optimization Guide

## Quick Start: From Logs to Optimized EA in 5 Steps

This system transforms your trading logs into actionable EA improvements using database-driven analysis. Follow these steps to start optimizing based on real trading data.

---

## STEP 1: Seed Database from Historical Data

Run the seeding script to import your existing trading history:

```powershell
cd C:\git\AutoTrade\VTrade.Framework\applications\mql5\Experts\Grande
.\scripts\SeedTradingDatabase.ps1
```

**What it does:**
- Parses all log files in `MQL5\Logs\` for FILLED trades
- Imports decision data from `FinBERT_Data_*.csv` files
- Matches trade executions with outcomes (TP/SL hits)
- Populates GrandeTradingData.db with historical records

**Expected output:**
```
✅ Database seeding complete!
Trades: 45 (TP: 28, SL: 17, Pending: 0)
Decisions: 156 (Rejected: 111)
Win Rate: 62.22%
```

---

## STEP 2: Run Your First Analysis

Generate a comprehensive performance report:

```powershell
.\scripts\RunDailyAnalysis.ps1
```

**What it does:**
- Analyzes last 30 days of trading data
- Identifies winning vs losing signal types
- Finds optimal RSI/ADX thresholds
- Analyzes rejection patterns
- Generates EA parameter recommendations

**Output location:** `docs\DAILY_ANALYSIS_REPORT_YYYYMMDD.md`

**Console summary:**
```
=== SUMMARY ===
Total Trades: 45
Win Rate: 62.22%
Recommendations: 3

Top Recommendations:
  [HIGH] DISABLE_SIGNAL: Triangle signals have low win rate (15%) over 20 trades
  [MEDIUM] RSI_THRESHOLD: TREND BUY performs best in RSI BEARISH zone (70% over 15 trades)
  [HIGH] REJECTION_CRITERIA: High rejection rate for PULLBACK_TOO_FAR (45%)
```

---

## STEP 3: Review Recommendations

Open the generated report and review each recommendation:

### Example Recommendation

```markdown
#### DISABLE_SIGNAL
- **Parameter**: `InpEnableTriangleSignals`
- **Current**: true
- **Recommended**: false
- **Reason**: Triangle signals have low win rate (15%) over 20 trades
- **Confidence**: HIGH
```

### Statistical Confidence Levels

| Confidence | Meaning | Action |
|------------|---------|--------|
| **HIGH** | 20+ trades, clear pattern | Apply immediately |
| **MEDIUM** | 10-19 trades, emerging pattern | Test in Strategy Tester |
| **LOW** | <10 trades | Wait for more data |

---

## STEP 4: Apply Optimizations to EA

### Manual Application (Recommended)

1. **Open EA in MetaEditor**
   ```
   File → Open → GrandeTradingSystem.mq5
   ```

2. **Locate Input Parameters** (top of file)
   ```cpp
   input bool InpEnableTriangleSignals = true;  // ← Find this line
   ```

3. **Apply Recommendation**
   ```cpp
   input bool InpEnableTriangleSignals = false; // Disabled - 15% win rate (20 trades)
   ```

4. **Document Change in Comment**
   ```cpp
   // Changed 2025-10-31: Analysis showed 15% win rate over 20 trades
   input bool InpEnableTriangleSignals = false;
   ```

5. **Recompile EA**
   - Press `F7` in MetaEditor
   - Check for errors in Toolbox
   - Confirm "0 error(s), 0 warning(s)"

6. **Reload in MT5**
   - Right-click chart → Expert Advisors → Remove
   - Drag GrandeTradingSystem.ex5 back onto chart
   - Verify new parameters in Inputs tab

### Log the Change in Database

Document the optimization for tracking:

```powershell
# Run this after applying changes
$dbPath = "$env:APPDATA\MetaQuotes\Terminal\5C659F0E64BA794E712EE4C936BCFED5\MQL5\Files\GrandeTradingData.db"
$connection = New-Object System.Data.SQLite.SQLiteConnection
$connection.ConnectionString = "Data Source=$dbPath;Version=3;"
$connection.Open()

$command = $connection.CreateCommand()
$command.CommandText = @"
INSERT INTO optimization_history (
    timestamp, parameter_name, old_value, new_value, 
    change_reason, trades_analyzed, win_rate_before, applied_by
) VALUES (
    datetime('now'), 
    'InpEnableTriangleSignals', 
    1, 
    0,
    'Analysis showed 15% win rate over 20 Triangle signal trades',
    20,
    15.0,
    'Manual'
);
"@
$command.ExecuteNonQuery()
$connection.Close()

Write-Host "✅ Optimization logged in database" -ForegroundColor Green
```

---

## STEP 5: Integrate Database Logging in EA

To enable real-time data collection for future analysis:

### Quick Integration

1. **Copy database helper class**
   ```
   Copy: docs\MQL5_DATABASE_INTEGRATION.md (section: Database Helper Class)
   Paste to: GrandeTradingSystem_Database.mqh
   ```

2. **Include in EA**
   ```cpp
   #include "GrandeTradingSystem_Database.mqh"
   CGrandeTradingDatabase g_database;
   ```

3. **Initialize in OnInit()**
   ```cpp
   int OnInit() {
       if(!g_database.Open())
           Print("WARNING: Database logging disabled");
       // ... rest of init
   }
   ```

4. **Log before OrderSend()**
   ```cpp
   // Before executing trade
   int trade_id = g_database.LogTradeDecision(
       _Symbol, signalType, direction, 
       entryPrice, sl, tp, lotSize, rr, riskPercent, 
       AccountInfoDouble(ACCOUNT_EQUITY)
   );
   
   // Execute trade
   if(OrderSend(request, result)) {
       g_database.UpdateTradeTicket(trade_id, result.order);
   }
   ```

5. **Update outcomes in OnTrade()**
   ```cpp
   void OnTrade() {
       // Detect closed positions
       // Update database with outcome (TP_HIT/SL_HIT)
       g_database.UpdateTradeOutcome(ticket, outcome, closePrice, profit, pips);
   }
   ```

**Full implementation**: See `docs/MQL5_DATABASE_INTEGRATION.md`

---

## Daily Workflow

Once everything is set up, follow this daily routine:

### Morning Routine (5 minutes)

```powershell
# Run daily analysis
cd C:\git\AutoTrade\VTrade.Framework\applications\mql5\Experts\Grande
.\scripts\RunDailyAnalysis.ps1

# Review report
code docs\DAILY_ANALYSIS_REPORT_$(Get-Date -Format "yyyyMMdd").md
```

### Weekly Optimization (15 minutes)

1. **Check statistical confidence**: Do recommendations have 20+ trades?
2. **Apply 1-2 high-priority changes**: Don't change too much at once
3. **Document in optimization_history**: Use SQL template from report
4. **Monitor next week**: Compare before/after win rates

### Monthly Review (30 minutes)

1. **Query optimization effectiveness**:
   ```sql
   SELECT parameter_name, win_rate_before, win_rate_after,
          win_rate_after - win_rate_before as improvement
   FROM optimization_history
   WHERE timestamp >= datetime('now', '-30 days')
   ORDER BY improvement DESC;
   ```

2. **Identify persistent issues**: Are certain rejections still high?
3. **Plan next optimization cycle**: Focus on lowest-performing signal types

---

## Key Documents Reference

| Document | Purpose | When to Use |
|----------|---------|-------------|
| `PROFIT_LOSS_ANALYSIS_PROMPT.md` | Complete analysis query library | Manual deep-dive analysis |
| `DATABASE_SCHEMA.md` | Database structure & queries | Understanding data relationships |
| `MQL5_DATABASE_INTEGRATION.md` | EA integration code | Adding database logging to EA |
| `DAILY_ANALYSIS_REPORT_*.md` | Generated insights | Every day after running script |
| `GETTING_STARTED.md` (this) | Quick setup guide | Initial setup and reference |

---

## Scripts Reference

| Script | Purpose | Frequency |
|--------|---------|-----------|
| `SeedTradingDatabase.ps1` | Import historical data | Once (or when adding new log files) |
| `RunDailyAnalysis.ps1` | Generate performance report | Daily |

---

## Success Metrics to Track

Monitor these KPIs weekly:

| Metric | Target | Current |
|--------|--------|---------|
| Overall Win Rate | >60% | Check report |
| TP Hit Rate | >60% | Check report |
| SL Hit Rate | <40% | Check report |
| Profit Factor | >1.5 | Check report |
| Rejection Rate | <30% | Check report |

---

## Troubleshooting

### "Database connection failed"

**Solution**:
```powershell
# Check database exists
Test-Path "$env:APPDATA\MetaQuotes\Terminal\*\MQL5\Files\GrandeTradingData.db"

# If false, run seeding script first
.\scripts\SeedTradingDatabase.ps1
```

### "No recommendations generated"

**Reason**: Not enough data (< 20 trades per signal type)

**Solution**: Continue trading. Collect at least 20 trades before expecting recommendations.

### "Analysis report shows 0 trades"

**Solution**: 
1. Verify log files exist in `MQL5\Logs\`
2. Re-run seed script: `.\scripts\SeedTradingDatabase.ps1`
3. Check that trades are FILLED (not just signals)

### "PowerShell execution policy error"

**Solution**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Advanced: Custom Queries

For specialized analysis, use PowerShell with custom SQL:

```powershell
# Connect to database
$dbPath = "$env:APPDATA\MetaQuotes\Terminal\5C659F0E64BA794E712EE4C936BCFED5\MQL5\Files\GrandeTradingData.db"
$connection = New-Object System.Data.SQLite.SQLiteConnection
$connection.ConnectionString = "Data Source=$dbPath;Version=3;"
$connection.Open()

# Run custom query
$command = $connection.CreateCommand()
$command.CommandText = @"
SELECT signal_type, 
       COUNT(*) as trades,
       ROUND(AVG(pips_gained), 2) as avg_pips
FROM trades
WHERE outcome = 'TP_HIT'
  AND timestamp >= datetime('now', '-7 days')
GROUP BY signal_type;
"@

$adapter = New-Object System.Data.SQLite.SQLiteDataAdapter $command
$dataset = New-Object System.Data.DataSet
$adapter.Fill($dataset) | Out-Null
$dataset.Tables[0] | Format-Table

$connection.Close()
```

**More queries**: See `PROFIT_LOSS_ANALYSIS_PROMPT.md` sections 1-10

---

## Next Steps

1. **Today**: Run STEP 1 & 2 (seed database + first analysis)
2. **This Week**: Review recommendations, apply 1-2 high-confidence changes
3. **Next Week**: Run daily analysis, measure improvement
4. **This Month**: Integrate database logging into EA for real-time collection

## Support

For questions or issues:
1. Check troubleshooting section above
2. Review `PROFIT_LOSS_ANALYSIS_PROMPT.md` for detailed queries
3. Verify database schema in `DATABASE_SCHEMA.md`

---

**Remember**: Data-driven optimization requires patience. Wait for statistical significance (20+ trades) before making changes. Small, incremental improvements compound over time.

**Goal**: Turn your EA into a continuously improving system based on real market performance, not guesswork.

