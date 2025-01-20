# Backtesting Module

This module provides comprehensive backtesting capabilities for trading strategies within the VTrade Framework.

## Structure

```
backtesting/
├── engine/           # Core backtesting engine components
│   ├── simulator.cs  # Trade execution simulator
│   └── results.cs    # Performance analysis
├── data_providers/   # Historical data interfaces and implementations
│   ├── mt5/         # MetaTrader 5 data provider
│   └── mt4/         # MetaTrader 4 data provider
└── models/          # Data models for backtesting
```

## Features

### Data Providers
- Historical price data retrieval
- Custom timeframe generation
- Data normalization and validation
- Support for multiple data sources (MT4/MT5)

### Backtesting Engine
- Event-driven simulation
- Realistic order execution modeling
- Transaction cost consideration
- Time-based position management

### Performance Analysis
- Profit/Loss calculation
- Risk metrics (Sharpe ratio, drawdown)
- Trade statistics
- Equity curve generation

## Usage

```csharp
// Example of running a backtest
var strategy = new TrendFollowingStrategy();
var dataProvider = new MT5DataProvider();
var engine = new BacktestEngine(dataProvider);

var results = await engine.RunBacktest(
    strategy,
    "EURUSD",
    new DateTime(2024, 1, 1),
    new DateTime(2024, 1, 31),
    TimeFrame.H1
);

// Analyze results
var performance = new PerformanceAnalyzer(results);
Console.WriteLine($"Net Profit: {performance.NetProfit}");
Console.WriteLine($"Max Drawdown: {performance.MaxDrawdown}%");
```

## Integration with Live Trading

The backtesting module is designed to work seamlessly with the live trading module:
- Same strategy interface (`IStrategy`)
- Consistent data models
- Shared configuration 