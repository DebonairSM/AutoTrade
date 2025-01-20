# VTrade Framework

A comprehensive algorithmic trading framework supporting both MetaTrader 5 and MetaTrader 4 platforms.

## Project Structure

```
VTrade.Framework/
├── applications/            # Trading logic implementations
│   ├── experts/            # Trading strategies
│   │   ├── mql5/          # MT5 expert advisors
│   │   │   ├── trend_following/
│   │   │   ├── mean_reversion/
│   │   │   ├── scalping/
│   │   │   └── shared/    # Reusable trading logic
│   │   └── mt4/           # MT4 expert advisors
│   ├── indicators/        # Custom indicators
│   └── scripts/          # Utility scripts
│       ├── backtesting/
│       ├── data_export/
│       └── utilities/
├── src/                  # Core framework logic
│   ├── core/            # Main computational modules
│   ├── analytics/       # Market analysis tools
│   ├── patterns/        # Pattern recognition
│   ├── risk_management/ # Risk management tools
│   ├── utils/          # Helper utilities
│   ├── backtesting/    # Backtesting engine and data providers
│   └── live_trading/   # Live market connectivity and execution
├── tests/              # Testing suite
│   ├── unit/
│   ├── integration/
│   └── performance/
├── metatrader/        # Platform-specific data
│   ├── mt5/
│   │   ├── data/
│   │   └── logs/
│   └── mt4/
│       ├── data/
│       └── logs/
└── config/           # Configuration files
```

## Features

### Backtesting
- Historical data simulation
- Performance analysis
- Strategy optimization
- Risk metrics calculation

### Live Trading
- Real-time market execution
- Broker integration (MT4/MT5)
- Risk management
- Performance monitoring

### Analysis Tools
- Technical indicators
- Pattern recognition
- Market analytics
- Risk assessment

## Getting Started

1. Clone the repository
2. Configure your MetaTrader paths in `config/app_settings.json`
3. Build the project using Visual Studio or .NET CLI
4. Follow the setup guide in `docs/guides/setup.md`

## Documentation

- Architecture overview: `docs/architecture/`
- API documentation: `docs/api/`
- Tutorials: `docs/tutorials/`
- Usage guides: `docs/guides/`

## Development

### Prerequisites
- .NET 8.0 or later
- MetaTrader 5 (required for MT5 features)
- MetaTrader 4 (optional for MT4 features)

### Building
```powershell
dotnet build
```

### Testing
```powershell
dotnet test
```

### Example: Running a Backtest

```csharp
// Initialize strategy and data provider
var strategy = new TrendFollowingStrategy();
var dataProvider = new MT5DataProvider();
var engine = new BacktestEngine(dataProvider);

// Run backtest
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
```

### Example: Live Trading

```csharp
// Set up live trading
var broker = new MT5Broker(config);
var trader = new LiveTrader(broker, strategy);

// Start trading with risk management
await trader.Start(new TradingParameters
{
    Symbol = "EURUSD",
    RiskPerTrade = 1.0
});
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details. 