# Grande Build Script Usage Guide

## Overview
The GrandeBuild.ps1 script now supports building and deploying both Expert Advisors and Indicators to MetaTrader 5.

## Usage Examples

### Build All Components (Default)
```powershell
.\GrandeBuild.ps1
```
This builds and deploys all components including the new GrandeMonitorIndicator.

### Build Specific Component
```powershell
.\GrandeBuild.ps1 -ComponentName "GrandeTradingSystem"
.\GrandeBuild.ps1 -ComponentName "GrandeMonitorIndicator"
```

### Build Indicator Only
```powershell
.\GrandeBuild.ps1 -IndicatorOnly
```
This builds and deploys only the GrandeMonitorIndicator to the MT5 Indicators folder.

### Build All with Tests
```powershell
.\GrandeBuild.ps1 -RunTests
```

### Test Only Mode
```powershell
.\GrandeBuild.ps1 -TestOnly
```

## Deployment Locations

### Expert Advisors
- **Source**: `GrandeTradingSystem.mq5`
- **Deployed to**: `%APPDATA%\MetaQuotes\Terminal\{TERMINAL_ID}\MQL5\Experts\Grande\`

### Indicators
- **Source**: `GrandeMonitorIndicator.mq5`
- **Deployed to**: `%APPDATA%\MetaQuotes\Terminal\{TERMINAL_ID}\MQL5\Indicators\Grande\`

### Path Configuration
The build script automatically detects your MT5 terminal directory. You can also set a specific terminal ID using:
```powershell
$env:MT5_TERMINAL_ID = "YOUR_TERMINAL_ID_HERE"
```

## GrandeMonitorIndicator Features

The GrandeMonitorIndicator displays all important information from the Grande EA without actually running the EA:

### Market Regime Information
- Current market regime (Bull Trend, Bear Trend, Breakout Setup, Ranging, High Volatility)
- Confidence level
- ADX, +DI, -DI values
- ATR current and average values

### Key Levels
- Total number of detected levels
- Top 5 key levels with:
  - Detection order
  - Level type (Support/Resistance)
  - Price and distance in pips
  - Strength and touch count

### Technical Indicators
- EMA 20/50/200 trend analysis
- RSI overbought/oversold signals
- Stochastic signals
- ATR volatility measurement

### Multi-Timeframe Analysis
- Consensus decision across H4, H1, M15
- Individual timeframe analysis
- Strength percentage

### Risk Metrics
- Account equity and balance
- Margin level with color coding
- Open positions count
- Current P&L

### Trading Signals
- Primary trading signal based on regime and indicators
- Signal strength and reasoning
- Real-time signal updates

## How to Use the Indicator

1. **Build the indicator**: Run `.\GrandeBuild.ps1 -IndicatorOnly`
2. **Open MetaTrader 5**
3. **Add to chart**: 
   - Go to Navigator → Indicators → Custom → Grande → GrandeMonitorIndicator
   - Drag to any chart
4. **Configure**: Adjust display settings in the indicator parameters
5. **Monitor**: All Grande EA information will be displayed on the chart

## Configuration Options

The indicator includes extensive input parameters for customization:

- **Display Settings**: Toggle different information sections
- **Key Level Settings**: Adjust detection parameters
- **Technical Indicator Settings**: Configure indicator periods
- **Multi-Timeframe Settings**: Enable/disable specific timeframes
- **Visual Settings**: Customize colors, fonts, and positioning

## Benefits

- **No EA Required**: Monitor Grande signals without running the actual EA
- **Real-time Updates**: Information updates every 5 seconds
- **Comprehensive View**: All important Grande data in one place
- **Customizable**: Extensive configuration options
- **Performance**: Lightweight indicator with minimal resource usage
