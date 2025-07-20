//+------------------------------------------------------------------+
//| GrandeKeyLevelDetector.mqh                                       |
//| Copyright 2024, Grande Tech                                      |
//| Key Level Detection and Chart Display Library                    |
//+------------------------------------------------------------------+
// Pattern from: MetaTrader 5 MQL5 Documentation
// Reference: Object-oriented programming and chart object management

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"
#property description "Advanced key level detection system with visual chart display"

//+------------------------------------------------------------------+
//| Constants                                                        |
//+------------------------------------------------------------------+
#define VOLUME_SPIKE_MULTIPLIER 2.0
#define VOLUME_LOOKBACK_BARS 20
#define VOLUME_STRENGTH_MAX_BONUS 0.15

//+------------------------------------------------------------------+
//| Key Level and Touch Quality Structures                          |
//+------------------------------------------------------------------+
struct SKeyLevel
{
    double      price;              // Level price
    bool        isResistance;       // true = resistance, false = support
    int         touchCount;         // Number of touches
    double      strength;           // Level strength (0.0 - 1.0)
    datetime    firstTouch;         // First touch time
    datetime    lastTouch;          // Last touch time
    bool        volumeConfirmed;    // Volume confirmation
    double      volumeRatio;        // Volume ratio at formation
};

struct STouchQuality 
{
    int         touchCount;         // Number of touches
    double      avgBounceStrength;  // Average bounce strength in pips
    double      avgBounceVolume;    // Average volume during bounces
    double      maxBounceSize;      // Maximum bounce size
    int         quickestBounce;     // Quickest bounce in bars
    int         slowestBounce;      // Slowest bounce in bars
};

struct SChartLine
{
    string      name;               // Object name
    double      price;              // Line price
    datetime    lastUpdate;         // Last update time
    color       lineColor;          // Line color
    bool        isActive;           // Is line active
};

//+------------------------------------------------------------------+
//| Grande Key Level Detector Class                                  |
//+------------------------------------------------------------------+
class CGrandeKeyLevelDetector
{
private:
    // Configuration parameters
    int         m_lookbackPeriod;   // Lookback period for analysis
    double      m_minStrength;      // Minimum level strength
    double      m_touchZone;        // Touch zone tolerance
    int         m_minTouches;       // Minimum touches required
    int         m_maxBounceDelay;   // Maximum bounce delay in bars
    bool        m_showDebugPrints;  // Debug output flag
    
    // Key level storage
    SKeyLevel   m_keyLevels[];      // Array of key levels
    int         m_levelCount;       // Number of levels found
    datetime    m_lastUpdate;       // Last update time
    
    // Chart display
    SChartLine  m_chartLines[];     // Chart line objects
    datetime    m_lastChartUpdate;  // Last chart update
    long        m_chartID;          // Chart ID
    
public:
    //+------------------------------------------------------------------+
    //| Constructor and Destructor                                       |
    //+------------------------------------------------------------------+
    CGrandeKeyLevelDetector(void)
    {
        m_lookbackPeriod = 100;
        m_minStrength = 0.55;
        m_touchZone = 0.0005;
        m_minTouches = 2;
        m_maxBounceDelay = 8;
        m_showDebugPrints = false;
        m_levelCount = 0;
        m_lastUpdate = 0;
        m_lastChartUpdate = 0;
        m_chartID = ChartID();
        ArrayResize(m_keyLevels, 100);
        ArrayResize(m_chartLines, 100);
    }
    
    ~CGrandeKeyLevelDetector(void)
    {
        ClearAllChartObjects();
    }
    
    //+------------------------------------------------------------------+
    //| Initialization Method                                            |
    //+------------------------------------------------------------------+
    bool Initialize(int lookbackPeriod = 100, 
                    double minStrength = 0.55, 
                    double touchZone = 0.0005, 
                    int minTouches = 2,
                    bool showDebugPrints = false)
    {
        // Validate parameters
        if(lookbackPeriod < 10 || lookbackPeriod > 1000)
        {
            Print("ERROR: Invalid lookback period. Must be between 10 and 1000");
            return false;
        }
        
        if(minStrength < 0.1 || minStrength > 1.0)
        {
            Print("ERROR: Invalid minimum strength. Must be between 0.1 and 1.0");
            return false;
        }
        
        if(minTouches < 2 || minTouches > 10)
        {
            Print("ERROR: Invalid minimum touches. Must be between 2 and 10");
            return false;
        }
        
        // Set configuration
        m_lookbackPeriod = lookbackPeriod;
        m_minStrength = minStrength;
        m_touchZone = GetOptimalTouchZone(touchZone);
        m_minTouches = minTouches;
        m_showDebugPrints = showDebugPrints;
        
        // Check data availability
        int bars = Bars(_Symbol, Period());
        if(bars < m_lookbackPeriod + 10)
        {
            Print("ERROR: Insufficient historical data. Need ", m_lookbackPeriod + 10, " bars, got ", bars);
            return false;
        }
        
        m_chartID = ChartID();
        m_levelCount = 0;
        m_lastUpdate = 0;
        m_lastChartUpdate = 0;
        
        if(m_showDebugPrints)
        {
            Print("Grande Key Level Detector initialized successfully:");
            Print("  - Lookback Period: ", m_lookbackPeriod);
            Print("  - Min Strength: ", DoubleToString(m_minStrength, 2));
            Print("  - Touch Zone: ", DoubleToString(m_touchZone, 5));
            Print("  - Min Touches: ", m_minTouches);
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Main Detection Method                                            |
    //+------------------------------------------------------------------+
    bool DetectKeyLevels()
    {
        // Get price data
        double highPrices[], lowPrices[], closePrices[];
        datetime times[];
        long volumes[];
        
        ArraySetAsSeries(highPrices, true);
        ArraySetAsSeries(lowPrices, true);
        ArraySetAsSeries(closePrices, true);
        ArraySetAsSeries(times, true);
        ArraySetAsSeries(volumes, true);
        
        // Copy data with error handling
        if(CopyHigh(_Symbol, Period(), 0, m_lookbackPeriod, highPrices) <= 0 ||
           CopyLow(_Symbol, Period(), 0, m_lookbackPeriod, lowPrices) <= 0 ||
           CopyClose(_Symbol, Period(), 0, m_lookbackPeriod, closePrices) <= 0 ||
           CopyTime(_Symbol, Period(), 0, m_lookbackPeriod, times) <= 0 ||
           CopyTickVolume(_Symbol, Period(), 0, m_lookbackPeriod, volumes) <= 0)
        {
            Print("ERROR: Failed to copy market data. Error: ", GetLastError());
            return false;
        }
        
        // Reset level count
        m_levelCount = 0;
        
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
                    
                    if(newLevel.touchCount >= m_minTouches)
                    {
                        newLevel.strength = CalculateLevelStrength(newLevel, quality);
                        
                        // Add volume strength bonus
                        double volumeBonus = GetVolumeStrengthBonus(volumes, i);
                        if(volumeBonus > 0)
                        {
                            newLevel.strength = MathMin(newLevel.strength * (1.0 + volumeBonus), 0.98);
                            newLevel.volumeConfirmed = true;
                            newLevel.volumeRatio = (double)volumes[i] / GetAverageVolume(volumes, i, 20);
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
                    
                    if(newLevel.touchCount >= m_minTouches)
                    {
                        newLevel.strength = CalculateLevelStrength(newLevel, quality);
                        
                        // Add volume strength bonus
                        double volumeBonus = GetVolumeStrengthBonus(volumes, i);
                        if(volumeBonus > 0)
                        {
                            newLevel.strength = MathMin(newLevel.strength * (1.0 + volumeBonus), 0.98);
                            newLevel.volumeConfirmed = true;
                            newLevel.volumeRatio = (double)volumes[i] / GetAverageVolume(volumes, i, 20);
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
        }
        
        m_lastUpdate = TimeCurrent();
        
        if(m_showDebugPrints)
        {
            Print("[Grande] Key level detection completed. Found ", m_levelCount, " levels");
        }
        
        return m_levelCount > 0;
    }
    
    //+------------------------------------------------------------------+
    //| Chart Display Methods                                            |
    //+------------------------------------------------------------------+
    void UpdateChartDisplay()
    {
        if(m_levelCount == 0)
        {
            if(m_showDebugPrints)
                Print("[Grande] No key levels to display on chart");
            return;
        }
        
        ClearAllChartObjects();
        
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        datetime currentTime = TimeCurrent();
        int successCount = 0;
        
        // Reset chart lines array
        ArrayFree(m_chartLines);
        ArrayResize(m_chartLines, m_levelCount);
        
        for(int i = 0; i < m_levelCount; i++)
        {
            string lineName = StringFormat("GKL_%s_%.5f_%d", 
                m_keyLevels[i].isResistance ? "R" : "S",
                m_keyLevels[i].price,
                currentTime);
            
            // Determine line properties
            bool isAbovePrice = m_keyLevels[i].price > currentPrice;
            color lineColor;
            int lineWidth;
            
            // Set line properties based on strength
            if(m_keyLevels[i].strength >= 0.85)
            {
                lineColor = isAbovePrice ? clrRed : clrLime;
                lineWidth = 3;
            }
            else if(m_keyLevels[i].strength >= 0.70)
            {
                lineColor = isAbovePrice ? clrOrange : clrAqua;
                lineWidth = 2;
            }
            else
            {
                lineColor = isAbovePrice ? clrPink : clrYellow;
                lineWidth = 1;
            }
            
            // Create horizontal line
            if(ObjectCreate(m_chartID, lineName, OBJ_HLINE, 0, 0, m_keyLevels[i].price))
            {
                // Set line properties
                ObjectSetInteger(m_chartID, lineName, OBJPROP_COLOR, lineColor);
                ObjectSetInteger(m_chartID, lineName, OBJPROP_STYLE, STYLE_SOLID);
                ObjectSetInteger(m_chartID, lineName, OBJPROP_WIDTH, lineWidth);
                ObjectSetInteger(m_chartID, lineName, OBJPROP_BACK, false);
                ObjectSetInteger(m_chartID, lineName, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(m_chartID, lineName, OBJPROP_HIDDEN, false);
                ObjectSetInteger(m_chartID, lineName, OBJPROP_RAY_RIGHT, true);
                ObjectSetInteger(m_chartID, lineName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
                
                // Set tooltip
                string tooltip = StringFormat("%s Level: %.5f\nStrength: %.2f\nTouches: %d\nDistance: %d pips", 
                    isAbovePrice ? "Resistance" : "Support",
                    m_keyLevels[i].price,
                    m_keyLevels[i].strength,
                    m_keyLevels[i].touchCount,
                    (int)(MathAbs(m_keyLevels[i].price - currentPrice) / _Point));
                
                ObjectSetString(m_chartID, lineName, OBJPROP_TOOLTIP, tooltip);
                
                // Add to tracking array
                m_chartLines[successCount].name = lineName;
                m_chartLines[successCount].price = m_keyLevels[i].price;
                m_chartLines[successCount].lastUpdate = currentTime;
                m_chartLines[successCount].lineColor = lineColor;
                m_chartLines[successCount].isActive = true;
                
                successCount++;
            }
            else
            {
                if(m_showDebugPrints)
                    Print("[Grande] Failed to create chart line for level: ", m_keyLevels[i].price);
            }
        }
        
        ChartRedraw(m_chartID);
        m_lastChartUpdate = currentTime;
        
        if(m_showDebugPrints)
        {
            Print("[Grande] Chart display updated. ", successCount, "/", m_levelCount, " lines created successfully");
        }
    }
    
    void ClearAllChartObjects()
    {
        int deletedCount = ObjectsDeleteAll(m_chartID, "GKL_");
        ArrayFree(m_chartLines);
        
        if(deletedCount > 0 && m_showDebugPrints)
        {
            Print("[Grande] Cleared ", deletedCount, " chart objects");
        }
        
        ChartRedraw(m_chartID);
    }
    
    //+------------------------------------------------------------------+
    //| Public Access Methods                                            |
    //+------------------------------------------------------------------+
    int GetKeyLevelCount() const { return m_levelCount; }
    
    bool GetKeyLevel(int index, SKeyLevel &level) const
    {
        if(index >= 0 && index < m_levelCount)
        {
            level = m_keyLevels[index];
            return true;
        }
        return false;
    }
    
    bool GetStrongestLevel(SKeyLevel &level) const
    {
        if(m_levelCount == 0) return false;
        
        double maxStrength = 0;
        int strongestIdx = -1;
        
        for(int i = 0; i < m_levelCount; i++)
        {
            if(m_keyLevels[i].strength > maxStrength)
            {
                maxStrength = m_keyLevels[i].strength;
                strongestIdx = i;
            }
        }
        
        if(strongestIdx >= 0)
        {
            level = m_keyLevels[strongestIdx];
            return true;
        }
        
        return false;
    }
    
    void PrintKeyLevelsReport() const
    {
        if(!m_showDebugPrints) return;
        
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        Print("=== GRANDE KEY LEVELS REPORT ===");
        Print("Current Price: ", DoubleToString(currentPrice, _Digits));
        Print("Total Levels Found: ", m_levelCount);
        Print("Last Update: ", TimeToString(m_lastUpdate, TIME_DATE|TIME_MINUTES));
        
        for(int i = 0; i < m_levelCount; i++)
        {
            double distance = MathAbs(currentPrice - m_keyLevels[i].price);
            string arrow = m_keyLevels[i].price > currentPrice ? "↑" : "↓";
            
            Print(StringFormat("%s %.5f (%s) | Strength:%.2f | Touches:%d | Distance:%d pips",
                arrow,
                m_keyLevels[i].price,
                m_keyLevels[i].isResistance ? "Resistance" : "Support",
                m_keyLevels[i].strength,
                m_keyLevels[i].touchCount,
                (int)(distance / _Point)));
        }
        
        Print("================================");
    }
    
    datetime GetLastUpdateTime() const { return m_lastUpdate; }
    
    //+------------------------------------------------------------------+
    //| Configuration Methods                                            |
    //+------------------------------------------------------------------+
    void SetDebugMode(bool enabled) { m_showDebugPrints = enabled; }
    bool GetDebugMode() const { return m_showDebugPrints; }
    
    void SetMinStrength(double strength)
    {
        if(strength >= 0.1 && strength <= 1.0)
            m_minStrength = strength;
    }
    
    double GetMinStrength() const { return m_minStrength; }
    
private:
    //+------------------------------------------------------------------+
    //| Private Helper Methods                                           |
    //+------------------------------------------------------------------+
    double GetOptimalTouchZone(double providedTouchZone)
    {
        double touchZone = providedTouchZone;
        
        // Check if this is US500/SPX
        if(StringFind(_Symbol, "US500") >= 0 || StringFind(_Symbol, "SPX") >= 0)
        {
            switch(_Period)
            {
                case PERIOD_MN1: touchZone = 50.0; break;
                case PERIOD_W1:  touchZone = 30.0; break;
                case PERIOD_D1:  touchZone = 20.0; break;
                case PERIOD_H4:  touchZone = 15.0; break;
                case PERIOD_H1:  touchZone = 10.0; break;
                case PERIOD_M30: touchZone = 7.5;  break;
                case PERIOD_M15: touchZone = 5.0;  break;
                case PERIOD_M5:  touchZone = 3.0;  break;
                case PERIOD_M1:  touchZone = 2.0;  break;
                default:         touchZone = 5.0;  break;
            }
        }
        else
        {
            // Forex pairs - ALWAYS adjust touch zones based on timeframe
            // Remove the condition that was preventing adjustment
            switch(_Period)
            {
                case PERIOD_MN1: touchZone = 0.0200; break;
                case PERIOD_W1:  touchZone = 0.0100; break;
                case PERIOD_D1:  touchZone = 0.0060; break;
                case PERIOD_H4:  touchZone = 0.0040; break;
                case PERIOD_H1:  touchZone = 0.0025; break;
                case PERIOD_M30: touchZone = 0.0010; break;
                case PERIOD_M15: touchZone = 0.0007; break;
                case PERIOD_M5:  touchZone = 0.0005; break;
                case PERIOD_M1:  touchZone = 0.0003; break;
                default:         touchZone = 0.0005; break;
            }
        }
        
        return touchZone;
    }
    
    bool IsSwingHigh(const double &prices[], int index)
    {
        int size = ArraySize(prices);
        if(index < 2 || index >= size - 2) return false;
        
        // Basic swing high pattern
        bool basicPattern = prices[index] > prices[index-1] && 
                          prices[index] > prices[index-2] &&
                          prices[index] > prices[index+1] && 
                          prices[index] > prices[index+2];
        
        if(!basicPattern) return false;
        
        // Calculate minimum height based on timeframe
        double minHeight;
        switch(Period())
        {
            case PERIOD_MN1: minHeight = _Point * 200; break;
            case PERIOD_W1:  minHeight = _Point * 150; break;
            case PERIOD_D1:  minHeight = _Point * 100; break;
            case PERIOD_H4:  minHeight = _Point * 50;  break;
            case PERIOD_H1:  minHeight = _Point * 25;  break;
            case PERIOD_M30: minHeight = _Point * 15;  break;
            case PERIOD_M15: minHeight = _Point * 10;  break;
            case PERIOD_M5:  minHeight = _Point * 6;   break;
            case PERIOD_M1:  minHeight = _Point * 4;   break;
            default:         minHeight = _Point * 10;  break;
        }
        
        double leftHeight = prices[index] - MathMin(prices[index-1], prices[index-2]);
        double rightHeight = prices[index] - MathMin(prices[index+1], prices[index+2]);
        
        return (leftHeight >= minHeight && rightHeight >= minHeight);
    }
    
    bool IsSwingLow(const double &prices[], int index)
    {
        int size = ArraySize(prices);
        if(index < 2 || index >= size - 2) return false;
        
        // Basic swing low pattern
        bool basicPattern = prices[index] < prices[index-1] && 
                          prices[index] < prices[index-2] &&
                          prices[index] < prices[index+1] && 
                          prices[index] < prices[index+2];
        
        if(!basicPattern) return false;
        
        // Calculate minimum height based on timeframe
        double minHeight;
        switch(Period())
        {
            case PERIOD_MN1: minHeight = _Point * 200; break;
            case PERIOD_W1:  minHeight = _Point * 150; break;
            case PERIOD_D1:  minHeight = _Point * 100; break;
            case PERIOD_H4:  minHeight = _Point * 50;  break;
            case PERIOD_H1:  minHeight = _Point * 25;  break;
            case PERIOD_M30: minHeight = _Point * 15;  break;
            case PERIOD_M15: minHeight = _Point * 10;  break;
            case PERIOD_M5:  minHeight = _Point * 6;   break;
            case PERIOD_M1:  minHeight = _Point * 4;   break;
            default:         minHeight = _Point * 10;  break;
        }
        
        double leftHeight = MathMax(prices[index-1], prices[index-2]) - prices[index];
        double rightHeight = MathMax(prices[index+1], prices[index+2]) - prices[index];
        
        return (leftHeight >= minHeight && rightHeight >= minHeight);
    }
    
    bool IsNearExistingLevel(double price)
    {
        for(int i = 0; i < m_levelCount; i++)
        {
            if(MathAbs(price - m_keyLevels[i].price) <= m_touchZone)
                return true;
        }
        return false;
    }
    
    int CountTouches(double level, bool isResistance, const double &highs[], 
                     const double &lows[], const datetime &times[], STouchQuality &quality)
    {
        quality.touchCount = 0;
        quality.avgBounceStrength = 0;
        quality.avgBounceVolume = 0;
        quality.maxBounceSize = 0;
        quality.quickestBounce = INT_MAX;
        quality.slowestBounce = 0;
        
        int touches = 0;
        double totalBounceStrength = 0;
        double minBounceDistance = m_touchZone * 0.3;
        
        for(int i = 0; i < m_lookbackPeriod - m_maxBounceDelay; i++)
        {
            if(i >= ArraySize(highs) || i >= ArraySize(lows)) break;
            
            double currentPrice = isResistance ? highs[i] : lows[i];
            double touchDistance = MathAbs(currentPrice - level);
            
            if(touchDistance <= m_touchZone)
            {
                // Look for bounce
                double extremePrice = currentPrice;
                int bounceBar = 0;
                
                for(int j = 1; j <= m_maxBounceDelay && (i+j) < ArraySize(highs) && (i+j) < ArraySize(lows); j++)
                {
                    double price = isResistance ? lows[i+j] : highs[i+j];
                    if(isResistance ? (price < extremePrice) : (price > extremePrice))
                    {
                        extremePrice = price;
                        bounceBar = j;
                    }
                }
                
                double bounceSize = MathAbs(currentPrice - extremePrice);
                if(bounceSize >= minBounceDistance)
                {
                    touches++;
                    totalBounceStrength += bounceSize / _Point;
                    
                    quality.maxBounceSize = MathMax(quality.maxBounceSize, bounceSize);
                    quality.quickestBounce = MathMin(quality.quickestBounce, bounceBar);
                    quality.slowestBounce = MathMax(quality.slowestBounce, bounceBar);
                }
            }
        }
        
        if(touches > 0)
        {
            quality.touchCount = touches;
            quality.avgBounceStrength = totalBounceStrength / touches;
        }
        
        return touches;
    }
    
    double CalculateLevelStrength(const SKeyLevel &level, const STouchQuality &quality)
    {
        // Base strength from touch count
        double touchBase = 0.50;
        switch(level.touchCount)
        {
            case 2: touchBase = 0.50; break;
            case 3: touchBase = 0.70; break;
            case 4: touchBase = 0.85; break;
            default: touchBase = MathMin(0.90 + ((level.touchCount - 5) * 0.01), 0.95);
        }
        
        // Recency modifier
        int periodMinutes = PeriodSeconds(Period()) / 60;
        double barsElapsed = (double)(TimeCurrent() - level.lastTouch) / (periodMinutes * 60);
        double recencyMod = 0;
        
        if(barsElapsed <= m_lookbackPeriod / 8)
            recencyMod = 0.30;
        else if(barsElapsed <= m_lookbackPeriod / 4)
            recencyMod = 0.20;
        else if(barsElapsed <= m_lookbackPeriod / 2)
            recencyMod = 0.10;
        else if(barsElapsed > m_lookbackPeriod)
            recencyMod = -0.60;
        
        // Duration bonus
        double barsDuration = (double)(level.lastTouch - level.firstTouch) / (periodMinutes * 60);
        double durationMod = 0;
        
        if(barsDuration >= m_lookbackPeriod * 0.75)
            durationMod = 0.35;
        else if(barsDuration >= m_lookbackPeriod / 2)
            durationMod = 0.25;
        else if(barsDuration >= m_lookbackPeriod / 4)
            durationMod = 0.15;
        else if(barsDuration >= m_lookbackPeriod / 8)
            durationMod = 0.05;
        
        // Quality bonus
        double qualityBonus = 0;
        if(quality.maxBounceSize > 0)
        {
            double bounceConsistency = quality.avgBounceStrength / (quality.maxBounceSize / _Point);
            qualityBonus += bounceConsistency * 0.10;
        }
        
        double strength = touchBase * (1.0 + recencyMod + durationMod + qualityBonus);
        
        return MathMin(MathMax(strength, 0.45), 0.98);
    }
    
    void AddKeyLevel(const SKeyLevel &level)
    {
        if(m_levelCount >= ArraySize(m_keyLevels))
        {
            ArrayResize(m_keyLevels, m_levelCount + 50);
        }
        
        m_keyLevels[m_levelCount] = level;
        m_levelCount++;
        
        if(m_showDebugPrints)
        {
            Print("[Grande] Added ", level.isResistance ? "resistance" : "support", 
                  " level at ", DoubleToString(level.price, _Digits),
                  " (strength: ", DoubleToString(level.strength, 3), ")");
        }
    }
    
    double GetAverageVolume(const long &volumes[], int startIndex, int barsToAverage)
    {
        if(startIndex < 0 || barsToAverage <= 0) return 0.0;
        
        double totalVolume = 0;
        int validBars = 0;
        
        for(int i = 0; i < barsToAverage && (startIndex + i) < ArraySize(volumes); i++)
        {
            totalVolume += (double)volumes[startIndex + i];
            validBars++;
        }
        
        return validBars > 0 ? totalVolume / validBars : 0.0;
    }
    
    double GetVolumeStrengthBonus(const long &volumes[], int index)
    {
        if(index < 0 || index >= ArraySize(volumes)) return 0.0;
        
        double avgVolume = GetAverageVolume(volumes, index, VOLUME_LOOKBACK_BARS);
        if(avgVolume <= 0) return 0.0;
        
        double volumeRatio = (double)volumes[index] / avgVolume;
        
        if(volumeRatio >= VOLUME_SPIKE_MULTIPLIER)
        {
            return MathMin((volumeRatio - 1.0) * 0.1, VOLUME_STRENGTH_MAX_BONUS);
        }
        
        return 0.0;
    }
}; 