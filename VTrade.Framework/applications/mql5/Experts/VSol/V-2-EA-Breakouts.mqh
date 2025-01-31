//+------------------------------------------------------------------+
//|                                              V-2-EA-Breakouts.mqh |
//|                                    Key Level Detection Implementation|
//+------------------------------------------------------------------+
#property copyright "Rommel Company"
#property link      "Your Link"
#property version   "1.01"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Constants                                                          |
//+------------------------------------------------------------------+
#define DEFAULT_BUFFER_SIZE 100 // Default size for price buffers
#define DEFAULT_DEBUG_INTERVAL 300 // Default debug interval (5 minutes)

//+------------------------------------------------------------------+
//| Structure Definitions                                              |
//+------------------------------------------------------------------+
struct SKeyLevel
{
    double    price;           // The price level
    int       touchCount;      // Number of times price touched this level
    bool      isResistance;    // Whether this is resistance (true) or support (false)
    datetime  firstTouch;      // Time of first touch
    datetime  lastTouch;       // Time of last touch
    double    strength;        // Relative strength of the level
};

struct SStrategyState
{
    bool      keyLevelFound;    // Whether a valid key level was found
    SKeyLevel activeKeyLevel;   // Currently active key level
    datetime  lastUpdate;       // Last time the state was updated
    
    void Reset()
    {
        keyLevelFound = false;
        lastUpdate = 0;
    }
};

//--- Level Performance Tracking
struct SLevelPerformance
{
    int successfulBounces;    // Number of times price respected the level
    int falseBreaks;         // Number of times price broke but returned
    int trueBreaks;          // Number of times price broke decisively
    double avgBounceSize;    // Average size of bounces from this level
    double successRate;      // Ratio of successful bounces to total tests
    
    void Reset()
    {
        successfulBounces = 0;
        falseBreaks = 0;
        trueBreaks = 0;
        avgBounceSize = 0;
        successRate = 0;
    }
};

//--- System Health Tracking
struct SSystemHealth
{
    int missedOpportunities;  // Clear levels that weren't detected
    int falseSignals;        // Invalid levels that were detected
    double detectionRate;     // Ratio of correct detections to total
    double noiseRatio;       // Ratio of false signals to valid signals
    datetime lastUpdate;      // Last time health metrics were updated
    
    void Reset()
    {
        missedOpportunities = 0;
        falseSignals = 0;
        detectionRate = 0;
        noiseRatio = 0;
        lastUpdate = 0;
    }
};

// Add after other struct definitions
struct SChartLine
{
    string name;        // Unique line name
    double price;      // Price level
    datetime lastUpdate; // Last update time
    color lineColor;   // Line color
    bool isActive;     // Whether line is currently shown
};

//+------------------------------------------------------------------+
//| Key Level Detection Class                                          |
//+------------------------------------------------------------------+
class CV2EABreakouts
{
private:
    //--- Key Level Parameters
    int           m_lookbackPeriod;    // Bars to look back for key levels
    double        m_minStrength;       // Minimum strength threshold for key levels
    double        m_touchZone;         // Zone size for touch detection
    int           m_minTouches;        // Minimum touches required
    
    //--- Key Level State
    SKeyLevel     m_currentKeyLevels[]; // Array of current key levels
    int           m_keyLevelCount;      // Number of valid key levels
    datetime      m_lastKeyLevelUpdate; // Last time key levels were updated
    
    //--- Strategy State
    SStrategyState m_state;            // Current strategy state
    
    //--- Debug settings
    bool            m_showDebugPrints; // Debug mode
    bool            m_initialized;      // Initialization state
    
    //--- Hourly statistics
    struct SHourlyStats
    {
        int totalSwingHighs;
        int totalSwingLows;
        int nearExistingLevels;
        int lowTouchCount;
        int lowStrength;
        int validLevels;
        double strongestLevel;
        double strongestStrength;
        int strongestTouches;
        bool isStrongestResistance;
        
        void Reset()
        {
            totalSwingHighs = 0;
            totalSwingLows = 0;
            nearExistingLevels = 0;
            lowTouchCount = 0;
            lowStrength = 0;
            validLevels = 0;
            strongestLevel = 0;
            strongestStrength = 0;
            strongestTouches = 0;
            isStrongestResistance = false;
        }
    } m_hourlyStats;

    //--- Performance tracking
    SLevelPerformance m_levelPerformance;  // Track level performance
    SSystemHealth m_systemHealth;          // Track system health
    
    //--- Key level history
    double m_recentBreaks[];              // Store recent level breaks
    datetime m_recentBreakTimes[];        // Times of recent breaks
    int m_recentBreakCount;               // Count of recent breaks

    struct SAlertTime
    {
        double price;
        datetime lastAlert;
    };
    SAlertTime m_lastAlerts[];  // Array to track last alert times for each level

    //--- Add to class private members
    SChartLine m_chartLines[];  // Array to track chart lines
    datetime m_lastChartUpdate; // Last chart update time

public:
    //--- Constructor and destructor
    CV2EABreakouts(void) : m_initialized(false),
                           m_lookbackPeriod(0),     // Will be set based on timeframe
                           m_minStrength(0.55),
                           m_touchZone(0),          // Will be set based on timeframe
                           m_minTouches(2),
                           m_keyLevelCount(0),
                           m_lastKeyLevelUpdate(0),
                           m_showDebugPrints(false)
    {
        ArrayResize(m_currentKeyLevels, DEFAULT_BUFFER_SIZE);
        m_state.Reset();
    }
    
    ~CV2EABreakouts(void)
    {
        // Clear all chart objects created by this EA
        for(int i = 0; i < ArraySize(m_chartLines); i++)
        {
            ObjectDelete(0, m_chartLines[i].name);
        }
    }
    
    //--- Initialization
    bool Init(int lookbackPeriod, double minStrength, double touchZone, 
              int minTouches, bool showDebugPrints)
    {
        // Adjust lookback period based on timeframe
        ENUM_TIMEFRAMES tf = Period();
        int periodMinutes = PeriodSeconds(tf) / 60;
        
        // Set default lookback to cover approximately 5 days of data
        if(lookbackPeriod == 0)
        {
            int barsPerDay = 1440 / periodMinutes;  // 1440 minutes in a day
            m_lookbackPeriod = barsPerDay * 5;      // 5 days of data
        }
        else
        {
            m_lookbackPeriod = lookbackPeriod;
        }
        
        // Adjust touch zone based on timeframe
        if(touchZone == 0)
        {
            switch(tf)
            {
                case PERIOD_M1:  m_touchZone = 0.0003; break; // 3 pips
                case PERIOD_M5:  m_touchZone = 0.0005; break; // 5 pips
                case PERIOD_M15: m_touchZone = 0.0007; break; // 7 pips
                case PERIOD_M30: m_touchZone = 0.0010; break; // 10 pips
                case PERIOD_H1:  m_touchZone = 0.0015; break; // 15 pips
                case PERIOD_H4:  m_touchZone = 0.0020; break; // 20 pips
                case PERIOD_D1:  m_touchZone = 0.0030; break; // 30 pips
                default:         m_touchZone = 0.0005;        // Default 5 pips
            }
        }
        else
        {
            m_touchZone = touchZone;
        }
        
        m_minStrength = minStrength;
        m_minTouches = minTouches;
        m_showDebugPrints = showDebugPrints;
        
        m_initialized = true;
        
        // Enhanced debug information for timeframe verification
        string timeframeInfo = StringFormat(
            "\n=== TIMEFRAME CONFIGURATION DETAILS ===\n" +
            "Timeframe: %s\n" +
            "Period Minutes: %d\n" +
            "Bars per Day: %d\n" +
            "Lookback Period: %d bars (%.1f days)\n" +
            "Touch Zone: %.5f (%d pips)\n" +
            "Touch Zone Range in Points: %.1f to %.1f\n" +
            "Min Strength Threshold: %.2f\n" +
            "Min Touches Required: %d\n" +
            "Current Symbol Point: %.5f\n" +
            "=== END CONFIGURATION ===",
            EnumToString(tf),
            periodMinutes,
            1440 / periodMinutes,
            m_lookbackPeriod,
            (double)m_lookbackPeriod * periodMinutes / 1440,
            m_touchZone,
            (int)(m_touchZone * 10000),
            m_touchZone / _Point,
            m_touchZone * 3 / _Point,  // Max range for touch validation
            m_minStrength,
            m_minTouches,
            _Point
        );
        
        Print(timeframeInfo);
        
        return true;
    }
    
    //--- Main Strategy Method
    void ProcessStrategy()
    {
        if(!m_initialized)
        {
            DebugPrint("❌ Strategy not initialized");
            return;
        }
        
        datetime currentTime = TimeCurrent();
        
        // Step 1: Key Level Identification
        SKeyLevel strongestLevel;
        bool foundKeyLevel = FindKeyLevels(strongestLevel);
        
        // Update system state
        if(foundKeyLevel)
        {
            // If we found a new key level that's significantly different from our active one
            if(!m_state.keyLevelFound || 
               MathAbs(strongestLevel.price - m_state.activeKeyLevel.price) > m_touchZone)
            {
                // Update strategy state with new key level
                m_state.keyLevelFound = true;
                m_state.activeKeyLevel = strongestLevel;
                m_state.lastUpdate = currentTime;
                
                // Print key levels report when we find a new significant level
                PrintKeyLevelsReport();
            }
        }
        else if(m_state.keyLevelFound)
        {
            // If we had a key level but can't find it anymore, reset state
            DebugPrint("ℹ️ Previous key level no longer valid, resetting state");
            m_state.Reset();
        }
        
        // Step 2: Check for price approaching key levels
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        for(int i = 0; i < m_keyLevelCount; i++)
        {
            double distance = MathAbs(currentPrice - m_currentKeyLevels[i].price);
            if(distance <= m_touchZone * 2) // Alert when price is within 2x the touch zone
            {
                PrintTradeSetupAlert(m_currentKeyLevels[i], distance);
            }
        }
        
        // Step 3: Update and print system health report (hourly)
        PrintSystemHealthReport();
        
        // Step 4: Update chart lines
        UpdateChartLines();
        
        // Future steps will be added here:
        // Step 5: Breakout Detection
        // Step 6: Retest Validation
        // Step 7: Trade Management
    }
    
    // Helper method to update system health metrics
    void UpdateSystemHealth(bool validDetection, bool falseSignal)
    {
        static int totalDetections = 0;
        totalDetections++;
        
        if(validDetection)
            m_systemHealth.detectionRate = (m_systemHealth.detectionRate * (totalDetections - 1) + 1.0) / totalDetections;
        
        if(falseSignal)
        {
            m_systemHealth.falseSignals++;
            m_systemHealth.noiseRatio = (double)m_systemHealth.falseSignals / totalDetections;
        }
    }
    
    // Helper method to track level breaks
    void AddLevelBreak(double price, bool isFalseBreak = false)
    {
        if(isFalseBreak)
        {
            m_levelPerformance.falseBreaks++;
        }
        else
        {
            m_levelPerformance.trueBreaks++;
            
            // Add to recent breaks array
            if(m_recentBreakCount >= ArraySize(m_recentBreaks))
            {
                ArrayResize(m_recentBreaks, m_recentBreakCount + 10);
                ArrayResize(m_recentBreakTimes, m_recentBreakCount + 10);
            }
            
            m_recentBreaks[m_recentBreakCount] = price;
            m_recentBreakTimes[m_recentBreakCount] = TimeCurrent();
            m_recentBreakCount++;
        }
        
        // Update success rate
        int totalTests = m_levelPerformance.successfulBounces + 
                        m_levelPerformance.falseBreaks + 
                        m_levelPerformance.trueBreaks;
        
        if(totalTests > 0)
            m_levelPerformance.successRate = (double)m_levelPerformance.successfulBounces / totalTests;
    }
    
    void PrintHourlySummary()
    {
        string timeStr = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
        
        DebugPrint(StringFormat(
            "\n📊 HOURLY LEVEL DETECTION REPORT - %s 📊\n" +
            "================================================\n" +
            "SUMMARY STATISTICS:\n" +
            "🔍 Total Analysis:\n" +
            "   ↗️ Swing Highs: %d\n" +
            "   ↘️ Swing Lows: %d\n" +
            "   🎯 Near Existing: %d\n" +
            "\n" +
            "LEVEL QUALITY:\n" +
            "   ❌ Low Touch Count: %d\n" +
            "   ❌ Low Strength: %d\n" +
            "   ✅ Valid Levels: %d\n" +
            "\n" +
            "STRONGEST LEVEL:\n" +
            "   📍 Price: %.5f\n" +
            "   💪 Strength: %.4f\n" +
            "   👆 Touches: %d\n" +
            "   📈 Type: %s\n" +
            "================================================\n",
            timeStr,
            m_hourlyStats.totalSwingHighs,
            m_hourlyStats.totalSwingLows,
            m_hourlyStats.nearExistingLevels,
            m_hourlyStats.lowTouchCount,
            m_hourlyStats.lowStrength,
            m_hourlyStats.validLevels,
            m_hourlyStats.strongestLevel,
            m_hourlyStats.strongestStrength,
            m_hourlyStats.strongestTouches,
            m_hourlyStats.isStrongestResistance ? "RESISTANCE 🔴" : "SUPPORT 🟢"
        ));
    }
    
    //--- Key Level Methods
    bool FindKeyLevels(SKeyLevel &outStrongestLevel)
    {
        if(!m_initialized)
            return false;
            
        // Copy price data
        double highPrices[];
        double lowPrices[];
        double closePrices[];
        datetime times[];
        
        ArraySetAsSeries(highPrices, true);
        ArraySetAsSeries(lowPrices, true);
        ArraySetAsSeries(closePrices, true);
        ArraySetAsSeries(times, true);
        
        if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, m_lookbackPeriod, highPrices) <= 0 ||
           CopyLow(_Symbol, PERIOD_CURRENT, 0, m_lookbackPeriod, lowPrices) <= 0 ||
           CopyClose(_Symbol, PERIOD_CURRENT, 0, m_lookbackPeriod, closePrices) <= 0 ||
           CopyTime(_Symbol, PERIOD_CURRENT, 0, m_lookbackPeriod, times) <= 0)
        {
            DebugPrint("❌ Failed to copy price data");
            return false;
        }
        
        // Reset key levels array
        m_keyLevelCount = 0;
        
        // Get current hour for stats tracking
        datetime currentTime = TimeCurrent();
        MqlDateTime dt;
        TimeToStruct(currentTime, dt);
        datetime currentHour = currentTime - dt.min * 60 - dt.sec;
        
        static datetime lastStatReset = 0;
        
        // Check if we need to reset hourly stats
        if(lastStatReset < currentHour)
        {
            // Reset hourly stats structure
            m_hourlyStats.Reset();
            lastStatReset = currentHour;
            
            DebugPrint("🔄 Reset hourly stats for new hour");
        }
        
        // Find swing highs (resistance levels)
        for(int i = 2; i < m_lookbackPeriod - 2; i++)
        {
            if(IsSwingHigh(highPrices, i))
            {
                m_hourlyStats.totalSwingHighs++;
                double level = highPrices[i];
                
                if(!IsNearExistingLevel(level))
                {
                    SKeyLevel newLevel;
                    newLevel.price = level;
                    newLevel.isResistance = true;
                    newLevel.firstTouch = times[i];
                    newLevel.lastTouch = times[i];
                    newLevel.touchCount = CountTouches(level, true, highPrices, lowPrices, times);
                    
                    if(newLevel.touchCount < m_minTouches)
                    {
                        m_hourlyStats.lowTouchCount++;
                        continue;
                    }
                    
                    newLevel.strength = CalculateLevelStrength(newLevel);
                    
                    if(newLevel.strength >= m_minStrength)
                    {
                        AddKeyLevel(newLevel);
                        m_hourlyStats.validLevels++;
                    }
                    else
                    {
                        m_hourlyStats.lowStrength++;
                    }
                }
                else
                {
                    m_hourlyStats.nearExistingLevels++;
                }
            }
        }
        
        // Find swing lows (support levels)
        for(int i = 2; i < m_lookbackPeriod - 2; i++)
        {
            if(IsSwingLow(lowPrices, i))
            {
                m_hourlyStats.totalSwingLows++;
                double level = lowPrices[i];
                
                if(!IsNearExistingLevel(level))
                {
                    SKeyLevel newLevel;
                    newLevel.price = level;
                    newLevel.isResistance = false;
                    newLevel.firstTouch = times[i];
                    newLevel.lastTouch = times[i];
                    newLevel.touchCount = CountTouches(level, false, highPrices, lowPrices, times);
                    
                    if(newLevel.touchCount < m_minTouches)
                    {
                        m_hourlyStats.lowTouchCount++;
                        continue;
                    }
                    
                    newLevel.strength = CalculateLevelStrength(newLevel);
                    
                    if(newLevel.strength >= m_minStrength)
                    {
                        AddKeyLevel(newLevel);
                        m_hourlyStats.validLevels++;
                    }
                    else
                    {
                        m_hourlyStats.lowStrength++;
                    }
                }
                else
                {
                    m_hourlyStats.nearExistingLevels++;
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

    //--- Add to public methods section
    void ClearChartObjects()
    {
        // Clear all existing chart lines
        for(int i = 0; i < ArraySize(m_chartLines); i++)
        {
            if(!ObjectDelete(0, m_chartLines[i].name))
            {
                DebugPrint(StringFormat("❌ Failed to delete line %s", m_chartLines[i].name));
            }
        }
        
        // Reset chart lines array
        ArrayResize(m_chartLines, 0);
        m_lastChartUpdate = 0;
        
        // Force chart redraw
        ChartRedraw(0);
        
        if(m_showDebugPrints)
            DebugPrint("🧹 Cleared all chart objects");
    }

private:
    //--- Key Level Helper Methods
    bool IsSwingHigh(const double &prices[], int index)
    {
        return prices[index] > prices[index-1] && 
               prices[index] > prices[index-2] &&
               prices[index] > prices[index+1] && 
               prices[index] > prices[index+2];
    }
    
    bool IsSwingLow(const double &prices[], int index)
    {
        return prices[index] < prices[index-1] && 
               prices[index] < prices[index-2] &&
               prices[index] < prices[index+1] && 
               prices[index] < prices[index+2];
    }
    
    bool IsNearExistingLevel(double price)
    {
        for(int i = 0; i < m_keyLevelCount; i++)
        {
            if(MathAbs(price - m_currentKeyLevels[i].price) <= m_touchZone)
                return true;
        }
        return false;
    }
    
    int CountTouches(double level, bool isResistance, const double &highs[], 
                     const double &lows[], const datetime &times[])
    {
        int touches = 0;
        double lastPrice = 0;
        datetime lastTouchTime = 0;
        
        // Calculate pip size based on digits
        double pipSize = _Point;
        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
        if(digits == 3 || digits == 5)  // JPY pairs or 3-digit pairs
            pipSize = _Point * 10;
        
        // Debug info for touch zone
        if(m_showDebugPrints)
        {
            Print(StringFormat(
                "\n=== TOUCH DETECTION FOR LEVEL %.5f ===\n" +
                "Type: %s\n" +
                "Touch Zone Size: %.5f (%d pips)\n" +
                "Valid Range: %.5f to %.5f",
                level,
                isResistance ? "RESISTANCE" : "SUPPORT",
                m_touchZone,
                (int)(m_touchZone / pipSize),  // Convert to actual pips
                level - m_touchZone,
                level + m_touchZone
            ));
        }
        
        for(int i = 0; i < m_lookbackPeriod; i++)
        {
            if(isResistance)
            {
                if(MathAbs(highs[i] - level) <= m_touchZone)
                {
                    // Only count as new touch if price moved away from level
                    if(lastPrice == 0 || MathAbs(highs[i] - lastPrice) > m_touchZone * 2)
                    {
                        touches++;
                        lastPrice = highs[i];
                        
                        if(m_showDebugPrints)
                        {
                            datetime touchTime = times[i];
                            string timeGap = lastTouchTime == 0 ? "FIRST TOUCH" : 
                                           StringFormat("%.1f hours from last", 
                                           (double)(touchTime - lastTouchTime) / 3600);
                                           
                            Print(StringFormat(
                                "✓ Touch %d at %.5f (%.1f pips from level) - %s",
                                touches,
                                highs[i],
                                MathAbs(highs[i] - level) / pipSize,
                                timeGap
                            ));
                            
                            lastTouchTime = touchTime;
                        }
                    }
                }
                else if(MathAbs(highs[i] - level) > m_touchZone * 3)
                {
                    // Reset last price if moved far enough away
                    lastPrice = 0;
                }
            }
            else
            {
                if(MathAbs(lows[i] - level) <= m_touchZone)
                {
                    if(lastPrice == 0 || MathAbs(lows[i] - lastPrice) > m_touchZone * 2)
                    {
                        touches++;
                        lastPrice = lows[i];
                        
                        if(m_showDebugPrints)
                        {
                            datetime touchTime = times[i];
                            string timeGap = lastTouchTime == 0 ? "FIRST TOUCH" : 
                                           StringFormat("%.1f hours from last", 
                                           (double)(touchTime - lastTouchTime) / 3600);
                                           
                            Print(StringFormat(
                                "✓ Touch %d at %.5f (%.1f pips from level) - %s",
                                touches,
                                lows[i],
                                MathAbs(lows[i] - level) / pipSize,
                                timeGap
                            ));
                            
                            lastTouchTime = touchTime;
                        }
                    }
                }
                else if(MathAbs(lows[i] - level) > m_touchZone * 3)
                {
                    lastPrice = 0;
                }
            }
        }
        
        if(m_showDebugPrints && touches > 0)
        {
            Print(StringFormat(
                "=== TOTAL TOUCHES: %d ===\n",
                touches
            ));
        }
        
        return touches;
    }
    
    double CalculateLevelStrength(const SKeyLevel &level)
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
        
        // Adjust recency based on timeframe
        if(barsElapsed <= m_lookbackPeriod / 4) {  // Very recent (within 1/4 of lookback)
            recencyMod = 0.30;
        } else if(barsElapsed <= m_lookbackPeriod / 2) {  // Recent (within 1/2 of lookback)
            recencyMod = 0.15;
        } else if(barsElapsed <= m_lookbackPeriod) {  // Within lookback
            recencyMod = 0;
        } else {  // Old
            recencyMod = -0.60;
        }
        
        // Duration bonus (up to +35% of base)
        double barsDuration = (double)(level.lastTouch - level.firstTouch) / (periodMinutes * 60);
        double durationMod = 0;
        
        if(barsDuration >= m_lookbackPeriod / 2) {  // Long-lasting
            durationMod = 0.35;
        } else if(barsDuration >= m_lookbackPeriod / 4) {  // Medium duration
            durationMod = 0.20;
        } else if(barsDuration >= m_lookbackPeriod / 8) {  // Short duration
            durationMod = 0.10;
        }
        
        // Calculate final strength with modifiers
        double strength = touchBase * (1.0 + recencyMod + durationMod);
        
        // Add tiny random variation (0.05% max)
        strength += 0.0005 * MathMod(level.price * 10000, 10) / 10;
        
        // Ensure bounds
        return MathMin(MathMax(strength, 0.45), 0.98);
    }
    
    void AddKeyLevel(const SKeyLevel &level)
    {
        if(m_keyLevelCount < ArraySize(m_currentKeyLevels))
        {
            m_currentKeyLevels[m_keyLevelCount] = level;
            m_keyLevelCount++;
            
            // Change debug level to VERBOSE so it only shows in full debug mode
            DebugPrint(StringFormat(
                "✅ Added %s level at %.5f with strength %.4f",
                level.isResistance ? "resistance" : "support",
                level.price,
                level.strength
            ));  // Changed from DEBUG_NORMAL to DEBUG_VERBOSE
        }
    }
    
    //--- Debug print method
    void DebugPrint(string message)
    {
        if(!m_showDebugPrints)
            return;
            
        // Add timestamp and current price to debug messages
        string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        Print(StringFormat("[%s] [%.5f] %s", timestamp, currentPrice, message));
    }

    void PrintKeyLevelsReport()
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
        
        // Print Recent Breaks if any (limit to last 3)
        if(m_recentBreakCount > 0)
        {
            DebugPrint("\nRECENT BREAKS:");
            for(int i = MathMax(0, m_recentBreakCount - 3); i < m_recentBreakCount; i++)
            {
                DebugPrint(StringFormat("%.5f @ %s",
                    m_recentBreaks[i],
                    TimeToString(m_recentBreakTimes[i], TIME_MINUTES)));
            }
        }
    }
    
    void PrintSystemHealthReport()
    {
        if(!m_showDebugPrints) return;
        if(m_systemHealth.lastUpdate == 0) return;
        
        datetime currentTime = TimeCurrent();
        if(currentTime - m_systemHealth.lastUpdate < 3600) return; // Only update hourly
        
        DebugPrint(StringFormat(
            "\n=== SYSTEM HEALTH REPORT ===\n" +
            "Detection Rate: %.1f%%\n" +
            "Noise Ratio: %.1f%%\n" +
            "Missed Opportunities: %d\n" +
            "False Signals: %d",
            m_systemHealth.detectionRate * 100,
            m_systemHealth.noiseRatio * 100,
            m_systemHealth.missedOpportunities,
            m_systemHealth.falseSignals));
            
        m_systemHealth.lastUpdate = currentTime;
    }
    
    void PrintTradeSetupAlert(const SKeyLevel &level, double distance)
    {
        if(!m_showDebugPrints) return;
        
        // Only alert if price is within 30 pips of the level
        if(distance > 0.0030) return;
        
        // Check last alert time for this level
        datetime lastAlertTime = 0;
        bool found = false;
        
        for(int i = 0; i < ArraySize(m_lastAlerts); i++)
        {
            if(MathAbs(m_lastAlerts[i].price - level.price) < m_touchZone)
            {
                lastAlertTime = m_lastAlerts[i].lastAlert;
                found = true;
                break;
            }
        }
        
        // Prevent alert spam by requiring minimum 5 minutes between alerts for same level
        datetime currentTime = TimeCurrent();
        if(found && currentTime - lastAlertTime < 300) return;
        
        // Only alert if level has some proven success
        if(m_levelPerformance.successRate < 0.30) return;
        
        DebugPrint(StringFormat(
            "\n🔔 TRADE SETUP ALERT\n" +
            "Price approaching %s @ %.5f\n" +
            "Distance: %.1f pips\n" +
            "Level Strength: %.2f\n" +
            "Previous Touches: %d\n" +
            "Success Rate: %.1f%%",
            level.isResistance ? "resistance" : "support",
            level.price,
            distance / _Point,
            level.strength,
            level.touchCount,
            m_levelPerformance.successRate * 100));
        
        // Update last alert time
        if(!found)
        {
            int size = ArraySize(m_lastAlerts);
            ArrayResize(m_lastAlerts, size + 1);
            m_lastAlerts[size].price = level.price;
            m_lastAlerts[size].lastAlert = currentTime;
        }
        else
        {
            for(int i = 0; i < ArraySize(m_lastAlerts); i++)
            {
                if(MathAbs(m_lastAlerts[i].price - level.price) < m_touchZone)
                {
                    m_lastAlerts[i].lastAlert = currentTime;
                    break;
                }
            }
        }
    }
    
    //--- Add new methods
    void UpdateChartLines()
    {
        datetime currentTime = TimeCurrent();
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        // Update if an hour has passed or if it's the first update
        bool shouldUpdate = (m_lastChartUpdate == 0) || 
                           (currentTime - m_lastChartUpdate >= 3600) ||
                           (m_keyLevelCount != ArraySize(m_chartLines));
                
        if(!shouldUpdate)
            return;
                
        // Clear old lines
        ClearInactiveChartLines();
        
        // Mark all lines as inactive before update
        for(int i = 0; i < ArraySize(m_chartLines); i++)
            m_chartLines[i].isActive = false;
        
        // Update lines for current key levels
        for(int i = 0; i < m_keyLevelCount; i++)
        {
            string lineName = StringFormat("KL_%s_%.5f", 
                m_currentKeyLevels[i].isResistance ? "R" : "S",
                m_currentKeyLevels[i].price);
                    
            // First determine if this is above or below current price
            bool isAbovePrice = m_currentKeyLevels[i].price > currentPrice;
            
            // Determine line properties based on position and strength
            color lineColor;
            ENUM_LINE_STYLE lineStyle;
            int lineWidth;
            
            // Strong levels (>= 0.85)
            if(m_currentKeyLevels[i].strength >= 0.85) {
                if(isAbovePrice) {
                    lineColor = clrCrimson;      // Strong resistance = dark red
                } else {
                    lineColor = clrForestGreen;  // Strong support = dark green
                }
                lineStyle = STYLE_SOLID;
                lineWidth = 2;
            }
            // Medium levels (>= 0.70)
            else if(m_currentKeyLevels[i].strength >= 0.70) {
                if(isAbovePrice) {
                    lineColor = clrLightCoral;      // Medium resistance = lighter red
                } else {
                    lineColor = clrMediumSeaGreen;  // Medium support = lighter green
                }
                lineStyle = STYLE_SOLID;
                lineWidth = 1;
            }
            // Weak levels (< 0.70)
            else {
                if(isAbovePrice) {
                    lineColor = clrPink;       // Weak resistance = very light red
                } else {
                    lineColor = clrPaleGreen;  // Weak support = very light green
                }
                lineStyle = STYLE_DOT;
                lineWidth = 1;
            }
            
            // Check if line already exists
            bool found = false;
            for(int j = 0; j < ArraySize(m_chartLines); j++)
            {
                if(m_chartLines[j].name == lineName)
                {
                    // Update existing line
                    m_chartLines[j].isActive = true;
                    m_chartLines[j].lineColor = lineColor;
                    m_chartLines[j].lastUpdate = currentTime;
                    found = true;
                    
                    // Update line properties
                    ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
                    ObjectSetInteger(0, lineName, OBJPROP_STYLE, lineStyle);
                    ObjectSetInteger(0, lineName, OBJPROP_WIDTH, lineWidth);
                    
                    // Update tooltip with more information
                    string tooltip = StringFormat("%s Level\nStrength: %.2f\nTouches: %d\nDistance: %d pips", 
                        isAbovePrice ? "Resistance" : "Support",
                        m_currentKeyLevels[i].strength,
                        m_currentKeyLevels[i].touchCount,
                        (int)(MathAbs(m_currentKeyLevels[i].price - currentPrice) / _Point));
                    ObjectSetString(0, lineName, OBJPROP_TOOLTIP, tooltip);
                    break;
                }
            }
            
            // Create new line if not found
            if(!found)
            {
                int size = ArraySize(m_chartLines);
                ArrayResize(m_chartLines, size + 1);
                m_chartLines[size].name = lineName;
                m_chartLines[size].price = m_currentKeyLevels[i].price;
                m_chartLines[size].lastUpdate = currentTime;
                m_chartLines[size].lineColor = lineColor;
                m_chartLines[size].isActive = true;
                
                // Create and set up new line
                if(ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, m_currentKeyLevels[i].price))
                {
                    ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
                    ObjectSetInteger(0, lineName, OBJPROP_STYLE, lineStyle);
                    ObjectSetInteger(0, lineName, OBJPROP_WIDTH, lineWidth);
                    ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
                    ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
                    
                    // Enhanced tooltip with more information
                    string tooltip = StringFormat("%s Level\nStrength: %.2f\nTouches: %d\nDistance: %d pips", 
                        isAbovePrice ? "Resistance" : "Support",
                        m_currentKeyLevels[i].strength,
                        m_currentKeyLevels[i].touchCount,
                        (int)(MathAbs(m_currentKeyLevels[i].price - currentPrice) / _Point));
                    ObjectSetString(0, lineName, OBJPROP_TOOLTIP, tooltip);
                }
                else
                {
                    DebugPrint(StringFormat("❌ Failed to create line %s", lineName));
                }
            }
        }
        
        m_lastChartUpdate = currentTime;
        ChartRedraw(0);  // Force chart redraw
    }
    
    void ClearInactiveChartLines()
    {
        // First pass: delete objects for inactive lines
        for(int i = 0; i < ArraySize(m_chartLines); i++)
        {
            if(!m_chartLines[i].isActive)
            {
                if(!ObjectDelete(0, m_chartLines[i].name))
                {
                    DebugPrint(StringFormat("❌ Failed to delete line %s", m_chartLines[i].name));
                }
            }
        }
        
        // Second pass: remove inactive lines from array
        int newSize = 0;
        SChartLine tempLines[];
        ArrayResize(tempLines, ArraySize(m_chartLines));
        
        // Copy active lines to temporary array
        for(int i = 0; i < ArraySize(m_chartLines); i++)
        {
            if(m_chartLines[i].isActive)
            {
                tempLines[newSize] = m_chartLines[i];
                newSize++;
            }
        }
        
        // Resize and copy back
        ArrayResize(tempLines, newSize);
        ArrayResize(m_chartLines, newSize);
        for(int i = 0; i < newSize; i++)
        {
            m_chartLines[i] = tempLines[i];
        }
    }
}; 