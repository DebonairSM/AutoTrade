//+------------------------------------------------------------------+
//|                                              V-2-EA-US500Data.mqh |
//|                        US500-Specific Configuration Parameters    |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.01"

//+------------------------------------------------------------------+
//| US500 Configuration Class                                          |
//+------------------------------------------------------------------+
class CV2EAUS500Data
{
private:
    static double m_us500TouchZones[];      // Touch zones in points per timeframe
    static double m_us500BounceMinSizes[];  // Minimum bounce sizes
    static int    m_us500MinTouches[];      // Minimum number of touches
    static double m_us500MinStrengths[];    // Minimum acceptable strength
    static int    m_us500Lookbacks[];       // Lookback periods
    static int    m_us500MaxBounceDelays[]; // Maximum allowed bounce delays
    
    static bool   m_initialized;            // Initialization state
    
public:
    static void Initialize()
    {
        if(m_initialized) return;
        
        // Initialize arrays
        ArrayResize(m_us500TouchZones, 9);      // One for each timeframe
        ArrayResize(m_us500BounceMinSizes, 9);
        ArrayResize(m_us500MinTouches, 9);
        ArrayResize(m_us500MinStrengths, 9);
        ArrayResize(m_us500Lookbacks, 9);
        ArrayResize(m_us500MaxBounceDelays, 9);
        
        // Touch zones in points
        m_us500TouchZones[PERIOD_MN1] = 50.0;  // 50 points
        m_us500TouchZones[PERIOD_W1]  = 30.0;  // 30 points
        m_us500TouchZones[PERIOD_D1]  = 20.0;  // 20 points
        m_us500TouchZones[PERIOD_H4]  = 15.0;  // 15 points
        m_us500TouchZones[PERIOD_H1]  = 10.0;  // 10 points
        m_us500TouchZones[PERIOD_M30] = 7.5;   // 7.5 points
        m_us500TouchZones[PERIOD_M15] = 5.0;   // 5 points
        m_us500TouchZones[PERIOD_M5]  = 3.0;   // 3 points
        m_us500TouchZones[PERIOD_M1]  = 2.0;   // 2 points
        
        // Minimum bounce sizes (in points)
        m_us500BounceMinSizes[PERIOD_MN1] = 200.0;
        m_us500BounceMinSizes[PERIOD_W1]  = 150.0;
        m_us500BounceMinSizes[PERIOD_D1]  = 100.0;
        m_us500BounceMinSizes[PERIOD_H4]  = 50.0;
        m_us500BounceMinSizes[PERIOD_H1]  = 25.0;
        m_us500BounceMinSizes[PERIOD_M30] = 15.0;
        m_us500BounceMinSizes[PERIOD_M15] = 10.0;
        m_us500BounceMinSizes[PERIOD_M5]  = 6.0;
        m_us500BounceMinSizes[PERIOD_M1]  = 4.0;
        
        // Minimum touches required (higher due to more noise)
        m_us500MinTouches[PERIOD_MN1] = 2;
        m_us500MinTouches[PERIOD_W1]  = 2;
        m_us500MinTouches[PERIOD_D1]  = 3;
        m_us500MinTouches[PERIOD_H4]  = 3;
        m_us500MinTouches[PERIOD_H1]  = 4;
        m_us500MinTouches[PERIOD_M30] = 4;
        m_us500MinTouches[PERIOD_M15] = 4;
        m_us500MinTouches[PERIOD_M5]  = 5;
        m_us500MinTouches[PERIOD_M1]  = 5;
        
        // Minimum strength thresholds (higher due to more noise)
        m_us500MinStrengths[PERIOD_MN1] = 0.55;
        m_us500MinStrengths[PERIOD_W1]  = 0.55;
        m_us500MinStrengths[PERIOD_D1]  = 0.60;
        m_us500MinStrengths[PERIOD_H4]  = 0.65;
        m_us500MinStrengths[PERIOD_H1]  = 0.70;
        m_us500MinStrengths[PERIOD_M30] = 0.75;
        m_us500MinStrengths[PERIOD_M15] = 0.75;
        m_us500MinStrengths[PERIOD_M5]  = 0.80;
        m_us500MinStrengths[PERIOD_M1]  = 0.85;
        
        // Lookback periods
        m_us500Lookbacks[PERIOD_MN1] = 24;   // 24 months
        m_us500Lookbacks[PERIOD_W1]  = 52;   // 52 weeks
        m_us500Lookbacks[PERIOD_D1]  = 200;  // 200 days
        m_us500Lookbacks[PERIOD_H4]  = 200;  // 200 4h bars
        m_us500Lookbacks[PERIOD_H1]  = 200;  // 200 1h bars
        m_us500Lookbacks[PERIOD_M30] = 200;  // 200 30m bars
        m_us500Lookbacks[PERIOD_M15] = 200;  // 200 15m bars
        m_us500Lookbacks[PERIOD_M5]  = 200;  // 200 5m bars
        m_us500Lookbacks[PERIOD_M1]  = 200;  // 200 1m bars
        
        // Maximum bounce delays (in bars)
        m_us500MaxBounceDelays[PERIOD_MN1] = 3;
        m_us500MaxBounceDelays[PERIOD_W1]  = 4;
        m_us500MaxBounceDelays[PERIOD_D1]  = 5;
        m_us500MaxBounceDelays[PERIOD_H4]  = 6;
        m_us500MaxBounceDelays[PERIOD_H1]  = 8;
        m_us500MaxBounceDelays[PERIOD_M30] = 10;
        m_us500MaxBounceDelays[PERIOD_M15] = 12;
        m_us500MaxBounceDelays[PERIOD_M5]  = 15;
        m_us500MaxBounceDelays[PERIOD_M1]  = 20;
        
        m_initialized = true;
    }
    
    static double GetTouchZone(ENUM_TIMEFRAMES timeframe)
    {
        if(!m_initialized) Initialize();
        return timeframe < ArraySize(m_us500TouchZones) ? m_us500TouchZones[timeframe] * _Point : 5.0 * _Point;
    }
    
    static double GetBounceMinSize(ENUM_TIMEFRAMES timeframe)
    {
        if(!m_initialized) Initialize();
        return timeframe < ArraySize(m_us500BounceMinSizes) ? m_us500BounceMinSizes[timeframe] * _Point : 10.0 * _Point;
    }
    
    static int GetMinTouches(ENUM_TIMEFRAMES timeframe)
    {
        if(!m_initialized) Initialize();
        return timeframe < ArraySize(m_us500MinTouches) ? m_us500MinTouches[timeframe] : 4;
    }
    
    static double GetMinStrength(ENUM_TIMEFRAMES timeframe)
    {
        if(!m_initialized) Initialize();
        return timeframe < ArraySize(m_us500MinStrengths) ? m_us500MinStrengths[timeframe] : 0.70;
    }
    
    static int GetLookback(ENUM_TIMEFRAMES timeframe)
    {
        if(!m_initialized) Initialize();
        return timeframe < ArraySize(m_us500Lookbacks) ? m_us500Lookbacks[timeframe] : 200;
    }
    
    static int GetMaxBounceDelay(ENUM_TIMEFRAMES timeframe)
    {
        if(!m_initialized) Initialize();
        return timeframe < ArraySize(m_us500MaxBounceDelays) ? m_us500MaxBounceDelays[timeframe] : 8;
    }
    
    // Market hours volume adjustments
    static double GetMarketHoursFactor()
    {
        int hourET = CV2EAUtils::GetCurrentHourET();
        
        // Regular market hours (9:30 AM - 4:00 PM ET)
        if(CV2EAUtils::IsWithinSession(hourET, 9, 16))
            return 1.0;
            
        // Pre-market (4:00 AM - 9:30 AM ET)
        if(CV2EAUtils::IsWithinSession(hourET, 4, 9))
            return 0.7;
            
        // After-hours (4:00 PM - 8:00 PM ET)
        if(CV2EAUtils::IsWithinSession(hourET, 16, 20))
            return 0.7;
            
        // Overnight
        return 0.5;
    }
};

// Initialize static members
double CV2EAUS500Data::m_us500TouchZones[];
double CV2EAUS500Data::m_us500BounceMinSizes[];
int    CV2EAUS500Data::m_us500MinTouches[];
double CV2EAUS500Data::m_us500MinStrengths[];
int    CV2EAUS500Data::m_us500Lookbacks[];
int    CV2EAUS500Data::m_us500MaxBounceDelays[];
bool   CV2EAUS500Data::m_initialized = false; 