# Grande Trading System - Documentation Index

## Quick Navigation

- [Architecture](ARCHITECTURE.md) - System architecture, components, and design patterns
- [Development](DEVELOPMENT.md) - Development guide, implementation plan, and refactoring
- [Backtesting](BACKTESTING.md) - Backtesting workflow, configuration, and analysis
- [Deployment](DEPLOYMENT.md) - Build, deployment, and verification procedures
- [Limit Orders](LIMIT_ORDERS.md) - Limit order system design, implementation, and optimization
- [Profit Critical](PROFIT_CRITICAL.md) - Profit calculation, risk management, and performance tracking
- [Data Sources](DATA_SOURCES.md) - Historical data sources and integration
- [Reference](REFERENCE.md) - Function documentation templates and code patterns

## System Overview

**Grande Trading System** is a modular MQL5 Expert Advisor for MetaTrader 5 with:
- Event-driven architecture with centralized state management
- Multi-timeframe regime detection (trending, ranging, breakout)
- Confluence-based limit order placement
- SQLite database for trade history and analysis
- Comprehensive risk management and position optimization

## Key Components

| Component | File | Purpose |
|----------|------|---------|
| State Manager | `Include/GrandeStateManager.mqh` | Centralized state management |
| Event Bus | `Include/GrandeEventBus.mqh` | Decoupled event communication |
| Regime Detector | `Include/GrandeMarketRegimeDetector.mqh` | Market regime identification |
| Limit Order Manager | `Include/GrandeLimitOrderManager.mqh` | Limit order lifecycle |
| Database Manager | `Include/GrandeDatabaseManager.mqh` | SQLite data persistence |
| Risk Manager | `../VSol/GrandeRiskManager.mqh` | Position sizing and risk checks |

## Current Status

**Build:** ✅ 0 errors, 14 warnings (pre-existing)  
**Integration:** ✅ Infrastructure components integrated  
**State Management:** ✅ Regime and key level state using State Manager  
**Event Logging:** ✅ Regime changes and key events logged  
**Historical Data:** ✅ Automatic backfill integrated

## Documentation Structure

```
docs/
├── INDEX.md              (this file)
├── ARCHITECTURE.md       (system design and components)
├── DEVELOPMENT.md        (development guide and roadmap)
├── BACKTESTING.md        (backtesting procedures)
├── DEPLOYMENT.md         (build and deployment)
├── LIMIT_ORDERS.md       (limit order system)
├── PROFIT_CRITICAL.md    (profit and risk management)
├── DATA_SOURCES.md       (data source integration)
├── REFERENCE.md          (templates and patterns)
└── archive/              (time-specific reports)
```

## Quick Start

1. **Deploy:** Run `.\scripts\GrandeBuild.ps1`
2. **Backfill Data:** Run `BackfillHistoricalData.mq5` script in MT5
3. **Configure:** Set EA input parameters
4. **Monitor:** Check Experts tab and database logs

## Related Files

- Main EA: `GrandeTradingSystem.mq5`
- Build Script: `scripts/GrandeBuild.ps1`
- Data Check: `scripts/CheckBacktestData.ps1`
- Database: `MQL5/Files/Data/GrandeTradingData.db`

---

**Last Updated:** 2025-11-29
