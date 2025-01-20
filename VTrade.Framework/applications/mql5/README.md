# MQL5 Integration

This directory contains MetaTrader 5 Expert Advisors and Indicators that integrate with the VTrade Framework.

## Directory Structure

```
mql5/
├── Experts/
│   └── VSol/           # Expert Advisors using VTrade Framework
├── Include/
│   └── VTrade/        # Framework interface headers
└── Indicators/
    └── VSol/          # Custom indicators
```

## Setup Instructions

1. **Framework DLL Integration**
   - Build the VTrade Framework solution
   - Copy the generated DLL to MT5's `Libraries` folder:
     ```
     %APPDATA%\MetaQuotes\Terminal\<TERMINAL_ID>\MQL5\Libraries\VTrade.Framework.dll
     ```
   - Import required functions in your EA using:
     ```cpp
     #import "VTrade.Framework.dll"
     // Function declarations here
     #import
     ```

2. **Development Workflow**
   - Create new EAs in `Experts/VSol/`
   - Use the provided base classes and interfaces
   - Follow the naming convention: `V-EA-{Strategy}.mq5`

3. **Building Expert Advisors**
   - Open MetaEditor
   - Compile the EA (F7)
   - Verify DLL imports
   - Test in Strategy Tester

## Example Usage

See `V-EA-Example.mq5` for a complete example of:
- Framework DLL integration
- Risk management implementation
- Pattern recognition usage
- Market analysis integration

## Best Practices

1. **Risk Management**
   - Always use framework's risk management functions
   - Implement proper stop-loss handling
   - Follow position sizing rules

2. **Error Handling**
   - Check DLL function return values
   - Implement proper error logging
   - Handle connection issues gracefully

3. **Performance**
   - Minimize DLL calls in tight loops
   - Cache analysis results when possible
   - Use appropriate timeframes for analysis 