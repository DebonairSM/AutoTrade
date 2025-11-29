# Grande Trading System - Deployment Guide

## Overview

Automated build and deployment scripts handle compilation, dependency management, and deployment to MetaTrader 5.

## Quick Start

### Build and Deploy Main EA

```powershell
.\scripts\GrandeBuild.ps1
```

**This will:**
- ✅ Compile `GrandeTradingSystem.mq5` to `.ex5`
- ✅ Copy all dependencies to MT5
- ✅ Deploy the EA to `MQL5\Experts\Grande\`
- ✅ Deploy testing scripts to `MQL5\Scripts\Grande\`
- ✅ Deploy compiled `.ex5` file

### Build All Components

```powershell
.\scripts\GrandeBuild.ps1 -ComponentName "All"
```

### Build Indicator Only

```powershell
.\scripts\GrandeBuild.ps1 -IndicatorOnly
```

## What Gets Deployed

### Main EA Files
- `GrandeTradingSystem.mq5` → `MQL5\Experts\Grande\`
- `GrandeTradingSystem.ex5` → `MQL5\Experts\Grande\` (compiled)

### Dependencies (Include Files)
All files from `Include\` directory are copied to:
- `MQL5\Experts\Grande\Include\`

### Testing Scripts
- `BackfillHistoricalData.mq5` → `MQL5\Scripts\Grande\`
- `TestDatabaseBackfill.mq5` → `MQL5\Scripts\Grande\`

### MCP Files (if enabled)
- `mcp\analyze_sentiment_server\` → `MQL5\Experts\Grande\mcp\`

## Using the Backfill Script

After deployment, the backfill script is available in MT5:

1. **Open MT5 Terminal**
2. **Navigate to:** `Navigator → Scripts → Grande → BackfillHistoricalData`
3. **Right-click → Attach to Chart**
4. **Set Parameters:**
   - `InpBackfillYears = 5` (or more)
   - `InpSymbol = "EURUSD"` (or your symbol)
   - `InpTimeframe = PERIOD_H1`
   - `InpBackfillMultipleTimeframes = true` (for H1/H4/D1)
5. **Click OK** to run

The script will:
- Connect to your database
- Backfill years of historical data
- Show progress in the Experts tab
- Display completion statistics

## Build Script Parameters

### ComponentName
- `"GrandeTradingSystem"` (default) - Main EA
- `"GrandeMonitorIndicator"` - Monitor indicator
- `"All"` - All components

### RunTests
- `-RunTests` - Run automated tests after build

### TestOnly
- `-TestOnly` - Only run tests, don't build

### IndicatorOnly
- `-IndicatorOnly` - Build only the indicator

## Manual Deployment

If you prefer to deploy manually:

### 1. Copy EA Files
```
Source: GrandeTradingSystem.mq5
Destination: %APPDATA%\MetaQuotes\Terminal\<TERMINAL_ID>\MQL5\Experts\Grande\
```

### 2. Copy Include Files
```
Source: Include\*.mqh
Destination: %APPDATA%\MetaQuotes\Terminal\<TERMINAL_ID>\MQL5\Experts\Grande\Include\
```

### 3. Copy Testing Scripts
```
Source: Testing\BackfillHistoricalData.mq5
Destination: %APPDATA%\MetaQuotes\Terminal\<TERMINAL_ID>\MQL5\Scripts\Grande\
```

### 4. Compile in MetaEditor
- Open `GrandeTradingSystem.mq5` in MetaEditor
- Press F7 to compile
- Check for errors in the Toolbox

## Verification

After deployment, verify:

1. **EA is available:**
   - Navigator → Experts → Grande → GrandeTradingSystem

2. **Script is available:**
   - Navigator → Scripts → Grande → BackfillHistoricalData

3. **Dependencies exist:**
   - Check `MQL5\Experts\Grande\Include\` folder

4. **Database is accessible:**
   - Run EA with `InpEnableDatabase = true`
   - Check `MQL5\Files\Data\GrandeTradingData.db` is created

## Troubleshooting

### Build Script Fails

**Error: "MT5 terminal not found"**
- Set `MT5_TERMINAL_ID` environment variable
- Example: `$env:MT5_TERMINAL_ID = '5C659F0E64BA794E712EE4C936BCFED5'`

**Error: "MetaEditor not found"**
- Update path in `GrandeBuild.ps1` line 245
- Default: `C:\Program Files\FOREX.com US\MetaEditor64.exe`

### Script Not Available in MT5

**Check:**
1. Script is in `MQL5\Scripts\Grande\` folder
2. File extension is `.mq5` (not `.mqh`)
3. Refresh Navigator (F5)
4. Check for compilation errors in MetaEditor

### Database Not Created

**Check:**
1. EA has `InpEnableDatabase = true`
2. EA has write permissions to `MQL5\Files\Data\`
3. Check Experts tab for error messages

## File Structure After Deployment

```
MQL5/
├── Experts/
│   └── Grande/
│       ├── GrandeTradingSystem.mq5
│       ├── GrandeTradingSystem.ex5
│       ├── Include/
│       │   ├── GrandeDatabaseManager.mqh
│       │   ├── GrandeLimitOrderManager.mqh
│       │   └── ... (all include files)
│       └── mcp/
│           └── analyze_sentiment_server/
│               ├── finbert_calendar_analyzer.py
│               └── GrandeNewsSentimentIntegration.mqh
└── Scripts/
    └── Grande/
        ├── BackfillHistoricalData.mq5
        └── TestDatabaseBackfill.mq5
```

## Next Steps After Deployment

1. **Attach EA to Chart:**
   - Drag `GrandeTradingSystem` to a chart
   - Configure input parameters
   - Enable database: `InpEnableDatabase = true`

2. **Backfill Historical Data:**
   - Run `BackfillHistoricalData.mq5` script
   - Set years of data to backfill
   - Wait for completion

3. **Verify Database:**
   - Run `.\scripts\CheckBacktestData.ps1`
   - Check data coverage statistics

4. **Start Trading:**
   - Enable trading in EA inputs
   - Monitor in Experts tab
   - Check database for trade history

## Environment Variables

### MT5_TERMINAL_ID
Set this to use a specific MT5 terminal:
```powershell
$env:MT5_TERMINAL_ID = '5C659F0E64BA794E712EE4C936BCFED5'
```

To find your terminal ID:
```powershell
Get-ChildItem "$env:APPDATA\MetaQuotes\Terminal" | Select-Object Name
```

---

**Related:** [BACKTESTING.md](BACKTESTING.md) | [INDEX.md](INDEX.md)

