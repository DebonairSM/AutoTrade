//+------------------------------------------------------------------+
//|                                              V-2-EA-Breakouts.mqh |
//|                                    Key Level Detection Implementation|
//+------------------------------------------------------------------+
#property copyright "Rommel Company"
#property link      "Your Link"
#property version   "1.02"

#include <Trade\Trade.mqh>
#include <VErrorDesc.mqh>  // Add this include for error descriptions
#include "V-2-EA-US500Data.mqh"  // Add US500 specific data handling

//+------------------------------------------------------------------+
//| Constants                                                          |
//+------------------------------------------------------------------+
#define DEFAULT_BUFFER_SIZE 100 // Default size for price buffers
#define DEFAULT_DEBUG_INTERVAL 300 // Default debug interval (5 minutes)
#define ERR_OBJECT_DOES_NOT_EXIST 4202 // MQL5 error code for non-existent object

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
    bool      volumeConfirmed; // Whether this level is confirmed by significant volume
    double    volumeRatio;     // Ratio of level volume to average volume
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
class CV2EABreakouts
{
private:
    //--- US500 Detection
    bool IsUS500()
    {
        return (StringFind(_Symbol, "US500") >= 0 || StringFind(_Symbol, "SPX") >= 0);
    }

    //--- Safe Array Resize Template Function
    template<typename T>
    bool SafeResizeArray(T &arr[], int newSize, const string context)
    {
        if(!ArrayResize(arr, newSize))
        {
            Print("❌ [", context, "] Error: Failed to resize array to ", newSize, " elements.");
            return false;
        }
        return true;
    }

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

    //--- Chart visualization
    SChartLine m_chartLines[];  // Array to track chart lines
    datetime m_lastChartUpdate; // Last chart update time

    int m_maxBounceDelay;  // Maximum bars to wait for bounce

public:
    //--- Constructor and destructor
    CV2EABreakouts(void) : m_initialized(false),
                           m_lookbackPeriod(0),     
                           m_minStrength(0.55),
                           m_touchZone(0),          
                           m_minTouches(2),
                           m_keyLevelCount(0),
                           m_lastKeyLevelUpdate(0),
                           m_showDebugPrints(false),
                           m_maxBounceDelay(8)  
    {
        // Initialize each array with robust error checking
        if(!SafeResizeArray(m_currentKeyLevels, DEFAULT_BUFFER_SIZE, "CV2EABreakouts::Constructor - m_currentKeyLevels"))
        {
            Print("❌ [CV2EABreakouts::Constructor] Initialization failed for m_currentKeyLevels");
            return;
        }
        
        if(!SafeResizeArray(m_chartLines, DEFAULT_BUFFER_SIZE, "CV2EABreakouts::Constructor - m_chartLines"))
        {
            Print("❌ [CV2EABreakouts::Constructor] Initialization failed for m_chartLines");
            return;
        }
        
        if(!SafeResizeArray(m_recentBreaks, DEFAULT_BUFFER_SIZE, "CV2EABreakouts::Constructor - m_recentBreaks") ||
           !SafeResizeArray(m_recentBreakTimes, DEFAULT_BUFFER_SIZE, "CV2EABreakouts::Constructor - m_recentBreakTimes"))
        {
            Print("❌ [CV2EABreakouts::Constructor] Initialization failed for recent breaks arrays");
            return;
        }
        
        if(!SafeResizeArray(m_lastAlerts, DEFAULT_BUFFER_SIZE, "CV2EABreakouts::Constructor - m_lastAlerts"))
        {
            Print("❌ [CV2EABreakouts::Constructor] Initialization failed for m_lastAlerts");
            return;
        }
        
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
    bool Init(int lookbackPeriod, double minStrength, double touchZone, int minTouches, bool showDebugPrints)
    {
        if(IsUS500())
        {
            // Initialize US500 specific data handler
            CV2EAUS500Data::InitUS500(showDebugPrints);
            
            // Get settings based on current timeframe
            ENUM_TIMEFRAMES tf = Period();
            m_touchZone = CV2EAUS500Data::GetUS500TouchZone(tf);
            m_minTouches = CV2EAUS500Data::GetUS500MinTouches(tf);
            m_minStrength = CV2EAUS500Data::GetUS500MinStrength(tf);
            m_lookbackPeriod = CV2EAUS500Data::GetUS500Lookback(tf);
            
            // Override with any user-specified values if provided
            if(lookbackPeriod > 0) m_lookbackPeriod = lookbackPeriod;
            if(minStrength > 0) m_minStrength = minStrength;
            if(touchZone > 0) m_touchZone = touchZone;
            if(minTouches > 0) m_minTouches = minTouches;
            
            DebugPrint("Initialized with US500 specific settings");
        }
        else
        {
            // Original initialization code
            if(minStrength <= 0.0 || minStrength > 1.0)
            {
                Print("❌ [Init] Invalid minStrength (", minStrength, "). Resetting to default 0.55.");
                minStrength = 0.55;
            }
            if(minTouches < 1)
            {
                Print("❌ [Init] Invalid minTouches (", minTouches, "). Resetting to minimum value 2.");
                minTouches = 2;
            }
            
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
        }
        
        // Common initialization code
        if(!SafeResizeArray(m_currentKeyLevels, DEFAULT_BUFFER_SIZE, "CV2EABreakouts::Init - m_currentKeyLevels"))
        {
            Print("❌ [CV2EABreakouts::Init] Failed to resize key levels array");
            return false;
        }
        
        if(!SafeResizeArray(m_chartLines, DEFAULT_BUFFER_SIZE, "CV2EABreakouts::Init - m_chartLines"))
        {
            Print("❌ [CV2EABreakouts::Init] Failed to resize chart lines array");
            return false;
        }
        
        m_keyLevelCount = 0;
        m_state.Reset();
        m_lastChartUpdate = 0;
        
        // Validate symbol point value with error handling
        double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        if(symbolPoint <= 0)
        {
            Print("❌ [Init] SymbolInfoDouble failed, checking _Point...");
            symbolPoint = _Point;
            if(symbolPoint <= 0)
            {
                Print("❌ [Init] All point value retrievals failed. Using fallback value.");
                symbolPoint = 0.0001;
            }
        }
        
        m_initialized = true;
        Print("✅ [CV2EABreakouts::Init] Configuration complete for ", _Symbol);
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
        bool foundKeyLevel;
        
        if(IsUS500())
        {
            foundKeyLevel = CV2EAUS500Data::FindUS500KeyLevels(_Symbol, strongestLevel);
        }
        else
        {
            foundKeyLevel = FindKeyLevels(strongestLevel);
        }
        
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
        
        // Step 4: Update chart lines - Force update on each call
        m_lastChartUpdate = 0; // Reset last update time to force update
        UpdateChartLines();
    }

    // ... rest of the existing methods ...
}; 