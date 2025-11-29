# Grande Trading System - Development Guide

## Overview

Development roadmap and implementation guide for making the Grande Trading System optimized for AI-driven development and maintenance.

**Status:** Phase 1 Complete ✅ | Phase 2 In Progress ⚠️ | Phase 6 Complete ✅

## Implementation Phases

### Phase 1: Infrastructure Layer ✅ COMPLETE

**Components Created:**
- State Manager - Centralized state management
- Config Manager - Configuration management
- Component Registry - Dynamic component registration
- Health Monitor - System health monitoring
- Event Bus - Event-driven communication
- Interfaces - Standardized interfaces

**Integration Status:**
- State Manager: ✅ Integrated (regime, key levels, ATR)
- Event Bus: ✅ Integrated (regime changes, key events)
- Health Monitor: ✅ Integrated (system health checks)
- Config Manager: ⚠️ Ready (needs input parameter migration)
- Component Registry: ⚠️ Ready (needs component registration)

### Phase 2: Code Organization & Documentation ⚠️ IN PROGRESS

**Global Variable Migration:**
- ✅ Regime and key level state → State Manager
- ❌ Timestamp variables (g_lastRegimeUpdate, etc.)
- ❌ RSI cache variables (g_cachedRsiCTF, etc.)
- ❌ Data collection timestamps

**Function Documentation:**
- ✅ Infrastructure components well documented
- ⚠️ Core components partially documented
- ❌ Main EA functions need documentation
- ❌ Utility functions need documentation

**File Headers:**
- ✅ Main EA and infrastructure files
- ⚠️ Core component files (inconsistent)
- ❌ Utility files

**Code Pattern Consistency:**
- ⚠️ Needs review (error handling, initialization, logging)

### Phase 3: Modular Extraction ❌ PLANNED

**Modules to Extract:**
1. Signal Generation Module (`GrandeSignalGenerator.mqh`)
2. Order Management Module (`GrandeOrderManager.mqh`)
3. Position Management Module (`GrandePositionManager.mqh`)
4. Display Management Module (`GrandeDisplayManager.mqh`)

### Phase 4: Testing & Quality Assurance ❌ PLANNED

- Unit testing framework
- Code quality metrics
- Integration tests

### Phase 5: Advanced LLM Features ❌ PLANNED

- Code generation templates
- Architecture Decision Records (ADRs)
- AI assistance context files

### Phase 6: Profit-Critical Code Patterns ✅ COMPLETE

**Modules Created:**
- ✅ Profit Calculator (`GrandeProfitCalculator.mqh`)
- ✅ Performance Tracker (`GrandePerformanceTracker.mqh`)
- ✅ Signal Quality Analyzer (`GrandeSignalQualityAnalyzer.mqh`)
- ✅ Position Optimizer (`GrandePositionOptimizer.mqh`)

## Refactoring History

### Before Refactoring
- Single 8,774-line EA file
- 50+ global variables
- Mixed concerns (trading + UI + data)
- Implicit dependencies
- Difficult to test and extend

### After Refactoring
- Modular architecture with clear separation
- Infrastructure layer (State, Config, Registry, Health, Events)
- Component layer (Regime, Key Levels, Analyzers, Database)
- Main EA as coordinator
- ~3,000 lines of infrastructure code

## Migration Guide

### Step 1: Replace Global Variables

**Before:**
```mql5
datetime g_lastRegimeUpdate = 0;
RegimeSnapshot g_currentRegime;
double g_currentATR = 0;
```

**After:**
```mql5
g_stateManager.SetLastRegimeUpdate(TimeCurrent());
RegimeSnapshot regime = g_stateManager.GetCurrentRegime();
double atr = g_stateManager.GetCurrentATR();
```

### Step 2: Use Event Bus for Communication

**Before:**
```mql5
Print("Regime changed to ", newRegime);
UpdateDisplay();
```

**After:**
```mql5
g_eventBus.PublishEvent(EVENT_REGIME_CHANGED, "RegimeDetector", 
                       "Regime changed to BULL_TREND", 0.85, 0);
```

### Step 3: Register Components

**Before:**
```mql5
CGrandeMarketRegimeDetector* g_regimeDetector;
// Direct access throughout code
```

**After:**
```mql5
g_registry.RegisterComponent("RegimeDetector", g_regimeDetector);
// Access via registry or direct (both supported)
```

## Best Practices

### 1. Always Check System Health
```mql5
if(!g_healthMonitor.CanTrade())
{
    Print("System health check failed - trading disabled");
    return;
}
```

### 2. Use State Manager for All State
```mql5
// DON'T: Use global variables
datetime g_lastUpdate = TimeCurrent();

// DO: Use state manager
g_stateManager.SetLastRegimeUpdate(TimeCurrent());
```

### 3. Validate Configuration
```mql5
if(!g_configManager.Validate())
{
    Print("Configuration validation failed!");
    return INIT_FAILED;
}
```

### 4. Monitor Component Health
```mql5
if(!g_registry.CheckComponentHealth("RegimeDetector"))
{
    Print("Regime detector health check failed");
}
```

### 5. Use Events for Logging
```mql5
// Instead of direct Print()
g_eventBus.PublishEvent(EVENT_SIGNAL_GENERATED, "MyComponent",
                       "Important event occurred", value, severity);
```

## Documentation Standards

### Function Documentation Template

Each public function should have:
- **PURPOSE:** One-sentence description
- **BEHAVIOR:** Detailed step-by-step process (if complex)
- **PARAMETERS:** All parameters with types, constraints, units
- **RETURNS:** Return value meaning and special cases
- **SIDE EFFECTS:** State changes, I/O operations, events
- **ERROR CONDITIONS:** How errors are handled
- **USAGE EXAMPLE:** Code example (for complex functions)
- **NOTES:** Implementation details, performance, limitations

See [REFERENCE.md](REFERENCE.md) for complete template.

## Next Steps

### Immediate (High Priority)
1. **Complete Function Documentation** (4-6 hours)
   - Audit all public functions
   - Add missing documentation
   - Document complex logic decisions

2. **Migrate Remaining Global Variables** (2-3 hours)
   - Move timestamp variables to State Manager
   - Move RSI cache to State Manager
   - Clean up unused globals

3. **Expand Event Bus Coverage** (3-4 hours)
   - Add order placement events
   - Add position management events
   - Add risk management events
   - Subscribe components to events

### Short Term (Medium Priority)
4. **Integrate Config Manager** (2-3 hours)
   - Load input parameters into Config Manager
   - Add preset support
   - Validate configuration on startup

5. **Integrate Component Registry** (3-4 hours)
   - Register all components
   - Replace direct access with registry
   - Add component health tracking

6. **Standardize File Headers** (2-3 hours)
   - Create header template
   - Update all files
   - Ensure consistency

### Medium Term (Lower Priority)
7. Extract Signal Generation Module (4-6 hours)
8. Extract Order Management Module (4-6 hours)
9. Create Unit Testing Framework (6-8 hours)
10. Create Architecture Decision Records (2-3 hours)

## Success Metrics

**Code Quality:**
- [ ] All public functions documented (0% → 100%)
- [ ] All files have standardized headers (50% → 100%)
- [ ] Global variables reduced by 80% (50% → 80%+)
- [ ] Event Bus coverage for all major operations (30% → 100%)

**Architecture:**
- [ ] Components follow interfaces (0% → 80%+)
- [ ] Clear separation of concerns (60% → 90%+)
- [ ] Test coverage (0% → 50%+)

**LLM-Friendliness:**
- [ ] Files are self-contained with clear purposes (70% → 95%+)
- [ ] Dependencies are explicit and documented (60% → 95%+)
- [ ] "Why" decisions documented (40% → 80%+)
- [ ] Consistent patterns throughout codebase (70% → 95%+)

## Key Files for AI Development

**Start Here:**
1. `Include/GrandeInterfaces.mqh` - Interface definitions
2. `Include/GrandeStateManager.mqh` - State management
3. `Include/GrandeEventBus.mqh` - Event system
4. `GrandeTradingSystem.mq5` - Main EA (lines 1-500 for structure)

**Common Patterns:**
- State management: Use State Manager, not globals
- Events: Publish to Event Bus for decoupled communication
- Initialization: Check health before enabling features
- Error handling: Log errors with context, return error codes
- Configuration: Use Config Manager for centralized config

**Areas Requiring Caution:**
- Database operations: Always handle connection failures
- Indicator handles: Always validate before use, clean up in OnDeinit()
- Order operations: Check broker constraints (min stops, lot sizes)
- Memory management: Always delete pointers in OnDeinit()

---

**Related:** [ARCHITECTURE.md](ARCHITECTURE.md) | [REFERENCE.md](REFERENCE.md)
