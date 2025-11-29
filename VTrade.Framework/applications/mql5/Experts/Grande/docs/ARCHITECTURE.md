# Grande Trading System - Architecture

## System Overview

Modular MQL5 Expert Advisor with event-driven architecture, centralized state management, and component-based design optimized for AI-driven development.

## Architecture Principles

1. **Explicit Context Over Implicit Knowledge** - Self-contained files with clear purpose
2. **Single Responsibility** - Each component has one clear purpose
3. **Layered Architecture** - Clear boundaries between data, logic, and presentation
4. **Event-Driven Communication** - Decoupled components via Event Bus
5. **Centralized State** - Single source of truth via State Manager
6. **Configuration Management** - Type-safe configuration with validation

## Component Architecture

### Infrastructure Layer

| Component | File | Status | Purpose |
|-----------|------|--------|---------|
| State Manager | `GrandeStateManager.mqh` | ✅ Integrated | Centralized state storage and persistence |
| Config Manager | `GrandeConfigManager.mqh` | ✅ Ready | Type-safe configuration management |
| Component Registry | `GrandeComponentRegistry.mqh` | ✅ Ready | Dynamic component registration |
| Health Monitor | `GrandeHealthMonitor.mqh` | ✅ Integrated | System health and graceful degradation |
| Event Bus | `GrandeEventBus.mqh` | ✅ Integrated | Event-driven communication |
| Interfaces | `GrandeInterfaces.mqh` | ✅ Complete | Standardized component interfaces |

### Analysis Layer

| Component | File | Purpose |
|-----------|------|---------|
| Regime Detector | `GrandeMarketRegimeDetector.mqh` | Detects market regime (trend/ranging/breakout) |
| Key Level Detector | `GrandeKeyLevelDetector.mqh` | Identifies support/resistance levels |
| Multi-Timeframe Analyzer | `GrandeMultiTimeframeAnalyzer.mqh` | Analyzes H4/H1/M15 consensus |
| Candle Analyzer | `GrandeCandleAnalyzer.mqh` | Analyzes candle patterns |
| Fibonacci Calculator | `GrandeFibonacciCalculator.mqh` | Calculates Fibonacci levels |
| Confluence Detector | `GrandeConfluenceDetector.mqh` | Combines factors for entry zones |

### Trading Layer

| Component | File | Purpose |
|-----------|------|---------|
| Signal Quality Analyzer | `GrandeSignalQualityAnalyzer.mqh` | Scores signal quality (0-100) |
| Limit Order Manager | `GrandeLimitOrderManager.mqh` | Limit order placement and lifecycle |
| Position Optimizer | `GrandePositionOptimizer.mqh` | Trailing stops, breakeven, partial closes |
| Risk Manager | `../VSol/GrandeRiskManager.mqh` | Position sizing and risk checks |
| Profit Calculator | `GrandeProfitCalculator.mqh` | Profit calculation in pips and currency |
| Performance Tracker | `GrandePerformanceTracker.mqh` | Trade outcome tracking and reporting |

### Infrastructure Layer

| Component | File | Purpose |
|-----------|------|---------|
| Database Manager | `GrandeDatabaseManager.mqh` | SQLite database operations |
| Intelligent Reporter | `GrandeIntelligentReporter.mqh` | Hourly reports and decision tracking |

## Data Flow

```
OnTick() → Regime Detection → Signal Generation → Quality Filter → Order Placement
                ↓                      ↓                ↓              ↓
         State Manager         Event Bus         Risk Check    Limit Order Manager
                ↓                      ↓                ↓              ↓
         Database Log         Event Log         Position Mgr    Position Optimizer
```

## State Management

**State Manager** (`GrandeStateManager.mqh`) organizes state into categories:

- **Regime State:** Current regime, confidence, timestamps
- **Key Levels:** Support/resistance levels, strength metrics
- **ATR Values:** Current and cached ATR values
- **Range State:** Range boundaries, range type
- **Cool-off Periods:** Trade cooldown timestamps
- **RSI Cache:** Cached RSI values per timeframe

**Usage:**
```mql5
g_stateManager.SetCurrentRegime(regime);
RegimeSnapshot current = g_stateManager.GetCurrentRegime();
double atr = g_stateManager.GetCurrentATR();
```

## Event System

**Event Bus** (`GrandeEventBus.mqh`) provides decoupled communication:

**Event Types:**
- `EVENT_SYSTEM_INIT` / `EVENT_SYSTEM_DEINIT`
- `EVENT_REGIME_CHANGED` / `EVENT_KEY_LEVEL_DETECTED`
- `EVENT_SIGNAL_GENERATED` / `EVENT_ORDER_PLACED`
- `EVENT_RISK_WARNING` / `EVENT_POSITION_MODIFIED`

**Usage:**
```mql5
g_eventBus.PublishEvent(EVENT_REGIME_CHANGED, "RegimeDetector", 
                       "Regime changed to BULL_TREND", 0.85, 0);
```

## Configuration Management

**Config Manager** (`GrandeConfigManager.mqh`) provides:

- Type-safe configuration structures
- Configuration validation
- Preset save/load
- Configuration summary reporting

**Structures:**
- `RegimeDetectionConfig` - Regime detection parameters
- `RiskManagementConfig` - Risk and position sizing
- `LimitOrderConfig` - Limit order parameters
- `DisplayConfig` - Chart display settings

## Component Registration

**Component Registry** (`GrandeComponentRegistry.mqh`) enables:

- Dynamic component registration
- Runtime enable/disable
- Health monitoring integration
- Performance tracking
- Batch analyzer execution

## Health Monitoring

**Health Monitor** (`GrandeHealthMonitor.mqh`) provides:

- System health levels: HEALTHY, WARNING, DEGRADED, CRITICAL, FAILED
- Component health tracking
- Graceful degradation support
- Trading disable on critical failures

## File Structure

```
Grande/
├── GrandeTradingSystem.mq5          (Main EA)
├── Include/
│   ├── GrandeStateManager.mqh       (State management)
│   ├── GrandeEventBus.mqh            (Event system)
│   ├── GrandeConfigManager.mqh       (Configuration)
│   ├── GrandeComponentRegistry.mqh   (Component management)
│   ├── GrandeHealthMonitor.mqh       (Health monitoring)
│   ├── GrandeInterfaces.mqh          (Interfaces)
│   ├── GrandeMarketRegimeDetector.mqh
│   ├── GrandeKeyLevelDetector.mqh
│   ├── GrandeLimitOrderManager.mqh
│   ├── GrandeDatabaseManager.mqh
│   └── ... (other components)
├── scripts/
│   ├── GrandeBuild.ps1               (Build script)
│   └── CheckBacktestData.ps1         (Data validation)
└── docs/                             (Documentation)
```

## Integration Status

**Fully Integrated:**
- State Manager (regime, key levels, ATR)
- Event Bus (regime changes, key events)
- Health Monitor (system health checks)

**Ready for Integration:**
- Config Manager (needs input parameter migration)
- Component Registry (needs component registration)

**Remaining Work:**
- Migrate remaining global variables to State Manager
- Expand Event Bus coverage (orders, positions)
- Complete interface implementation migration

## Design Patterns

**State Management Pattern:**
- Use State Manager, not global variables
- Explicit getters/setters
- State validation before use

**Event-Driven Pattern:**
- Publish events instead of direct calls
- Subscribe to relevant events
- Decouple components

**Configuration Pattern:**
- Load inputs into Config Manager
- Validate on startup
- Use preset management

**Component Pattern:**
- Register all components
- Check health before use
- Enable graceful degradation

---

**Related:** [DEVELOPMENT.md](DEVELOPMENT.md) | [REFERENCE.md](REFERENCE.md)
