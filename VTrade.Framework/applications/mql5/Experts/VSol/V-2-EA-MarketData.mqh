//+------------------------------------------------------------------+
//|                                             V-2-EA-MarketData.mqh |
//|                        Market Data Analysis and Price Level Module |
//|                           Copyright 2024, Your Company Name        |
//|                                     https://www.yourwebsite.com    |
//+------------------------------------------------------------------+
#property copyright "Your Company Name"
#property link      "https://www.yourwebsite.com"
#property version   "1.01"
#property description "Market data analysis and price level detection module"

//+------------------------------------------------------------------+
//| Structure Definitions                                              |
//+------------------------------------------------------------------+
struct STouch
{
    datetime time;       // When the touch occurred
    double   price;     // Exact price of the touch
    double   strength;  // How close to the exact level (0.0-1.0)
    bool     isValid;   // Whether this is a valid touch or not a spike
};

struct SKeyLevel
{
    double    price;           // The price level
    int       touchCount;      // Number of times price touched this level
    bool      isResistance;    // True for resistance, false for support
    datetime  firstTouch;      // Time of first touch
    datetime  lastTouch;       // Time of last touch
    double    strength;        // Relative strength of the level (0.0-1.0)
    STouch    touches[];      // Array of all touches at this level
};

//+------------------------------------------------------------------+
//| Market Data Analysis Class                                         |
//+------------------------------------------------------------------+
class CV2EAMarketData
{
private:
    //--- Debug and Logging
    static bool     m_showDebugPrints;    // Controls debug message output
    
    //--- Pivot Point Cache
    static datetime m_lastDailyUpdate;    // Last update time for daily pivots
    static double   m_cachedPivot;        // Cached daily pivot point
    static double   m_cachedR1;           // Cached daily R1 level
    static double   m_cachedR2;           // Cached daily R2 level
    static double   m_cachedS1;           // Cached daily S1 level
    static double   m_cachedS2;           // Cached daily S2 level
    
    //--- Level Detection Settings
    static int      m_lookbackPeriod;         // Bars to analyze for level detection
    static double   m_minStrengthThreshold;   // Min level strength (0.0-1.0)
    static double   m_touchZoneSize;          // Price zone size for touch detection
    static int      m_minTouchCount;          // Min touches for valid level
    
    //--- Level Scoring Parameters
    static double   m_touchScoreWeight;       // Weight of touch count (0.0-1.0)
    static double   m_recencyWeight;          // Weight of recent touches (0.0-1.0)
    static double   m_durationWeight;         // Weight of level duration (0.0-1.0)
    static int      m_minLevelDurationHours;  // Min hours between touches
    
    //--- Volume Analysis Settings
    static double   m_volumeMultiplier;       // Required volume above average
    static ENUM_APPLIED_VOLUME m_volumeType;  // Volume data type to use

    //--- Private Helper Methods
    static bool     IsNearExistingLevel(const double price, const SKeyLevel &levels[], const int count);
    static double   CalculateLevelStrength(const SKeyLevel &level);
    static bool     IsValidTouch(const double &prices[], const datetime &times[], 
                                const int touchIndex, const int lookback=3);

public:
    //--- Initialization and Configuration
    static void Init(bool showDebugPrints=false);
    static void ConfigureLevelDetection(int lookbackPeriod,
                                      double minStrength,
                                      double touchZone,
                                      int minTouches,
                                      double touchScoreWeight,
                                      double recencyWeight,
                                      double durationWeight,
                                      int minDurationHours);
    static void ConfigureVolumeAnalysis(double volumeMultiplier,
                                      ENUM_APPLIED_VOLUME volumeType);
    static void ResetCache(void);

    //--- Configuration Getters
    static double GetTouchZoneSize()      { return m_touchZoneSize; }
    static double GetVolumeMultiplier()   { return m_volumeMultiplier; }
    static int    GetMinTouchCount()      { return m_minTouchCount; }
    static double GetMinStrength()        { return m_minStrengthThreshold; }
    
    //--- Market Analysis Methods
    static bool GetDailyPivotPoints(string symbol, double &pivot, double &r1, double &r2, 
                                  double &s1, double &s2);
    static bool GetWeeklyPivotPoints(string symbol, double &pivot, double &r1, double &r2, 
                                   double &s1, double &s2);
    static bool GetPriceAction(string symbol, ENUM_TIMEFRAMES timeframe, int lookback,
                             double &highestHigh, double &lowestLow, double &averageRange);
    static double GetATR(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift=1);
    static double GetStdDev(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift=1);
    static bool GetVolumeProfile(string symbol, ENUM_TIMEFRAMES timeframe, int lookback,
                               double &valueAreaHigh, double &valueAreaLow, double &poc);
    
    //--- Key Level Analysis Methods
    static bool FindKeyLevels(string symbol, SKeyLevel &outStrongestLevel);
    static bool CountTouchesEnhanced(string symbol, const double &highPrices[], 
                                   const double &lowPrices[], const datetime &times[], 
                                   const double level, SKeyLevel &outLevel);

    //--- Volume Analysis Methods
    static bool DoesVolumeMeetRequirement(string symbol, const int lookback);
    static bool GetVolumeData(string symbol, long &volumes[], const int count);

    //--- Price Analysis Utilities
    static bool IsATRDistanceValid(string symbol, double price1, double price2, 
                                 int atrPeriod, double multiplier);
    static bool IsPriceInZone(string symbol, double price, double zonePrice, double zoneSize);
    static bool HasPriceClearedZone(string symbol, double zonePrice, double clearanceMultiple,
                                  double zoneSize);
    static double GetNormalizedPrice(string symbol, double price, int digits=0);
    static int GetBarsSince(string symbol, datetime startTime);
    static bool CalculateATRBasedLevels(string symbol, bool isBullish, double basePrice,
                                      int atrPeriod, double slMultiplier, double tpMultiplier,
                                      double &outSL, double &outTP);
};

//+------------------------------------------------------------------+
//| Initialize static members with default values                      |
//+------------------------------------------------------------------+
bool     CV2EAMarketData::m_showDebugPrints = false;
datetime CV2EAMarketData::m_lastDailyUpdate = 0;
double   CV2EAMarketData::m_cachedPivot = 0.0;
double   CV2EAMarketData::m_cachedR1 = 0.0;
double   CV2EAMarketData::m_cachedR2 = 0.0;
double   CV2EAMarketData::m_cachedS1 = 0.0;
double   CV2EAMarketData::m_cachedS2 = 0.0;

//--- Level Detection Parameters
int      CV2EAMarketData::m_lookbackPeriod = 24;         // 24 bars lookback
double   CV2EAMarketData::m_minStrengthThreshold = 0.65; // 65% minimum strength
double   CV2EAMarketData::m_touchZoneSize = 0.0004;      // 4 pips zone size
int      CV2EAMarketData::m_minTouchCount = 2;           // Minimum 2 touches

//--- Scoring Weights (must sum to 1.0)
double   CV2EAMarketData::m_touchScoreWeight = 0.5;      // 50% touch weight
double   CV2EAMarketData::m_recencyWeight = 0.3;         // 30% recency weight
double   CV2EAMarketData::m_durationWeight = 0.2;        // 20% duration weight
int      CV2EAMarketData::m_minLevelDurationHours = 12;  // 12 hours minimum

//--- Volume Analysis Parameters
double   CV2EAMarketData::m_volumeMultiplier = 2.0;      // 2x average volume required
ENUM_APPLIED_VOLUME CV2EAMarketData::m_volumeType = VOLUME_TICK;

//+------------------------------------------------------------------+
//| Initialize the market data analyzer                                |
//+------------------------------------------------------------------+
void CV2EAMarketData::Init(bool showDebugPrints=false)
{
    m_showDebugPrints = showDebugPrints;
    ResetCache();
}

//+------------------------------------------------------------------+
//| Configure level detection parameters                               |
//+------------------------------------------------------------------+
void CV2EAMarketData::ConfigureLevelDetection(
    int lookbackPeriod,
    double minStrength,
    double touchZone,
    int minTouches,
    double touchScoreWeight,
    double recencyWeight,
    double durationWeight,
    int minDurationHours)
{
    m_lookbackPeriod = lookbackPeriod;
    m_minStrengthThreshold = minStrength;
    m_touchZoneSize = touchZone;
    m_minTouchCount = minTouches;
    m_touchScoreWeight = touchScoreWeight;
    m_recencyWeight = recencyWeight;
    m_durationWeight = durationWeight;
    m_minLevelDurationHours = minDurationHours;
}

//+------------------------------------------------------------------+
//| Configure volume analysis parameters                               |
//+------------------------------------------------------------------+
void CV2EAMarketData::ConfigureVolumeAnalysis(
    double volumeMultiplier,
    ENUM_APPLIED_VOLUME volumeType)
{
    m_volumeMultiplier = volumeMultiplier;
    m_volumeType = volumeType;
}

//+------------------------------------------------------------------+
//| Reset cached values                                               |
//+------------------------------------------------------------------+
void CV2EAMarketData::ResetCache(void)
{
    m_lastDailyUpdate = 0;
    m_cachedPivot = 0.0;
    m_cachedR1 = 0.0;
    m_cachedR2 = 0.0;
    m_cachedS1 = 0.0;
    m_cachedS2 = 0.0;
}

//+------------------------------------------------------------------+
//| Get daily pivot points with caching                                |
//+------------------------------------------------------------------+
bool CV2EAMarketData::GetDailyPivotPoints(string symbol, double &pivot, double &r1, double &r2, 
                                         double &s1, double &s2)
{
    // Check if we can use cached values
    datetime currentDailyTime = iTime(symbol, PERIOD_D1, 0);
    if(currentDailyTime == m_lastDailyUpdate && m_cachedPivot != 0.0)
    {
        pivot = m_cachedPivot;
        r1 = m_cachedR1;
        r2 = m_cachedR2;
        s1 = m_cachedS1;
        s2 = m_cachedS2;
        return true;
    }
    
    // Get daily price data
    MqlRates dailyRates[];
    ArraySetAsSeries(dailyRates, true);
    if(CopyRates(symbol, PERIOD_D1, 0, 2, dailyRates) < 2)
    {
        if(m_showDebugPrints)
            Print("❌ [GetDailyPivotPoints] Unable to copy daily bars, error =", GetLastError());
        return false;
    }

    // Calculate pivot points using standard formula
    double prevHigh = dailyRates[1].high;
    double prevLow = dailyRates[1].low;
    double prevClose = dailyRates[1].close;

    pivot = (prevHigh + prevLow + prevClose) / 3.0;
    r1 = 2.0 * pivot - prevLow;    // First resistance
    s1 = 2.0 * pivot - prevHigh;   // First support
    r2 = pivot + (r1 - s1);        // Second resistance
    s2 = pivot - (r1 - s1);        // Second support
    
    // Cache the calculated values
    m_lastDailyUpdate = currentDailyTime;
    m_cachedPivot = pivot;
    m_cachedR1 = r1;
    m_cachedR2 = r2;
    m_cachedS1 = s1;
    m_cachedS2 = s2;

    return true;
}

//+------------------------------------------------------------------+
//| Get ATR value with error handling                                  |
//+------------------------------------------------------------------+
double CV2EAMarketData::GetATR(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift=1)
{
    // Create ATR indicator
    int handle = iATR(symbol, timeframe, period);
    if(handle == INVALID_HANDLE)
    {
        if(m_showDebugPrints)
            Print("❌ [GetATR] Failed to create ATR indicator");
        return 0.0;
    }
    
    // Copy ATR data
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(handle, 0, shift, 1, atr) <= 0)
    {
        if(m_showDebugPrints)
            Print("❌ [GetATR] Failed to copy ATR data");
        IndicatorRelease(handle);
        return 0.0;
    }
    
    double result = atr[0];
    IndicatorRelease(handle);
    return result;
}

//+------------------------------------------------------------------+
//| Check if price level is near existing levels                       |
//+------------------------------------------------------------------+
bool CV2EAMarketData::IsNearExistingLevel(const double price, const SKeyLevel &levels[], 
                                         const int count)
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
    // Calculate touch score based on quality of touches
    double totalTouchStrength = 0.0;
    for(int i = 0; i < ArraySize(level.touches); i++)
        totalTouchStrength += level.touches[i].strength;
    
    double touchScore = MathMin(totalTouchStrength / m_minTouchCount, 3.0);
    
    // Calculate recency score with exponential decay
    datetime now = TimeCurrent();
    double hoursElapsed = (double)(now - level.lastTouch) / 3600.0;
    double recencyScore = MathExp(-hoursElapsed / (m_lookbackPeriod * 12.0));
    
    // Calculate duration score with logarithmic scaling
    double hoursDuration = (double)(level.lastTouch - level.firstTouch) / 3600.0;
    double normalizedDuration = hoursDuration / (double)m_minLevelDurationHours;
    double durationScore = MathMin(1.0 + MathLog(normalizedDuration) / 1.5, 1.5);
    
    // Return weighted average of scores
    return (touchScore * m_touchScoreWeight + 
            recencyScore * m_recencyWeight + 
            durationScore * m_durationWeight);
}

//+------------------------------------------------------------------+
//| Validate a price touch                                            |
//+------------------------------------------------------------------+
bool CV2EAMarketData::IsValidTouch(const double &prices[], const datetime &times[], 
                                  const int touchIndex, const int lookback=3)
{
    int arraySize = ArraySize(prices);
    if(touchIndex < 0 || touchIndex >= arraySize)
    {
        if(m_showDebugPrints)
            Print("❌ [IsValidTouch] Touch index out of bounds");
        return false;
    }
    
    // Handle recent touches differently
    bool isRecentTouch = (touchIndex + lookback >= arraySize);
    int requiredBarsBack = isRecentTouch ? 1 : lookback;
    
    // Handle early bar touches with limited history
    if(touchIndex - requiredBarsBack < 0)
    {
        int availableBars = touchIndex;
        if(availableBars > 0)
        {
            double price = prices[touchIndex];
            for(int i = 1; i <= availableBars; i++)
            {
                if(MathAbs(prices[touchIndex - i] - price) <= m_touchZoneSize)
                {
                    if(m_showDebugPrints)
                        Print("ℹ️ [IsValidTouch] Limited history but found confirming touch");
                    return true;
                }
            }
        }
        if(m_showDebugPrints)
            Print("ℹ️ [IsValidTouch] Limited history, treating as potentially valid");
        return true;
    }
    
    // Standard touch validation
    double price = prices[touchIndex];
    datetime time = times[touchIndex];
    
    if(isRecentTouch)
    {
        // For recent touches, check previous bars only
        for(int i = 1; i <= requiredBarsBack; i++)
        {
            if(touchIndex - i >= 0 && MathAbs(prices[touchIndex - i] - price) <= m_touchZoneSize)
                return true;
        }
    }
    else
    {
        // For non-recent touches, check both previous and following bars
        for(int i = 1; i <= lookback; i++)
        {
            if(touchIndex - i >= 0 && MathAbs(prices[touchIndex - i] - price) <= m_touchZoneSize)
                return true;
                
            if(touchIndex + i < arraySize && MathAbs(prices[touchIndex + i] - price) <= m_touchZoneSize)
                return true;
        }
    }
    
    return false;
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
                newLevel.isResistance = true;
                
                if(CountTouchesEnhanced(symbol, highPrices, lowPrices, times, level, newLevel))
                {
                    if(newLevel.strength >= m_minStrengthThreshold)
                    {
                        ArrayResize(tempLevels, levelCount + 1);
                        tempLevels[levelCount] = newLevel;
                        levelCount++;
                    }
                }
            }
        }
        
        // Check swing lows
        if(lowPrices[i] < lowPrices[i-1] && lowPrices[i] < lowPrices[i+1])
        {
            double level = lowPrices[i];
            if(!IsNearExistingLevel(level, tempLevels, levelCount))
            {
                SKeyLevel newLevel;
                newLevel.isResistance = false;
                
                if(CountTouchesEnhanced(symbol, highPrices, lowPrices, times, level, newLevel))
                {
                    if(newLevel.strength >= m_minStrengthThreshold)
                    {
                        ArrayResize(tempLevels, levelCount + 1);
                        tempLevels[levelCount] = newLevel;
                        levelCount++;
                    }
                }
            }
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
//| Count and validate touches at a price level                        |
//+------------------------------------------------------------------+
bool CV2EAMarketData::CountTouchesEnhanced(string symbol, const double &highPrices[], 
                                         const double &lowPrices[], const datetime &times[], 
                                         const double level, SKeyLevel &outLevel)
{
    // Create local copies of arrays to work with
    double localHighs[];
    double localLows[];
    datetime localTimes[];
    
    int highSize = ArraySize(highPrices);
    int lowSize = ArraySize(lowPrices);
    int timeSize = ArraySize(times);
    
    // Validate array sizes
    if(highSize < m_lookbackPeriod || lowSize < m_lookbackPeriod || timeSize < m_lookbackPeriod)
    {
        if(m_showDebugPrints)
            Print("❌ [CountTouchesEnhanced] Invalid array sizes");
        return false;
    }
    
    // Copy arrays to local variables
    ArrayResize(localHighs, highSize);
    ArrayResize(localLows, lowSize);
    ArrayResize(localTimes, timeSize);
    
    for(int i = 0; i < highSize; i++)
        localHighs[i] = highPrices[i];
    for(int i = 0; i < lowSize; i++)
        localLows[i] = lowPrices[i];
    for(int i = 0; i < timeSize; i++)
        localTimes[i] = times[i];

    // Initialize output level
    outLevel.price = level;
    outLevel.touchCount = 0;
    outLevel.firstTouch = 0;
    outLevel.lastTouch = 0;
    ArrayResize(outLevel.touches, 0);
    
    // Count and validate touches
    int touches = 0;
    datetime firstTouch = 0;
    datetime lastTouch = 0;
    
    for(int j = 0; j < m_lookbackPeriod; j++)
    {
        // Check if price is within touch zone
        if(MathAbs(localHighs[j] - level) <= m_touchZoneSize ||
           MathAbs(localLows[j] - level) <= m_touchZoneSize)
        {
            // Determine if it's a high or low touch
            bool isHighTouch = (MathAbs(localHighs[j] - level) <= m_touchZoneSize);
            double touchPrice = isHighTouch ? localHighs[j] : localLows[j];
            
            // Create temporary array for validation
            double priceArray[];
            ArrayResize(priceArray, isHighTouch ? highSize : lowSize);
            
            // Copy the appropriate price array
            for(int i = 0; i < ArraySize(priceArray); i++)
                priceArray[i] = isHighTouch ? localHighs[i] : localLows[i];
            
            // Validate the touch
            if(IsValidTouch(priceArray, localTimes, j))
            {
                // Record the touch
                int touchIndex = ArraySize(outLevel.touches);
                ArrayResize(outLevel.touches, touchIndex + 1);
                
                outLevel.touches[touchIndex].time = localTimes[j];
                outLevel.touches[touchIndex].price = touchPrice;
                outLevel.touches[touchIndex].strength = 
                    1.0 - MathAbs(touchPrice - level) / m_touchZoneSize;
                outLevel.touches[touchIndex].isValid = true;
                
                // Update touch statistics
                touches++;
                if(firstTouch == 0 || localTimes[j] < firstTouch) firstTouch = localTimes[j];
                if(localTimes[j] > lastTouch) lastTouch = localTimes[j];
            }
        }
    }
    
    // Update level information
    outLevel.touchCount = touches;
    outLevel.firstTouch = firstTouch;
    outLevel.lastTouch = lastTouch;
    
    // Calculate and validate level strength
    if(touches >= m_minTouchCount)
    {
        outLevel.strength = CalculateLevelStrength(outLevel);
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get volume data based on type                                     |
//+------------------------------------------------------------------+
bool CV2EAMarketData::GetVolumeData(string symbol, long &volumes[], const int count)
{
    ArraySetAsSeries(volumes, true);
    
    // Get volume data based on configured type
    if(m_volumeType == VOLUME_REAL)
    {
        if(CopyRealVolume(symbol, PERIOD_CURRENT, 0, count, volumes) <= 0)
        {
            if(m_showDebugPrints)
                Print("❌ [GetVolumeData] Failed to copy real volume data");
            return false;
        }
    }
    else // VOLUME_TICK
    {
        if(CopyTickVolume(symbol, PERIOD_CURRENT, 0, count, volumes) <= 0)
        {
            if(m_showDebugPrints)
                Print("❌ [GetVolumeData] Failed to copy tick volume data");
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Get volume metrics for analysis                                    |
//+------------------------------------------------------------------+
bool CV2EAMarketData::DoesVolumeMeetRequirement(string symbol, const int lookback)
{
    // Get volume data
    long volumes[];
    if(!GetVolumeData(symbol, volumes, lookback + 1))
        return false;

    // Calculate average volume
    long sumVol = 0;
    int countVol = 0;
    long maxVol = 0;
    
    for(int i = 1; i < lookback + 1; i++)  // Skip current bar
    {
        if(volumes[i] > 0)
        {
            sumVol += volumes[i];
            countVol++;
            maxVol = MathMax(maxVol, volumes[i]);
        }
    }
    
    if(countVol == 0)
    {
        if(m_showDebugPrints)
            Print("❌ [DoesVolumeMeetRequirement] No valid volume data found");
        return false;
    }
    
    // Calculate volume metrics
    double avgVol = (double)sumVol / (double)countVol;
    double currentVol = (double)volumes[1];  // Previous bar's volume
    
    if(avgVol <= 0)
    {
        if(m_showDebugPrints)
            Print("❌ [DoesVolumeMeetRequirement] Average volume is zero");
        return false;
    }
    
    // Return true if we have valid volume data
    return (currentVol >= avgVol * m_volumeMultiplier);
}

//+------------------------------------------------------------------+
//| Check if price has broken a key level                             |
//+------------------------------------------------------------------+
bool CV2EAMarketData::IsATRDistanceValid(string symbol, double price1, double price2, 
                                 int atrPeriod, double multiplier)
{
    double atr = GetATR(symbol, PERIOD_CURRENT, atrPeriod);
    if(atr <= 0)
        return false;
            
    double minDist = atr * multiplier;
    double actualDist = MathAbs(price1 - price2);
        
    return (actualDist >= minDist);
}

//+------------------------------------------------------------------+
//| Check if price level is near existing levels                       |
//+------------------------------------------------------------------+
bool CV2EAMarketData::IsPriceInZone(string symbol, double price, double zonePrice, double zoneSize)
{
    double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double zoneSizePoints = zoneSize * pointSize;
        
    return (MathAbs(price - zonePrice) <= zoneSizePoints);
}

//+------------------------------------------------------------------+
//| Check if price has cleared a zone                                 |
//+------------------------------------------------------------------+
bool CV2EAMarketData::HasPriceClearedZone(string symbol, double zonePrice, double clearanceMultiple,
                                  double zoneSize)
{
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double clearanceZone = zoneSize * clearanceMultiple * pointSize;
        
    return (MathAbs(currentPrice - zonePrice) >= clearanceZone);
}

//+------------------------------------------------------------------+
//| Get normalized price                                             |
//+------------------------------------------------------------------+
double CV2EAMarketData::GetNormalizedPrice(string symbol, double price, int digits=0)
{
    if(digits == 0)
        digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
            
    return NormalizeDouble(price, digits);
}

//+------------------------------------------------------------------+
//| Get bars since a specific time                                   |
//+------------------------------------------------------------------+
int CV2EAMarketData::GetBarsSince(string symbol, datetime startTime)
{
    return iBarShift(symbol, PERIOD_CURRENT, startTime, false);
}

//+------------------------------------------------------------------+
//| Calculate ATR-based levels                                        |
//+------------------------------------------------------------------+
bool CV2EAMarketData::CalculateATRBasedLevels(string symbol, bool isBullish, double basePrice,
                                      int atrPeriod, double slMultiplier, double tpMultiplier,
                                      double &outSL, double &outTP)
{
    double atr = GetATR(symbol, PERIOD_CURRENT, atrPeriod);
    if(atr <= 0)
        return false;
            
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double slDistance = atr * slMultiplier;
    double tpDistance = atr * tpMultiplier;
        
    if(isBullish)
    {
        outSL = NormalizeDouble(basePrice - slDistance, digits);
        outTP = NormalizeDouble(basePrice + tpDistance, digits);
    }
    else
    {
        outSL = NormalizeDouble(basePrice + slDistance, digits);
        outTP = NormalizeDouble(basePrice - tpDistance, digits);
    }
        
    return true;
} 