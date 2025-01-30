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

//+------------------------------------------------------------------+
//| Key Level Detection Class                                          |
//+------------------------------------------------------------------+
class CV2EABreakouts
{
private:
    //--- Debug levels
    enum ENUM_DEBUG_LEVEL
    {
        DEBUG_NONE = 0,      // No debug output
        DEBUG_ERRORS = 1,    // Only errors
        DEBUG_IMPORTANT = 2, // Important events (trades, major state changes)
        DEBUG_NORMAL = 3,    // Normal operational events
        DEBUG_VERBOSE = 4    // All events including validation checks
    };
    
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
    ENUM_DEBUG_LEVEL m_debugLevel;     // Current debug level
    datetime         m_lastDebugTime;   // Last debug print time
    datetime         m_lastHourlyReport;// Last hourly report time
    int             m_debugInterval;    // Minimum seconds between performance prints
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

public:
    //--- Constructor and destructor
    CV2EABreakouts(void) : m_initialized(false),
                           m_lookbackPeriod(288),
                           m_minStrength(0.55),     // Reduced from 0.65
                           m_touchZone(0.0005),     // Increased to 5 pips
                           m_minTouches(2),         // Reduced from 3
                           m_keyLevelCount(0),
                           m_lastKeyLevelUpdate(0),
                           m_debugLevel(DEBUG_IMPORTANT),
                           m_lastDebugTime(0),
                           m_lastHourlyReport(0),
                           m_debugInterval(300),
                           m_showDebugPrints(false)
    {
        ArrayResize(m_currentKeyLevels, DEFAULT_BUFFER_SIZE);
        m_state.Reset();
    }
    
    ~CV2EABreakouts(void) {}
    
    //--- Initialization
    bool Init(int lookbackPeriod, double minStrength, double touchZone, 
              int minTouches, bool showDebugPrints, ENUM_DEBUG_LEVEL debugLevel=DEBUG_IMPORTANT)
    {
        m_lookbackPeriod = lookbackPeriod;
        m_minStrength = minStrength;
        m_touchZone = touchZone;
        m_minTouches = minTouches;
        m_showDebugPrints = showDebugPrints;
        
        // Ensure we never set to VERBOSE unless explicitly requested
        m_debugLevel = (debugLevel == DEBUG_VERBOSE) ? DEBUG_IMPORTANT : debugLevel;
        
        m_initialized = true;
        DebugPrint("✅ Key Level Detection initialized successfully", DEBUG_IMPORTANT);
        
        // Print initial configuration only for IMPORTANT level
        DebugPrint(StringFormat(
            "📋 Configuration:" +
            "\n  LookbackPeriod: %d" +
            "\n  MinStrength: %.2f" +
            "\n  TouchZone: %.5f" +
            "\n  MinTouches: %d" +
            "\n  DebugLevel: %d",
            m_lookbackPeriod,
            m_minStrength,
            m_touchZone,
            m_minTouches,
            m_debugLevel
        ), DEBUG_IMPORTANT);
        
        return true;
    }
    
    //--- Main Strategy Method
    void ProcessStrategy()
    {
        if(!m_initialized)
        {
            DebugPrint("❌ Strategy not initialized", DEBUG_ERRORS);
            return;
        }
        
        // Check if it's time for hourly report
        datetime currentTime = TimeCurrent();
        
        // Get current hour components for more explicit hour change detection
        MqlDateTime dt;
        TimeToStruct(currentTime, dt);
        datetime currentHour = currentTime - dt.min * 60 - dt.sec;  // More precise hour rounding
        
        // Validate last report time
        if(m_lastHourlyReport > currentTime)
        {
            DebugPrint("⚠️ Invalid last report time detected, resetting", DEBUG_ERRORS);
            m_lastHourlyReport = 0;
        }
        
        // Only print report at the start of each hour
        if(m_lastHourlyReport == 0 || currentHour > m_lastHourlyReport)
        {
            // Print hourly summary and reset stats
            PrintHourlySummary();
            
            // Ensure complete reset of all stats
            m_hourlyStats.Reset();
            m_hourlyStats.lowTouchCount = 0;  // Explicitly reset low touch count
            m_hourlyStats.lowStrength = 0;    // Explicitly reset low strength
            m_hourlyStats.validLevels = 0;    // Explicitly reset valid levels
            
            m_lastHourlyReport = currentHour;  // Store the hour timestamp
            
            DebugPrint(StringFormat("📊 Starting new hourly period at %s", 
                TimeToString(currentTime, TIME_DATE|TIME_MINUTES)), DEBUG_NORMAL);
        }
        
        // Step 1: Key Level Identification
        SKeyLevel strongestLevel;
        bool foundKeyLevel = FindKeyLevels(strongestLevel);
        
        // Update hourly statistics
        if(foundKeyLevel)
        {
            // Update strongest level if needed
            if(strongestLevel.strength > m_hourlyStats.strongestStrength)
            {
                m_hourlyStats.strongestLevel = strongestLevel.price;
                m_hourlyStats.strongestStrength = strongestLevel.strength;
                m_hourlyStats.strongestTouches = strongestLevel.touchCount;
                m_hourlyStats.isStrongestResistance = strongestLevel.isResistance;
            }
            
            // If we found a new key level that's significantly different from our active one
            if(!m_state.keyLevelFound || 
               MathAbs(strongestLevel.price - m_state.activeKeyLevel.price) > m_touchZone)
            {
                // Update strategy state with new key level
                m_state.keyLevelFound = true;
                m_state.activeKeyLevel = strongestLevel;
                m_state.lastUpdate = TimeCurrent();
                
            }
        }
        else if(m_state.keyLevelFound)
        {
            // If we had a key level but can't find it anymore, reset state
            DebugPrint("ℹ️ Previous key level no longer valid, resetting state", DEBUG_NORMAL);
            m_state.Reset();
        }
        
        // Future steps will be added here:
        // Step 2: Breakout Detection
        // Step 3: Retest Validation
        // Step 4: Trade Management
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
        ), DEBUG_IMPORTANT);
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
            DebugPrint("❌ Failed to copy price data", DEBUG_ERRORS);
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
            
            DebugPrint("🔄 Reset hourly stats for new hour", DEBUG_VERBOSE);
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
                    }
                }
                else if(MathAbs(lows[i] - level) > m_touchZone * 3)
                {
                    lastPrice = 0;
                }
            }
        }
        
        return touches;
    }
    
    double CalculateLevelStrength(const SKeyLevel &level)
    {
        // Touch score (0.4 weight)
        double touchScore = MathMin((double)level.touchCount / m_minTouches, 1.5);
        
        // Recency score (0.3 weight)
        double hoursElapsed = (double)(TimeCurrent() - level.lastTouch) / 3600.0;
        double recencyScore = MathExp(-hoursElapsed / (m_lookbackPeriod * 12.0));
        
        // Duration score (0.3 weight)
        double hoursDuration = (double)(level.lastTouch - level.firstTouch) / 3600.0;
        double durationScore = MathMin(hoursDuration / 24.0, 1.0);
        
        return (touchScore * 0.4 + recencyScore * 0.3 + durationScore * 0.3);
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
            ), DEBUG_VERBOSE);  // Changed from DEBUG_NORMAL to DEBUG_VERBOSE
        }
    }
    
    //--- Debug print method
    void DebugPrint(string message, ENUM_DEBUG_LEVEL level = DEBUG_NORMAL)
    {
        if(!m_showDebugPrints || level > m_debugLevel)
            return;
            
        // Add timestamp and current price to debug messages
        string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        Print(StringFormat("[%s] [%.5f] %s", timestamp, currentPrice, message));
    }
}; 