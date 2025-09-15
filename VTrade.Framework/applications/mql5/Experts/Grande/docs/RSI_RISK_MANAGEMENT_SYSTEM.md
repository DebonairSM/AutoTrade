# Grande RSI Risk Management System

## 🎯 **Overview**

The Grande Trading System now includes a comprehensive **RSI-based risk management system** that prevents entries into exhausted market conditions and provides intelligent exit management based on RSI extremes across multiple timeframes.

---

## 🔧 **Core Features**

### **1. Multi-Timeframe RSI Filtering**
Prevents entries when higher timeframes show exhaustion signals:

- **H4 RSI Gate**: Blocks long entries when H4 RSI ≥ 68, short entries when H4 RSI ≤ 32
- **D1 RSI Gate**: Optional additional filter at 70/30 extremes for macro context
- **Chart TF Timing**: Maintains existing 40-60 RSI reset + hook for precise entry timing
- **Exhaustion Prevention**: Prevents buying into overbought conditions or selling into oversold

### **2. RSI-Based Exit Management**
Intelligent position management using RSI extremes:

- **Partial Closes**: Configurable fraction (default 50%) closed at RSI extremes
- **Multi-TF Triggers**: Chart TF RSI 70/30 OR H4 RSI 68/32 trigger partial exits
- **Profit Protection**: Requires minimum profit (default 10 pips) before RSI exits
- **Risk Integration**: Works alongside existing trailing stops and breakeven logic
- **Cooldown**: Prevent repeated partial closes using time-based cooldown per ticket
- **Guards**: Optional ATR-collapse guard and ≥1R structure guard before executing exits

---

## ⚙️ **Configuration Parameters**

### **Entry Filtering Settings**
```cpp
input bool   InpEnableMTFRSI = true;              // Enable H4/D1 RSI filtering
input double InpH4RSIOverbought = 68.0;           // H4 RSI overbought threshold
input double InpH4RSIOversold  = 32.0;            // H4 RSI oversold threshold
input bool   InpUseD1RSI = true;                  // Enable D1 RSI filter
input double InpD1RSIOverbought = 70.0;           // D1 RSI overbought threshold
input double InpD1RSIOversold  = 30.0;            // D1 RSI oversold threshold
```

### **Exit Management Settings**
```cpp
input bool   InpEnableRSIExits = true;            // Enable RSI-based exits
input double InpRSIExitOB = 70.0;                 // Chart TF RSI overbought exit
input double InpRSIExitOS = 30.0;                 // Chart TF RSI oversold exit
input double InpRSIPartialClose = 0.50;           // Fraction to close on RSI extreme
input int    InpRSIExitMinProfitPips = 10;        // Minimum profit required
input int    InpRSIExitCooldownSec = 900;         // Cooldown between RSI partial closes (seconds)
input double InpMinRemainingVolume = 0.02;        // Min remaining volume after partial close
input bool   InpExitRequireATROK = false;         // Require ATR not collapsing for RSI exit
input double InpExitMinATRRat = 0.80;             // Min ATR ratio vs 10-bar avg (0.8 = 80%)
input bool   InpExitStructureGuard = false;       // Require >=1R in favor before RSI exit
```

---

## 🎯 **How It Works**

### **Entry Signal Flow**
1. **Chart TF Analysis**: Standard 40-60 RSI reset + hook for timing
2. **H4 RSI Check**: Verify H4 RSI is not in exhaustion zone (68/32)
3. **D1 RSI Check**: Optional macro filter at 70/30 extremes
4. **Signal Confirmation**: Only proceed if all RSI conditions are met

### **Exit Management Flow**
1. **Position Monitoring**: Continuously check open positions
2. **RSI Analysis**: Cached per management cycle for efficiency (chart TF, H4 and optional D1)
3. **Exit Trigger**: Partial close when RSI reaches extreme levels
4. **Cooldown/Guards**: Enforce cooldown; optionally require ATR OK and ≥1R in favor
5. **Profit Protection**: Only close if minimum profit threshold is met
6. **Risk Integration**: Works with existing trailing stops and breakeven

---

## 📊 **Recommended Settings**

### **Conservative Approach**
- H4 RSI: 65/35 (more restrictive)
- D1 RSI: 70/30 (enabled)
- Exit Triggers: 70/30 (chart TF)
- Partial Close: 40% (smaller exits)

### **Aggressive Approach**
- H4 RSI: 70/30 (less restrictive)
- D1 RSI: Disabled
- Exit Triggers: 75/25 (chart TF)
- Partial Close: 60% (larger exits)

### **Balanced Approach (Default)**
- H4 RSI: 68/32
- D1 RSI: 70/30 (enabled)
- Exit Triggers: 70/30 (chart TF)
- Partial Close: 50%
- Cooldown: 900 seconds; ATR/Structure guards disabled by default

---

## 🔍 **Implementation Details**

### **Code Structure**
- **`GetRSIValue()`**: Helper function for multi-timeframe RSI access
- **`Signal_TREND()`**: Enhanced with H4/D1 RSI exhaustion filters
- **`ApplyRSIExitRules()`**: RSI-based exit management function
- **`OnTimer()`**: Integrated RSI exit logic with risk management

### **Validation**
- Input parameter validation with sensible ranges
- Error handling for indicator failures
- Graceful degradation if RSI data unavailable

---

## 📈 **Benefits**

### **Risk Reduction**
- Prevents entries into exhausted market conditions
- Reduces drawdowns from poor timing
- Protects against overbought/oversold traps

### **Profit Optimization**
- Captures profits at RSI extremes
- Allows runners to continue with trailing stops
- Balances profit-taking with trend following

### **Market Adaptation**
- Responds to different market conditions
- Configurable for various trading styles
- Integrates seamlessly with existing risk management

---

## ⚠️ **Important Notes**

### **Timeframe Considerations**
- **Chart TF**: Used for precise entry timing and exit triggers
- **H4**: Primary exhaustion filter for trend context
- **D1**: Optional macro filter for longer-term context

### **Integration Points**
- Works alongside existing risk manager
- Compatible with trailing stops and breakeven
- Respects position limits and drawdown protection

### **Performance Impact**
- Minimal overhead with efficient indicator calls
- Timer-based execution to avoid tick-level processing
- Proper resource cleanup and memory management

---

## 🚀 **Getting Started**

1. **Enable the System**: Set `InpEnableMTFRSI = true`
2. **Configure Thresholds**: Adjust H4/D1 RSI levels based on your strategy
3. **Set Exit Parameters**: Configure partial close percentages and profit thresholds
4. **Test Thoroughly**: Backtest with different parameter combinations
5. **Monitor Performance**: Track RSI-based exits and their impact on profitability

---

## 📝 **Example Usage**

```cpp
// Conservative setup for risk-averse trading
InpEnableMTFRSI = true;
InpH4RSIOverbought = 65.0;    // More restrictive
InpH4RSIOversold = 35.0;
InpUseD1RSI = true;
InpEnableRSIExits = true;
InpRSIPartialClose = 0.40;    // Smaller partial closes
InpRSIExitMinProfitPips = 15; // Higher profit requirement
```

This RSI risk management system provides a sophisticated layer of protection and profit optimization while maintaining the core Grande trading logic and risk management principles.
