//+------------------------------------------------------------------+
//|                                             V-2-EA-MarketData.mqh |
//|                                    Market Data Analysis Functions  |
//+------------------------------------------------------------------+
#property copyright "Your Company"
#property link      "Your Link"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Structure Definitions                                              |
//+------------------------------------------------------------------+
struct STouch
{
    datetime time;       // When the touch occurred
    double   price;     // Exact price of the touch
    double   strength;  // How close to the exact level (0.0-1.0)
    bool     isValid;   // Whether this is a valid touch or just a spike
};

struct SKeyLevel
{
    double    price;           // The price level
    int       touchCount;      // Number of times price touched this level
    bool      isResistance;    // Whether this is resistance (true) or support (false)
    datetime  firstTouch;      // Time of first touch
    datetime  lastTouch;       // Time of last touch
    double    strength;        // Relative strength of the level
    STouch    touches[];      // Dynamic array of touches
};

//+------------------------------------------------------------------+
//| Market Data Analysis Class                                         |
//+------------------------------------------------------------------+
class CV2EAMarketData
{
private:
    static bool     m_showDebugPrints;    // Debug mode
    
    // Cache variables for optimization
    static datetime m_lastDailyUpdate;
    static double   m_cachedPivot;
    static double   m_cachedR1;
    static double   m_cachedR2;
    static double   m_cachedS1;
    static double   m_cachedS2;
    
    // Level detection parameters
    static int      m_lookbackPeriod;
    static double   m_minStrengthThreshold;
    static double   m_touchZoneSize;
    static int      m_minTouchCount;
    static double   m_touchScoreWeight;
    static double   m_recencyWeight;
    static double   m_durationWeight;
    static int      m_minLevelDurationHours;
    
    // Private helper methods
    static bool     IsNearExistingLevel(const double price, const SKeyLevel &levels[], const int count);
    static double   CalculateLevelStrength(const SKeyLevel &level);
    static bool     IsValidTouch(const double &prices[], const datetime &times[], const int touchIndex, const int lookback=3);

public:
    //--- Initialization
    static void Init(bool showDebugPrints, int lookbackPeriod=24, double minStrength=0.65,
                    double touchZone=0.0004, int minTouches=2)
    {
        m_showDebugPrints = showDebugPrints;
        m_lookbackPeriod = lookbackPeriod;
        m_minStrengthThreshold = minStrength;
        m_touchZoneSize = touchZone;
        m_minTouchCount = minTouches;
        
        // Initialize weights
        m_touchScoreWeight = 0.5;
        m_recencyWeight = 0.3;
        m_durationWeight = 0.2;
        m_minLevelDurationHours = 12;
        
        ResetCache();
    }
    
    //--- Reset cache
    static void ResetCache(void)
    {
        m_lastDailyUpdate = 0;
        m_cachedPivot = 0;
        m_cachedR1 = 0;
        m_cachedR2 = 0;
        m_cachedS1 = 0;
        m_cachedS2 = 0;
    }
    
    //--- Market Analysis Methods
    static bool GetDailyPivotPoints(string symbol, double &pivot, double &r1, double &r2, double &s1, double &s2);
    static bool GetWeeklyPivotPoints(string symbol, double &pivot, double &r1, double &r2, double &s1, double &s2);
    static bool GetPriceAction(string symbol, ENUM_TIMEFRAMES timeframe, int lookback,
                             double &highestHigh, double &lowestLow, double &averageRange);
    static double GetATR(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift = 1);
    static double GetStdDev(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift = 1);
    static bool GetVolumeProfile(string symbol, ENUM_TIMEFRAMES timeframe, int lookback,
                               double &valueAreaHigh, double &valueAreaLow, double &poc);
    
    //--- Key Level Analysis
    static bool FindKeyLevels(string symbol, SKeyLevel &outStrongestLevel);
    static bool IsBreakoutCandidate(string symbol, const SKeyLevel &level, bool &isBullish);
};

// Initialize static members
bool     CV2EAMarketData::m_showDebugPrints = false;
datetime CV2EAMarketData::m_lastDailyUpdate = 0;
double   CV2EAMarketData::m_cachedPivot = 0;
double   CV2EAMarketData::m_cachedR1 = 0;
double   CV2EAMarketData::m_cachedR2 = 0;
double   CV2EAMarketData::m_cachedS1 = 0;
double   CV2EAMarketData::m_cachedS2 = 0;

// Initialize level detection parameters
int      CV2EAMarketData::m_lookbackPeriod = 24;
double   CV2EAMarketData::m_minStrengthThreshold = 0.65;
double   CV2EAMarketData::m_touchZoneSize = 0.0004;
int      CV2EAMarketData::m_minTouchCount = 2;
double   CV2EAMarketData::m_touchScoreWeight = 0.5;
double   CV2EAMarketData::m_recencyWeight = 0.3;
double   CV2EAMarketData::m_durationWeight = 0.2;
int      CV2EAMarketData::m_minLevelDurationHours = 12;

//+------------------------------------------------------------------+
//| Get daily pivot points with caching                                |
//+------------------------------------------------------------------+
bool CV2EAMarketData::GetDailyPivotPoints(string symbol, double &pivot, double &r1, double &r2, double &s1, double &s2)
{
    // Check if we can use cached values
    datetime currentDailyTime = iTime(symbol, PERIOD_D1, 0);
    if(currentDailyTime == m_lastDailyUpdate && m_cachedPivot != 0)
    {
        pivot = m_cachedPivot;
        r1 = m_cachedR1;
        r2 = m_cachedR2;
        s1 = m_cachedS1;
        s2 = m_cachedS2;
        return true;
    }
    
    // Calculate new values
    MqlRates dailyRates[];
    ArrayResize(dailyRates, 2);
    ArraySetAsSeries(dailyRates, true);

    if(CopyRates(symbol, PERIOD_D1, 0, 2, dailyRates) < 2)
    {
        if(m_showDebugPrints)
            Print("❌ [GetDailyPivotPoints] Unable to copy daily bars, error =", GetLastError());
        return false;
    }

    double prevDayHigh = dailyRates[1].high;
    double prevDayLow = dailyRates[1].low;
    double prevDayClose = dailyRates[1].close;

    // Calculate pivot points
    pivot = (prevDayHigh + prevDayLow + prevDayClose) / 3.0;
    r1 = 2.0 * pivot - prevDayLow;
    s1 = 2.0 * pivot - prevDayHigh;
    r2 = pivot + (r1 - s1);
    s2 = pivot - (r1 - s1);
    
    // Cache the values
    m_lastDailyUpdate = currentDailyTime;
    m_cachedPivot = pivot;
    m_cachedR1 = r1;
    m_cachedR2 = r2;
    m_cachedS1 = s1;
    m_cachedS2 = s2;

    return true;
}

//+------------------------------------------------------------------+
//| Get ATR value                                                      |
//+------------------------------------------------------------------+
double CV2EAMarketData::GetATR(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift = 1)
{
    int handle = iATR(symbol, timeframe, period);
    if(handle == INVALID_HANDLE)
    {
        if(m_showDebugPrints)
            Print("❌ [GetATR] Failed to create ATR indicator");
        return 0;
    }
    
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(handle, 0, shift, 1, atr) <= 0)
    {
        if(m_showDebugPrints)
            Print("❌ [GetATR] Failed to copy ATR data");
        IndicatorRelease(handle);
        return 0;
    }
    
    double result = atr[0];
    IndicatorRelease(handle);
    return result;
}

//+------------------------------------------------------------------+
//| Check if price level is near existing levels                       |
//+------------------------------------------------------------------+
bool CV2EAMarketData::IsNearExistingLevel(const double price, const SKeyLevel &levels[], const int count)
{
    for(int i = 0; i < count; i++)
    {
        if(MathAbs(price - levels[i].price) < m_touchZoneSize)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Calculate strength of a key level                                  |
//+------------------------------------------------------------------+
double CV2EAMarketData::CalculateLevelStrength(const SKeyLevel &level)
{
    // Touch score with higher cap and weighted by touch quality
    double totalTouchStrength = 0;
    for(int i = 0; i < ArraySize(level.touches); i++)
        totalTouchStrength += level.touches[i].strength;
    
    double touchScore = MathMin(totalTouchStrength / m_minTouchCount, 3.0);
    
    // Recency score with adjusted decay
    datetime now = TimeCurrent();
    double hoursElapsed = (double)(now - level.lastTouch) / 3600.0;
    double recencyScore = MathExp(-hoursElapsed / (m_lookbackPeriod * 12.0));
    
    // Duration score with enhanced scaling
    double hoursDuration = (double)(level.lastTouch - level.firstTouch) / 3600.0;
    double normalizedDuration = hoursDuration / (double)m_minLevelDurationHours;
    double durationScore = MathMin(1.0 + MathLog(normalizedDuration) / 1.5, 1.5);
    
    // Calculate weighted sum
    return (touchScore * m_touchScoreWeight + 
            recencyScore * m_recencyWeight + 
            durationScore * m_durationWeight);
}

//+------------------------------------------------------------------+
//| Find key price levels                                             |
//+------------------------------------------------------------------+
bool CV2EAMarketData::FindKeyLevels(string symbol, SKeyLevel &outStrongestLevel)
{
    // Copy price data
    double highPrices[];
    double lowPrices[];
    datetime times[];
    
    ArraySetAsSeries(highPrices, true);
    ArraySetAsSeries(lowPrices, true);
    ArraySetAsSeries(times, true);

    if(CopyHigh(symbol, PERIOD_CURRENT, 0, m_lookbackPeriod, highPrices) <= 0 ||
       CopyLow(symbol, PERIOD_CURRENT, 0, m_lookbackPeriod, lowPrices) <= 0 ||
       CopyTime(symbol, PERIOD_CURRENT, 0, m_lookbackPeriod, times) <= 0)
    {
        if(m_showDebugPrints)
            Print("❌ [FindKeyLevels] Failed to copy price data");
        return false;
    }

    SKeyLevel tempLevels[];
    int levelCount = 0;

    // Find swing highs and lows
    for(int i = 1; i < m_lookbackPeriod - 1; i++)
    {
        // Check swing highs
        if(highPrices[i] > highPrices[i-1] && highPrices[i] > highPrices[i+1])
        {
            double level = highPrices[i];
            if(!IsNearExistingLevel(level, tempLevels, levelCount))
            {
                SKeyLevel newLevel;
                newLevel.price = level;
                newLevel.isResistance = true;
                
                // Count and validate touches
                int touches = 0;
                datetime firstTouch = times[i];
                datetime lastTouch = times[i];
                
                for(int j = 0; j < m_lookbackPeriod; j++)
                {
                    if(MathAbs(highPrices[j] - level) <= m_touchZoneSize ||
                       MathAbs(lowPrices[j] - level) <= m_touchZoneSize)
                    {
                        if(IsValidTouch(highPrices, times, j))
                        {
                            touches++;
                            if(times[j] < firstTouch) firstTouch = times[j];
                            if(times[j] > lastTouch) lastTouch = times[j];
                        }
                    }
                }
                
                if(touches >= m_minTouchCount)
                {
                    newLevel.touchCount = touches;
                    newLevel.firstTouch = firstTouch;
                    newLevel.lastTouch = lastTouch;
                    newLevel.strength = CalculateLevelStrength(newLevel);
                    
                    if(newLevel.strength >= m_minStrengthThreshold)
                    {
                        ArrayResize(tempLevels, levelCount + 1);
                        tempLevels[levelCount] = newLevel;
                        levelCount++;
                    }
                }
            }
        }
        
        // Check swing lows (similar logic)
        if(lowPrices[i] < lowPrices[i-1] && lowPrices[i] < lowPrices[i+1])
        {
            // ... Similar logic for swing lows ...
        }
    }

    // Find strongest level
    if(levelCount > 0)
    {
        int strongestIdx = 0;
        double maxStrength = tempLevels[0].strength;
        
        for(int i = 1; i < levelCount; i++)
        {
            if(tempLevels[i].strength > maxStrength)
            {
                maxStrength = tempLevels[i].strength;
                strongestIdx = i;
            }
        }
        
        outStrongestLevel = tempLevels[strongestIdx];
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Check if touch is valid                                           |
//+------------------------------------------------------------------+
bool CV2EAMarketData::IsValidTouch(const double &prices[], const datetime &times[], const int touchIndex, const int lookback=3)
{
    if(touchIndex < 0 || touchIndex >= ArraySize(prices))
        return false;
    
    double price = prices[touchIndex];
    datetime time = times[touchIndex];
    
    for(int i = 1; i <= lookback; i++)
    {
        if(MathAbs(prices[touchIndex - i] - price) <= m_touchZoneSize ||
           MathAbs(prices[touchIndex + i] - price) <= m_touchZoneSize)
        {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check if price has broken a key level                             |
//+------------------------------------------------------------------+
bool CV2EAMarketData::IsBreakoutCandidate(string symbol, const SKeyLevel &level, bool &isBullish)
{
    double close = iClose(symbol, PERIOD_CURRENT, 1);
    
    // Simple breakout check - can be enhanced with more conditions
    if(close > level.price)
    {
        isBullish = true;
        return true;
    }
    else if(close < level.price)
    {
        isBullish = false;
        return true;
    }
    
    return false;
} 