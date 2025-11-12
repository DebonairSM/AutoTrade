# Grande Trading System

Multi-timeframe trend-following Expert Advisor for MT5 with AI-powered sentiment analysis and automated trade management.

## Quick Start

### First Time Setup

1. **Install FinBERT service:**
   ```powershell
   cd mcp\analyze_sentiment_server
   .\install_finbert.bat
   ```

2. **Start the sentiment analysis service:**
   ```powershell
   .\start_finbert_watcher.bat
   ```

3. **Build and deploy the EA:**
   ```powershell
   cd scripts
   .\GrandeBuild.ps1
   ```

4. **Attach EA to chart in MT5:**
   - Open any supported currency pair
   - Drag GrandeTradingSystem from Navigator to chart
   - Configure settings (see EA Settings section)
   - Enable AutoTrading

### Daily Operations

**Start trading session:**
```powershell
cd mcp\analyze_sentiment_server
.\start_finbert_watcher.bat
```

**Stop trading session:**
```powershell
cd mcp\analyze_sentiment_server
.\stop_finbert_watcher.bat
```

**Check FinBERT status:**
- View `finbert_watcher.log` for recent activity
- Verify `integrated_calendar_analysis.json` in `%APPDATA%\MetaQuotes\Terminal\Common\Files\`
- Timestamps should update every 15 minutes

**Generate performance report:**
```powershell
cd scripts
.\RunDailyAnalysis.ps1
```
View report in `docs\daily_analysis\DAILY_ANALYSIS_REPORT_YYYYMMDD.md`

## EA Settings

### Recommended Settings by Pair Type

**Standard Pairs (EURUSD, GBPUSD, USDCHF, USDCAD, AUDUSD, NZDUSD):**
- `InpRiskPercent`: 1.5 - 2.0
- `InpSLATRMultiplier`: 1.8 - 2.0
- `InpRewardRatio`: 2.5 - 3.0
- `InpTouchZone`: 0 (auto-calculate from ATR)

**JPY Pairs (USDJPY, EURJPY, GBPJPY, AUDJPY):**
- `InpRiskPercent`: 2.0
- `InpSLATRMultiplier`: 1.8
- `InpRewardRatio`: 2.5 - 3.0
- `InpTouchZone`: 0 (required)

**Cross Pairs (EURGBP, EURAUD, GBPCAD, AUDCAD):**
- `InpRiskPercent`: 1.5 - 2.0
- `InpSLATRMultiplier`: 2.0
- `InpRewardRatio`: 2.5 - 3.0
- `InpTouchZone`: 0

### Critical Setting Notes

- Always set `InpTouchZone = 0` to use ATR-based calculation
- EA adapts automatically to different pip sizes and volatility
- Adjust risk based on your account size and risk tolerance
- Higher ATR multipliers reduce false stops but lower win rate

## System Components

### Trading Logic
- Multi-timeframe trend analysis (H1, H4, D1)
- Market regime detection (trending vs ranging)
- Key support/resistance level identification
- Triangle pattern detection and breakout trading
- ATR-based dynamic position sizing and stop loss

### AI Sentiment Integration
- FinBERT analyzes economic calendar events
- Updates every 15 minutes
- Provides sentiment scores and trading signals
- No Docker required, runs as Windows service

### Data Management
- SQLite database stores all trade history
- Automated daily reporting
- Performance analytics and optimization
- Sentiment correlation tracking

## Analysis Tools

**Performance Analysis:**
```powershell
cd scripts
.\RunDailyAnalysis.ps1
```
Generates comprehensive report with win rates, profit analysis, and parameter recommendations.

**FinBERT Impact Analysis:**
```powershell
.\AnalyzeFinBERTImpact.ps1
```
Correlates sentiment scores with trade outcomes.

**FinBERT Quality Check:**
```powershell
.\AssessFinBERTQuality.ps1
```
Validates sentiment data accuracy and coverage.

**Reset Database (testing only):**
```powershell
.\SeedTradingDatabase.ps1
```

## Development

### Making Changes to EA

1. **Edit source files:**
   - Main EA: `GrandeTradingSystem.mq5`
   - Components: `Include\Grande*.mqh`

2. **Build and deploy:**
   ```powershell
   cd scripts
   .\GrandeBuild.ps1
   ```

3. **Verify in MT5:**
   - Check Navigator panel for compilation errors
   - Restart EA on active charts
   - Monitor Experts tab for runtime errors

### File Locations

**Source Code:**
- `GrandeTradingSystem.mq5` - Main EA
- `Include\*.mqh` - All components and libraries
- `mcp\analyze_sentiment_server\` - FinBERT service

**MT5 Common Files:** `%APPDATA%\MetaQuotes\Terminal\Common\Files\`
- `economic_events.json` - Raw calendar data
- `integrated_calendar_analysis.json` - FinBERT analysis

**MT5 Terminal Files:** `%APPDATA%\MetaQuotes\Terminal\{ID}\MQL5\Files\`
- `FinBERT_Data_*.csv` - Trade logs with sentiment
- `GrandeReport_*.txt` - Daily reports
- `GrandeTradingData.db` - Trade database

**Reports:**
- `docs\daily_analysis\` - Performance reports
- `Data\GrandeTradingData.db` - Source database

## Troubleshooting

### FinBERT Service Issues

**Service not running:**
```powershell
cd mcp\analyze_sentiment_server
.\start_finbert_watcher.bat
```

**Check logs:**
- View `finbert_watcher.log` for errors
- Verify Python installation
- Check network connectivity for calendar data

**Files not updating:**
- Confirm service is running
- Check file timestamps in Common Files folder
- Restart service if stale

### EA Issues

**Compilation errors:**
- Run `.\scripts\GrandeBuild.ps1` to see specific errors
- Verify Include files are in MT5 Include directory
- Check for syntax errors in modified files

**Invalid stops error:**
- Increase `InpSLATRMultiplier` to 2.0+
- Check broker's minimum stop distance requirements
- Verify ATR is providing sufficient values

**No trades opening:**
- Check if FinBERT service is running
- Verify AutoTrading is enabled in MT5
- Review recent market conditions (may not meet criteria)
- Check Journal tab for rejection reasons

**Database errors:**
- Verify `GrandeTradingData.db` exists in Data folder
- Check file permissions
- Run `.\scripts\SeedTradingDatabase.ps1` to reset

### Performance Issues

**Review daily analysis report:**
- Check win rates by signal type
- Identify underperforming conditions
- Review recommended parameter adjustments
- Implement changes with confidence levels

**Adjust settings:**
- Start with recommended values
- Test changes in Strategy Tester first
- Make one change at a time
- Monitor results for 20+ trades before evaluating

## Supported Currency Pairs

**Major Pairs:** EURUSD, GBPUSD, USDCHF, USDCAD, AUDUSD, NZDUSD

**JPY Pairs:** USDJPY, EURJPY, GBPJPY, AUDJPY

**Cross Pairs:** EURGBP, EURAUD, GBPCAD, AUDCAD

All pairs use automatic pip size and volatility adjustment via ATR calculations.

## Additional Documentation

- `docs\AI_CONTEXT.md` - System architecture and component details
- `docs\daily_analysis\README.md` - Analysis report documentation
- `mcp\analyze_sentiment_server\README_FILE_WATCHER.md` - FinBERT service details
- `SETTINGS_TEMPLATES_BY_PAIR.txt` - Detailed settings for each pair

