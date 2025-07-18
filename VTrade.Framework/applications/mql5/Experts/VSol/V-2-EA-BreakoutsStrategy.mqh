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
    bool m_currentTimeframeOnly;        // Only process current timeframe
    
    string m_version;
    
    int GetRequiredLookback(ENUM_TIMEFRAMES tf)
    {
        int required = m_lookbackPeriod; // Default to configured value
        
        // For higher timeframes, use more appropriate values
        switch(tf)
        {
            case PERIOD_MN1:  
                required = MathMin(12, m_lookbackPeriod);   // 1 year of monthly data
                break;
            case PERIOD_W1:   
                required = MathMin(52, m_lookbackPeriod);   // 1 year of weekly data
                break;
            case PERIOD_D1:   
                required = MathMin(90, m_lookbackPeriod);   // ~3 months of daily data
                break;
            case PERIOD_H4:   
                required = MathMin(180, m_lookbackPeriod);  // ~30 days of 4H data
                break;
            case PERIOD_H1:   
                required = MathMin(168, m_lookbackPeriod);  // 1 week of hourly data
                break;
            case PERIOD_M30:  
                required = MathMin(336, m_lookbackPeriod);  // 1 week of M30 data
                break;
            case PERIOD_M15:  
                required = MathMin(672, m_lookbackPeriod);  // 1 week of M15 data
                break;
            case PERIOD_M5:   
                required = MathMin(2016, m_lookbackPeriod); // 1 week of M5 data
                break;
            case PERIOD_M1:   
                required = MathMin(10080, m_lookbackPeriod); // 1 week of M1 data
                break;
        }
        
        if(m_showDebugPrints) {
            Print(StringFormat("Lookback calc: %s -> %d bars (Config: %d)",
                  EnumToString(tf), required, m_lookbackPeriod));
        }
        return required;
    }
    
public:
    //--- Constructor
    CV2EABreakoutsStrategy(void) : m_breakouts(NULL),
                                  m_initialized(false),
                                  m_showDebugPrints(false),
                                  m_lookbackPeriod(0),
                                  m_minStrength(0),
                                  m_touchZone(0),
                                  m_minTouches(0),
                                  m_version("1.0.4")
    {
        m_report.Reset();
        // NOTE: InitializeTimeframes() moved to Init() method after m_currentTimeframeOnly is set
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
              int minTouches, bool showDebugPrints, bool useVolumeFilter = true, bool ignoreMarketHours = false, bool currentTimeframeOnly = false)
    {
        // Add parameter validation
        if(lookbackPeriod < 50 || lookbackPeriod > 50000) {
            Print("❌ Invalid lookback period: ", lookbackPeriod);
            return false;
        }
        
        if(minStrength < 0.1 || minStrength > 0.99) {
            Print("❌ Invalid min strength: ", minStrength);
            return false;
        }
        
        // Store configuration
        m_lookbackPeriod = lookbackPeriod;
        m_minStrength = minStrength;
        m_touchZone = touchZone;
        m_minTouches = minTouches;
        m_showDebugPrints = showDebugPrints;
        m_currentTimeframeOnly = currentTimeframeOnly;
        
        // Initialize timeframes AFTER m_currentTimeframeOnly is set
        InitializeTimeframes();
        
        // Print configuration info
        Print(StringFormat("🔧 DEBUG: m_currentTimeframeOnly = %s", m_currentTimeframeOnly ? "TRUE" : "FALSE"));
        Print(StringFormat("🔧 DEBUG: Period() = %s", EnumToString(Period())));
        if(m_currentTimeframeOnly) {
            Print("📊 Strategy: SIMPLIFIED MODE - Processing current timeframe only: ", EnumToString(Period()));
        } else {
            Print("📊 Strategy: MULTI-TIMEFRAME MODE - Processing ", ArraySize(m_timeframes), " timeframes");
        }
        
        // Create breakouts analyzer
        if(m_breakouts == NULL)
            m_breakouts = new CV2EABreakouts();
            
        if(m_breakouts == NULL) {
            Print("❌ Error: Failed to create breakouts analyzer");
            return false;
        }
        
        // Initialize breakouts analyzer
        if(!m_breakouts.Init(lookbackPeriod, minStrength, touchZone, minTouches, showDebugPrints, useVolumeFilter, ignoreMarketHours)) {
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
        // Add this check first
        if(!SymbolInfoInteger(_Symbol, SYMBOL_SELECT)) {
            Print("❌ Symbol not selected: ", _Symbol);
            return false;
        }
        
        int required = GetRequiredLookback(tf);
        int available = iBars(_Symbol, tf);
        
        // Enhanced diagnostic output
        if(m_showDebugPrints) {
            Print(StringFormat("Validation start: %s | Req: %d | Avail: %d | TF: %s",
                  __FUNCTION__, required, available, EnumToString(tf)));
        }

        // Special handling for higher timeframes
        if(tf >= PERIOD_W1) {
            double ratio = (double)available/required;
            if(ratio >= 0.8) {  // Allow 80% of required bars for higher timeframes
                if(m_showDebugPrints) {
                    Print(StringFormat("Adjusted validation for %s: %.1f%% available (%d/%d)",
                          EnumToString(tf), ratio*100, available, required));
                }
                return true;
            }
        }
        
        if(available < required) {
            if(m_showDebugPrints) {
                Print(StringFormat("Validation FAILED: %s | Need: %d | Have: %d | Diff: %d",
                      EnumToString(tf), required, available, required-available));
            }
            return false;
        }
        
        // Add data synchronization verification
        if(!SeriesInfoInteger(_Symbol, tf, SERIES_SYNCHRONIZED)) {
            Print("⚠️ Data not synchronized for ", EnumToString(tf));
            return false;
        }
        
        if(m_showDebugPrints) {
            Print(StringFormat("Validation PASSED: %s | Bars: %d", 
                  EnumToString(tf), available));
        }
        return true;
    }
    
    string GetVersion() const { return m_version; }
    
    //--- Chart visualization methods
    void ForceChartUpdate() 
    { 
        if(m_breakouts != NULL) {
            Print("🔧 Strategy: Forcing chart line update...");
            m_breakouts.ForceChartUpdate();
        } else {
            Print("❌ Strategy: Cannot update chart - breakouts analyzer not initialized");
        }
    }
    
    void RunDiagnostics() 
    { 
        if(m_breakouts != NULL) {
            Print("🔧 Strategy: Running diagnostic check...");
            m_breakouts.DiagnoseChartIssues();
        } else {
            Print("❌ Strategy: Cannot run diagnostics - breakouts analyzer not initialized");
        }
    }
    
private:
    //--- Internal methods
    void InitializeTimeframes(void)
    {
        Print(StringFormat("🔧 DEBUG: InitializeTimeframes called, m_currentTimeframeOnly = %s", m_currentTimeframeOnly ? "TRUE" : "FALSE"));
        
        if(m_currentTimeframeOnly) {
            // SIMPLIFIED MODE: Only process current chart timeframe
            ArrayResize(m_timeframes, 1);
            m_timeframes[0] = Period();
            Print(StringFormat("🔧 DEBUG: SIMPLIFIED MODE - Array size set to %d, timeframe = %s", ArraySize(m_timeframes), EnumToString(m_timeframes[0])));
        } else {
            // MULTI-TIMEFRAME MODE: Process all timeframes
            static ENUM_TIMEFRAMES tf[] = {
                PERIOD_MN1, PERIOD_W1, PERIOD_D1,
                PERIOD_H4, PERIOD_H1,
                PERIOD_M30, PERIOD_M15, PERIOD_M5, PERIOD_M1
            };
            
            ArrayResize(m_timeframes, ArraySize(tf));
            ArrayCopy(m_timeframes, tf);
            Print(StringFormat("🔧 DEBUG: MULTI-TIMEFRAME MODE - Array size set to %d timeframes", ArraySize(m_timeframes)));
        }
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
        Print(StringFormat("🔧 DEBUG: UpdateReport processing %d timeframes", ArraySize(m_timeframes)));
        for(int i = 0; i < ArraySize(m_timeframes); i++) {
            Print(StringFormat("🔧 DEBUG: Processing timeframe %d: %s", i, EnumToString(m_timeframes[i])));
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