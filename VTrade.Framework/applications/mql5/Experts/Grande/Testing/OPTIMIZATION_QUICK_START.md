# Parameter Optimization - Quick Start Guide

## How to Run Optimization

### Step 1: Open MetaTrader 5
1. Launch MetaTrader 5
2. Open a chart for the symbol you want to optimize (e.g., EURUSD!)

### Step 2: Run the Script
1. In MT5, go to **Navigator** → **Scripts**
2. Find **OptimizeParameters**
3. Double-click it (or drag to chart)
4. Configure parameters in the dialog
5. Click **OK** to start

### Step 3: Monitor Progress
- Watch the **Experts** tab for progress updates
- The script will show percentage complete
- Results will be printed when finished

## Recommended Settings for First Run

### Quick Test (5-10 minutes)
```
Symbol: EURUSD! (or your backfilled symbol)
Timeframe: H1 or H4
Years: 2
Optimize Risk: true
Optimize SL/TP: true
Optimize ADX: false
Optimize Key Levels: false

Risk Ranges (keep defaults):
- Risk Trend: 1.0 to 3.0 (step 0.5)
- Risk Range: 0.5 to 1.5 (step 0.3)
- Risk Breakout: 2.0 to 5.0 (step 0.5)

SL/TP Ranges (keep defaults):
- SL ATR: 1.2 to 2.5 (step 0.3)
- TP Ratio: 2.0 to 4.0 (step 0.5)

Optimization Mode: 0 (Net Profit)
Min Trades: 20
Min Win Rate: 45%
```

### Full Optimization (30-60 minutes)
```
Years: 3-5
All optimization options: true
Use default ranges
Optimization Mode: 3 (Custom Score)
Min Trades: 30
Min Win Rate: 50%
```

## Understanding Results

### Best Parameters Section
Shows the optimal parameter combination found:
- **Risk Trend/Range/Breakout**: Risk percentages for different market regimes
- **SL ATR Multiplier**: Stop loss distance multiplier
- **TP Reward Ratio**: Take profit to stop loss ratio

### Performance Metrics
- **Total Trades**: Number of trades executed
- **Win Rate**: Percentage of winning trades
- **Net Profit**: Total profit/loss
- **Profit Factor**: Gross profit / Gross loss
- **Max Drawdown**: Largest peak-to-trough decline
- **Expectancy**: Average profit per trade
- **Risk:Reward**: Average win / Average loss

### Top 10 Results
Shows the best parameter combinations ranked by your selected optimization mode.

## Optimization Modes Explained

1. **Net Profit (0)**: Maximizes total profit
   - Best for: Maximum returns
   - Risk: May have high drawdown

2. **Profit Factor (1)**: Maximizes profit factor
   - Best for: Consistent profitability
   - Risk: May sacrifice total profit

3. **Sharpe Ratio (2)**: Balances return vs risk
   - Best for: Risk-adjusted returns
   - Risk: May be conservative

4. **Custom Score (3)**: Weighted combination
   - Best for: Balanced optimization
   - Formula: Net Profit (40%) + Profit Factor (30%) + Win Rate (20%) + Low Drawdown (10%)

## Tips

1. **Start Small**: Test with 1-2 years first to verify it works
2. **Check Data**: Run `CheckBacktestData.ps1` first to ensure you have data
3. **Be Patient**: Full optimization can take 30-60 minutes
4. **Review Top 10**: Don't just use #1 - review multiple top results
5. **Validate**: Test optimized parameters on out-of-sample data

## Troubleshooting

### "Database not found"
- Run `BackfillHistoricalData.mq5` first to populate database
- Check database path in script (should be `Data/GrandeTradingData.db`)

### "No valid results found"
- Lower `Min Trades` requirement (try 10-15)
- Lower `Min Win Rate` requirement (try 40%)
- Check that you have sufficient historical data

### "Optimization taking too long"
- Reduce number of years (try 1-2 years)
- Increase step sizes (fewer combinations to test)
- Disable some optimization options

### "Insufficient data"
- Run `CheckBacktestData.ps1` to verify data coverage
- Backfill more historical data if needed

## Next Steps After Optimization

1. **Apply Best Parameters**: Update your EA with the optimized values
2. **Forward Test**: Test on demo account with optimized parameters
3. **Compare**: Run comparison script to see limit vs market order performance
4. **Refine**: Run optimization again with narrower ranges around best result
