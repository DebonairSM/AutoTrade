//+------------------------------------------------------------------+
//|                                              V-2-EA-Breakouts.mqh |
//|                                    Key Level Detection Implementation|
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.01"

//--- Volume Analysis Constants
#define VOLUME_SPIKE_MULTIPLIER      2.0    // Minimum ratio for volume spike detection (current/average)
#define VOLUME_LOOKBACK_BARS         20     // Number of bars for volume average calculation
#define VOLUME_STRENGTH_MAX_BONUS    0.15   // Maximum strength bonus from volume (15%)
#define VOLUME_MIN_RATIO_BREAKOUT    1.5    // Minimum volume ratio required for breakout confirmation
#define VOLUME_CONSISTENCY_THRESHOLD  0.3    // Minimum ratio of volume to average for consistency check
#define VOLUME_EXPANSION_THRESHOLD   0.2    // Minimum ratio of bars with expanding volume
#define VOLUME_PRE_BREAKOUT_BARS     10     // Bars to analyze before breakout
#define VOLUME_RETEST_MIN_RATIO      0.5    // Minimum volume ratio for retest validation

/*
REFACTORING TODO:

1. Move to MarketData (only generic market analysis helpers):
   MOVE:
   - Basic volume analysis (IsVolumeSpike, GetAverageVolume)
   - Basic price validation (IsTouchValid)
   - Market instrument identification (IsUS500)
   - Generic candle pattern detection
   
   KEEP IN BREAKOUTS:
   - Key level specific calculations (CalculateLevelStrength)
   - Breakout pattern detection
   - Level touch counting logic
   - Level validation specific to breakout strategy
   - Swing point detection tuned for levels

2. Move to Utils (purely technical helpers):
   - SafeResizeArray template
   - Debug printing functionality
   - Generic error handling
   - Common constants
   - Time/date utilities
   - Array manipulation helpers

3. Create new components:
   a. ChartVisualizer class (purely visual aspects):
      - Generic line drawing methods
      - SChartLine structure
      - Basic chart object management
      
      KEEP IN BREAKOUTS:
      - Level-specific visualization logic
      - Level strength coloring rules
      - Level label formatting
   
   b. SystemHealth class (generic monitoring):
      - Basic health tracking structure
      - Generic performance metrics
      - Error rate tracking
      
      KEEP IN BREAKOUTS:
      - Level-specific success metrics
      - Breakout validation statistics
      - Strategy-specific health checks
   
   c. ReportGenerator class (generic formatting):
      - Basic message formatting
      - Alert framework
      - Time-based report scheduling
      
      KEEP IN BREAKOUTS:
      - Level-specific report content
      - Breakout alert conditions
      - Strategy performance metrics

4. Move to VTradeTypes:
   MOVE:
   - Generic market structures
   - Basic level structure
   - Common trading enums
   
   KEEP IN BREAKOUTS:
   - Strategy-specific state
   - Key level quality metrics
   - Breakout-specific configurations

5. Create Configuration class:
   MOVE:
   - Generic timeframe settings
   - Basic buffer sizes
   - Common market parameters
   
   KEEP IN BREAKOUTS:
   - Level detection parameters
   - Strength calculation settings
   - Strategy-specific timeouts
   - Breakout validation thresholds

This refactoring maintains the core breakout detection intelligence in CV2EABreakouts while
moving only truly reusable components to shared locations. The breakouts class will remain
focused on:
- Key level detection algorithms
- Breakout pattern recognition
- Level strength calculations
- Strategy-specific validation
- Trade setup identification
- Breakout-specific visualization
*/

#include <Trade\Trade.mqh>
#include <VErrorDesc.mqh>  // Add this include for error descriptions
#include "V-2-EA-MarketData.mqh"  // Add this include for market data functions
#include "V-2-EA-Utils.mqh"  // Add this include for utilities
#include "V-2-EA-US500Data.mqh"
#include "V-2-EA-ForexData.mqh"

//+------------------------------------------------------------------+
//| Constants                                                          |
//+------------------------------------------------------------------+
#define DEFAULT_BUFFER_SIZE 100 // Default size for price buffers
#define DEFAULT_DEBUG_INTERVAL 300 // Default debug interval (5 minutes)
#define ERR_OBJECT_DOES_NOT_EXIST 4202 // MQL5 error code for non-existent object

//+------------------------------------------------------------------+
//| Structure Definitions                                              |
//+------------------------------------------------------------------+
// Note: SKeyLevel is defined in V-2-EA-MarketData.mqh

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
    string labelName;   // Name of associated text label
};

struct STouchQuality {
    int touchCount;
    double avgBounceStrength;
    double avgBounceVolume;
    double maxBounceSize;
    int quickestBounce;
    int slowestBounce;
};

//+------------------------------------------------------------------+
//| Key Level Detection Class                                          |
//+------------------------------------------------------------------+
class CV2EABreakouts : public CV2EAMarketDataBase
{
private:
    //--- Volume Settings
    bool            m_useVolumeFilter;  // Whether to use volume filtering
    
    //--- US500 Detection
    bool IsUS500()
    {
        return (StringFind(_Symbol, "US500") >= 0 || StringFind(_Symbol, "SPX") >= 0);
    }

    //--- Key Level Parameters
    int           m_maxBounceDelay;  // Maximum bars to wait for bounce
    
    //--- Key Level State
    SKeyLevel     m_currentKeyLevels[]; // Array of current key levels
    int           m_keyLevelCount;      // Number of valid key levels
    datetime      m_lastKeyLevelUpdate; // Last time key levels were updated
    
    //--- Strategy State
    SStrategyState m_state;            // Current strategy state
    
    //--- Debug settings
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
                           m_keyLevelCount(0),
                           m_lastKeyLevelUpdate(0),
                           m_maxBounceDelay(8),
                           m_useVolumeFilter(true)  
    {
        // Initialize each array with robust error checking
        if(!CV2EAUtils::SafeResizeArray(m_currentKeyLevels, DEFAULT_BUFFER_SIZE, "CV2EABreakouts::Constructor - m_currentKeyLevels"))
        {
            CV2EAUtils::LogError("Initializing m_currentKeyLevels failed");
            return;
        }
        
        if(!CV2EAUtils::SafeResizeArray(m_chartLines, DEFAULT_BUFFER_SIZE, "CV2EABreakouts::Constructor - m_chartLines"))
        {
            CV2EAUtils::LogError("Initializing m_chartLines failed");
            return;
        }
        
        if(!CV2EAUtils::SafeResizeArray(m_recentBreaks, DEFAULT_BUFFER_SIZE, "CV2EABreakouts::Constructor - m_recentBreaks") ||
           !CV2EAUtils::SafeResizeArray(m_recentBreakTimes, DEFAULT_BUFFER_SIZE, "CV2EABreakouts::Constructor - m_recentBreakTimes"))
        {
            CV2EAUtils::LogError("Initializing recent breaks arrays failed");
            return;
        }
        
        if(!CV2EAUtils::SafeResizeArray(m_lastAlerts, DEFAULT_BUFFER_SIZE, "CV2EABreakouts::Constructor - m_lastAlerts"))
        {
            CV2EAUtils::LogError("Initializing m_lastAlerts failed");
            return;
        }
        
        m_state.Reset();
    }
    
    ~CV2EABreakouts(void)
    {
        ClearAllChartObjects();  // Clean up chart objects before destruction
    }
    
    //--- Initialization
    bool Init(int lookbackPeriod, double minStrength, double touchZone, int minTouches, bool showDebugPrints, bool useVolumeFilter = true)
    {
        // Check for sufficient historical data first
        int bars = Bars(_Symbol, Period());
        if(bars < lookbackPeriod + 10)  // Add buffer for swing detection
        {
            CV2EAUtils::LogError(StringFormat(
                "Not enough historical data loaded. Need at least %d bars, got %d", 
                lookbackPeriod + 10, bars));
            return false;
        }

        // Validate inputs
        if(minStrength <= 0.0 || minStrength > 1.0)
        {
            CV2EAUtils::LogError("Invalid minStrength", minStrength);
            minStrength = 0.55;
        }
        if(minTouches < 1)
        {
            CV2EAUtils::LogError("Invalid minTouches", minTouches);
            minTouches = 2;
        }
        
        m_useVolumeFilter = useVolumeFilter;
        
        // Adjust touch zone for US500
        if(IsUS500())
        {
            // Adjust touch zone for US500 based on timeframe
            switch(_Period)
            {
                case PERIOD_MN1: touchZone = 50.0; break;  // 50 points for monthly
                case PERIOD_W1:  touchZone = 30.0; break;  // 30 points for weekly  
                case PERIOD_D1:  touchZone = 20.0; break;  // 20 points
                case PERIOD_H4:  touchZone = 15.0; break;  // 15 points
                case PERIOD_H1:  touchZone = 10.0; break;  // 10 points
                case PERIOD_M30: touchZone = 7.5;  break;  // 7.5 points
                case PERIOD_M15: touchZone = 5.0;  break;  // 5 points
                case PERIOD_M5:  touchZone = 3.0;  break;  // 3 points
                case PERIOD_M1:  touchZone = 2.0;  break;  // 2 points
                default:         touchZone = 5.0;  break;  // Default 5 points
            }
            CV2EAUtils::LogInfo("Adjusted touch zone for US500", DoubleToString(touchZone, 5));
        }
        else
        {
            // Use forex touch zones if not explicitly set
            if(touchZone == 0 || touchZone > 1.0)  // Added check for unreasonably large values
            {
                // Default touch zones for forex (in pips)
                switch(_Period)
                {
                    case PERIOD_MN1: touchZone = 0.0200; break; // 200 pips for monthly
                    case PERIOD_W1:  touchZone = 0.0100; break; // 100 pips for weekly
                    case PERIOD_D1:  touchZone = 0.0060; break; // 60 pips
                    case PERIOD_H4:  touchZone = 0.0040; break; // 40 pips
                    case PERIOD_H2:  touchZone = 0.0032; break; // 32 pips
                    case PERIOD_H1:  touchZone = 0.0025; break; // 25 pips
                    case PERIOD_M30: touchZone = 0.0010; break; // 10 pips
                    case PERIOD_M15: touchZone = 0.0007; break; // 7 pips
                    case PERIOD_M5:  touchZone = 0.0005; break; // 5 pips
                    case PERIOD_M1:  touchZone = 0.0003; break; // 3 pips
                    default:         touchZone = 0.0005;        // Default 5 pips
                }
                CV2EAUtils::LogInfo("Using default forex touch zone", DoubleToString(touchZone, 5), 
                    StringFormat(" (%.1f pips)", touchZone/_Point));
            }
            else
            {
                CV2EAUtils::LogInfo("Using provided forex touch zone", DoubleToString(touchZone, 5), 
                    StringFormat(" (%.1f pips)", touchZone/_Point));
            }
        }
        
        m_touchZone = touchZone;
        
        m_minStrength = minStrength;
        m_minTouches = minTouches;
        m_showDebugPrints = showDebugPrints;
        
        ENUM_TIMEFRAMES tf = Period();
        int periodMinutes = PeriodSeconds(tf) / 60;
        
        if(lookbackPeriod == 0)
        {
            // Set default lookback period based on timeframe
            switch(tf)
            {
                case PERIOD_MN1: m_lookbackPeriod = 36;   break;  // 3 years of monthly data
                case PERIOD_W1:  m_lookbackPeriod = 52;   break;  // ~1 year of weekly data
                case PERIOD_D1:  m_lookbackPeriod = 90;   break;  // ~3 months
                case PERIOD_H4:  m_lookbackPeriod = 180;  break;  // ~30 days
                case PERIOD_H2:  m_lookbackPeriod = 150;  break;  // ~12.5 days
                case PERIOD_H1:  m_lookbackPeriod = 120;  break;  // ~5 days
                default:
                {
                    int barsPerDay = 1440 / periodMinutes;  // 1440 minutes in a day
                    m_lookbackPeriod = barsPerDay * 5;      // 5 days of data
                }
            }
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
                case PERIOD_MN1: m_touchZone = 0.0200; break; // 200 pips for monthly
                case PERIOD_W1:  m_touchZone = 0.0100; break; // 100 pips for weekly
                case PERIOD_D1:  m_touchZone = 0.0060; break; // 60 pips
                case PERIOD_H4:  m_touchZone = 0.0040; break; // 40 pips
                case PERIOD_H2:  m_touchZone = 0.0032; break; // 32 pips (between H1 and H4)
                case PERIOD_H1:  m_touchZone = 0.0025; break; // 25 pips
                case PERIOD_M30: m_touchZone = 0.0010; break; // 10 pips
                case PERIOD_M15: m_touchZone = 0.0007; break; // 7 pips
                case PERIOD_M5:  m_touchZone = 0.0005; break; // 5 pips
                case PERIOD_M1:  m_touchZone = 0.0003; break; // 3 pips
                default:         m_touchZone = 0.0005;        // Default 5 pips
            }
        }
        else
        {
            m_touchZone = touchZone;
        }
        
        // Reinitialize arrays with robust error checks
        if(!CV2EAUtils::SafeResizeArray(m_currentKeyLevels, DEFAULT_BUFFER_SIZE, "CV2EABreakouts::Init - m_currentKeyLevels"))
        {
            CV2EAUtils::LogError("Failed to resize key levels array");
            return false;
        }
        
        if(!CV2EAUtils::SafeResizeArray(m_chartLines, DEFAULT_BUFFER_SIZE, "CV2EABreakouts::Init - m_chartLines"))
        {
            CV2EAUtils::LogError("Failed to resize chart lines array");
            return false;
        }
        
        if(!CV2EAUtils::SafeResizeArray(m_recentBreaks, DEFAULT_BUFFER_SIZE, "CV2EABreakouts::Init - m_recentBreaks") ||
           !CV2EAUtils::SafeResizeArray(m_recentBreakTimes, DEFAULT_BUFFER_SIZE, "CV2EABreakouts::Init - m_recentBreakTimes"))
        {
            CV2EAUtils::LogError("Failed to resize recent breaks arrays");
            return false;
        }
        
        if(!CV2EAUtils::SafeResizeArray(m_lastAlerts, DEFAULT_BUFFER_SIZE, "CV2EABreakouts::Init - m_lastAlerts"))
        {
            CV2EAUtils::LogError("Failed to resize last alerts array");
            return false;
        }
        
        m_keyLevelCount = 0;
        m_recentBreakCount = 0;
        m_state.Reset();
        m_lastChartUpdate = 0;
        
        // Validate symbol point value with error handling
        double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        if(symbolPoint <= 0)
        {
            CV2EAUtils::LogError("SymbolInfoDouble failed, checking _Point...");
            symbolPoint = _Point;
            if(symbolPoint <= 0)
            {
                CV2EAUtils::LogError("All point value retrievals failed. Using fallback value.");
                symbolPoint = 0.0001;
            }
        }
        
        m_initialized = true;
        CV2EAUtils::LogInfo("Configuration complete for ", _Symbol);
        return true;
    }
    
    //--- Main Strategy Method
    void ProcessStrategy()
    {
        if(!m_initialized)
        {
            CV2EAUtils::LogError("Strategy not initialized");
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
        else if(m_state.keyLevelFound && !IsKeyLevelValid(m_state.activeKeyLevel))
        {
            // If we had a key level but can't find it anymore, reset state
            CV2EAUtils::LogInfo("Previous key level no longer valid, resetting state");
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
        
        // Step 4: Update chart lines - Force update on each call
        m_lastChartUpdate = 0; // Reset last update time to force update
        UpdateChartLines();
        
        // Force chart redraw
        ChartRedraw(0);
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
        
        CV2EAUtils::DebugPrint(StringFormat(
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
        {
            CV2EAUtils::LogError("Strategy not initialized");
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
        CV2EAUtils::DebugPrint(StringFormat("Available bars for %s: %d", EnumToString(Period()), availableBars));
        
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
        CV2EAUtils::DebugPrint(StringFormat("Bars to use for %s: %d (minimum required: %d)", 
            EnumToString(Period()), barsToUse, minRequiredBars));
        
        if(barsToUse < minRequiredBars)
        {
            CV2EAUtils::LogError(StringFormat("Insufficient bars available: %d (needed at least %d for %s timeframe)", 
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
            CV2EAUtils::LogError(StringFormat("Failed to copy price/volume data. Available bars: %d, Requested: %d, Error: %d", 
                (int)availableBars, (int)barsToUse, GetLastError()));
            return false;
        }
        
        // Add debug output for data copy success
        CV2EAUtils::DebugPrint(StringFormat("Successfully copied data for %s timeframe. Processing %d bars for key levels", 
            EnumToString(Period()), barsToUse));
        
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
            
            CV2EAUtils::LogInfo("Reset hourly stats for new hour");
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
                    STouchQuality quality;
                    newLevel.touchCount = CountTouches(level, true, highPrices, lowPrices, times, quality);
                    
                    if(newLevel.touchCount < m_minTouches)
                    {
                        m_hourlyStats.lowTouchCount++;
                        continue;
                    }
                    
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
                            CV2EAUtils::LogInfo(StringFormat(
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
                    STouchQuality quality;
                    newLevel.touchCount = CountTouches(level, false, highPrices, lowPrices, times, quality);
                    
                    if(newLevel.touchCount < m_minTouches)
                    {
                        m_hourlyStats.lowTouchCount++;
                        continue;
                    }
                    
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
                            CV2EAUtils::LogInfo(StringFormat(
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
                CV2EAUtils::LogError(StringFormat("Failed to delete line %s", m_chartLines[i].name));
            }
        }
        
        // Reset chart lines array
        ArrayResize(m_chartLines, 0);
        m_lastChartUpdate = 0;
        
        // Force chart redraw
        ChartRedraw(0);
        
        if(m_showDebugPrints)
            CV2EAUtils::LogInfo("Cleared all chart objects");
    }

    // Test-specific methods
    bool TEST_GetKeyLevel(int index, SKeyLevel &level) const
    {
        if(index >= 0 && index < m_keyLevelCount)
        {
            level = m_currentKeyLevels[index];
            return true;
        }
        return false;
    }
    
    int TEST_GetKeyLevelCount() const
    {
        return m_keyLevelCount;
    }
    
    double TEST_GetMinStrength() const
    {
        return m_minStrength;
    }
    
    double TEST_GetTouchZone() const
    {
        return m_touchZone;
    }
    
    int TEST_GetMinTouches() const
    {
        return m_minTouches;
    }

    bool TEST_IsUS500()  // Add this test-specific method
    {
        return IsUS500();
    }

    //--- Add to public section of CV2EABreakouts class
    public:
        bool ProcessTimeframe(ENUM_TIMEFRAMES timeframe)
        {
            if(!m_initialized) {
                CV2EAUtils::LogError("Strategy not initialized");
                return false;
            }
            
            // Store current timeframe and rates
            ENUM_TIMEFRAMES currentTF = Period();
            
            // Check if we're in testing mode
            bool isTesting = MQLInfoInteger(MQL_TESTER);
            
            if(isTesting) {
                // Testing mode - use CopyRates
                MqlRates rates[];
                double high[], low[], close[];
                long volume[];
                datetime time[];
                
                ArraySetAsSeries(rates, true);
                ArraySetAsSeries(high, true);
                ArraySetAsSeries(low, true);
                ArraySetAsSeries(close, true);
                ArraySetAsSeries(volume, true);
                ArraySetAsSeries(time, true);
                
                // Get enough bars for lookback plus buffer
                int barsNeeded = m_lookbackPeriod + 10;  // Add buffer for swing detection
                
                // Copy all necessary data
                if(CopyHigh(_Symbol, timeframe, 0, barsNeeded, high) <= 0 ||
                   CopyLow(_Symbol, timeframe, 0, barsNeeded, low) <= 0 ||
                   CopyClose(_Symbol, timeframe, 0, barsNeeded, close) <= 0 ||
                   CopyTickVolume(_Symbol, timeframe, 0, barsNeeded, volume) <= 0 ||
                   CopyTime(_Symbol, timeframe, 0, barsNeeded, time) <= 0) {
                    CV2EAUtils::LogError(StringFormat("Failed to copy data for %s", EnumToString(timeframe)));
                    return false;
                }
                
                // Process strategy using the copied data
                SKeyLevel strongestLevel;
                ProcessStrategyOnData(high, low, close, volume, time, strongestLevel);
                
                // Update chart lines after processing each timeframe
                m_lastChartUpdate = 0; // Force update
                UpdateChartLines();
                ChartRedraw(0);
            }
            else {
                // Live trading - use chart switching for proper visualization
                if(timeframe == currentTF) {
                    ProcessStrategy();
                }
                else if(!ChartSetSymbolPeriod(0, _Symbol, timeframe)) {
                    CV2EAUtils::LogError(StringFormat("Failed to switch from %s to %s", 
                        EnumToString(currentTF), EnumToString(timeframe)));
                    return false;
                }
                
                // Process strategy on this timeframe
                ProcessStrategy();
                
                // Switch back to original timeframe
                ChartSetSymbolPeriod(0, _Symbol, currentTF);
            }
            
            return true;
        }
        
        bool GetStrongestLevel(SKeyLevel &outLevel)
        {
            if(m_keyLevelCount == 0)
                return false;
                
            double maxStrength = 0;
            int strongestIdx = -1;
            
            // Find strongest level
            for(int i = 0; i < m_keyLevelCount; i++) {
                if(m_currentKeyLevels[i].strength > maxStrength) {
                    maxStrength = m_currentKeyLevels[i].strength;
                    strongestIdx = i;
                }
            }
            
            if(strongestIdx >= 0) {
                outLevel = m_currentKeyLevels[strongestIdx];
                return true;
            }
            
            return false;
        }

        //--- Chart object cleanup
        void ClearAllChartObjects()
        {
            // Clear all objects with our prefix
            ObjectsDeleteAll(0, "KL_");
            
            // Reset our internal tracking arrays
            ArrayFree(m_chartLines);
            m_lastChartUpdate = 0;
            
            if(m_showDebugPrints)
                CV2EAUtils::LogInfo("Cleared all chart objects");
        }

private:
    //--- Key Level Helper Methods
    bool IsSwingHigh(const double &prices[], int index)
    {
        // Validate array bounds first
        int size = ArraySize(prices);
        if(index < 2 || index >= size - 2)
        {
            if(m_showDebugPrints)
                CV2EAUtils::LogInfo(StringFormat("IsSwingHigh: Index %d out of valid range [2, %d]", index, size - 3));
            return false;
        }
        
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
        // Make sure we don't go out of bounds
        int startIdx = MathMax(0, index - windowSize);
        int endIdx = MathMin(size - 1, index + windowSize);
        
        for(int i = startIdx; i <= endIdx; i++)
        {
            if(i != index && prices[i] > prices[index])
                return false;  // Found a higher point nearby
        }
        
        return true;
    }
    
    bool IsSwingLow(const double &prices[], int index)
    {
        // Validate array bounds first
        int size = ArraySize(prices);
        if(index < 2 || index >= size - 2)
        {
            if(m_showDebugPrints)
                CV2EAUtils::LogInfo(StringFormat("IsSwingLow: Index %d out of valid range [2, %d]", index, size - 3));
            return false;
        }
        
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
        // Make sure we don't go out of bounds
        int startIdx = MathMax(0, index - windowSize);
        int endIdx = MathMin(size - 1, index + windowSize);
        
        for(int i = startIdx; i <= endIdx; i++)
        {
            if(i != index && prices[i] < prices[index])
                return false;  // Found a lower point nearby
        }
        
        return true;
    }
    
    bool IsNearExistingLevel(const double price)
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
    
    bool IsNearExistingLevel(const double price, SKeyLevel &nearestLevel, double &distance)
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
                CV2EAUtils::LogInfo(StringFormat(
                    "Found nearby level: %.5f (%.1f pips away)",
                    m_currentKeyLevels[nearestIdx].price,
                    minDistance / _Point
                ));
            }
        }
        
        return found;
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
            CV2EAUtils::LogInfo(StringFormat(
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
        
        // Add safety check for array size
        if(ArraySize(highs) < m_lookbackPeriod || ArraySize(lows) < m_lookbackPeriod)
        {
            if(m_showDebugPrints)
                CV2EAUtils::LogError(StringFormat("[%s] Insufficient data for analysis. Need %d bars, got High:%d Low:%d", 
                    TimeToString(TimeCurrent()), m_lookbackPeriod, ArraySize(highs), ArraySize(lows)));
            return 0;
        }
        
        for(int i = 0; i < m_lookbackPeriod - m_maxBounceDelay; i++)
        {
            // Add bounds check for main arrays
            if(i >= ArraySize(highs) || i >= ArraySize(lows))
            {
                CV2EAUtils::LogError("Array index out of bounds in touch detection");
                break;
            }
            
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
                    
                    // Find the bounce with bounds checking
                    for(int j = 1; j <= m_maxBounceDelay && (i+j) < ArraySize(highs) && (i+j) < ArraySize(lows); j++)
                    {
                        if(i+j >= m_lookbackPeriod) break;  // Safety check
                        
                        double price = isResistance ? lows[i+j] : highs[i+j];
                        if(isResistance ? (price < extremePrice) : (price > extremePrice))
                        {
                            extremePrice = price;
                            bounceBar = j;
                            if(hasVolume && (i+j) < ArraySize(times)) 
                                bounceVolume = (double)iVolume(_Symbol, Period(), i+j);
                        }
                    }
                    
                    // Verify clean bounce with bounds checking
                    for(int j = 1; j < bounceBar && (i+j) < ArraySize(highs) && (i+j) < ArraySize(lows); j++)
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
                            CV2EAUtils::LogInfo(StringFormat(
                                "Touch %d at %.5f (%.1f pips from level) - Bounce Size: %.1f pips, Bounce Bar: %d, Bounce Volume: %.2f",
                                touches,
                                currentPrice,
                                touchDistance / pipSize,
                                bounceSize / pipSize,
                                bounceBar,
                                bounceVolume
                            ));
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
                CV2EAUtils::LogInfo(StringFormat(
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
    
    double CalculateLevelStrength(const SKeyLevel &level, const STouchQuality &quality)
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
        if(CV2EAUtils::IsUS500()) {
            timeframeBonus = CV2EAUS500Data::GetTimeframeBonus(tf);
        }
        else if(CV2EAUtils::IsForexPair()) {
            timeframeBonus = CV2EAForexData::GetTimeframeBonus(tf);
        }
        else {
            timeframeBonus = 0.0; // Default for other instruments
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
            CV2EAUtils::LogInfo(StringFormat(
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
    
    void AddKeyLevel(const SKeyLevel &level)
    {
        // Validate level
        if(level.price <= 0 || level.touchCount < m_minTouches || level.strength < m_minStrength)
        {
            if(m_showDebugPrints)
            {
                CV2EAUtils::LogError(StringFormat(
                    "Invalid level rejected: Price=%.5f, Touches=%d, Strength=%.4f",
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
            if(!CV2EAUtils::SafeResizeArray(m_currentKeyLevels, newSize, "CV2EABreakouts::AddKeyLevel"))
            {
                CV2EAUtils::LogError("Failed to resize key levels array");
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
            
            CV2EAUtils::LogInfo(StringFormat(
                "Added %s level at %.5f\n" +
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
    
    void RemoveWeakestLevels(int maxPerType)
    {
        // Create arrays for sorting
        SKeyLevel resistanceLevels[];
        SKeyLevel supportLevels[];
        double resistanceStrengths[];
        double supportStrengths[];
        int resistanceCount = 0;
        int supportCount = 0;
        
        // Separate levels by type
        for(int i = 0; i < m_keyLevelCount; i++)
        {
            if(m_currentKeyLevels[i].isResistance)
            {
                if(!CV2EAUtils::SafeResizeArray(resistanceLevels, resistanceCount + 1, "CV2EABreakouts::RemoveWeakestLevels - resistanceLevels") ||
                   !CV2EAUtils::SafeResizeArray(resistanceStrengths, resistanceCount + 1, "CV2EABreakouts::RemoveWeakestLevels - resistanceStrengths"))
                {
                    CV2EAUtils::LogError("Failed to resize resistance arrays");
                    return;
                }
                resistanceLevels[resistanceCount] = m_currentKeyLevels[i];
                resistanceStrengths[resistanceCount] = m_currentKeyLevels[i].strength;
                resistanceCount++;
            }
            else
            {
                if(!CV2EAUtils::SafeResizeArray(supportLevels, supportCount + 1, "CV2EABreakouts::RemoveWeakestLevels - supportLevels") ||
                   !CV2EAUtils::SafeResizeArray(supportStrengths, supportCount + 1, "CV2EABreakouts::RemoveWeakestLevels - supportStrengths"))
                {
                    CV2EAUtils::LogError("Failed to resize support arrays");
                    return;
                }
                supportLevels[supportCount] = m_currentKeyLevels[i];
                supportStrengths[supportCount] = m_currentKeyLevels[i].strength;
                supportCount++;
            }
        }
        
        // Sort levels by strength (descending)
        if(resistanceCount > 1)
            CV2EAUtils::QuickSort(resistanceLevels, 0, resistanceCount - 1, resistanceStrengths);
        if(supportCount > 1)
            CV2EAUtils::QuickSort(supportLevels, 0, supportCount - 1, supportStrengths);
        
        m_keyLevelCount = 0;
        
        // Resize arrays to keep only strongest levels
        if(!CV2EAUtils::SafeResizeArray(resistanceLevels, MathMin(maxPerType, resistanceCount), "CV2EABreakouts::RemoveWeakestLevels - resistanceLevels"))
        {
            CV2EAUtils::LogError("Failed to resize resistance levels array to final size");
            return;
        }
        
        if(!CV2EAUtils::SafeResizeArray(supportLevels, MathMin(maxPerType, supportCount), "CV2EABreakouts::RemoveWeakestLevels - supportLevels"))
        {
            CV2EAUtils::LogError("Failed to resize support levels array to final size");
            return;
        }
        
        // Copy strongest levels back to main array
        for(int i = 0; i < MathMin(maxPerType, resistanceCount); i++)
            m_currentKeyLevels[m_keyLevelCount++] = resistanceLevels[i];
        for(int i = 0; i < MathMin(maxPerType, supportCount); i++)
            m_currentKeyLevels[m_keyLevelCount++] = supportLevels[i];
        
        CV2EAUtils::LogInfo(StringFormat("Cleaned up levels. Kept %d resistance and %d support levels.",
              IntegerToString(MathMin(maxPerType, resistanceCount)),
              IntegerToString(MathMin(maxPerType, supportCount))));
    }
    
    //--- Debug print method
    void DebugPrint(string message)
    {
        if(!m_showDebugPrints)
            return;
            
        // Add timestamp and current price to debug messages
        string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        CV2EAUtils::LogInfo(StringFormat("[%s] [%.5f] %s", timestamp, currentPrice, message));
    }

    void PrintKeyLevelsReport()
    {
        if(!m_showDebugPrints) return;

        string timeStr = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        CV2EAUtils::DebugPrint(StringFormat("=== KEY LEVELS REPORT [%s] ===\nPrice: %.5f", 
            timeStr, currentPrice));
        
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
        CV2EAUtils::DebugPrint(StringFormat("=== KEY LEVELS REPORT [%s] ===\nPrice: %.5f", timeStr, currentPrice));
        
        // Print Support Levels
        if(supportCount > 0)
        {
            CV2EAUtils::DebugPrint("\nSUPPORT:");
            for(int i = 0; i < supportCount; i++)
            {
                double distance = MathAbs(currentPrice - supportLevels[i].price);
                string marker = (supportLevels[i].strength > 0.8) ? "⭐" : "";
                string arrow = (currentPrice > supportLevels[i].price) ? "↓" : " ";
                string distanceStr = StringFormat("%d pips", (int)(distance / _Point));
                
                CV2EAUtils::DebugPrint(StringFormat("%s %.5f (%s) | S:%.2f T:%d %s",
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
            CV2EAUtils::DebugPrint("\nRESISTANCE:");
            for(int i = 0; i < resistanceCount; i++)
            {
                double distance = MathAbs(currentPrice - resistanceLevels[i].price);
                string marker = (resistanceLevels[i].strength > 0.8) ? "⭐" : "";
                string arrow = (currentPrice < resistanceLevels[i].price) ? "↑" : " ";
                string distanceStr = StringFormat("%d pips", (int)(distance / _Point));
                
                CV2EAUtils::DebugPrint(StringFormat("%s %.5f (%s) | S:%.2f T:%d %s",
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
            CV2EAUtils::DebugPrint("\nRECENT BREAKS:");
            for(int i = MathMax(0, m_recentBreakCount - 3); i < m_recentBreakCount; i++)
            {
                CV2EAUtils::DebugPrint(StringFormat("%.5f @ %s",
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
        
        CV2EAUtils::LogInfo(StringFormat(
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
        
        CV2EAUtils::LogInfo(StringFormat(
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
        
        // Always update on timeframe change
        static ENUM_TIMEFRAMES lastTimeframe = PERIOD_CURRENT;
        ENUM_TIMEFRAMES currentTimeframe = Period();
        bool timeframeChanged = (lastTimeframe != currentTimeframe);
        
        // Update if conditions are met
        bool shouldUpdate = (m_lastChartUpdate == 0) || 
                          timeframeChanged ||
                          (currentTime - m_lastChartUpdate >= 3600) ||
                          (m_keyLevelCount != ArraySize(m_chartLines));
                
        if(!shouldUpdate)
            return;
        
        lastTimeframe = currentTimeframe;
        
        // Delete all existing lines first on timeframe change
        if(timeframeChanged)
        {
            CV2EAUtils::LogInfo(StringFormat("Timeframe changed from %s to %s - Clearing all lines", 
                EnumToString(lastTimeframe), EnumToString(currentTimeframe)));
            
            // Delete all existing chart objects with our prefix
            ObjectsDeleteAll(0, "KL_");
            ArrayFree(m_chartLines);
            ArrayResize(m_chartLines, 0); // Reset array size to 0 instead of NULL
            m_lastChartUpdate = 0;
        }
        
        // Clear old lines
        ClearInactiveChartLines();
        
        // Mark all lines as inactive before update
        for(int i = 0; i < ArraySize(m_chartLines); i++)
            m_chartLines[i].isActive = false;
        
        // Debug print for line updates
        CV2EAUtils::LogInfo(StringFormat("Updating chart lines. Key level count: %d", m_keyLevelCount));
        
        // Update lines for current key levels
        for(int i = 0; i < m_keyLevelCount; i++)
        {
            string lineName = StringFormat("KL_%s_%.5f_%s", 
                m_currentKeyLevels[i].isResistance ? "R" : "S",
                m_currentKeyLevels[i].price,
                EnumToString(currentTimeframe));  // Add timeframe to line name
                    
            // First determine if this is above or below current price
            bool isAbovePrice = m_currentKeyLevels[i].price > currentPrice;
            
            // Determine line properties based on position and strength
            color lineColor;
            ENUM_LINE_STYLE lineStyle;
            int lineWidth;
            
            // Strong levels (>= 0.85)
            if(m_currentKeyLevels[i].strength >= 0.85) {
                if(isAbovePrice) {
                    lineColor = m_currentKeyLevels[i].volumeConfirmed ? clrDarkRed : clrCrimson;      // Dark red for volume-confirmed
                } else {
                    lineColor = m_currentKeyLevels[i].volumeConfirmed ? clrDarkGreen : clrForestGreen;  // Dark green for volume-confirmed
                }
                lineStyle = m_currentKeyLevels[i].volumeConfirmed ? STYLE_SOLID : STYLE_SOLID;
                lineWidth = m_currentKeyLevels[i].volumeConfirmed ? 3 : 2;
            }
            // Medium levels (>= 0.70)
            else if(m_currentKeyLevels[i].strength >= 0.70) {
                if(isAbovePrice) {
                    lineColor = m_currentKeyLevels[i].volumeConfirmed ? clrFireBrick : clrLightCoral;
                } else {
                    lineColor = m_currentKeyLevels[i].volumeConfirmed ? clrSeaGreen : clrMediumSeaGreen;
                }
                lineStyle = m_currentKeyLevels[i].volumeConfirmed ? STYLE_SOLID : STYLE_SOLID;
                lineWidth = m_currentKeyLevels[i].volumeConfirmed ? 2 : 1;
            }
            // Weak levels (< 0.70)
            else {
                if(isAbovePrice) {
                    lineColor = m_currentKeyLevels[i].volumeConfirmed ? clrIndianRed : clrPink;
                } else {
                    lineColor = m_currentKeyLevels[i].volumeConfirmed ? clrMediumSpringGreen : clrPaleGreen;
                }
                lineStyle = m_currentKeyLevels[i].volumeConfirmed ? STYLE_SOLID : STYLE_DOT;
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
                    if(!ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor))
                        CV2EAUtils::LogError(StringFormat("Failed to update color for line %s", lineName));
                    if(!ObjectSetInteger(0, lineName, OBJPROP_STYLE, lineStyle))
                        CV2EAUtils::LogError(StringFormat("Failed to update style for line %s", lineName));
                    if(!ObjectSetInteger(0, lineName, OBJPROP_WIDTH, lineWidth))
                        CV2EAUtils::LogError(StringFormat("Failed to update width for line %s", lineName));
                    
                    // Update tooltip with more information
                    string volumeInfo = m_currentKeyLevels[i].volumeConfirmed ? 
                        StringFormat("\nVolume: %.1fx average", m_currentKeyLevels[i].volumeRatio) : 
                        "\nNo significant volume";
                        
                    string timeInfo = StringFormat("\nLast Update: %s", TimeToString(m_chartLines[j].lastUpdate, TIME_DATE|TIME_MINUTES));
                        
                    string tooltip = StringFormat("%s Level (%s)\nStrength: %.2f%s\nTouches: %d\nDistance: %d pips%s%s", 
                        isAbovePrice ? "Resistance" : "Support",
                        EnumToString(currentTimeframe),
                        m_currentKeyLevels[i].strength,
                        m_currentKeyLevels[i].volumeConfirmed ? " (Volume Confirmed)" : "",
                        m_currentKeyLevels[i].touchCount,
                        (int)(MathAbs(m_currentKeyLevels[i].price - currentPrice) / _Point),
                        volumeInfo,
                        timeInfo);
                    ObjectSetString(0, lineName, OBJPROP_TOOLTIP, tooltip);
                    break;
                }
            }
            
            // Create new line if not found
            if(!found)
            {
                int size = ArraySize(m_chartLines);
                if(!CV2EAUtils::SafeResizeArray(m_chartLines, size + 1, "CV2EABreakouts::UpdateChartLines - m_chartLines"))
                {
                    CV2EAUtils::LogError("Failed to resize chart lines array");
                    continue;
                }
                
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
                    ObjectSetInteger(0, lineName, OBJPROP_HIDDEN, false);
                    ObjectSetInteger(0, lineName, OBJPROP_SELECTED, false);
                    ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, true);
                    ObjectSetInteger(0, lineName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
                    
                    // Enhanced tooltip with volume information
                    string volumeInfo = m_currentKeyLevels[i].volumeConfirmed ? 
                        StringFormat("\nVolume: %.1fx average", m_currentKeyLevels[i].volumeRatio) : 
                        "\nNo significant volume";
                        
                    string timeInfo = StringFormat("\nLast Update: %s", TimeToString(currentTime, TIME_DATE|TIME_MINUTES));
                        
                    string tooltip = StringFormat("%s Level (%s)\nStrength: %.2f%s\nTouches: %d\nDistance: %d pips%s%s", 
                        isAbovePrice ? "Resistance" : "Support",
                        EnumToString(currentTimeframe),
                        m_currentKeyLevels[i].strength,
                        m_currentKeyLevels[i].volumeConfirmed ? " (Volume Confirmed)" : "",
                        m_currentKeyLevels[i].touchCount,
                        (int)(MathAbs(m_currentKeyLevels[i].price - currentPrice) / _Point),
                        volumeInfo,
                        timeInfo);
                    ObjectSetString(0, lineName, OBJPROP_TOOLTIP, tooltip);
                    
                    // Create text label for volume-confirmed levels
                    if(m_currentKeyLevels[i].volumeConfirmed)
                    {
                        string labelName = StringFormat("KL_Label_%s_%.5f_%s", 
                            m_currentKeyLevels[i].isResistance ? "R" : "S",
                            m_currentKeyLevels[i].price,
                            EnumToString(currentTimeframe));
                        
                        CV2EAUtils::LogInfo(StringFormat("Attempting to create label: %s", labelName));
                        
                        // Get chart dimensions
                        long chartWidth = 0, chartHeight = 0;
                        if(!ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0, chartWidth) ||
                           !ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0, chartHeight))
                        {
                            CV2EAUtils::LogError(StringFormat("Failed to get chart dimensions. Error: %d", GetLastError()));
                        }
                        else
                        {
                            CV2EAUtils::LogInfo(StringFormat("Chart dimensions: %dx%d pixels", chartWidth, chartHeight));
                        }
                        
                        // Get first visible bar time
                        datetime firstVisibleTime = 0;
                        int firstVisibleBar = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
                        if(firstVisibleBar <= 0)
                        {
                            CV2EAUtils::LogError(StringFormat("Failed to get first visible bar. Error: %d", GetLastError()));
                            firstVisibleTime = TimeCurrent();
                        }
                        else
                        {
                            firstVisibleTime = iTime(_Symbol, Period(), firstVisibleBar);
                            CV2EAUtils::LogInfo(StringFormat("First visible bar: %d, Time: %s", 
                                firstVisibleBar, TimeToString(firstVisibleTime)));
                        }
                        
                        // Delete existing label if it exists
                        ObjectDelete(0, labelName);
                        
                        // Create or update the text label
                        if(ObjectCreate(0, labelName, OBJ_TEXT, 0, firstVisibleTime, m_currentKeyLevels[i].price))
                        {
                            string labelText = StringFormat("VOL %.1fx", m_currentKeyLevels[i].volumeRatio);
                            
                            ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
                            ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
                            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
                            ObjectSetInteger(0, labelName, OBJPROP_COLOR, lineColor);
                            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
                            ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
                            ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
                            ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, false);
                            ObjectSetInteger(0, labelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
                            
                            // Store label name for cleanup
                            m_chartLines[size].labelName = labelName;
                            
                            CV2EAUtils::LogInfo(StringFormat("Successfully created label %s at price %.5f with text '%s'", 
                                labelName, m_currentKeyLevels[i].price, labelText));
                        }
                        else
                        {
                            int error = GetLastError();
                            CV2EAUtils::LogError(StringFormat("Failed to create label %s. Error: %d - %s", 
                                labelName, error, ErrorDescription(error)));
                        }
                    }
                    
                    CV2EAUtils::LogInfo(StringFormat("Created new line %s at %.5f", lineName, m_currentKeyLevels[i].price));
                }
                else
                {
                    int error = GetLastError();
                    CV2EAUtils::LogError(StringFormat("Failed to create line %s. Error: %d", lineName, error));
                }
            }
        }
        
        m_lastChartUpdate = currentTime;
        ChartRedraw(0);  // Force chart redraw
        CV2EAUtils::LogInfo("Chart lines updated and redrawn");
    }
    
    void ClearInactiveChartLines()
    {
        int currentSize = ArraySize(m_chartLines);
        if(currentSize == 0)
            return;
        
        // Delete inactive chart objects (log errors directly)
        for(int i = 0; i < currentSize; i++)
        {
            if(m_chartLines[i].name == NULL || m_chartLines[i].name == "")
                continue;
                
            if(!m_chartLines[i].isActive)
            {
                // Delete the line
                if(!ObjectDelete(0, m_chartLines[i].name))
                {
                    int error = GetLastError();
                    if(error != ERR_OBJECT_DOES_NOT_EXIST)
                        CV2EAUtils::LogError(StringFormat("Failed to delete line %s. Error: %d", m_chartLines[i].name, error));
                }
                
                // Delete associated label if it exists
                if(m_chartLines[i].labelName != "" && m_chartLines[i].labelName != NULL)
                {
                    if(!ObjectDelete(0, m_chartLines[i].labelName))
                    {
                        int error = GetLastError();
                        if(error != ERR_OBJECT_DOES_NOT_EXIST)
                            CV2EAUtils::LogError(StringFormat("Failed to delete label %s. Error: %d", m_chartLines[i].labelName, error));
                    }
                }
            }
        }
        
        // Count active lines
        int activeCount = 0;
        for(int i = 0; i < currentSize; i++)
        {
            if(m_chartLines[i].isActive && m_chartLines[i].name != NULL && m_chartLines[i].name != "")
                activeCount++;
        }
        
        // If no active lines, free array and return
        if(activeCount == 0)
        {
            ArrayFree(m_chartLines);
            return;
        }
        
        // Create temporary array for active lines
        SChartLine tempLines[];
        if(!CV2EAUtils::SafeResizeArray(tempLines, activeCount, "CV2EABreakouts::ClearInactiveChartLines - tempLines"))
        {
            CV2EAUtils::LogError("Failed to resize temporary lines array");
            return;
        }
        
        // Copy active lines to temporary array
        int newIndex = 0;
        for(int i = 0; i < currentSize; i++)
        {
            if(m_chartLines[i].isActive && m_chartLines[i].name != NULL && m_chartLines[i].name != "")
            {
                if(newIndex < activeCount)
                {
                    tempLines[newIndex] = m_chartLines[i];
                    newIndex++;
                }
            }
        }
        
        // Free original array and resize to new size
        ArrayFree(m_chartLines);
        if(!CV2EAUtils::SafeResizeArray(m_chartLines, activeCount, "CV2EABreakouts::ClearInactiveChartLines - m_chartLines"))
        {
            CV2EAUtils::LogError("Failed to resize chart lines array to final size");
            return;
        }
        
        // Copy back from temporary array
        for(int i = 0; i < activeCount; i++)
            m_chartLines[i] = tempLines[i];
        
        ChartRedraw(0);
    }

    //--- Volume Detection Helper Methods
    double GetAverageVolume(const long &volumes[], int startIndex, int barsToAverage)
    {
        return CV2EAMarketDataBase::GetAverageVolume(volumes, startIndex, barsToAverage);
    }
    
    bool IsVolumeSpike(const long &volumes[], int index)
    {
        return CV2EAMarketDataBase::IsVolumeSpike(volumes, index);
    }
    
    double GetVolumeStrengthBonus(const long &volumes[], int index)
    {
        if(index < 0 || index >= ArraySize(volumes))
            return 0.0;
            
        double avgVolume = GetAverageVolume(volumes, index, VOLUME_LOOKBACK_BARS);
        if(avgVolume <= 0)
            return 0.0;
            
        double volumeRatio = (double)volumes[index] / avgVolume;
        
        // Return bonus based on volume ratio, capped at maximum
        if(volumeRatio >= VOLUME_SPIKE_MULTIPLIER)
        {
            double bonus = MathMin((volumeRatio - 1.0) * 0.1, VOLUME_STRENGTH_MAX_BONUS);
            
            if(m_showDebugPrints)
            {
                CV2EAUtils::LogInfo(StringFormat(
                    "Volume spike detected at bar %d:\n" +
                    "Current Volume: %d\n" +
                    "Average Volume: %.2f\n" +
                    "Ratio: %.2fx\n" +
                    "Strength Bonus: +%.1f%%",
                    index,
                    volumes[index],
                    avgVolume,
                    volumeRatio,
                    bonus * 100
                ));
            }
            
            return bonus;
        }
        
        return 0.0;
    }
    
    bool ValidateBounce(const double &prices[], double price, double level, double minBounceSize)
    {
        return CV2EAMarketDataBase::ValidateBounce(prices, price, level, minBounceSize);
    }
    
    bool IsTouchValid(double price, double level, double touchZone)
    {
        return CV2EAMarketDataBase::IsTouchValid(price, level, touchZone);
    }

    // Add this function before ProcessStrategy()
    bool IsKeyLevelValid(const SKeyLevel &level)
    {
        if(level.price <= 0 || level.touchCount < m_minTouches || level.strength < m_minStrength)
            return false;
            
        // Check if level is still within our lookback period
        datetime currentTime = TimeCurrent();
        
        // Use current timeframe instead of level's timeframe
        if(currentTime - level.lastTouch > PeriodSeconds(Period()) * m_lookbackPeriod)
            return false;
            
        return true;
    }

    bool DoesVolumeMeetRequirement(const long &volumes[], const int lookback)
    {
        if(!m_useVolumeFilter || lookback <= 0) 
            return true;
            
        // Calculate pre-breakout volume metrics
        double preBreakoutAvg = 0;
        int preBreakoutBars = MathMin(VOLUME_PRE_BREAKOUT_BARS, ArraySize(volumes) - lookback);
        
        for(int i = lookback; i < lookback + preBreakoutBars; i++)
            preBreakoutAvg += (double)volumes[i];  // Explicit cast
        preBreakoutAvg /= preBreakoutBars;
        
        // Calculate breakout volume metrics
        double avgVolume = 0;
        double maxVolume = (double)volumes[0];  // Explicit cast
        double minVolume = (double)volumes[0];  // Explicit cast
        double volumeSum = 0;
        
        for(int i = 0; i < lookback; i++)
        {
            double currentVolume = (double)volumes[i];  // Explicit cast
            avgVolume += currentVolume;
            maxVolume = MathMax(maxVolume, currentVolume);
            minVolume = MathMin(minVolume, currentVolume);
            volumeSum += currentVolume;
        }
        avgVolume /= lookback;
        
        // Calculate volume increase ratio compared to pre-breakout
        double volumeRatio = avgVolume / preBreakoutAvg;
        
        // Volume validation checks
        bool hasVolumeSpike = preBreakoutAvg > 0 && 
                              volumes[0] > preBreakoutAvg * VOLUME_MIN_RATIO_BREAKOUT;
        bool hasConsistentVolume = minVolume > preBreakoutAvg * VOLUME_CONSISTENCY_THRESHOLD;
        
        // Check if volume is expanding
        double volumeMA = volumeSum / lookback;
        int volumeExpansionCount = 0;
        
        for(int i = 0; i < lookback-1; i++)
        {
            if(volumes[i] > volumeMA)
                volumeExpansionCount++;
        }
        
        bool hasExpandingVolume = (double)volumeExpansionCount / lookback >= VOLUME_EXPANSION_THRESHOLD;
        
        if(m_showDebugPrints)
        {
            CV2EAUtils::LogInfo(StringFormat(
                "Volume Analysis:\n" +
                "Pre-breakout Avg: %.2f\n" +
                "Breakout Avg: %.2f\n" +
                "Volume Ratio: %.2fx\n" +
                "Volume Spike: %s\n" +
                "Volume Consistent: %s\n" +
                "Volume Expanding: %s",
                preBreakoutAvg,
                avgVolume,
                volumeRatio,
                hasVolumeSpike ? "Yes" : "No",
                hasConsistentVolume ? "Yes" : "No",
                hasExpandingVolume ? "Yes" : "No"
            ));
        }
        
        return (hasVolumeSpike && hasExpandingVolume) && hasConsistentVolume;
    }

    bool ValidateRetest(const double &prices[], const long &volumes[], const datetime &times[], int bars)
    {
        if(bars < 2) return false;
        
        // Calculate average volume during retest
        double avgVolume = 0;
        for(int i = 0; i < bars; i++)
            avgVolume += (double)volumes[i];
        avgVolume /= bars;
        
        // Get pre-retest volume average
        double preRetestAvg = 0;
        int preRetestBars = MathMin(VOLUME_PRE_BREAKOUT_BARS, ArraySize(volumes) - bars);
        
        for(int i = bars; i < bars + preRetestBars; i++)
            preRetestAvg += (double)volumes[i];
        preRetestAvg /= preRetestBars;
        
        // Volume should be at least VOLUME_RETEST_MIN_RATIO of pre-retest average
        bool hasValidVolume = avgVolume >= preRetestAvg * VOLUME_RETEST_MIN_RATIO;
        
        if(m_showDebugPrints)
        {
            CV2EAUtils::LogInfo(StringFormat(
                "Retest Volume Analysis:\n" +
                "Retest Avg Volume: %.2f\n" +
                "Pre-retest Avg: %.2f\n" +
                "Volume Ratio: %.2fx\n" +
                "Volume Valid: %s",
                avgVolume,
                preRetestAvg,
                avgVolume / preRetestAvg,
                hasValidVolume ? "Yes" : "No"
            ));
        }
        
        return hasValidVolume;
    }

    bool FindKeyLevelsOnData(const double &highs[], const double &lows[], const double &closes[],
                            const long &volumes[], const datetime &times[], SKeyLevel &outStrongestLevel)
    {
        if(!m_initialized)
        {
            CV2EAUtils::LogError("Strategy not initialized");
            return false;
        }
        
        // Validate array sizes
        int highSize = ArraySize(highs);
        int lowSize = ArraySize(lows);
        int closeSize = ArraySize(closes);
        int volumeSize = ArraySize(volumes);
        int timeSize = ArraySize(times);
        
        // Get required lookback based on timeframe
        int requiredBars = m_lookbackPeriod;  // Default to configured value
        ENUM_TIMEFRAMES tf = Period();
        
        // Adjust lookback based on instrument type and timeframe
        if(CV2EAUtils::IsUS500()) {
            switch(tf) {
                case PERIOD_MN1: requiredBars = 12; break;  // 1 year
                case PERIOD_W1:  requiredBars = 52; break;  // 1 year
                case PERIOD_D1:  requiredBars = 90; break;  // ~3 months
                case PERIOD_H4:  requiredBars = 180; break; // ~30 days
                case PERIOD_H1:  requiredBars = 168; break; // 1 week
                default:         requiredBars = m_lookbackPeriod;
            }
        }
        else if(CV2EAUtils::IsForexPair()) {
            switch(tf) {
                case PERIOD_MN1: requiredBars = 12; break;  // 1 year
                case PERIOD_W1:  requiredBars = 52; break;  // 1 year
                case PERIOD_D1:  requiredBars = 90; break;  // ~3 months
                case PERIOD_H4:  requiredBars = 180; break; // ~30 days
                case PERIOD_H1:  requiredBars = 168; break; // 1 week
                default:         requiredBars = m_lookbackPeriod;
            }
        }
        
        // All arrays should have the same size and be large enough
        if(highSize < requiredBars || lowSize < requiredBars || 
           closeSize < requiredBars || volumeSize < requiredBars || 
           timeSize < requiredBars)
        {
            CV2EAUtils::LogError(StringFormat(
                "[%s] Insufficient data for analysis. Need %d bars, got High:%d Low:%d Close:%d Volume:%d Time:%d",
                TimeToString(TimeCurrent()), requiredBars, highSize, lowSize, closeSize, volumeSize, timeSize
            ));
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
            
            CV2EAUtils::LogInfo("Reset hourly stats for new hour");
        }
        
        // Use the minimum size for iteration to prevent out of bounds access
        int maxBars = MathMin(MathMin(MathMin(highSize, lowSize), 
                            MathMin(closeSize, volumeSize)), timeSize);
        int barsToProcess = MathMin(requiredBars, maxBars - 4);  // Leave room for swing detection
        
        if(m_showDebugPrints)
        {
            CV2EAUtils::LogInfo(StringFormat(
                "Processing %d bars out of %d available",
                barsToProcess, maxBars
            ));
        }
        
        // Find swing highs (resistance levels)
        for(int i = 2; i < barsToProcess - 2; i++)
        {
            if(IsSwingHigh(highs, i))
            {
                m_hourlyStats.totalSwingHighs++;
                double level = highs[i];
                
                if(!IsNearExistingLevel(level))
                {
                    SKeyLevel newLevel;
                    newLevel.price = level;
                    newLevel.isResistance = true;
                    newLevel.firstTouch = times[i];
                    newLevel.lastTouch = times[i];
                    STouchQuality quality;
                    newLevel.touchCount = CountTouches(level, true, highs, lows, times, quality);
                    
                    if(newLevel.touchCount < m_minTouches)
                    {
                        m_hourlyStats.lowTouchCount++;
                        continue;
                    }
                    
                    newLevel.strength = CalculateLevelStrength(newLevel, quality);
                    
                    // Add volume strength bonus if there's a volume spike
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
        for(int i = 2; i < barsToProcess - 2; i++)
        {
            if(IsSwingLow(lows, i))
            {
                m_hourlyStats.totalSwingLows++;
                double level = lows[i];
                
                if(!IsNearExistingLevel(level))
                {
                    SKeyLevel newLevel;
                    newLevel.price = level;
                    newLevel.isResistance = false;
                    newLevel.firstTouch = times[i];
                    newLevel.lastTouch = times[i];
                    STouchQuality quality;
                    newLevel.touchCount = CountTouches(level, false, highs, lows, times, quality);
                    
                    if(newLevel.touchCount < m_minTouches)
                    {
                        m_hourlyStats.lowTouchCount++;
                        continue;
                    }
                    
                    newLevel.strength = CalculateLevelStrength(newLevel, quality);
                    
                    // Add volume strength bonus if there's a volume spike
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

    bool ProcessStrategyOnData(const double &highs[], const double &lows[], const double &closes[], 
                             const long &volumes[], const datetime &times[], SKeyLevel &outStrongestLevel)
    {
        if(!m_initialized)
        {
            CV2EAUtils::LogError("Strategy not initialized");
            return false;
        }
        
        // Validate array sizes
        int highSize = ArraySize(highs);
        int lowSize = ArraySize(lows);
        int closeSize = ArraySize(closes);
        int volumeSize = ArraySize(volumes);
        int timeSize = ArraySize(times);
        
        // Get required lookback based on timeframe
        int requiredBars = m_lookbackPeriod;  // Default to configured value
        ENUM_TIMEFRAMES tf = Period();
        
        // Adjust lookback based on instrument type and timeframe
        if(CV2EAUtils::IsUS500()) {
            switch(tf) {
                case PERIOD_MN1: requiredBars = 12; break;  // 1 year
                case PERIOD_W1:  requiredBars = 52; break;  // 1 year
                case PERIOD_D1:  requiredBars = 90; break;  // ~3 months
                case PERIOD_H4:  requiredBars = 180; break; // ~30 days
                case PERIOD_H1:  requiredBars = 168; break; // 1 week
                default:         requiredBars = m_lookbackPeriod;
            }
        }
        else if(CV2EAUtils::IsForexPair()) {
            switch(tf) {
                case PERIOD_MN1: requiredBars = 12; break;  // 1 year
                case PERIOD_W1:  requiredBars = 52; break;  // 1 year
                case PERIOD_D1:  requiredBars = 90; break;  // ~3 months
                case PERIOD_H4:  requiredBars = 180; break; // ~30 days
                case PERIOD_H1:  requiredBars = 168; break; // 1 week
                default:         requiredBars = m_lookbackPeriod;
            }
        }
        
        // All arrays should have the same size and be large enough
        if(highSize < requiredBars || lowSize < requiredBars || 
           closeSize < requiredBars || volumeSize < requiredBars || 
           timeSize < requiredBars)
        {
            CV2EAUtils::LogError(StringFormat(
                "[%s] Insufficient data for analysis. Need %d bars, got High:%d Low:%d Close:%d Volume:%d Time:%d",
                TimeToString(TimeCurrent()), requiredBars, highSize, lowSize, closeSize, volumeSize, timeSize
            ));
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
            
            CV2EAUtils::LogInfo("Reset hourly stats for new hour");
        }
        
        // Use the minimum size for iteration to prevent out of bounds access
        int maxBars = MathMin(MathMin(MathMin(highSize, lowSize), 
                            MathMin(closeSize, volumeSize)), timeSize);
        int barsToProcess = MathMin(requiredBars, maxBars - 4);  // Leave room for swing detection
        
        if(m_showDebugPrints)
        {
            CV2EAUtils::LogInfo(StringFormat(
                "Processing %d bars out of %d available",
                barsToProcess, maxBars
            ));
        }
        
        // Find swing highs (resistance levels)
        for(int i = 2; i < barsToProcess - 2; i++)
        {
            if(IsSwingHigh(highs, i))
            {
                m_hourlyStats.totalSwingHighs++;
                double level = highs[i];
                
                if(!IsNearExistingLevel(level))
                {
                    SKeyLevel newLevel;
                    newLevel.price = level;
                    newLevel.isResistance = true;
                    newLevel.firstTouch = times[i];
                    newLevel.lastTouch = times[i];
                    STouchQuality quality;
                    newLevel.touchCount = CountTouches(level, true, highs, lows, times, quality);
                    
                    if(newLevel.touchCount < m_minTouches)
                    {
                        m_hourlyStats.lowTouchCount++;
                        continue;
                    }
                    
                    newLevel.strength = CalculateLevelStrength(newLevel, quality);
                    
                    // Add volume strength bonus if there's a volume spike
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
        for(int i = 2; i < barsToProcess - 2; i++)
        {
            if(IsSwingLow(lows, i))
            {
                m_hourlyStats.totalSwingLows++;
                double level = lows[i];
                
                if(!IsNearExistingLevel(level))
                {
                    SKeyLevel newLevel;
                    newLevel.price = level;
                    newLevel.isResistance = false;
                    newLevel.firstTouch = times[i];
                    newLevel.lastTouch = times[i];
                    STouchQuality quality;
                    newLevel.touchCount = CountTouches(level, false, highs, lows, times, quality);
                    
                    if(newLevel.touchCount < m_minTouches)
                    {
                        m_hourlyStats.lowTouchCount++;
                        continue;
                    }
                    
                    newLevel.strength = CalculateLevelStrength(newLevel, quality);
                    
                    // Add volume strength bonus if there's a volume spike
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
}; 