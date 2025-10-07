# Grande Trading System

## Overview

Grande Trading System is an advanced MQL5 Expert Advisor with integrated AI-powered calendar analysis. The system combines technical analysis, market regime detection, key level identification, and FinBERT sentiment analysis for informed trading decisions.

## Current Status: Operational

### Core Components
- **Trading Engine**: Multi-timeframe trend following with regime detection
- **Key Level Detection**: Support/resistance identification with strength scoring
- **Market Regime Detector**: Identifies trending, ranging, and breakout conditions
- **AI Calendar Analysis**: FinBERT-powered economic event sentiment analysis
- **Risk Management**: ATR-based position sizing and stop loss management
- **Database Logging**: SQLite database for trade analysis and reporting

### Supported Currency Pairs

**Standard Pairs (5 digits)**: EUR/USD, GBP/USD, USD/CHF, USD/CAD, AUD/USD, NZD/USD

**JPY Pairs (3 digits)**: USD/JPY, EUR/JPY, GBP/JPY, AUD/JPY

**Cross Pairs**: EUR/GBP, EUR/AUD, GBP/CAD, AUD/CAD

The EA automatically adapts to different pip sizes and volatility levels using ATR-based calculations.

## Quick Start

### Installation

1. Copy all `.mqh` files to your MT5 `Include` folder
2. Copy `GrandeTradingSystem.mq5` to your MT5 `Experts` folder
3. Copy `GrandeMonitorIndicator.mq5` to your MT5 `Indicators` folder
4. Compile or use the build script: `.\GrandeBuild.ps1`

### Critical Settings

**For all currency pairs:**
```
InpTouchZone = 0  // Auto-calculate from ATR (critical!)
InpEnableTrading = true
InpLogDetailedInfo = true
```

**Risk Management:**
```
InpRiskPctTrend = 2.0  // Lower to 1.0-1.5% for volatile pairs
InpMaxPositions = 7
InpMaxDrawdownPct = 30.0
```

**ATR-Based Risk:**
```
InpSLATRMultiplier = 1.8  // Increase to 2.0-2.5 for volatile pairs
InpTPRewardRatio = 3.0
```

### Settings by Pair Type

#### Low Volatility (EUR/USD, USD/CHF)
- Risk: 2.0%
- SL ATR: 1.8
- TP R:R: 3.0
- Min Range: 15 pips

#### High Volatility (GBP/USD, GBP/JPY)
- Risk: 1.5%
- SL ATR: 2.0
- TP R:R: 2.5
- Min Range: 30 pips

#### JPY Pairs (USD/JPY, EUR/JPY)
- Risk: 2.0%
- SL ATR: 1.8
- TP R:R: 3.0
- Min Range: 25 pips
- **Must use InpTouchZone = 0**

## Features

### Universal Compatibility

The EA works across all major currency pairs through:

1. **Automatic Pip Size Detection**: Handles 2, 3, 4, and 5-digit quotes
2. **ATR-Based Calculations**: Adapts to each pair's volatility
3. **Dynamic Symbol Properties**: Queries broker-specific values
4. **Smart Position Sizing**: Calculates correct pip values for accurate risk management

### AI Calendar Integration

- Analyzes economic events using FinBERT sentiment analysis
- Provides trading signals with confidence scores
- Updates automatically every 15 minutes
- File-based integration (no Docker required)

### Market Regime Detection

- **Trend Bull/Bear**: Strong directional movement
- **Ranging**: Consolidation between support/resistance
- **Breakout Setup**: Tight consolidation before breakout
- **High Volatility**: Elevated risk conditions

### Key Level Detection

- Identifies support and resistance levels
- Scores level strength based on touches and price action
- Updates every 5 minutes
- Visualizes levels on chart

## File Structure

### Core Trading Files
- `GrandeTradingSystem.mq5` - Main EA
- `GrandeMonitorIndicator.mq5` - Chart monitor indicator
- `GrandeMarketRegimeDetector.mqh` - Regime detection
- `GrandeKeyLevelDetector.mqh` - Support/resistance detection
- `GrandeMultiTimeframeAnalyzer.mqh` - Multi-timeframe analysis
- `GrandeDatabaseManager.mqh` - SQLite database management
- `GrandeIntelligentReporter.mqh` - Reporting system

### AI Integration
- `GrandeMT5CalendarReader.mqh` - Calendar data reader
- `mcp/analyze_sentiment_server/GrandeNewsSentimentIntegration.mqh` - FinBERT integration
- `mcp/analyze_sentiment_server/finbert_calendar_analyzer.py` - Python analysis script

### Build & Configuration
- `GrandeBuild.ps1` - Automated build script
- `Set-MT5Environment.ps1` - Environment setup
- `BUILD_USAGE.md` - Build system documentation
- `PATH_CONFIGURATION.md` - Path configuration guide

## Testing Procedure

### Before Live Trading

1. **Strategy Tester** (3-6 months)
   - Verify no "Invalid stops" errors
   - Check lot sizes are reasonable
   - Confirm risk calculations

2. **Demo Account** (1-2 weeks)
   - Monitor order execution
   - Verify stop/limit placement
   - Check position sizing

3. **Live (Minimum Size)** (1 week)
   - Start with 0.01 lot
   - Watch first 5-10 trades
   - Adjust settings if needed

## Monitoring

### Daily Checks

Check these files for system health:

```
%APPDATA%\MetaQuotes\Terminal\Common\Files\
├── economic_events.json (Calendar data)
├── integrated_calendar_analysis.json (FinBERT results)
└── integrated_news_analysis.json (News sentiment)

%APPDATA%\MetaQuotes\Terminal\{ID}\MQL5\Files\
├── FinBERT_Data_EURUSD!_YYYY.MM.DD.csv (Trade log)
├── GrandeReport_EURUSD!_YYYY.MM.DD.txt (Reports)
└── GrandeTradingData.db (SQLite database)
```

### Monitoring Script

Run the included monitoring script:
```powershell
.\monitor_improvements.ps1
```

## Troubleshooting

### "Invalid Stops" Error
- Increase `InpSLATRMultiplier` to 2.0+
- Check broker's `SYMBOL_TRADE_STOPS_LEVEL`
- Verify `InpMinStopDistanceMultiplier`

### "Invalid Volume" Error
- Check broker's min/max lot sizes
- Verify sufficient margin
- Adjust risk percentages downward

### Positions Not Opening
- Enable `InpLogDetailedInfo = true`
- Check Experts tab for rejection reasons
- Verify `InpEnableTrading = true`

### Calendar Analysis Not Loading
- Check `integrated_calendar_analysis.json` exists
- Run `python finbert_calendar_analyzer.py`
- Enable calendar in MT5: Tools > Options > Server > Enable news

## Documentation

- `docs/GRANDE_EA_STATUS.md` - Detailed system status and monitoring guide
- `docs/DEBUG_LOGS_PROMPT.md` - Debugging guide
- `docs/PROFIT_LOSS_ANALYSIS_PROMPT.md` - P&L analysis guide
- `BUILD_USAGE.md` - Build system documentation
- `PATH_CONFIGURATION.md` - Path configuration

## Version History

### v1.01 (Current)
- Universal multi-currency support
- Auto-calculated touch zones from ATR
- Symbol validation on initialization
- Enhanced logging and reporting
- Fixed RSI logic for trend trading
- Fixed Risk Manager error counter
- Database logging improvements

### v1.00
- Initial release
- Core trading logic
- AI calendar integration
- Basic multi-timeframe analysis

## Support

For issues or questions:
1. Check this README first
2. Review initialization logs (Experts tab)
3. Enable detailed logging (`InpLogDetailedInfo = true`)
4. Check the docs folder for specific guides

## Requirements

- MetaTrader 5 (build 3661+)
- Python 3.8+ (for AI calendar analysis)
- Windows 10/11
- Minimum account: $1,000 recommended

## License

Copyright 2024, Grande Tech
https://www.grandetech.com.br

