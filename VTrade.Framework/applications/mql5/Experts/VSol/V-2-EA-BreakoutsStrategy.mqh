//+------------------------------------------------------------------+
//|                                     V-2-EA-BreakoutsStrategy.mqh   |
//|                                    Key Level Strategy Management    |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.01"

#include "V-2-EA-Breakouts.mqh"

// Key level report structure
struct STimeframeKeyLevel {
    ENUM_TIMEFRAMES timeframe;
    SKeyLevel strongestLevel;
    datetime lastUpdate;
    bool isValid;
    
    void Reset() {
        timeframe = PERIOD_CURRENT;
        lastUpdate = 0;
        isValid = false;
    }
};

struct SKeyLevelReport {
    STimeframeKeyLevel levels[];
    datetime reportTime;
    string symbol;
    bool isValid;
    
    void Reset() {
        ArrayResize(levels, 0);
        reportTime = 0;
        symbol = "";
        isValid = false;
    }
};

//+------------------------------------------------------------------+
//| Strategy Management Class                                          |
//+------------------------------------------------------------------+
class CV2EABreakoutsStrategy {
private:
    CV2EABreakouts* m_breakouts;  // Breakouts analysis engine
    bool m_initialized;           // Initialization state
    SKeyLevelReport m_report;     // Current key level report
    bool m_showDebugPrints;       // Debug output control
    
    // Configuration
    int m_lookbackPeriod;
    double m_minStrength;
    double m_touchZone;
    int m_minTouches;
    
    // Monitored timeframes
    ENUM_TIMEFRAMES m_timeframes[];
    
    int GetRequiredLookback(ENUM_TIMEFRAMES tf)
    {
        switch(tf)
        {
            case PERIOD_MN1:  return 12;    // 1 year of monthly data
            case PERIOD_W1:   return 52;    // 1 year of weekly data
            case PERIOD_D1:   return 90;    // 3 months of daily data
            case PERIOD_H4:   return 84;     // 2 weeks of H4 data (6 bars/day × 14 days)
            case PERIOD_H1:   return 168;    // 1 week of hourly data
            case PERIOD_M30:  return 336;    // 2 weeks of 30-minute data
            case PERIOD_M15:  return 672;    // 1 week of 15-minute data
            case PERIOD_M5:   return 2016;   // 1 week of 5-minute data
            case PERIOD_M1:   return 10080;  // 1 week of 1-minute data
            default:          return m_lookbackPeriod; // Use configured value for custom TFs
        }
    }
    
public:
    //--- Constructor
    CV2EABreakoutsStrategy(void) : m_breakouts(NULL),
                                  m_initialized(false),
                                  m_showDebugPrints(false),
                                  m_lookbackPeriod(0),
                                  m_minStrength(0),
                                  m_touchZone(0),
                                  m_minTouches(0)
    {
        m_report.Reset();
        InitializeTimeframes();
    }
    
    //--- Destructor
    ~CV2EABreakoutsStrategy(void)
    {
        if(m_breakouts != NULL) {
            delete m_breakouts;
            m_breakouts = NULL;
        }
    }
    
    //--- Initialization
    bool Init(int lookbackPeriod, double minStrength, double touchZone, 
              int minTouches, bool showDebugPrints)
    {
        // Store configuration
        m_lookbackPeriod = lookbackPeriod;
        m_minStrength = minStrength;
        m_touchZone = touchZone;
        m_minTouches = minTouches;
        m_showDebugPrints = showDebugPrints;
        
        // Create breakouts analyzer
        if(m_breakouts == NULL)
            m_breakouts = new CV2EABreakouts();
            
        if(m_breakouts == NULL) {
            Print("❌ Error: Failed to create breakouts analyzer");
            return false;
        }
        
        // Initialize breakouts analyzer
        if(!m_breakouts.Init(lookbackPeriod, minStrength, touchZone, minTouches, showDebugPrints)) {
            Print("❌ Error: Failed to initialize breakouts analyzer");
            return false;
        }
        
        m_initialized = true;
        return true;
    }
    
    //--- Main processing
    void OnNewBar(void)
    {
        if(!m_initialized) {
            Print("❌ Error: Strategy not initialized");
            return;
        }
        
        // Update report
        UpdateReport();
    }
    
    //--- Report access
    void GetReport(SKeyLevelReport &report)
    {
        if(!m_initialized) {
            report.Reset();
            return;
        }
        
        report = m_report;
    }
    
    //--- State checks
    bool IsInitialized(void) const { return m_initialized; }
    
    // Add this validation helper function
    bool ValidateTimeframeData(ENUM_TIMEFRAMES tf)
    {
        int required = GetRequiredLookback(tf);
        int available = iBars(_Symbol, tf);
        
        if(available < required) {
            if(m_showDebugPrints) {
                Print(StringFormat("Data validation failed for %s: %d/%d bars available",
                      EnumToString(tf), available, required));
            }
            return false;
        }
        return true;
    }
    
private:
    //--- Internal methods
    void InitializeTimeframes(void)
    {
        static ENUM_TIMEFRAMES tf[] = {
            PERIOD_MN1, PERIOD_W1, PERIOD_D1,
            PERIOD_H4, PERIOD_H1,
            PERIOD_M30, PERIOD_M15, PERIOD_M5, PERIOD_M1
        };
        
        ArrayResize(m_timeframes, ArraySize(tf));
        ArrayCopy(m_timeframes, tf);
    }
    
    void UpdateReport(void)
    {
        if(m_breakouts == NULL)
            return;
            
        datetime currentTime = TimeCurrent();
        
        // Reset report
        m_report.Reset();
        m_report.symbol = _Symbol;
        m_report.reportTime = currentTime;
        
        // Process each timeframe
        for(int i = 0; i < ArraySize(m_timeframes); i++) {
            ProcessTimeframe(m_timeframes[i]);
        }
        
        // Mark report as valid if we have any levels
        m_report.isValid = ArraySize(m_report.levels) > 0;
    }
    
    bool ProcessTimeframe(ENUM_TIMEFRAMES timeframe)
    {
        if(!m_initialized) {
            CV2EAUtils::LogError("Strategy not initialized");
            return false;
        }
        
        if(!ValidateTimeframeData(timeframe)) {
            return false;
        }
        
        // Process on the timeframe using the breakouts analyzer
        if(!m_breakouts.ProcessTimeframe(timeframe)) {
            if(m_showDebugPrints)
                Print("Failed to process ", EnumToString(timeframe));
            return false;
        }
        
        // Get strongest level
        SKeyLevel strongestLevel;
        if(!m_breakouts.GetStrongestLevel(strongestLevel)) {
            if(m_showDebugPrints)
                Print("No strong levels found for ", EnumToString(timeframe));
            return false;
        }
        
        // Add to report
        int idx = ArraySize(m_report.levels);
        ArrayResize(m_report.levels, idx + 1);
        
        m_report.levels[idx].timeframe = timeframe;
        m_report.levels[idx].strongestLevel = strongestLevel;
        m_report.levels[idx].lastUpdate = TimeCurrent();
        m_report.levels[idx].isValid = true;
        
        return true;
    }
};