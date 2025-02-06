//+------------------------------------------------------------------+
//|                                              V-2-EA-KeyLevels.mqh |
//|                          Key Level Management and Processing       |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.01"

#include <Trade\Trade.mqh>
#include <VErrorDesc.mqh>  // For error descriptions
#include "V-2-EA-MarketData.mqh"  // For SKeyLevel and related structs

//+------------------------------------------------------------------+
//| Constants                                                          |
//+------------------------------------------------------------------+
#define DEFAULT_BUFFER_SIZE 100 // Default size for price buffers

//+------------------------------------------------------------------+
//| Key level management class for detecting and maintaining key levels |
//+------------------------------------------------------------------+
class CV2EAKeyLevels : public CV2EAMarketDataBase
{
private:
    //--- Key Levels Data Members
    SKeyLevel     m_currentKeyLevels[];  ///< Array of current key levels
    int           m_keyLevelCount;       ///< Number of valid key levels
    datetime      m_lastKeyLevelUpdate;  ///< Last time key levels were updated
    bool          m_initialized;         ///< Initialization state
    bool          m_showDebugPrints;     ///< Whether to show debug prints
    double        m_minStrength;         ///< Minimum strength for valid levels
    double        m_touchZone;           ///< Zone around level for touch detection
    int           m_minTouches;          ///< Minimum touches for valid level
    int           m_lookbackPeriod;      ///< Bars to look back for level detection
    int           m_maxBounceDelay;      ///< Maximum bars to wait for bounce

    //--- Internal helper methods
    void QuickSortLevels(SKeyLevel &levels[], int left, int right);
    bool IsNearExistingLevel(const double price);
    bool IsNearExistingLevel(const double price, SKeyLevel &nearestLevel, double &distance);
    bool IsSwingHigh(const double &prices[], int index);
    bool IsSwingLow(const double &prices[], int index);
    int CountTouches(double level, bool isResistance, const double &highs[], 
                     const double &lows[], const datetime &times[], STouchQuality &quality);
    double CalculateLevelStrength(const SKeyLevel &level, const STouchQuality &quality);
    void DebugPrint(string message);

    //--- Market-specific configuration
    bool IsUS500Symbol(string symbol)
    {
        return StringFind(symbol, "US500") >= 0 || 
               StringFind(symbol, "SP500") >= 0 || 
               StringFind(symbol, "SPX500") >= 0;
    }
    
    double GetMarketTouchZone(string symbol, ENUM_TIMEFRAMES timeframe)
    {
        if(IsUS500Symbol(symbol))
        {
            // US500 touch zones in points
            switch(timeframe) {
                case PERIOD_MN1: return 50.0;  // 50 points
                case PERIOD_W1:  return 30.0;  // 30 points
                case PERIOD_D1:  return 20.0;  // 20 points
                case PERIOD_H4:  return 15.0;  // 15 points
                case PERIOD_H1:  return 10.0;  // 10 points
                case PERIOD_M30: return 7.5;   // 7.5 points
                case PERIOD_M15: return 5.0;   // 5 points
                case PERIOD_M5:  return 3.0;   // 3 points
                case PERIOD_M1:  return 2.0;   // 2 points
                default:         return 5.0;   // Default to M15 setting
            }
        }
        else  // Forex
        {
            // Forex touch zones in pips
            switch(timeframe) {
                case PERIOD_MN1: return 0.0050;  // 50 pips
                case PERIOD_W1:  return 0.0030;  // 30 pips
                case PERIOD_D1:  return 0.0020;  // 20 pips
                case PERIOD_H4:  return 0.0015;  // 15 pips
                case PERIOD_H1:  return 0.0010;  // 10 pips
                case PERIOD_M30: return 0.00075; // 7.5 pips
                case PERIOD_M15: return 0.0005;  // 5 pips
                case PERIOD_M5:  return 0.0003;  // 3 pips
                case PERIOD_M1:  return 0.0002;  // 2 pips
                default:         return 0.0005;  // Default to M15 setting
            }
        }
    }
    
    double GetMarketMinStrength(string symbol, ENUM_TIMEFRAMES timeframe)
    {
        if(IsUS500Symbol(symbol))
        {
            // US500 tends to need higher strength thresholds due to more noise
            switch(timeframe) {
                case PERIOD_MN1: return 0.55;  // Monthly levels are more significant
                case PERIOD_W1:  return 0.55;
                case PERIOD_D1:  return 0.60;
                case PERIOD_H4:  return 0.65;
                case PERIOD_H1:  return 0.70;
                case PERIOD_M30: return 0.75;
                case PERIOD_M15: return 0.75;
                case PERIOD_M5:  return 0.80;
                case PERIOD_M1:  return 0.85;
                default:         return 0.70;
            }
        }
        else  // Forex
        {
            // Forex can use slightly lower thresholds due to cleaner price action
            switch(timeframe) {
                case PERIOD_MN1: return 0.50;
                case PERIOD_W1:  return 0.50;
                case PERIOD_D1:  return 0.55;
                case PERIOD_H4:  return 0.60;
                case PERIOD_H1:  return 0.65;
                case PERIOD_M30: return 0.70;
                case PERIOD_M15: return 0.70;
                case PERIOD_M5:  return 0.75;
                case PERIOD_M1:  return 0.80;
                default:         return 0.65;
            }
        }
    }
    
    int GetMarketMinTouches(string symbol, ENUM_TIMEFRAMES timeframe)
    {
        if(IsUS500Symbol(symbol))
        {
            // US500 needs more touches to confirm due to noise
            switch(timeframe) {
                case PERIOD_MN1: return 2;  // Monthly can use fewer touches
                case PERIOD_W1:  return 2;
                case PERIOD_D1:  return 3;
                case PERIOD_H4:  return 3;
                case PERIOD_H1:  return 4;
                case PERIOD_M30: return 4;
                case PERIOD_M15: return 4;
                case PERIOD_M5:  return 5;
                case PERIOD_M1:  return 5;
                default:         return 4;
            }
        }
        else  // Forex
        {
            // Forex can use fewer touches due to cleaner price action
            switch(timeframe) {
                case PERIOD_MN1: return 2;
                case PERIOD_W1:  return 2;
                case PERIOD_D1:  return 2;
                case PERIOD_H4:  return 3;
                case PERIOD_H1:  return 3;
                case PERIOD_M30: return 3;
                case PERIOD_M15: return 4;
                case PERIOD_M5:  return 4;
                case PERIOD_M1:  return 5;
                default:         return 3;
            }
        }
    }
    
    double GetMarketVolatilityAdjustment(string symbol)
    {
        if(IsUS500Symbol(symbol))
        {
            // Use ATR for US500 volatility adjustment
            double atr = iATR(symbol, Period(), 14, 0);
            return atr > 0 ? atr * 0.1 : 1.0;  // Use 10% of ATR
        }
        else  // Forex
        {
            // Use spread-based adjustment for Forex
            double spread = SymbolInfoDouble(symbol, SYMBOL_ASK) - SymbolInfoDouble(symbol, SYMBOL_BID);
            double normalSpread = spread / _Point;
            return MathMax(1.0, normalSpread / 10.0);  // Adjust if spread > 10 pips
        }
    }

public:
    //--- Constructor and destructor
    CV2EAKeyLevels(void);
    ~CV2EAKeyLevels(void);

    //--- Initialization
    bool Init(string symbol, int lookbackPeriod, double minStrength, double touchZone, 
              int minTouches, bool showDebugPrints);

    //--- Main methods
    bool FindKeyLevels(SKeyLevel &outStrongestLevel);
    void AddKeyLevel(const SKeyLevel &level);
    void RemoveWeakestLevels(int maxPerType);
    void PrintKeyLevelsReport();

    //--- Getters
    int GetKeyLevelCount() const { return m_keyLevelCount; }
    bool GetKeyLevel(int index, SKeyLevel &level) const;
    double GetMinStrength() const { return m_minStrength; }
    double GetTouchZone() const { return m_touchZone; }
    int GetMinTouches() const { return m_minTouches; }
};

//+------------------------------------------------------------------+
//| Constructor                                                        |
//+------------------------------------------------------------------+
CV2EAKeyLevels::CV2EAKeyLevels(void) : m_initialized(false),
                                       m_keyLevelCount(0),
                                       m_lastKeyLevelUpdate(0),
                                       m_maxBounceDelay(8)
{
    if(!ArrayResize(m_currentKeyLevels, DEFAULT_BUFFER_SIZE))
    {
        Print("❌ [CV2EAKeyLevels::Constructor] Failed to initialize key levels array");
        return;
    }
}

//+------------------------------------------------------------------+
//| Destructor                                                         |
//+------------------------------------------------------------------+
CV2EAKeyLevels::~CV2EAKeyLevels(void)
{
    // Clean up arrays
    ArrayFree(m_currentKeyLevels);
}

//+------------------------------------------------------------------+
//| Initialize the key level handler                                   |
//+------------------------------------------------------------------+
bool CV2EAKeyLevels::Init(string symbol, int lookbackPeriod, double minStrength, double touchZone, 
                          int minTouches, bool showDebugPrints)
{
    m_showDebugPrints = showDebugPrints;
    
    // Get market-specific settings
    ENUM_TIMEFRAMES tf = Period();
    m_touchZone = GetMarketTouchZone(symbol, tf);
    m_minStrength = GetMarketMinStrength(symbol, tf);
    m_minTouches = GetMarketMinTouches(symbol, tf);
    m_lookbackPeriod = lookbackPeriod;
    
    // Apply volatility adjustment
    double volAdj = GetMarketVolatilityAdjustment(symbol);
    m_touchZone *= volAdj;
    
    // Reset state
    m_keyLevelCount = 0;
    m_lastKeyLevelUpdate = 0;
    
    m_initialized = true;
    Print("✅ [CV2EAKeyLevels::Init] Configuration complete for ", symbol);
    return true;
}

//+------------------------------------------------------------------+
//| Get a key level by index                                          |
//+------------------------------------------------------------------+
bool CV2EAKeyLevels::GetKeyLevel(int index, SKeyLevel &level) const
{
    if(index >= 0 && index < m_keyLevelCount)
    {
        level = m_currentKeyLevels[index];
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Debug print method                                                |
//+------------------------------------------------------------------+
void CV2EAKeyLevels::DebugPrint(string message)
{
    if(!m_showDebugPrints)
        return;
            
    // Add timestamp and current price to debug messages
    string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
    Print(StringFormat("[%s] [%.5f] %s", timestamp, currentPrice, message));
}

//+------------------------------------------------------------------+
//| Find and process key levels                                        |
//+------------------------------------------------------------------+
bool CV2EAKeyLevels::FindKeyLevels(SKeyLevel &outStrongestLevel)
{
    if(!m_initialized)
    {
        DebugPrint("❌ Strategy not initialized");
        return false;
    }
            
    // Copy price and volume data
    double highPrices[];
    double lowPrices[];
    double closePrices[];
    datetime times[];
    long volumes[];
    
    ArraySetAsSeries(highPrices, true);
    ArraySetAsSeries(lowPrices, true);
    ArraySetAsSeries(closePrices, true);
    ArraySetAsSeries(times, true);
    ArraySetAsSeries(volumes, true);
    
    // Get available bars for the current timeframe
    long availableBars = SeriesInfoInteger(_Symbol, Period(), SERIES_BARS_COUNT);
    
    // Add debug output for bars availability
    DebugPrint(StringFormat("Available bars for %s: %d", EnumToString(Period()), availableBars));
    
    // Adjust minimum bars requirement based on timeframe
    int minRequiredBars;
    switch(Period())
    {
        case PERIOD_MN1: minRequiredBars = 6;  break; // 6 months minimum
        case PERIOD_W1:  minRequiredBars = 8;  break; // 8 weeks minimum
        case PERIOD_D1:  minRequiredBars = 10; break; // 10 days minimum
        default:         minRequiredBars = 10; break; // Default 10 bars
    }
    
    long barsToUse = MathMin((long)m_lookbackPeriod, availableBars - 5); // Leave room for swing detection
    
    // Add debug output for bars calculation
    DebugPrint(StringFormat("Bars to use for %s: %d (minimum required: %d)", 
        EnumToString(Period()), barsToUse, minRequiredBars));
    
    if(barsToUse < minRequiredBars)
    {
        DebugPrint(StringFormat("❌ Insufficient bars available: %d (needed at least %d for %s timeframe)", 
            (int)availableBars, minRequiredBars, EnumToString(Period())));
        return false;
    }
    
    // Copy with error handling
    if(CopyHigh(_Symbol, Period(), 0, (int)barsToUse, highPrices) <= 0 ||
       CopyLow(_Symbol, Period(), 0, (int)barsToUse, lowPrices) <= 0 ||
       CopyClose(_Symbol, Period(), 0, (int)barsToUse, closePrices) <= 0 ||
       CopyTime(_Symbol, Period(), 0, (int)barsToUse, times) <= 0 ||
       CopyTickVolume(_Symbol, Period(), 0, (int)barsToUse, volumes) <= 0)
    {
        DebugPrint(StringFormat("❌ Failed to copy price/volume data. Available bars: %d, Requested: %d, Error: %d", 
            (int)availableBars, (int)barsToUse, GetLastError()));
        return false;
    }
    
    // Add debug output for data copy success
    DebugPrint(StringFormat("Successfully copied data for %s timeframe. Processing %d bars for key levels", 
        EnumToString(Period()), barsToUse));
    
    // Reset key levels array
    m_keyLevelCount = 0;
    
    // Find swing highs (resistance levels)
    for(int i = 2; i < m_lookbackPeriod - 2; i++)
    {
        if(IsSwingHigh(highPrices, i))
        {
            double level = highPrices[i];
            
            if(!IsNearExistingLevel(level))
            {
                SKeyLevel newLevel;
                newLevel.price = level;
                newLevel.isResistance = true;
                newLevel.firstTouch = times[i];
                newLevel.lastTouch = times[i];
                STouchQuality quality;
                newLevel.touchCount = CountTouches(level, true, highPrices, lowPrices, times, quality);
                
                if(newLevel.touchCount < m_minTouches)
                    continue;
                
                newLevel.strength = CalculateLevelStrength(newLevel, quality);
                
                // Add volume strength bonus if there's a volume spike
                double volumeBonus = GetVolumeStrengthBonus(volumes, i);
                if(volumeBonus > 0)
                {
                    newLevel.strength = MathMin(newLevel.strength * (1.0 + volumeBonus), 0.98);
                    newLevel.volumeConfirmed = true;
                    newLevel.volumeRatio = (double)volumes[i] / GetAverageVolume(volumes, i, 20);
                    
                    if(m_showDebugPrints)
                    {
                        Print(StringFormat(
                            "Volume bonus applied to %s level %.5f:\n" +
                            "Original strength: %.4f\n" +
                            "Volume bonus: +%.1f%%\n" +
                            "Volume ratio: %.2fx\n" +
                            "Final strength: %.4f",
                            newLevel.isResistance ? "resistance" : "support",
                            level,
                            newLevel.strength / (1.0 + volumeBonus),
                            volumeBonus * 100,
                            newLevel.volumeRatio,
                            newLevel.strength
                        ));
                    }
                }
                else
                {
                    newLevel.volumeConfirmed = false;
                    newLevel.volumeRatio = 1.0;
                }
                
                if(newLevel.strength >= m_minStrength)
                {
                    AddKeyLevel(newLevel);
                }
            }
        }
    }
    
    // Find swing lows (support levels)
    for(int i = 2; i < m_lookbackPeriod - 2; i++)
    {
        if(IsSwingLow(lowPrices, i))
        {
            double level = lowPrices[i];
            
            if(!IsNearExistingLevel(level))
            {
                SKeyLevel newLevel;
                newLevel.price = level;
                newLevel.isResistance = false;
                newLevel.firstTouch = times[i];
                newLevel.lastTouch = times[i];
                STouchQuality quality;
                newLevel.touchCount = CountTouches(level, false, highPrices, lowPrices, times, quality);
                
                if(newLevel.touchCount < m_minTouches)
                    continue;
                
                newLevel.strength = CalculateLevelStrength(newLevel, quality);
                
                // Add volume strength bonus if there's a volume spike
                double volumeBonus = GetVolumeStrengthBonus(volumes, i);
                if(volumeBonus > 0)
                {
                    newLevel.strength = MathMin(newLevel.strength * (1.0 + volumeBonus), 0.98);
                    newLevel.volumeConfirmed = true;
                    newLevel.volumeRatio = (double)volumes[i] / GetAverageVolume(volumes, i, 20);
                    
                    if(m_showDebugPrints)
                    {
                        Print(StringFormat(
                            "Volume bonus applied to %s level %.5f:\n" +
                            "Original strength: %.4f\n" +
                            "Volume bonus: +%.1f%%\n" +
                            "Volume ratio: %.2fx\n" +
                            "Final strength: %.4f",
                            newLevel.isResistance ? "resistance" : "support",
                            level,
                            newLevel.strength / (1.0 + volumeBonus),
                            volumeBonus * 100,
                            newLevel.volumeRatio,
                            newLevel.strength
                        ));
                    }
                }
                else
                {
                    newLevel.volumeConfirmed = false;
                    newLevel.volumeRatio = 1.0;
                }
                
                if(newLevel.strength >= m_minStrength)
                {
                    AddKeyLevel(newLevel);
                }
            }
        }
    }
    
    // Find strongest level
    if(m_keyLevelCount > 0)
    {
        int strongestIdx = 0;
        double maxStrength = m_currentKeyLevels[0].strength;
        
        for(int i = 1; i < m_keyLevelCount; i++)
        {
            if(m_currentKeyLevels[i].strength > maxStrength)
            {
                maxStrength = m_currentKeyLevels[i].strength;
                strongestIdx = i;
            }
        }
        
        outStrongestLevel = m_currentKeyLevels[strongestIdx];
        m_lastKeyLevelUpdate = TimeCurrent();
        
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Add a new key level                                                |
//+------------------------------------------------------------------+
void CV2EAKeyLevels::AddKeyLevel(const SKeyLevel &level)
{
    // Validate level
    if(level.price <= 0 || level.touchCount < m_minTouches || level.strength < m_minStrength)
    {
        if(m_showDebugPrints)
        {
            Print(StringFormat(
                "❌ Invalid level rejected: Price=%.5f, Touches=%d, Strength=%.4f",
                level.price,
                level.touchCount,
                level.strength
            ));
        }
        return;
    }
    
    // Check array capacity
    if(m_keyLevelCount >= ArraySize(m_currentKeyLevels))
    {
        int newSize = MathMax(10, ArraySize(m_currentKeyLevels) * 2);
        if(!ArrayResize(m_currentKeyLevels, newSize))
        {
            Print("❌ Failed to resize key levels array");
            return;
        }
    }
    
    // Find insertion point to maintain sorted array (by price)
    int insertIdx = m_keyLevelCount;
    for(int i = 0; i < m_keyLevelCount; i++)
    {
        if(level.price < m_currentKeyLevels[i].price)
        {
            insertIdx = i;
            break;
        }
    }
    
    // Shift elements to make room for new level
    if(insertIdx < m_keyLevelCount)
    {
        for(int i = m_keyLevelCount; i > insertIdx; i--)
        {
            m_currentKeyLevels[i] = m_currentKeyLevels[i-1];
        }
    }
    
    // Insert new level
    m_currentKeyLevels[insertIdx] = level;
    m_keyLevelCount++;
    
    // Debug output
    if(m_showDebugPrints)
    {
        string levelType = level.isResistance ? "resistance" : "support";
        string strengthDesc;
        
        if(level.strength >= 0.90) strengthDesc = "Very Strong";
        else if(level.strength >= 0.80) strengthDesc = "Strong";
        else if(level.strength >= 0.70) strengthDesc = "Moderate";
        else strengthDesc = "Normal";
        
        // Calculate actual duration in hours
        double durationHours = (double)(level.lastTouch - level.firstTouch) / 3600.0;
        
        Print(StringFormat(
            "✅ Added %s level at %.5f\n" +
            "   Strength: %.4f (%s)\n" +
            "   Touches: %d\n" +
            "   First Touch: %s\n" +
            "   Last Touch: %s\n" +
            "   Duration: %.1f hours",
            levelType,
            level.price,
            level.strength,
            strengthDesc,
            level.touchCount,
            TimeToString(level.firstTouch),
            TimeToString(level.lastTouch),
            durationHours
        ));
    }
    
    // Maintain maximum number of levels per type if needed
    const int maxLevelsPerType = 10;  // Adjust as needed
    int resistanceCount = 0;
    int supportCount = 0;
    
    for(int i = 0; i < m_keyLevelCount; i++)
    {
        if(m_currentKeyLevels[i].isResistance)
            resistanceCount++;
        else
            supportCount++;
    }
    
    // Remove weakest levels if we have too many
    if(resistanceCount > maxLevelsPerType || supportCount > maxLevelsPerType)
    {
        RemoveWeakestLevels(maxLevelsPerType);
    }
}

//+------------------------------------------------------------------+
//| Remove weakest levels to maintain maximum per type                 |
//+------------------------------------------------------------------+
void CV2EAKeyLevels::RemoveWeakestLevels(int maxPerType)
{
    SKeyLevel resistanceLevels[];
    SKeyLevel supportLevels[];
    int resistanceCount = 0;
    int supportCount = 0;
    
    // Separate levels by type
    for(int i = 0; i < m_keyLevelCount; i++)
    {
        if(m_currentKeyLevels[i].isResistance)
        {
            ArrayResize(resistanceLevels, resistanceCount + 1);
            resistanceLevels[resistanceCount++] = m_currentKeyLevels[i];
        }
        else
        {
            ArrayResize(supportLevels, supportCount + 1);
            supportLevels[supportCount++] = m_currentKeyLevels[i];
        }
    }
    
    // Sort by strength (descending order)
    if(resistanceCount > 1)
        QuickSortLevels(resistanceLevels, 0, resistanceCount - 1);
    if(supportCount > 1)
        QuickSortLevels(supportLevels, 0, supportCount - 1);
    
    m_keyLevelCount = 0;
    
    // Resize arrays to keep only strongest levels
    ArrayResize(resistanceLevels, MathMin(maxPerType, resistanceCount));
    ArrayResize(supportLevels, MathMin(maxPerType, supportCount));
    
    // Copy strongest levels back to main array
    for(int i = 0; i < MathMin(maxPerType, resistanceCount); i++)
        m_currentKeyLevels[m_keyLevelCount++] = resistanceLevels[i];
    for(int i = 0; i < MathMin(maxPerType, supportCount); i++)
        m_currentKeyLevels[m_keyLevelCount++] = supportLevels[i];
    
    Print("🧹 [CV2EAKeyLevels::RemoveWeakestLevels] Cleaned up levels. Kept ",
          IntegerToString(MathMin(maxPerType, resistanceCount)), " resistance and ",
          IntegerToString(MathMin(maxPerType, supportCount)), " support levels.");
}

//+------------------------------------------------------------------+
//| QuickSort implementation for key levels                           |
//+------------------------------------------------------------------+
void CV2EAKeyLevels::QuickSortLevels(SKeyLevel &arr[], int left, int right)
{
    if(left >= right) return;
    
    int i = left, j = right;
    SKeyLevel pivot = arr[(left + right) / 2];
    
    while(i <= j)
    {
        while(arr[i].strength > pivot.strength) i++;
        while(arr[j].strength < pivot.strength) j--;
        
        if(i <= j)
        {
            if(i != j)
            {
                SKeyLevel temp = arr[i];
                arr[i] = arr[j];
                arr[j] = temp;
            }
            i++;
            j--;
        }
    }
    
    if(left < j) QuickSortLevels(arr, left, j);
    if(i < right) QuickSortLevels(arr, i, right);
}

//+------------------------------------------------------------------+
//| Check if price point is a swing high                               |
//+------------------------------------------------------------------+
bool CV2EAKeyLevels::IsSwingHigh(const double &prices[], int index)
{
    // Validate array bounds
    int size = ArraySize(prices);
    if(index < 2 || index >= size - 2)
        return false;
            
    // Basic swing high pattern
    bool basicPattern = prices[index] > prices[index-1] && 
                       prices[index] > prices[index-2] &&
                       prices[index] > prices[index+1] && 
                       prices[index] > prices[index+2];
                          
    if(!basicPattern) return false;
        
    // Calculate slopes for better validation
    double leftSlope1 = prices[index] - prices[index-1];
    double leftSlope2 = prices[index-1] - prices[index-2];
    double rightSlope1 = prices[index] - prices[index+1];
    double rightSlope2 = prices[index+1] - prices[index+2];
        
    // Validate slope consistency
    bool validSlopes = (leftSlope1 > 0 && leftSlope2 >= 0) &&    // Increasing slope on left
                      (rightSlope1 > 0 && rightSlope2 >= 0);      // Decreasing slope on right
        
    if(!validSlopes) return false;
        
    // Calculate the minimum required height based on timeframe
    double minHeight;
    int windowSize;
        
    // Adjust requirements based on timeframe
    switch(Period()) {
        case PERIOD_MN1: 
            minHeight = _Point * 200;
            windowSize = 5;
            break;
        case PERIOD_W1:  
            minHeight = _Point * 150;
            windowSize = 4;
            break;
        case PERIOD_D1:  
            minHeight = _Point * 100;
            windowSize = 4;
            break;
        case PERIOD_H4:  
            minHeight = _Point * 50;
            windowSize = 3;
            break;
        case PERIOD_H1:
            minHeight = _Point * 25;
            windowSize = 3;
            break;
        case PERIOD_M30:
            minHeight = _Point * 15;
            windowSize = 2;
            break;
        case PERIOD_M15:
            minHeight = _Point * 10;
            windowSize = 2;
            break;
        case PERIOD_M5:
            minHeight = _Point * 6;
            windowSize = 2;
            break;
        case PERIOD_M1:
            minHeight = _Point * 4;
            windowSize = 2;
            break;
        default:         
            minHeight = _Point * 10;
            windowSize = 2;
    }
        
    // Check if the swing is significant enough
    double leftHeight = prices[index] - MathMin(prices[index-1], prices[index-2]);
    double rightHeight = prices[index] - MathMin(prices[index+1], prices[index+2]);
        
    // Both sides should have significant height
    if(leftHeight < minHeight || rightHeight < minHeight)
        return false;
            
    // Additional validation: check if it's the highest in a wider window
    for(int i = index-windowSize; i <= index+windowSize; i++)
    {
        if(i != index && i >= 0 && i < size)
        {
            if(prices[i] > prices[index])
                return false;  // Found a higher point nearby
        }
    }
        
    // Optional: Check volume if available
    double volume = (double)iVolume(_Symbol, Period(), index);
    double volumePrev = (double)iVolume(_Symbol, Period(), index-1);
    double volumeNext = (double)iVolume(_Symbol, Period(), index+1);
        
    if(volume > 0.0 && volumePrev > 0.0 && volumeNext > 0.0)
    {
        // Volume should be higher at the swing point
        if(volume <= (volumePrev + volumeNext) / 2.0)
            return false;
    }
        
    return true;
}

//+------------------------------------------------------------------+
//| Check if price point is a swing low                                |
//+------------------------------------------------------------------+
bool CV2EAKeyLevels::IsSwingLow(const double &prices[], int index)
{
    // Basic swing low pattern
    bool basicPattern = prices[index] < prices[index-1] && 
                       prices[index] < prices[index-2] &&
                       prices[index] < prices[index+1] && 
                       prices[index] < prices[index+2];
                          
    if(!basicPattern) return false;
        
    // Calculate the minimum required height based on timeframe
    double minHeight;
    int windowSize;
        
    // Adjust requirements based on timeframe
    switch(Period()) {
        case PERIOD_MN1: 
            minHeight = _Point * 200;  // 200 points for monthly
            windowSize = 5;            // Increased for better monthly validation
            break;
        case PERIOD_W1:  
            minHeight = _Point * 150;  // 150 points for weekly
            windowSize = 4;
            break;
        case PERIOD_D1:  
            minHeight = _Point * 100;  // 100 points for daily
            windowSize = 4;
            break;
        case PERIOD_H4:  
            minHeight = _Point * 50;   // 50 points for 4h
            windowSize = 3;
            break;
        case PERIOD_H1:
            minHeight = _Point * 25;   // Reduced from 30 to 25 for 1h
            windowSize = 3;
            break;
        case PERIOD_M30:
            minHeight = _Point * 15;   // Reduced from 20 to 15 for M30
            windowSize = 2;            // Reduced window size for faster timeframes
            break;
        case PERIOD_M15:
            minHeight = _Point * 10;   // Reduced from 15 to 10 for M15
            windowSize = 2;
            break;
        case PERIOD_M5:
            minHeight = _Point * 6;    // Reduced from 8 to 6 for M5
            windowSize = 2;
            break;
        case PERIOD_M1:
            minHeight = _Point * 4;    // Reduced from 5 to 4 for M1
            windowSize = 2;
            break;
        default:         
            minHeight = _Point * 10;   // Default fallback
            windowSize = 2;
    }
        
    // Check if the swing is significant enough
    double leftHeight = MathMax(prices[index-1], prices[index-2]) - prices[index];
    double rightHeight = MathMax(prices[index+1], prices[index+2]) - prices[index];
        
    // Both sides should have significant height
    if(leftHeight < minHeight || rightHeight < minHeight)
        return false;
            
    // Additional validation: check if it's the lowest in a wider window
    for(int i = index-windowSize; i <= index+windowSize; i++)
    {
        if(i != index && i >= 0 && i < ArraySize(prices))
        {
            if(prices[i] < prices[index])
                return false;  // Found a lower point nearby
        }
    }
        
    return true;
}

//+------------------------------------------------------------------+
//| Check if price is near an existing level                          |
//+------------------------------------------------------------------+
bool CV2EAKeyLevels::IsNearExistingLevel(const double price)
{
    // Calculate appropriate touch zone based on timeframe
    double adjustedTouchZone = m_touchZone;
    switch(Period()) {
        case PERIOD_MN1: adjustedTouchZone *= 2.0; break;
        case PERIOD_W1:  adjustedTouchZone *= 1.8; break;
        case PERIOD_D1:  adjustedTouchZone *= 1.5; break;
        case PERIOD_H4:  adjustedTouchZone *= 1.2; break;
    }
    
    for(int i = 0; i < m_keyLevelCount; i++)
    {
        double currentDistance = MathAbs(price - m_currentKeyLevels[i].price);
        if(currentDistance <= adjustedTouchZone)
            return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if price is near an existing level and get details          |
//+------------------------------------------------------------------+
bool CV2EAKeyLevels::IsNearExistingLevel(const double price, SKeyLevel &nearestLevel, double &distance)
{
    // Calculate appropriate touch zone based on timeframe
    double adjustedTouchZone = m_touchZone;
    switch(Period()) {
        case PERIOD_MN1: adjustedTouchZone *= 2.0; break;
        case PERIOD_W1:  adjustedTouchZone *= 1.8; break;
        case PERIOD_D1:  adjustedTouchZone *= 1.5; break;
        case PERIOD_H4:  adjustedTouchZone *= 1.2; break;
    }
    
    bool found = false;
    double minDistance = DBL_MAX;
    int nearestIdx = -1;
    
    for(int i = 0; i < m_keyLevelCount; i++)
    {
        double currentDistance = MathAbs(price - m_currentKeyLevels[i].price);
        if(currentDistance <= adjustedTouchZone)
        {
            found = true;
            if(currentDistance < minDistance)
            {
                minDistance = currentDistance;
                nearestIdx = i;
            }
        }
    }
    
    // If a nearest level was found, fill the reference parameters
    if(found && nearestIdx >= 0)
    {
        nearestLevel = m_currentKeyLevels[nearestIdx];
        distance = minDistance;
        
        if(m_showDebugPrints)
        {
            Print(StringFormat(
                "Found nearby level: %.5f (%.1f pips away)",
                m_currentKeyLevels[nearestIdx].price,
                minDistance / _Point
            ));
        }
    }
    
    return found;
}

//+------------------------------------------------------------------+
//| Print key levels report                                           |
//+------------------------------------------------------------------+
void CV2EAKeyLevels::PrintKeyLevelsReport()
{
    if(!m_showDebugPrints) return;

    string timeStr = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Create arrays to store and sort levels
    SKeyLevel supportLevels[];
    SKeyLevel resistanceLevels[];
    ArrayResize(supportLevels, m_keyLevelCount);
    ArrayResize(resistanceLevels, m_keyLevelCount);
    int supportCount = 0;
    int resistanceCount = 0;
    
    // Separate levels into support and resistance
    for(int i = 0; i < m_keyLevelCount; i++)
    {
        if(m_currentKeyLevels[i].isResistance)
            resistanceLevels[resistanceCount++] = m_currentKeyLevels[i];
        else
            supportLevels[supportCount++] = m_currentKeyLevels[i];
    }
    
    // Sort levels by distance from current price
    for(int i = 0; i < supportCount - 1; i++)
    {
        for(int j = i + 1; j < supportCount; j++)
        {
            if(MathAbs(supportLevels[i].price - currentPrice) > MathAbs(supportLevels[j].price - currentPrice))
            {
                SKeyLevel temp = supportLevels[i];
                supportLevels[i] = supportLevels[j];
                supportLevels[j] = temp;
            }
        }
    }
    
    for(int i = 0; i < resistanceCount - 1; i++)
    {
        for(int j = i + 1; j < resistanceCount; j++)
        {
            if(MathAbs(resistanceLevels[i].price - currentPrice) > MathAbs(resistanceLevels[j].price - currentPrice))
            {
                SKeyLevel temp = resistanceLevels[i];
                resistanceLevels[i] = resistanceLevels[j];
                resistanceLevels[j] = temp;
            }
        }
    }
    
    // Print header without timestamp in each line
    DebugPrint(StringFormat("=== KEY LEVELS REPORT [%s] ===\nPrice: %.5f", timeStr, currentPrice));
    
    // Print Support Levels
    if(supportCount > 0)
    {
        DebugPrint("\nSUPPORT:");
        for(int i = 0; i < supportCount; i++)
        {
            double distance = MathAbs(currentPrice - supportLevels[i].price);
            string marker = (supportLevels[i].strength > 0.8) ? "⭐" : "";
            string arrow = (currentPrice > supportLevels[i].price) ? "↓" : " ";
            string distanceStr = StringFormat("%d pips", (int)(distance / _Point));
            
            DebugPrint(StringFormat("%s %.5f (%s) | S:%.2f T:%d %s",
                arrow,
                supportLevels[i].price,
                distanceStr,
                supportLevels[i].strength,
                supportLevels[i].touchCount,
                marker));
        }
    }
    
    // Print Resistance Levels
    if(resistanceCount > 0)
    {
        DebugPrint("\nRESISTANCE:");
        for(int i = 0; i < resistanceCount; i++)
        {
            double distance = MathAbs(currentPrice - resistanceLevels[i].price);
            string marker = (resistanceLevels[i].strength > 0.8) ? "⭐" : "";
            string arrow = (currentPrice < resistanceLevels[i].price) ? "↑" : " ";
            string distanceStr = StringFormat("%d pips", (int)(distance / _Point));
            
            DebugPrint(StringFormat("%s %.5f (%s) | S:%.2f T:%d %s",
                arrow,
                resistanceLevels[i].price,
                distanceStr,
                resistanceLevels[i].strength,
                resistanceLevels[i].touchCount,
                marker));
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate strength of a key level                                  |
//+------------------------------------------------------------------+
double CV2EAKeyLevels::CalculateLevelStrength(const SKeyLevel &level, const STouchQuality &quality)
{
    // Base strength from touch count (0.50-0.95 range)
    double touchBase = 0;
    switch(level.touchCount) {
        case 2: touchBase = 0.50; break;  // Base level
        case 3: touchBase = 0.70; break;  // Significant jump
        case 4: touchBase = 0.85; break;  // Strong level
        default: touchBase = MathMin(0.90 + ((level.touchCount - 5) * 0.01), 0.95); // Cap at 0.95
    }
    
    // Recency modifier (-60% to +30% of base)
    ENUM_TIMEFRAMES tf = Period();
    int periodMinutes = PeriodSeconds(tf) / 60;
    double barsElapsed = (double)(TimeCurrent() - level.lastTouch) / (periodMinutes * 60);
    double recencyMod = 0;
    
    // Enhanced recency calculation based on timeframe
    if(barsElapsed <= m_lookbackPeriod / 8) {      // Very recent (within 1/8 of lookback)
        recencyMod = 0.30;
    } else if(barsElapsed <= m_lookbackPeriod / 4) {  // Recent (within 1/4 of lookback)
        recencyMod = 0.20;
    } else if(barsElapsed <= m_lookbackPeriod / 2) {  // Moderately recent
        recencyMod = 0.10;
    } else if(barsElapsed <= m_lookbackPeriod) {      // Within lookback
        recencyMod = 0;
    } else {                                          // Old
        recencyMod = -0.60;
    }
    
    // Duration bonus (up to +35% of base)
    double barsDuration = (double)(level.lastTouch - level.firstTouch) / (periodMinutes * 60);
    double durationMod = 0;
    
    // Enhanced duration calculation
    if(barsDuration >= m_lookbackPeriod * 0.75) {     // Very long-lasting
        durationMod = 0.35;
    } else if(barsDuration >= m_lookbackPeriod / 2) {  // Long-lasting
        durationMod = 0.25;
    } else if(barsDuration >= m_lookbackPeriod / 4) {  // Medium duration
        durationMod = 0.15;
    } else if(barsDuration >= m_lookbackPeriod / 8) {  // Short duration
        durationMod = 0.05;
    }
    
    // Timeframe bonus - adjusted weights
    double timeframeBonus = 0;
    switch(tf) {
        case PERIOD_MN1: timeframeBonus = 0.12; break;
        case PERIOD_W1:  timeframeBonus = 0.10; break;
        case PERIOD_D1:  timeframeBonus = 0.08; break;
        case PERIOD_H4:  timeframeBonus = 0.06; break;
        case PERIOD_H1:  timeframeBonus = 0.04; break;
        case PERIOD_M30: timeframeBonus = 0.02; break;
        case PERIOD_M15: timeframeBonus = 0.015; break;
        case PERIOD_M5:  timeframeBonus = 0.01; break;
        case PERIOD_M1:  timeframeBonus = 0.005; break;
        default: timeframeBonus = 0.01;
    }
    
    // Touch quality bonus (up to +20% based on bounce characteristics)
    double qualityBonus = 0;
    double bounceSpeed = 0;  // Declare bounceSpeed here
    
    // Bonus for consistent bounce sizes
    double bounceConsistency = quality.maxBounceSize > 0 ? 
        quality.avgBounceStrength / (quality.maxBounceSize / _Point) : 0;
    qualityBonus += bounceConsistency * 0.10;  // Up to 10% for consistent bounces
    
    // Bonus for quick bounces
    if(quality.quickestBounce < INT_MAX)
    {
        bounceSpeed = 1.0 - ((double)(quality.quickestBounce + quality.slowestBounce) / 
                                  (2.0 * m_maxBounceDelay));
        qualityBonus += bounceSpeed * 0.05;  // Up to 5% for quick bounces
    }
    
    // Bonus for volume confirmation
    if(quality.avgBounceVolume > 0)
    {
        qualityBonus += 0.05;  // 5% bonus for volume confirmation
    }
    
    // Calculate final strength with all modifiers
    double strength = touchBase * (1.0 + recencyMod + durationMod + timeframeBonus + qualityBonus);
    
    // Add tiny random variation (0.05% max) to prevent identical strengths
    strength += 0.0005 * MathMod(level.price * 10000, 10) / 10;
    
    // Debug output for strength calculation
    if(m_showDebugPrints)
    {
        Print(StringFormat(
            "\n=== STRENGTH CALCULATION FOR LEVEL %.5f ===\n" +
            "Base Strength (from %d touches): %.4f\n" +
            "Recency Modifier: %.2f%%\n" +
            "Duration Modifier: %.2f%%\n" +
            "Timeframe Bonus: %.2f%%\n" +
            "Quality Bonus: %.2f%%\n" +
            "  - Bounce Consistency: %.2f\n" +
            "  - Bounce Speed: %.2f\n" +
            "  - Volume Confirmation: %s\n" +
            "Final Strength: %.4f",
            level.price,
            level.touchCount,
            touchBase,
            recencyMod * 100,
            durationMod * 100,
            timeframeBonus * 100,
            qualityBonus * 100,
            bounceConsistency,
            bounceSpeed,
            quality.avgBounceVolume > 0 ? "Yes" : "No",
            strength
        ));
    }
    
    // Ensure bounds
    return MathMin(MathMax(strength, 0.45), 0.98);
}

//+------------------------------------------------------------------+
//| Count touches and measure their quality                            |
//+------------------------------------------------------------------+
int CV2EAKeyLevels::CountTouches(double level, bool isResistance, const double &highs[], 
                                const double &lows[], const datetime &times[], STouchQuality &quality)
{
    quality.touchCount = 0;
    quality.avgBounceStrength = 0;
    quality.avgBounceVolume = 0;
    quality.maxBounceSize = 0;
    quality.quickestBounce = INT_MAX;
    quality.slowestBounce = 0;
    
    int touches = 0;
    double lastPrice = 0;
    datetime lastTouchTime = 0;
    double totalBounceStrength = 0;
    double totalBounceVolume = 0;
    
    // Calculate pip size based on digits
    double pipSize = _Point;
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    if(digits == 3 || digits == 5)
        pipSize = _Point * 10;
            
    // Get volume data if available
    bool hasVolume = true;  // We'll check each volume individually with iVolume
            
    // Adjust touch and bounce requirements based on timeframe
    double minTouchDistance = m_touchZone * 0.2;  // 20% of touch zone
    double minBounceDistance = m_touchZone * 0.3;  // 30% of touch zone
    
    // Debug info
    if(m_showDebugPrints)
    {
        Print(StringFormat(
            "\n=== TOUCH DETECTION FOR LEVEL %.5f ===\n" +
            "Type: %s\n" +
            "Touch Zone: %.5f (%d pips)\n" +
            "Min Touch Distance: %d pips\n" +
            "Min Bounce Distance: %d pips\n" +
            "Max Bounce Delay: %d bars",
            level,
            isResistance ? "RESISTANCE" : "SUPPORT",
            m_touchZone,
            (int)(m_touchZone / pipSize),
            (int)(minTouchDistance / pipSize),
            (int)(minBounceDistance / pipSize),
            m_maxBounceDelay
        ));
    }
    
    // Track consecutive touches within the same zone
    int consecutiveTouches = 0;
    double lastValidTouch = 0;
    
    for(int i = 0; i < m_lookbackPeriod - m_maxBounceDelay; i++)
    {
        double currentPrice = isResistance ? highs[i] : lows[i];
        double touchDistance = MathAbs(currentPrice - level);
        
        // Check if price is within touch zone
        if(touchDistance <= m_touchZone)
        {
            // Validate touch spacing
            bool validTouch = true;
            if(lastValidTouch != 0)
            {
                double spacing = MathAbs(currentPrice - lastValidTouch);
                if(spacing < minTouchDistance)
                {
                    consecutiveTouches++;
                    if(consecutiveTouches > 2)  // Allow up to 2 consecutive touches
                    {
                        validTouch = false;
                    }
                }
                else
                {
                    consecutiveTouches = 0;
                }
            }
            
            if(validTouch)
            {
                // Look for bounce
                double extremePrice = currentPrice;
                int bounceBar = 0;
                bool cleanBounce = true;
                double bounceVolume = 0;
                
                // Find the bounce
                for(int j = 1; j <= m_maxBounceDelay && (i+j) < m_lookbackPeriod; j++)
                {
                    double price = isResistance ? lows[i+j] : highs[i+j];
                    if(isResistance ? (price < extremePrice) : (price > extremePrice))
                    {
                        extremePrice = price;
                        bounceBar = j;
                        if(hasVolume) bounceVolume = (double)iVolume(_Symbol, Period(), i+j);
                    }
                }
                
                // Verify clean bounce
                for(int j = 1; j < bounceBar; j++)
                {
                    double checkPrice = isResistance ? highs[i+j] : lows[i+j];
                    if(isResistance ? (checkPrice > currentPrice - m_touchZone) : 
                                    (checkPrice < currentPrice + m_touchZone))
                    {
                        cleanBounce = false;
                        break;
                    }
                }
                
                double bounceSize = MathAbs(currentPrice - extremePrice);
                if(bounceSize >= minBounceDistance && cleanBounce)
                {
                    touches++;
                    lastValidTouch = currentPrice;
                    totalBounceStrength += bounceSize / pipSize;
                    if(hasVolume) totalBounceVolume += bounceVolume;
                    
                    // Update quality metrics
                    quality.maxBounceSize = MathMax(quality.maxBounceSize, bounceSize);
                    quality.quickestBounce = MathMin(quality.quickestBounce, bounceBar);
                    quality.slowestBounce = MathMax(quality.slowestBounce, bounceBar);
                    
                    if(m_showDebugPrints)
                    {
                        datetime touchTime = times[i];
                        string timeGap = lastTouchTime == 0 ? "FIRST TOUCH" : 
                                       StringFormat("%.1f hours from last", 
                                       (double)(touchTime - lastTouchTime) / 3600);
                                       
                        Print(StringFormat(
                            "✓ Touch %d at %.5f (%.1f pips from level) - %s\n" +
                            "  Bounce Size: %.1f pips\n" +
                            "  Bounce Bar: %d\n" +
                            "  Bounce Volume: %.2f",
                            touches,
                            currentPrice,
                            touchDistance / pipSize,
                            timeGap,
                            bounceSize / pipSize,
                            bounceBar,
                            bounceVolume
                        ));
                        
                        lastTouchTime = touchTime;
                    }
                }
            }
        }
        else if(touchDistance > m_touchZone * 3)
        {
            // Reset consecutive touch counter when price moves far from level
            consecutiveTouches = 0;
            lastValidTouch = 0;
        }
    }
    
    // Calculate final quality metrics
    if(touches > 0)
    {
        quality.touchCount = touches;
        quality.avgBounceStrength = totalBounceStrength / touches;
        if(hasVolume) quality.avgBounceVolume = totalBounceVolume / touches;
        
        if(m_showDebugPrints)
        {
            Print(StringFormat(
                "=== TOUCH QUALITY SUMMARY ===\n" +
                "Total Touches: %d\n" +
                "Avg Bounce: %.1f pips\n" +
                "Max Bounce: %.1f pips\n" +
                "Bounce Range: %d-%d bars\n" +
                "Avg Volume: %.2f\n" +
                "===================",
                touches,
                quality.avgBounceStrength,
                quality.maxBounceSize / pipSize,
                quality.quickestBounce,
                quality.slowestBounce,
                quality.avgBounceVolume
            ));
        }
    }
    
    return touches;
} 