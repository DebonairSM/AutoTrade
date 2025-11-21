//+------------------------------------------------------------------+
//|                                         GrandeCandleAnalyzer.mqh |
//|                                  Grande Trading System Component |
//|                                                                  |
//| Purpose: Comprehensive candle structure analysis                 |
//|          - Wick-to-body ratio calculations                       |
//|          - Pattern recognition (pin bars, hammers, etc.)         |
//|          - Multi-candle pattern detection                        |
//|          - Entry validation based on candle structure            |
//|                                                                  |
//| This module analyzes individual candles and multi-candle         |
//| patterns to validate entry conditions. It identifies rejection   |
//| wicks, momentum candles, and consolidation patterns.             |
//+------------------------------------------------------------------+
//
// RESPONSIBILITIES:
//   - Analyze individual candle structure (body, wicks, ratios)
//   - Identify candlestick patterns (pin bars, hammers, doji, engulfing)
//   - Validate entry conditions based on candle quality
//   - Detect rejection wicks and momentum candles
//   - Calculate wick-to-body ratios
//
// DEPENDENCIES:
//   - None (standalone component)
//   - Uses MT5 price data: iOpen, iHigh, iLow, iClose
//
// STATE MANAGED:
//   - Symbol and timeframe
//   - Analysis configuration (min body %, wick ratio threshold)
//
// PUBLIC INTERFACE:
//   bool Initialize(symbol, timeframe)
//   CandleStructure AnalyzeCandle(index) - Analyze specific candle
//   bool IsValidEntry(isBullish, index) - Validate entry candle
//   bool HasExcessiveWick(index) - Check for excessive wicks
//   bool IsDoji(index) - Check if candle is doji
//   void SetMinBodyPercentage(percent) - Configure minimum body size
//   void SetWickRatioThreshold(ratio) - Configure wick threshold
//
// THREAD SAFETY: Not thread-safe (MQL5 limitation)
//
// TESTING: See Testing/TestCandleAnalyzer.mqh
//+------------------------------------------------------------------+

#property copyright "Grande Trading System"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Structure to hold detailed candle analysis results               |
//+------------------------------------------------------------------+
struct CandleStructure
{
    // Price components
    double open;
    double high;
    double low;
    double close;
    
    // Size measurements
    double bodySize;           // Absolute size of candle body
    double totalRange;         // High - Low
    double upperWick;          // Distance from top of body to high
    double lowerWick;          // Distance from bottom of body to low
    
    // Ratios and flags
    double wickToBodyRatio;    // Maximum wick / body ratio
    double upperWickRatio;     // Upper wick / total range
    double lowerWickRatio;     // Lower wick / total range
    double bodyToRangeRatio;   // Body size / total range
    
    // Direction
    bool isBullish;            // Close > Open
    bool isBearish;            // Close < Open
    bool isDoji;               // Very small body (< 10% of range)
    
    // Pattern identification
    bool hasLongUpperWick;     // Upper wick > 2x body
    bool hasLongLowerWick;     // Lower wick > 2x body
    bool isPinBar;             // One long wick, small body
    bool isHammer;             // Bullish pin bar (long lower wick)
    bool isShootingStar;       // Bearish pin bar (long upper wick)
    bool isEngulfing;          // Engulfs previous candle
    
    // Momentum indicators
    bool isMomentumCandle;     // Large body relative to ATR
    bool isConsolidation;      // Small range relative to ATR
    double momentumStrength;   // Body size / ATR
    
    // Pattern description
    string pattern;            // Human-readable pattern name
    string rejectionDirection; // "BULLISH", "BEARISH", or "NEUTRAL"
};

//+------------------------------------------------------------------+
//| Structure for multi-candle pattern analysis                      |
//+------------------------------------------------------------------+
struct MultiCandlePattern
{
    bool isInsideBar;          // Current bar inside previous bar
    bool isOutsideBar;         // Current bar engulfs previous bar
    bool isBullishEngulfing;   // Bullish engulfing pattern
    bool isBearishEngulfing;   // Bearish engulfing pattern
    bool isThreeWhiteSoldiers; // Three consecutive bullish candles
    bool isThreeBlackCrows;    // Three consecutive bearish candles
    bool isDoubleTop;          // Recent highs at similar level
    bool isDoubleBottom;       // Recent lows at similar level
    
    string pattern;            // Pattern description
    int strength;              // Pattern strength (1-10)
};

//+------------------------------------------------------------------+
//| Candle Analyzer Class                                            |
//+------------------------------------------------------------------+
class CGrandeCandleAnalyzer
{
private:
    string            m_symbol;
    ENUM_TIMEFRAMES   m_timeframe;
    double            m_minBodyPercentage;  // Min body size for valid candle
    double            m_wickRatioThreshold; // Threshold for "long" wick
    
    // Helper functions
    double GetPipSize();
    bool IsApproximatelyEqual(double a, double b, double tolerance);
    
public:
    // Constructor
    CGrandeCandleAnalyzer(string symbol, ENUM_TIMEFRAMES timeframe);
    
    // Main analysis functions
    CandleStructure AnalyzeCandleStructure(int shift);
    MultiCandlePattern AnalyzeMultiCandlePattern(int startShift, int numCandles);
    
    // Validation functions
    bool IsValidEntryCandle(bool isBuy, int shift);
    bool ValidateWickStructure(bool isBuy, int shift, string &reason);
    bool ValidateMultiCandleSetup(bool isBuy, int shift, string &reason);
    
    // Pattern detection
    bool IsPinBar(int shift, bool &isBullish);
    bool IsEngulfingPattern(int shift, bool &isBullish);
    bool IsInsideBar(int shift);
    bool HasRejectionWick(int shift, bool checkUpper);
    
    // Momentum analysis
    double GetMomentumStrength(int shift, double atr);
    bool IsMomentumCandle(int shift, double atr, double threshold);
    bool IsConsolidationCandle(int shift, double atr);
    
    // Comparative analysis
    bool AreConsecutiveCandlesAgainstDirection(bool isBuy, int count);
    bool HasRecentRejection(bool atResistance, int lookback);
    
    // Settings
    void SetMinBodyPercentage(double percentage) { m_minBodyPercentage = percentage; }
    void SetWickRatioThreshold(double ratio) { m_wickRatioThreshold = ratio; }
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CGrandeCandleAnalyzer::CGrandeCandleAnalyzer(string symbol, ENUM_TIMEFRAMES timeframe)
{
    m_symbol = symbol;
    m_timeframe = timeframe;
    m_minBodyPercentage = 0.1;   // Body must be at least 10% of range
    m_wickRatioThreshold = 2.0;  // Wick must be 2x body to be "long"
}

//+------------------------------------------------------------------+
//| Get pip size for the symbol                                      |
//+------------------------------------------------------------------+
double CGrandeCandleAnalyzer::GetPipSize()
{
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    
    // For JPY pairs (2-3 digits), 1 pip = 0.01
    // For other pairs (4-5 digits), 1 pip = 0.0001
    if(digits == 2 || digits == 3)
        return 0.01;
    else
        return 0.0001;
}

//+------------------------------------------------------------------+
//| Check if two values are approximately equal                      |
//+------------------------------------------------------------------+
bool CGrandeCandleAnalyzer::IsApproximatelyEqual(double a, double b, double tolerance)
{
    return MathAbs(a - b) <= tolerance;
}

//+------------------------------------------------------------------+
//| Analyze detailed candle structure                                |
//+------------------------------------------------------------------+
CandleStructure CGrandeCandleAnalyzer::AnalyzeCandleStructure(int shift)
{
    CandleStructure candle;
    
    // Get OHLC data
    candle.open = iOpen(m_symbol, m_timeframe, shift);
    candle.high = iHigh(m_symbol, m_timeframe, shift);
    candle.low = iLow(m_symbol, m_timeframe, shift);
    candle.close = iClose(m_symbol, m_timeframe, shift);
    
    // Calculate basic measurements
    candle.bodySize = MathAbs(candle.close - candle.open);
    candle.totalRange = candle.high - candle.low;
    
    // Determine direction
    candle.isBullish = (candle.close > candle.open);
    candle.isBearish = (candle.close < candle.open);
    
    // Calculate wicks
    if(candle.isBullish)
    {
        candle.upperWick = candle.high - candle.close;
        candle.lowerWick = candle.open - candle.low;
    }
    else
    {
        candle.upperWick = candle.high - candle.open;
        candle.lowerWick = candle.close - candle.low;
    }
    
    // Calculate ratios (avoid division by zero)
    if(candle.totalRange > 0)
    {
        candle.bodyToRangeRatio = candle.bodySize / candle.totalRange;
        candle.upperWickRatio = candle.upperWick / candle.totalRange;
        candle.lowerWickRatio = candle.lowerWick / candle.totalRange;
    }
    else
    {
        candle.bodyToRangeRatio = 0;
        candle.upperWickRatio = 0;
        candle.lowerWickRatio = 0;
    }
    
    // Wick to body ratio (maximum of upper or lower)
    if(candle.bodySize > 0)
    {
        double upperRatio = candle.upperWick / candle.bodySize;
        double lowerRatio = candle.lowerWick / candle.bodySize;
        candle.wickToBodyRatio = MathMax(upperRatio, lowerRatio);
    }
    else
    {
        candle.wickToBodyRatio = 999; // Doji has infinite ratio
    }
    
    // Identify doji
    candle.isDoji = (candle.bodyToRangeRatio < m_minBodyPercentage);
    
    // Identify long wicks
    candle.hasLongUpperWick = (candle.bodySize > 0 && candle.upperWick > m_wickRatioThreshold * candle.bodySize);
    candle.hasLongLowerWick = (candle.bodySize > 0 && candle.lowerWick > m_wickRatioThreshold * candle.bodySize);
    
    // Identify specific patterns
    candle.isPinBar = ((candle.hasLongUpperWick && !candle.hasLongLowerWick) || 
                       (!candle.hasLongUpperWick && candle.hasLongLowerWick)) && 
                      candle.bodyToRangeRatio < 0.3;
    
    candle.isHammer = candle.hasLongLowerWick && !candle.hasLongUpperWick && 
                      candle.bodyToRangeRatio < 0.3 && candle.isBullish;
    
    candle.isShootingStar = candle.hasLongUpperWick && !candle.hasLongLowerWick && 
                            candle.bodyToRangeRatio < 0.3 && candle.isBearish;
    
    // Determine rejection direction
    if(candle.hasLongUpperWick && !candle.hasLongLowerWick)
        candle.rejectionDirection = "BEARISH"; // Rejected at highs
    else if(candle.hasLongLowerWick && !candle.hasLongUpperWick)
        candle.rejectionDirection = "BULLISH"; // Rejected at lows (bullish bounce)
    else
        candle.rejectionDirection = "NEUTRAL";
    
    // Build pattern description
    if(candle.isHammer)
        candle.pattern = "HAMMER";
    else if(candle.isShootingStar)
        candle.pattern = "SHOOTING_STAR";
    else if(candle.isPinBar)
        candle.pattern = candle.hasLongUpperWick ? "BEARISH_PIN_BAR" : "BULLISH_PIN_BAR";
    else if(candle.isDoji)
        candle.pattern = "DOJI";
    else if(candle.isBullish && candle.bodyToRangeRatio > 0.7)
        candle.pattern = "STRONG_BULLISH";
    else if(candle.isBearish && candle.bodyToRangeRatio > 0.7)
        candle.pattern = "STRONG_BEARISH";
    else
        candle.pattern = candle.isBullish ? "BULLISH" : "BEARISH";
    
    return candle;
}

//+------------------------------------------------------------------+
//| Analyze multi-candle patterns                                    |
//+------------------------------------------------------------------+
MultiCandlePattern CGrandeCandleAnalyzer::AnalyzeMultiCandlePattern(int startShift, int numCandles)
{
    MultiCandlePattern pattern;
    
    // Initialize all flags
    pattern.isInsideBar = false;
    pattern.isOutsideBar = false;
    pattern.isBullishEngulfing = false;
    pattern.isBearishEngulfing = false;
    pattern.isThreeWhiteSoldiers = false;
    pattern.isThreeBlackCrows = false;
    pattern.isDoubleTop = false;
    pattern.isDoubleBottom = false;
    pattern.pattern = "NONE";
    pattern.strength = 0;
    
    if(numCandles < 2)
        return pattern;
    
    // Get candle data for analysis
    CandleStructure current = AnalyzeCandleStructure(startShift);
    CandleStructure previous = AnalyzeCandleStructure(startShift + 1);
    
    // Inside bar pattern
    if(current.high <= previous.high && current.low >= previous.low)
    {
        pattern.isInsideBar = true;
        pattern.pattern = "INSIDE_BAR";
        pattern.strength = 5;
    }
    
    // Outside bar / engulfing
    if(current.high > previous.high && current.low < previous.low)
    {
        pattern.isOutsideBar = true;
        pattern.pattern = "OUTSIDE_BAR";
        pattern.strength = 6;
        
        // Check for engulfing patterns
        if(current.isBullish && previous.isBearish && 
           current.open <= previous.close && current.close > previous.open)
        {
            pattern.isBullishEngulfing = true;
            pattern.pattern = "BULLISH_ENGULFING";
            pattern.strength = 8;
        }
        else if(current.isBearish && previous.isBullish && 
                current.open >= previous.close && current.close < previous.open)
        {
            pattern.isBearishEngulfing = true;
            pattern.pattern = "BEARISH_ENGULFING";
            pattern.strength = 8;
        }
    }
    
    // Three candle patterns
    if(numCandles >= 3)
    {
        CandleStructure third = AnalyzeCandleStructure(startShift + 2);
        
        // Three white soldiers (bullish)
        if(current.isBullish && previous.isBullish && third.isBullish &&
           current.close > previous.close && previous.close > third.close)
        {
            pattern.isThreeWhiteSoldiers = true;
            pattern.pattern = "THREE_WHITE_SOLDIERS";
            pattern.strength = 9;
        }
        
        // Three black crows (bearish)
        if(current.isBearish && previous.isBearish && third.isBearish &&
           current.close < previous.close && previous.close < third.close)
        {
            pattern.isThreeBlackCrows = true;
            pattern.pattern = "THREE_BLACK_CROWS";
            pattern.strength = 9;
        }
        
        // Double top/bottom (check last 5 candles)
        if(numCandles >= 5)
        {
            double tolerance = GetPipSize() * 10; // Within 10 pips
            
            // Check for double top
            bool hasDoubleTop = false;
            for(int i = startShift; i < startShift + 4; i++)
            {
                double high1 = iHigh(m_symbol, m_timeframe, i);
                for(int j = i + 1; j < startShift + 5; j++)
                {
                    double high2 = iHigh(m_symbol, m_timeframe, j);
                    if(IsApproximatelyEqual(high1, high2, tolerance))
                    {
                        hasDoubleTop = true;
                        break;
                    }
                }
                if(hasDoubleTop) break;
            }
            
            // Check for double bottom
            bool hasDoubleBottom = false;
            for(int i = startShift; i < startShift + 4; i++)
            {
                double low1 = iLow(m_symbol, m_timeframe, i);
                for(int j = i + 1; j < startShift + 5; j++)
                {
                    double low2 = iLow(m_symbol, m_timeframe, j);
                    if(IsApproximatelyEqual(low1, low2, tolerance))
                    {
                        hasDoubleBottom = true;
                        break;
                    }
                }
                if(hasDoubleBottom) break;
            }
            
            if(hasDoubleTop)
            {
                pattern.isDoubleTop = true;
                pattern.pattern = "DOUBLE_TOP";
                pattern.strength = 7;
            }
            
            if(hasDoubleBottom)
            {
                pattern.isDoubleBottom = true;
                pattern.pattern = "DOUBLE_BOTTOM";
                pattern.strength = 7;
            }
        }
    }
    
    return pattern;
}

//+------------------------------------------------------------------+
//| Check if candle is valid for entry                               |
//+------------------------------------------------------------------+
bool CGrandeCandleAnalyzer::IsValidEntryCandle(bool isBuy, int shift)
{
    CandleStructure candle = AnalyzeCandleStructure(shift);
    
    // Reject if wick to body ratio is too high (indicates rejection)
    if(candle.wickToBodyRatio > m_wickRatioThreshold)
    {
        // Allow if rejection is in our favor
        if(isBuy && candle.hasLongLowerWick && !candle.hasLongUpperWick)
            return true; // Bullish rejection at lows
        if(!isBuy && candle.hasLongUpperWick && !candle.hasLongLowerWick)
            return true; // Bearish rejection at highs
        
        return false; // Rejection against our direction
    }
    
    // Reject doji candles (indecision)
    if(candle.isDoji)
        return false;
    
    // For buy signals, prefer bullish candles or bullish rejection
    if(isBuy)
    {
        if(candle.isBearish && !candle.hasLongLowerWick)
            return false;
    }
    // For sell signals, prefer bearish candles or bearish rejection
    else
    {
        if(candle.isBullish && !candle.hasLongUpperWick)
            return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate wick structure for entry                                |
//+------------------------------------------------------------------+
bool CGrandeCandleAnalyzer::ValidateWickStructure(bool isBuy, int shift, string &reason)
{
    CandleStructure candle = AnalyzeCandleStructure(shift);
    
    // Check for excessive wicks against direction
    if(isBuy)
    {
        if(candle.hasLongUpperWick && candle.upperWick > candle.lowerWick * 2)
        {
            reason = StringFormat("Bearish rejection wick detected (%.1f pips)", 
                                 candle.upperWick / GetPipSize());
            return false;
        }
    }
    else // Sell
    {
        if(candle.hasLongLowerWick && candle.lowerWick > candle.upperWick * 2)
        {
            reason = StringFormat("Bullish rejection wick detected (%.1f pips)", 
                                 candle.lowerWick / GetPipSize());
            return false;
        }
    }
    
    // Check for doji (indecision)
    if(candle.isDoji)
    {
        reason = "Doji candle indicates indecision";
        return false;
    }
    
    // Specific pattern rejections
    if(isBuy && candle.isShootingStar)
    {
        reason = "Shooting star pattern (bearish reversal)";
        return false;
    }
    
    if(!isBuy && candle.isHammer)
    {
        reason = "Hammer pattern (bullish reversal)";
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate multi-candle setup                                      |
//+------------------------------------------------------------------+
bool CGrandeCandleAnalyzer::ValidateMultiCandleSetup(bool isBuy, int shift, string &reason)
{
    // Check last 3 candles
    int bullishCount = 0;
    int bearishCount = 0;
    
    for(int i = shift; i < shift + 3; i++)
    {
        CandleStructure candle = AnalyzeCandleStructure(i);
        if(candle.isBullish) bullishCount++;
        if(candle.isBearish) bearishCount++;
    }
    
    // Don't enter if all recent candles are against direction
    if(isBuy && bearishCount == 3)
    {
        reason = "Last 3 candles are bearish - strong downtrend";
        return false;
    }
    
    if(!isBuy && bullishCount == 3)
    {
        reason = "Last 3 candles are bullish - strong uptrend";
        return false;
    }
    
    // Check for engulfing patterns against direction
    MultiCandlePattern pattern = AnalyzeMultiCandlePattern(shift, 3);
    
    if(isBuy && pattern.isBearishEngulfing)
    {
        reason = "Bearish engulfing pattern detected";
        return false;
    }
    
    if(!isBuy && pattern.isBullishEngulfing)
    {
        reason = "Bullish engulfing pattern detected";
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if candle is a pin bar                                     |
//+------------------------------------------------------------------+
bool CGrandeCandleAnalyzer::IsPinBar(int shift, bool &isBullish)
{
    CandleStructure candle = AnalyzeCandleStructure(shift);
    
    if(candle.isPinBar)
    {
        isBullish = candle.hasLongLowerWick;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check for engulfing pattern                                      |
//+------------------------------------------------------------------+
bool CGrandeCandleAnalyzer::IsEngulfingPattern(int shift, bool &isBullish)
{
    MultiCandlePattern pattern = AnalyzeMultiCandlePattern(shift, 2);
    
    if(pattern.isBullishEngulfing)
    {
        isBullish = true;
        return true;
    }
    
    if(pattern.isBearishEngulfing)
    {
        isBullish = false;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check for inside bar pattern                                     |
//+------------------------------------------------------------------+
bool CGrandeCandleAnalyzer::IsInsideBar(int shift)
{
    MultiCandlePattern pattern = AnalyzeMultiCandlePattern(shift, 2);
    return pattern.isInsideBar;
}

//+------------------------------------------------------------------+
//| Check if candle has rejection wick                               |
//+------------------------------------------------------------------+
bool CGrandeCandleAnalyzer::HasRejectionWick(int shift, bool checkUpper)
{
    CandleStructure candle = AnalyzeCandleStructure(shift);
    
    if(checkUpper)
        return candle.hasLongUpperWick;
    else
        return candle.hasLongLowerWick;
}

//+------------------------------------------------------------------+
//| Calculate momentum strength relative to ATR                      |
//+------------------------------------------------------------------+
double CGrandeCandleAnalyzer::GetMomentumStrength(int shift, double atr)
{
    if(atr <= 0)
        return 0;
    
    CandleStructure candle = AnalyzeCandleStructure(shift);
    return candle.bodySize / atr;
}

//+------------------------------------------------------------------+
//| Check if candle shows momentum                                   |
//+------------------------------------------------------------------+
bool CGrandeCandleAnalyzer::IsMomentumCandle(int shift, double atr, double threshold)
{
    double strength = GetMomentumStrength(shift, atr);
    return (strength > threshold);
}

//+------------------------------------------------------------------+
//| Check if candle is consolidation (small range)                   |
//+------------------------------------------------------------------+
bool CGrandeCandleAnalyzer::IsConsolidationCandle(int shift, double atr)
{
    if(atr <= 0)
        return false;
    
    CandleStructure candle = AnalyzeCandleStructure(shift);
    return (candle.totalRange < atr * 0.5); // Less than 50% of ATR
}

//+------------------------------------------------------------------+
//| Check if consecutive candles are against direction               |
//+------------------------------------------------------------------+
bool CGrandeCandleAnalyzer::AreConsecutiveCandlesAgainstDirection(bool isBuy, int count)
{
    int againstCount = 0;
    
    for(int i = 0; i < count; i++)
    {
        CandleStructure candle = AnalyzeCandleStructure(i);
        
        if(isBuy && candle.isBearish)
            againstCount++;
        else if(!isBuy && candle.isBullish)
            againstCount++;
    }
    
    return (againstCount == count);
}

//+------------------------------------------------------------------+
//| Check for recent rejection at key level                          |
//+------------------------------------------------------------------+
bool CGrandeCandleAnalyzer::HasRecentRejection(bool atResistance, int lookback)
{
    for(int i = 0; i < lookback; i++)
    {
        CandleStructure candle = AnalyzeCandleStructure(i);
        
        if(atResistance && candle.hasLongUpperWick && !candle.hasLongLowerWick)
            return true; // Rejection at resistance
        
        if(!atResistance && candle.hasLongLowerWick && !candle.hasLongUpperWick)
            return true; // Rejection at support (bounce)
    }
    
    return false;
}
//+------------------------------------------------------------------+

