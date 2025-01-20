# Live Trading Module

This module handles real-time market operations and broker connectivity for the VTrade Framework.

## Structure

```
live_trading/
├── brokers/          # Broker-specific implementations
│   ├── mt5/         # MetaTrader 5 connectivity
│   └── mt4/         # MetaTrader 4 connectivity
├── execution/        # Order execution and management
│   ├── orders/      # Order handling
│   └── positions/   # Position management
└── models/          # Live trading data models
```

## Features

### Broker Integration
- Real-time market data streaming
- Order execution via broker APIs
- Account management
- Position tracking

### Order Execution
- Market and pending orders
- Stop loss and take profit management
- Position sizing
- Risk management enforcement

### Real-time Monitoring
- Live performance tracking
- Risk metrics calculation
- Alert generation
- Logging and debugging

## Usage

```csharp
// Example of running a live trading strategy
var broker = new MT5Broker(config);
var executor = new OrderExecutor(broker);
var strategy = new TrendFollowingStrategy();

var trader = new LiveTrader(broker, executor, strategy);

// Start trading with risk management
await trader.Start(new TradingParameters
{
    Symbol = "EURUSD",
    RiskPerTrade = 1.0, // percent
    MaxPositions = 5
});

// Monitor performance
trader.OnTradeExecuted += (trade) =>
{
    Console.WriteLine($"Trade executed: {trade.Symbol} at {trade.Price}");
    Console.WriteLine($"Current P/L: {trade.ProfitLoss}");
};
```

## Integration with Backtesting

The live trading module uses the same interfaces as the backtesting module:
- Common strategy implementation
- Shared risk management rules
- Consistent performance metrics

## Safety Features

- Pre-trade validation
- Position size limits
- Maximum drawdown protection
- Emergency stop functionality
- Comprehensive logging 