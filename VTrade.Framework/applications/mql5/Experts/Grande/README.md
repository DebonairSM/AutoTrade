# Grande Trading System

Multi-timeframe trend-following Expert Advisor for MT5 with AI-powered sentiment analysis.

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
   - Configure settings (see Settings section)
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

**Generate performance report:**
```powershell
cd scripts
.\RunDailyAnalysis.ps1
```

## Settings

**Critical:** Always set `InpTouchZone = 0` to use ATR-based calculation.

### Recommended Settings by Pair Type

**Standard Pairs (EURUSD, GBPUSD, USDCHF, USDCAD, AUDUSD, NZDUSD):**
- `InpRiskPercent`: 1.5 - 2.0
- `InpSLATRMultiplier`: 1.8 - 2.0
- `InpRewardRatio`: 2.5 - 3.0
- `InpTouchZone`: 0

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

See `SETTINGS_TEMPLATES_BY_PAIR.txt` for detailed templates.

## File Locations

**Source Code:**
- `GrandeTradingSystem.mq5` - Main EA
- `Include\*.mqh` - Components

**MT5 Common Files:** `%APPDATA%\MetaQuotes\Terminal\Common\Files\`
- `economic_events.json` - Calendar data
- `integrated_calendar_analysis.json` - FinBERT analysis

**MT5 Terminal Files:** `%APPDATA%\MetaQuotes\Terminal\{ID}\MQL5\Files\`
- `FinBERT_Data_*.csv` - Trade logs
- `GrandeTradingData.db` - Trade database

**Reports:**
- `docs\daily_analysis\` - Performance reports

**Refactoring Documentation:**
- `docs\refactoring\SUMMARY.md` - Executive summary of refactoring
- `docs\refactoring\GUIDE.md` - Practical usage guide for new architecture
- `docs\refactoring\PROGRESS.md` - Detailed technical progress report
- `docs\refactoring\ARCHITECTURE.md` - Architecture, validation, and build status
- `docs\refactoring\plans\` - Future enhancement plans

## Troubleshooting

**FinBERT service not running:**
```powershell
cd mcp\analyze_sentiment_server
.\start_finbert_watcher.bat
```
Check `finbert_watcher.log` for errors.

**Compilation errors:**
```powershell
.\scripts\GrandeBuild.ps1
```

**Invalid stops error:**
- Increase `InpSLATRMultiplier` to 2.0+
- Check broker's minimum stop distance

**No trades opening:**
- Verify FinBERT service is running
- Check AutoTrading is enabled
- Review Journal tab for rejection reasons

## Supported Currency Pairs

**Major:** EURUSD, GBPUSD, USDCHF, USDCAD, AUDUSD, NZDUSD  
**JPY:** USDJPY, EURJPY, GBPJPY, AUDJPY  
**Cross:** EURGBP, EURAUD, GBPCAD, AUDCAD

All pairs use automatic pip size and volatility adjustment via ATR.
