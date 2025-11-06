//+------------------------------------------------------------------+
//|                                    GrandeFibonacciCalculator.mqh |
//|                                  Grande Trading System Component |
//|                                                                  |
//| Purpose: Calculate Fibonacci retracement and extension levels    |
//|          from recent swing highs and lows                        |
//|                                                                  |
//| This module identifies swing points in price action and          |
//| calculates standard Fibonacci ratios (23.6%, 38.2%, 50%, etc.)  |
//| for use in confluence-based entry point detection.              |
//+------------------------------------------------------------------+
#property copyright "Grande Trading System"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Structure to hold Fibonacci levels                               |
//+------------------------------------------------------------------+
struct FibLevels
{
    // Swing points
    double swingHigh;
    double swingLow;
    int swingHighBar;
    int swingLowBar;
    int barsToSwing;
    
    // Standard Fibonacci retracement levels
    double level_000;  // 0% (swing low for uptrend, swing high for downtrend)
    double level_236;  // 23.6%
    double level_382;  // 38.2%
    double level_500;  // 50%
    double level_618;  // 61.8% (Golden ratio)
    double level_786;  // 78.6%
    double level_100;  // 100% (swing high for uptrend, swing low for downtrend)
    
    // Fibonacci extension levels (for targets)
    double level_1272; // 127.2%
    double level_1618; // 161.8%
    double level_2000; // 200%
    
    // Direction
    bool isUptrend;    // true if swing from low to high
    bool isValid;      // true if valid swing found
    
    // Range information
    double range;      // Distance from swing high to swing low
    double rangePips;  // Range in pips
};

//+------------------------------------------------------------------+
//| Fibonacci Calculator Class                                       |
//+------------------------------------------------------------------+
class CGrandeFibonacciCalculator
{
private:
    string            m_symbol;
    ENUM_TIMEFRAMES   m_timeframe;
    int               m_defaultLookback;
    int               m_minSwingBars;      // Min bars between swing points
    
    // Helper functions
    double GetPipSize();
    int FindSwingHigh(int startBar, int lookback);
    int FindSwingLow(int startBar, int lookback);
    bool IsSwingHigh(int bar, int leftBars, int rightBars);
    bool IsSwingLow(int bar, int leftBars, int rightBars);
    
public:
    // Constructor
    CGrandeFibonacciCalculator(string symbol, ENUM_TIMEFRAMES timeframe);
    
    // Main calculation functions
    FibLevels CalculateFibonacciLevels(int lookback);
    FibLevels CalculateAutoFibonacci(); // Auto-detect swing points
    
    // Level finder functions
    double GetNearestFibLevel(FibLevels &fib, double currentPrice, bool isBuy);
    double GetBestFibEntry(FibLevels &fib, double currentPrice, bool isBuy);
    bool IsPriceNearFibLevel(double price, FibLevels &fib, double proximityPips, string &levelName);
    
    // Extension levels for profit targets
    double GetFibExtensionTarget(FibLevels &fib, int extensionLevel); // 127, 162, 200
    
    // Utility functions
    void PrintFibLevels(FibLevels &fib);
    void GetAllFibLevels(FibLevels &fib, double &levels[]);
    
    // Settings
    void SetMinSwingBars(int bars) { m_minSwingBars = bars; }
    void SetDefaultLookback(int bars) { m_defaultLookback = bars; }
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CGrandeFibonacciCalculator::CGrandeFibonacciCalculator(string symbol, ENUM_TIMEFRAMES timeframe)
{
    m_symbol = symbol;
    m_timeframe = timeframe;
    m_defaultLookback = 100;
    m_minSwingBars = 5; // At least 5 bars between swing points
}

//+------------------------------------------------------------------+
//| Get pip size for the symbol                                      |
//+------------------------------------------------------------------+
double CGrandeFibonacciCalculator::GetPipSize()
{
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    
    if(digits == 2 || digits == 3)
        return 0.01;
    else
        return 0.0001;
}

//+------------------------------------------------------------------+
//| Check if bar is a swing high                                     |
//+------------------------------------------------------------------+
bool CGrandeFibonacciCalculator::IsSwingHigh(int bar, int leftBars, int rightBars)
{
    double high = iHigh(m_symbol, m_timeframe, bar);
    
    // Check left side
    for(int i = 1; i <= leftBars; i++)
    {
        if(iHigh(m_symbol, m_timeframe, bar + i) >= high)
            return false;
    }
    
    // Check right side
    for(int i = 1; i <= rightBars; i++)
    {
        if(iHigh(m_symbol, m_timeframe, bar - i) > high)
            return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if bar is a swing low                                      |
//+------------------------------------------------------------------+
bool CGrandeFibonacciCalculator::IsSwingLow(int bar, int leftBars, int rightBars)
{
    double low = iLow(m_symbol, m_timeframe, bar);
    
    // Check left side
    for(int i = 1; i <= leftBars; i++)
    {
        if(iLow(m_symbol, m_timeframe, bar + i) <= low)
            return false;
    }
    
    // Check right side
    for(int i = 1; i <= rightBars; i++)
    {
        if(iLow(m_symbol, m_timeframe, bar - i) < low)
            return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Find most recent swing high                                      |
//+------------------------------------------------------------------+
int CGrandeFibonacciCalculator::FindSwingHigh(int startBar, int lookback)
{
    for(int i = startBar + m_minSwingBars; i < startBar + lookback; i++)
    {
        if(IsSwingHigh(i, m_minSwingBars, m_minSwingBars))
            return i;
    }
    
    return -1; // No swing high found
}

//+------------------------------------------------------------------+
//| Find most recent swing low                                       |
//+------------------------------------------------------------------+
int CGrandeFibonacciCalculator::FindSwingLow(int startBar, int lookback)
{
    for(int i = startBar + m_minSwingBars; i < startBar + lookback; i++)
    {
        if(IsSwingLow(i, m_minSwingBars, m_minSwingBars))
            return i;
    }
    
    return -1; // No swing low found
}

//+------------------------------------------------------------------+
//| Calculate Fibonacci levels from recent swing points              |
//+------------------------------------------------------------------+
FibLevels CGrandeFibonacciCalculator::CalculateFibonacciLevels(int lookback)
{
    FibLevels fib;
    fib.isValid = false;
    
    // Find most recent swing high and low
    int swingHighBar = FindSwingHigh(2, lookback);
    int swingLowBar = FindSwingLow(2, lookback);
    
    if(swingHighBar < 0 || swingLowBar < 0)
    {
        // No valid swing points found
        return fib;
    }
    
    // Determine trend direction (which came first)
    fib.isUptrend = (swingLowBar > swingHighBar); // Low is more recent = uptrend
    
    // Get swing prices
    fib.swingHigh = iHigh(m_symbol, m_timeframe, swingHighBar);
    fib.swingLow = iLow(m_symbol, m_timeframe, swingLowBar);
    fib.swingHighBar = swingHighBar;
    fib.swingLowBar = swingLowBar;
    
    // Calculate range
    fib.range = fib.swingHigh - fib.swingLow;
    fib.rangePips = fib.range / GetPipSize();
    
    // Calculate how many bars to most recent swing
    fib.barsToSwing = fib.isUptrend ? swingLowBar : swingHighBar;
    
    // Calculate Fibonacci retracement levels
    // For uptrend: retracement from high back down to low
    // For downtrend: retracement from low back up to high
    
    if(fib.isUptrend)
    {
        // Retracing from swing high down toward swing low
        fib.level_000 = fib.swingHigh;  // 0% = swing high
        fib.level_236 = fib.swingHigh - (fib.range * 0.236);
        fib.level_382 = fib.swingHigh - (fib.range * 0.382);
        fib.level_500 = fib.swingHigh - (fib.range * 0.500);
        fib.level_618 = fib.swingHigh - (fib.range * 0.618);
        fib.level_786 = fib.swingHigh - (fib.range * 0.786);
        fib.level_100 = fib.swingLow;   // 100% = swing low
        
        // Extensions (beyond 100%)
        fib.level_1272 = fib.swingHigh - (fib.range * 1.272);
        fib.level_1618 = fib.swingHigh - (fib.range * 1.618);
        fib.level_2000 = fib.swingHigh - (fib.range * 2.000);
    }
    else
    {
        // Retracing from swing low up toward swing high
        fib.level_000 = fib.swingLow;   // 0% = swing low
        fib.level_236 = fib.swingLow + (fib.range * 0.236);
        fib.level_382 = fib.swingLow + (fib.range * 0.382);
        fib.level_500 = fib.swingLow + (fib.range * 0.500);
        fib.level_618 = fib.swingLow + (fib.range * 0.618);
        fib.level_786 = fib.swingLow + (fib.range * 0.786);
        fib.level_100 = fib.swingHigh;  // 100% = swing high
        
        // Extensions (beyond 100%)
        fib.level_1272 = fib.swingLow + (fib.range * 1.272);
        fib.level_1618 = fib.swingLow + (fib.range * 1.618);
        fib.level_2000 = fib.swingLow + (fib.range * 2.000);
    }
    
    fib.isValid = true;
    return fib;
}

//+------------------------------------------------------------------+
//| Auto-detect and calculate Fibonacci levels                       |
//+------------------------------------------------------------------+
FibLevels CGrandeFibonacciCalculator::CalculateAutoFibonacci()
{
    return CalculateFibonacciLevels(m_defaultLookback);
}

//+------------------------------------------------------------------+
//| Get nearest Fibonacci level to current price                     |
//+------------------------------------------------------------------+
double CGrandeFibonacciCalculator::GetNearestFibLevel(FibLevels &fib, double currentPrice, bool isBuy)
{
    if(!fib.isValid)
        return 0;
    
    // Array of all retracement levels
    double levels[];
    ArrayResize(levels, 7);
    levels[0] = fib.level_000;
    levels[1] = fib.level_236;
    levels[2] = fib.level_382;
    levels[3] = fib.level_500;
    levels[4] = fib.level_618;
    levels[5] = fib.level_786;
    levels[6] = fib.level_100;
    
    double nearestLevel = 0;
    double minDistance = DBL_MAX;
    
    for(int i = 0; i < ArraySize(levels); i++)
    {
        double distance = MathAbs(currentPrice - levels[i]);
        
        // For buy orders, prefer levels below current price
        // For sell orders, prefer levels above current price
        bool isValidDirection = isBuy ? (levels[i] <= currentPrice) : (levels[i] >= currentPrice);
        
        if(distance < minDistance && isValidDirection)
        {
            minDistance = distance;
            nearestLevel = levels[i];
        }
    }
    
    return nearestLevel;
}

//+------------------------------------------------------------------+
//| Get best Fibonacci level for entry                               |
//+------------------------------------------------------------------+
double CGrandeFibonacciCalculator::GetBestFibEntry(FibLevels &fib, double currentPrice, bool isBuy)
{
    if(!fib.isValid)
        return 0;
    
    // Preferred levels for entries (in order of preference)
    // 1. 61.8% (Golden ratio - most common reversal point)
    // 2. 50% (Psychological level)
    // 3. 38.2% (Secondary retracement)
    // 4. 78.6% (Deep retracement)
    
    double preferredLevels[];
    ArrayResize(preferredLevels, 4);
    preferredLevels[0] = fib.level_618;
    preferredLevels[1] = fib.level_500;
    preferredLevels[2] = fib.level_382;
    preferredLevels[3] = fib.level_786;
    
    double maxDistance = 50 * GetPipSize(); // Max 50 pips away
    
    for(int i = 0; i < ArraySize(preferredLevels); i++)
    {
        double level = preferredLevels[i];
        double distance = MathAbs(currentPrice - level);
        
        // Check if level is in valid direction and within range
        bool isValidDirection = isBuy ? (level <= currentPrice) : (level >= currentPrice);
        
        if(distance <= maxDistance && isValidDirection)
        {
            return level;
        }
    }
    
    // If no preferred level found, return nearest level
    return GetNearestFibLevel(fib, currentPrice, isBuy);
}

//+------------------------------------------------------------------+
//| Check if price is near any Fibonacci level                       |
//+------------------------------------------------------------------+
bool CGrandeFibonacciCalculator::IsPriceNearFibLevel(double price, FibLevels &fib, 
                                                      double proximityPips, string &levelName)
{
    if(!fib.isValid)
        return false;
    
    double proximity = proximityPips * GetPipSize();
    
    // Check each level
    if(MathAbs(price - fib.level_000) <= proximity)
    {
        levelName = "Fib 0%";
        return true;
    }
    if(MathAbs(price - fib.level_236) <= proximity)
    {
        levelName = "Fib 23.6%";
        return true;
    }
    if(MathAbs(price - fib.level_382) <= proximity)
    {
        levelName = "Fib 38.2%";
        return true;
    }
    if(MathAbs(price - fib.level_500) <= proximity)
    {
        levelName = "Fib 50%";
        return true;
    }
    if(MathAbs(price - fib.level_618) <= proximity)
    {
        levelName = "Fib 61.8%";
        return true;
    }
    if(MathAbs(price - fib.level_786) <= proximity)
    {
        levelName = "Fib 78.6%";
        return true;
    }
    if(MathAbs(price - fib.level_100) <= proximity)
    {
        levelName = "Fib 100%";
        return true;
    }
    
    levelName = "";
    return false;
}

//+------------------------------------------------------------------+
//| Get Fibonacci extension target                                   |
//+------------------------------------------------------------------+
double CGrandeFibonacciCalculator::GetFibExtensionTarget(FibLevels &fib, int extensionLevel)
{
    if(!fib.isValid)
        return 0;
    
    switch(extensionLevel)
    {
        case 127:
            return fib.level_1272;
        case 162:
        case 161:
            return fib.level_1618;
        case 200:
            return fib.level_2000;
        default:
            return 0;
    }
}

//+------------------------------------------------------------------+
//| Print Fibonacci levels to log                                    |
//+------------------------------------------------------------------+
void CGrandeFibonacciCalculator::PrintFibLevels(FibLevels &fib)
{
    if(!fib.isValid)
    {
        Print("[Fibonacci] No valid swing points found");
        return;
    }
    
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    string trend = fib.isUptrend ? "UPTREND" : "DOWNTREND";
    
    Print("========== Fibonacci Levels (", trend, ") ==========");
    Print("Swing High: ", DoubleToString(fib.swingHigh, digits), " (Bar ", fib.swingHighBar, ")");
    Print("Swing Low:  ", DoubleToString(fib.swingLow, digits), " (Bar ", fib.swingLowBar, ")");
    Print("Range: ", DoubleToString(fib.rangePips, 1), " pips");
    Print("------- Retracement Levels -------");
    Print("  0.0%: ", DoubleToString(fib.level_000, digits));
    Print(" 23.6%: ", DoubleToString(fib.level_236, digits));
    Print(" 38.2%: ", DoubleToString(fib.level_382, digits));
    Print(" 50.0%: ", DoubleToString(fib.level_500, digits));
    Print(" 61.8%: ", DoubleToString(fib.level_618, digits));
    Print(" 78.6%: ", DoubleToString(fib.level_786, digits));
    Print("100.0%: ", DoubleToString(fib.level_100, digits));
    Print("------- Extension Levels -------");
    Print("127.2%: ", DoubleToString(fib.level_1272, digits));
    Print("161.8%: ", DoubleToString(fib.level_1618, digits));
    Print("200.0%: ", DoubleToString(fib.level_2000, digits));
    Print("====================================");
}

//+------------------------------------------------------------------+
//| Get all Fibonacci levels as array                                |
//+------------------------------------------------------------------+
void CGrandeFibonacciCalculator::GetAllFibLevels(FibLevels &fib, double &levels[])
{
    if(!fib.isValid)
    {
        ArrayResize(levels, 0);
        return;
    }
    
    ArrayResize(levels, 7);
    levels[0] = fib.level_000;
    levels[1] = fib.level_236;
    levels[2] = fib.level_382;
    levels[3] = fib.level_500;
    levels[4] = fib.level_618;
    levels[5] = fib.level_786;
    levels[6] = fib.level_100;
}
//+------------------------------------------------------------------+

