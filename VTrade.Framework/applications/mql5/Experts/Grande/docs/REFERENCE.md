# Grande Trading System - Reference

## Function Documentation Template

Standard format for documenting all public functions in the Grande Trading System.

### Template Structure

```mql5
//+------------------------------------------------------------------+
//| Function Name                                                    |
//+------------------------------------------------------------------+
// PURPOSE:
//   Brief one-sentence description of what the function does.
//
// BEHAVIOR:
//   Detailed description of how the function works, including:
//   - Step-by-step process (if complex)
//   - State changes that occur
//   - Side effects (file I/O, network calls, state mutations)
//   - Timing considerations
//
// PARAMETERS:
//   param1 (type) - Description of parameter, including:
//                   - Valid value ranges or constraints
//                   - Special values (NULL, 0, -1, etc.)
//                   - Units (pips, points, percentage, etc.)
//   param2 (type) - Description of parameter...
//
// RETURNS:
//   (return_type) - Description of return value:
//                   - Meaning of return value
//                   - Special return values (true/false, error codes, etc.)
//                   - When function returns each value
//
// SIDE EFFECTS:
//   - Modifies global state (specify what)
//   - Writes to files (specify which)
//   - Publishes events (specify which)
//   - Updates display (specify what)
//   - Logs messages (specify level)
//
// ERROR CONDITIONS:
//   - Condition 1: What happens and how it's handled
//   - Condition 2: What happens and how it's handled
//   - Returns error code X when Y occurs
//
// PRECONDITIONS:
//   - System must be initialized
//   - Valid symbol must be set
//   - Required indicators must be loaded
//
// POSTCONDITIONS:
//   - State will be updated to X
//   - Event Y will be published
//
// USAGE EXAMPLE:
//   // Example showing typical usage
//   if(ExecuteTradeLogic(regime))
//   {
//       Print("Trade executed successfully");
//   }
//
// NOTES:
//   - Important implementation details
//   - Performance considerations
//   - Thread safety notes
//   - Known limitations
//
// RELATED:
//   - See Also: RelatedFunction()
//   - Called By: CallingFunction()
//   - Calls: CalledFunction()
//+------------------------------------------------------------------+
```

### Required Sections

1. **PURPOSE** - One sentence describing what the function does
2. **BEHAVIOR** - Detailed description of how it works (required for complex functions)
3. **PARAMETERS** - All parameters with types, constraints, and units
4. **RETURNS** - Return value meaning and special cases
5. **SIDE EFFECTS** - All state changes, I/O operations, events
6. **ERROR CONDITIONS** - How errors are handled

### Optional Sections

- **PRECONDITIONS** - Required state before calling
- **POSTCONDITIONS** - Guaranteed state after calling
- **USAGE EXAMPLE** - Code example (required for complex functions)
- **NOTES** - Implementation details, performance, limitations
- **RELATED** - Cross-references to related functions

## Example: Simple Function

```mql5
//+------------------------------------------------------------------+
//| Get Current ATR Value                                            |
//+------------------------------------------------------------------+
// PURPOSE:
//   Returns the current ATR (Average True Range) value for the symbol.
//
// RETURNS:
//   (double) - Current ATR value in price units, or 0.0 if indicator
//              handle is invalid or data not available.
//
// SIDE EFFECTS:
//   - None (read-only operation)
//
// ERROR CONDITIONS:
//   - Returns 0.0 if ATR indicator handle is invalid
//   - Returns 0.0 if insufficient bars available
//
// NOTES:
//   - ATR value is cached in State Manager for performance
//   - Value is updated on each bar close
//+------------------------------------------------------------------+
double GetATRValue()
{
    // Implementation...
}
```

## Example: Complex Function

```mql5
//+------------------------------------------------------------------+
//| Execute Trade Logic Based on Market Regime                       |
//+------------------------------------------------------------------+
// PURPOSE:
//   Analyzes current market regime and executes appropriate trading
//   strategy (trend, breakout, or range trading).
//
// BEHAVIOR:
//   1. Validates trading conditions (risk checks, position limits)
//   2. Determines appropriate strategy based on regime
//   3. Generates trading signals
//   4. Executes trades if signals are valid
//   5. Publishes events for all trading decisions
//
// PARAMETERS:
//   rs (RegimeSnapshot) - Current market regime snapshot containing:
//                        - regime: Current market regime type
//                        - confidence: Regime confidence (0.0-1.0)
//                        - atr_current: Current ATR value
//                        - adx_h1, adx_h4, adx_d1: ADX values per timeframe
//
// RETURNS:
//   (void) - No return value. Check Event Bus for trade execution results.
//
// SIDE EFFECTS:
//   - May place market or pending orders
//   - Updates State Manager with trade decision data
//   - Publishes EVENT_SIGNAL_GENERATED, EVENT_ORDER_PLACED events
//   - Logs trading decisions to database
//   - Updates display with trade status
//
// ERROR CONDITIONS:
//   - Trading disabled: Function returns early, no trades placed
//   - Risk check fails: EVENT_SIGNAL_REJECTED published with reason
//   - Order placement fails: EVENT_ORDER_FAILED published with error code
//   - Insufficient margin: EVENT_MARGIN_WARNING published
//
// PRECONDITIONS:
//   - EA must be initialized (OnInit() completed successfully)
//   - State Manager must be initialized
//   - Event Bus must be initialized
//   - Valid symbol and timeframe must be set
//
// POSTCONDITIONS:
//   - Trade decision recorded in State Manager
//   - Events published to Event Bus
//   - Database updated with decision data (if enabled)
//
// USAGE EXAMPLE:
//   RegimeSnapshot regime = g_regimeDetector.GetCurrentRegime();
//   ExecuteTradeLogic(regime);
//   // Check Event Bus for results:
//   // SystemEvent events[];
//   // g_eventBus.GetRecentEvents(events, 10);
//
// NOTES:
//   - Called from OnTick() on each price update
//   - Throttled to prevent excessive analysis (see g_lastSignalAnalysisTime)
//   - Respects InpEnableTrading flag
//   - All trades use InpMagicNumber for identification
//
// RELATED:
//   - See Also: TrendTrade(), BreakoutTrade(), RangeTrade()
//   - Called By: OnTick()
//   - Calls: Signal_TREND(), Signal_BREAKOUT(), Signal_RANGE()
//+------------------------------------------------------------------+
void ExecuteTradeLogic(const RegimeSnapshot &rs)
{
    // Implementation...
}
```

## Documentation Checklist

Before marking a function as documented, verify:

- [ ] PURPOSE section clearly describes what the function does
- [ ] All parameters are documented with types and constraints
- [ ] Return value is documented with all possible values
- [ ] All side effects are listed
- [ ] Error conditions are documented
- [ ] Complex functions have BEHAVIOR section
- [ ] Complex functions have USAGE EXAMPLE
- [ ] Important implementation details in NOTES
- [ ] Cross-references in RELATED section (if applicable)

## Special Cases

### Trading Functions
- Must document risk management checks
- Must document position limit constraints
- Must document event publishing
- Must document error handling for order failures

### Display Functions
- Must document chart object creation/updates
- Must document performance considerations
- Must document cleanup requirements

### Data Collection Functions
- Must document database operations
- Must document error handling for connection failures
- Must document data validation

### State Management Functions
- Must document state mutations
- Must document persistence behavior
- Must document validation rules

## Code Patterns

### State Management Pattern
```mql5
// Use State Manager, not global variables
g_stateManager.SetCurrentRegime(regime);
RegimeSnapshot current = g_stateManager.GetCurrentRegime();
```

### Event-Driven Pattern
```mql5
// Publish events instead of direct calls
g_eventBus.PublishEvent(EVENT_REGIME_CHANGED, "RegimeDetector", 
                       "Regime changed to BULL_TREND", 0.85, 0);
```

### Error Handling Pattern
```mql5
// Always check return values and handle errors
if(!g_riskManager.CheckDrawdown())
{
    g_eventBus.PublishEvent(EVENT_RISK_WARNING, "RiskManager",
                           "Drawdown limit reached", drawdown, 2);
    return false;
}
```

### Configuration Pattern
```mql5
// Load inputs into Config Manager
RegimeDetectionConfig config = g_configManager.GetRegimeConfig();
config.adx_trend_threshold = InpADXTrendThreshold;
g_configManager.SetRegimeConfig(config);
```

---

**Related:** [DEVELOPMENT.md](DEVELOPMENT.md) | [ARCHITECTURE.md](ARCHITECTURE.md)
