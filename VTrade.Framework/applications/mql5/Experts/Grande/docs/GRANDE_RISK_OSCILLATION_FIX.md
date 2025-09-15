# GrandeRisk Oscillation Fix

## Problem Description

The GrandeRisk system was experiencing excessive logging and oscillation between `BREAKEVEN_SET` and `TRAILING_UPDATE` messages for the same position ticket. This was happening because:

1. **State Loss**: The `breakeven_set` flag was stored only in local memory
2. **Position Refresh**: Every `OnTick()` call refreshed position data from the broker
3. **Flag Reset**: The `breakeven_set` flag was lost during position refresh
4. **Infinite Loop**: This caused the system to repeatedly attempt breakeven operations

## Root Cause

```cpp
// In UpdatePositionInfo() - the flag was only preserved for existing positions
if(m_positions[j].ticket == ticket)
{
    isNewPosition = false;
    pos.breakeven_set = m_positions[j].breakeven_set;  // Only for existing
    // ... other flags
}

if(isNewPosition)
{
    pos.breakeven_set = false;  // Always false for new positions
    // ... other flags
}
```

## Solution Implemented

### 1. State Persistence Logic

Added logic to detect if a position is already at breakeven level by comparing the actual stop loss:

```cpp
// CRITICAL FIX: Check if position is already at breakeven by comparing stop loss
if(!pos.breakeven_set && pos.stop_loss > 0)
{
    double breakevenThreshold = pos.price_open + (pos.type == POSITION_TYPE_BUY ? 
                              m_config.breakeven_buffer * _Point : 
                              -m_config.breakeven_buffer * _Point);
    
    // If stop loss is at or beyond breakeven level, mark as breakeven_set
    if(pos.type == POSITION_TYPE_BUY)
    {
        if(pos.stop_loss >= breakevenThreshold)
            pos.breakeven_set = true;
    }
    else
    {
        if(pos.stop_loss <= breakevenThreshold)
            pos.breakeven_set = true;
    }
}
```

### 2. Enhanced Validation in UpdateBreakevenStops

Added additional checks to prevent repeated operations:

```cpp
// Additional check: if stop loss is already at breakeven level, mark as set
if(pos.stop_loss > 0)
{
    double breakevenThreshold = pos.price_open + (pos.type == POSITION_TYPE_BUY ? 
                              m_config.breakeven_buffer * _Point : 
                              -m_config.breakeven_buffer * _Point);
    
    bool alreadyAtBreakeven = false;
    if(pos.type == POSITION_TYPE_BUY)
        alreadyAtBreakeven = (pos.stop_loss >= breakevenThreshold);
    else
        alreadyAtBreakeven = (pos.stop_loss <= breakevenThreshold);
        
    if(alreadyAtBreakeven)
    {
        pos.breakeven_set = true;
        m_positions[i] = pos;
        LogRiskEvent("INFO", StringFormat("Ticket %d already at breakeven level %.5f", pos.ticket, pos.stop_loss));
        continue;
    }
}
```

### 3. Improved Trailing Stop Logic

Added minimum improvement threshold to prevent micro-adjustments:

```cpp
// Only update if new stop is significantly better (at least 1 pip improvement)
if(pos.type == POSITION_TYPE_BUY)
    shouldUpdate = (newStopLoss > pos.stop_loss + _Point);
else
    shouldUpdate = (newStopLoss < pos.stop_loss - _Point);
```

### 4. Rate Limiting

Implemented rate limiting to prevent excessive logging and operations:

```cpp
// Rate limiting: prevent excessive operations on the same position
static datetime lastBreakevenLog = 0;
static ulong lastBreakevenTicket = 0;

// Rate limit logging to prevent spam
if(TimeCurrent() - lastBreakevenLog >= 10 || lastBreakevenTicket != pos.ticket)
{
    LogRiskEvent("INFO", StringFormat("Ticket %d already at breakeven level %.5f", pos.ticket, pos.stop_loss));
    lastBreakevenLog = TimeCurrent();
    lastBreakevenTicket = pos.ticket;
}
```

## Benefits

1. **Eliminates Oscillation**: Positions are properly recognized as already at breakeven
2. **Reduces Log Spam**: Rate limiting prevents excessive logging
3. **Improves Performance**: Fewer unnecessary broker operations
4. **Better State Management**: Position state is properly synchronized with broker data
5. **Prevents Infinite Loops**: Invalid operations are properly handled

## Configuration

The fix works with existing configuration parameters:

- `InpEnableBreakeven`: Controls breakeven functionality
- `InpBreakevenBuffer`: Sets the breakeven buffer distance
- `InpEnableTrailingStop`: Controls trailing stop functionality
- `InpTrailingATRMultiplier`: Sets trailing stop distance

## Testing

After implementing this fix:

1. **Monitor Logs**: Should see significantly fewer repeated messages
2. **Check Performance**: Fewer broker operations should improve performance
3. **Verify Functionality**: Breakeven and trailing stops should work correctly
4. **State Persistence**: Positions should maintain their state across ticks

## Files Modified

- `VTrade.Framework/applications/mql5/Experts/VSol/GrandeRiskManager.mqh`
  - `UpdatePositionInfo()` method
  - `UpdateBreakevenStops()` method  
  - `UpdateTrailingStops()` method

## Implementation Notes

- The fix is backward compatible with existing configurations
- No changes required to the main EA or input parameters
- Rate limiting can be adjusted by modifying the time thresholds
- The solution handles both buy and sell positions correctly
