//+------------------------------------------------------------------+
//|                                            VSol.Market.Forex.mqh |
//|                 Forex-Specific Market Data Analysis Module         |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.00"
#property strict

#ifndef __VSOL_MARKET_FOREX_MQH__
#define __VSOL_MARKET_FOREX_MQH__

#include "VSol.Market.mqh"

//+------------------------------------------------------------------+
//| Forex-specific market data analysis class                          |
//+------------------------------------------------------------------+
class CVSolForexData : public CVSolMarketBase
{
private:
    //--- Forex Specific Settings
    static double   m_forexTouchZones[];      // Touch zones by timeframe (in pips)
    static double   m_forexBounceMinSizes[];  // Minimum bounce sizes by timeframe (in pips)
    static int      m_forexMinTouches[];      // Minimum touches by timeframe
    static double   m_forexMinStrengths[];    // Minimum strengths by timeframe
    static int      m_forexLookbacks[];       // Lookback periods by timeframe
    static int      m_forexMaxBounceDelays[]; // Maximum bounce delays by timeframe
    static double   m_pipValue;               // Current symbol pip value
    static int      m_pipDigits;             // Digits for pip calculation
    
    //--- Forex Market State
    static double   m_lastSpread;             // Last calculated spread
    static datetime m_lastSpreadUpdate;       // Last spread update time
    static double   m_maxAllowedSpread;       // Maximum allowed spread in pips
    static bool     m_initialized;            // Initialization state
    
    //--- Helper Methods
    static void InitializeForexSettings();
    static double GetForexSetting(const double &settings[], ENUM_TIMEFRAMES timeframe);
    static int GetForexIntSetting(const int &settings[], ENUM_TIMEFRAMES timeframe);
    static double CalculateForexStrength(const SKeyLevel &level, const STouch &touches[]);
    static bool ValidateForexTouch(const double price, const double level, ENUM_TIMEFRAMES timeframe);
    static double GetCurrentSpread(string symbol);
    static void UpdatePipValues(string symbol);

public:
    //--- Initialization
    static void Initialize()
    {
        if(m_initialized) return;
        
        // Initialize arrays
        ArrayResize(m_forexTouchZones, 9);      // One for each timeframe
        ArrayResize(m_forexBounceMinSizes, 9);
        ArrayResize(m_forexMinTouches, 9);
        ArrayResize(m_forexMinStrengths, 9);
        ArrayResize(m_forexLookbacks, 9);
        ArrayResize(m_forexMaxBounceDelays, 9);
        
        // Touch zones in pips
        m_forexTouchZones[PERIOD_MN1] = 50.0;   // 50 pips
        m_forexTouchZones[PERIOD_W1]  = 30.0;   // 30 pips
        m_forexTouchZones[PERIOD_D1]  = 20.0;   // 20 pips
        m_forexTouchZones[PERIOD_H4]  = 15.0;   // 15 pips
        m_forexTouchZones[PERIOD_H1]  = 10.0;   // 10 pips
        m_forexTouchZones[PERIOD_M30] = 7.5;    // 7.5 pips
        m_forexTouchZones[PERIOD_M15] = 5.0;    // 5 pips
        m_forexTouchZones[PERIOD_M5]  = 3.0;    // 3 pips
        m_forexTouchZones[PERIOD_M1]  = 2.0;    // 2 pips
        
        // Minimum bounce sizes (in pips)
        m_forexBounceMinSizes[PERIOD_MN1] = 100.0;
        m_forexBounceMinSizes[PERIOD_W1]  = 70.0;
        m_forexBounceMinSizes[PERIOD_D1]  = 50.0;
        m_forexBounceMinSizes[PERIOD_H4]  = 30.0;
        m_forexBounceMinSizes[PERIOD_H1]  = 20.0;
        m_forexBounceMinSizes[PERIOD_M30] = 15.0;
        m_forexBounceMinSizes[PERIOD_M15] = 10.0;
        m_forexBounceMinSizes[PERIOD_M5]  = 7.0;
        m_forexBounceMinSizes[PERIOD_M1]  = 5.0;
        
        // Minimum touches required
        m_forexMinTouches[PERIOD_MN1] = 2;
        m_forexMinTouches[PERIOD_W1]  = 2;
        m_forexMinTouches[PERIOD_D1]  = 2;
        m_forexMinTouches[PERIOD_H4]  = 3;
        m_forexMinTouches[PERIOD_H1]  = 3;
        m_forexMinTouches[PERIOD_M30] = 3;
        m_forexMinTouches[PERIOD_M15] = 4;
        m_forexMinTouches[PERIOD_M5]  = 4;
        m_forexMinTouches[PERIOD_M1]  = 5;
        
        // Minimum strength thresholds
        m_forexMinStrengths[PERIOD_MN1] = 0.50;
        m_forexMinStrengths[PERIOD_W1]  = 0.50;
        m_forexMinStrengths[PERIOD_D1]  = 0.55;
        m_forexMinStrengths[PERIOD_H4]  = 0.60;
        m_forexMinStrengths[PERIOD_H1]  = 0.65;
        m_forexMinStrengths[PERIOD_M30] = 0.70;
        m_forexMinStrengths[PERIOD_M15] = 0.70;
        m_forexMinStrengths[PERIOD_M5]  = 0.75;
        m_forexMinStrengths[PERIOD_M1]  = 0.80;
        
        // Lookback periods
        m_forexLookbacks[PERIOD_MN1] = 24;   // 24 months
        m_forexLookbacks[PERIOD_W1]  = 52;   // 52 weeks
        m_forexLookbacks[PERIOD_D1]  = 200;  // 200 days
        m_forexLookbacks[PERIOD_H4]  = 200;  // 200 4h bars
        m_forexLookbacks[PERIOD_H1]  = 200;  // 200 1h bars
        m_forexLookbacks[PERIOD_M30] = 200;  // 200 30m bars
        m_forexLookbacks[PERIOD_M15] = 200;  // 200 15m bars
        m_forexLookbacks[PERIOD_M5]  = 200;  // 200 5m bars
        m_forexLookbacks[PERIOD_M1]  = 200;  // 200 1m bars
        
        // Maximum bounce delays (in bars)
        m_forexMaxBounceDelays[PERIOD_MN1] = 3;
        m_forexMaxBounceDelays[PERIOD_W1]  = 4;
        m_forexMaxBounceDelays[PERIOD_D1]  = 5;
        m_forexMaxBounceDelays[PERIOD_H4]  = 6;
        m_forexMaxBounceDelays[PERIOD_H1]  = 8;
        m_forexMaxBounceDelays[PERIOD_M30] = 10;
        m_forexMaxBounceDelays[PERIOD_M15] = 12;
        m_forexMaxBounceDelays[PERIOD_M5]  = 15;
        m_forexMaxBounceDelays[PERIOD_M1]  = 20;
        
        m_initialized = true;
    }
    
    //--- Forex Specific Methods
    static void InitForex(bool showDebugPrints=false)
    {
        Init(showDebugPrints);  // Initialize base class
        Initialize();           // Initialize Forex settings
        m_maxAllowedSpread = 20.0;  // Default max spread of 2.0 pips
        m_lastSpread = 0;
        m_lastSpreadUpdate = 0;
        m_pipValue = 0;
        m_pipDigits = 0;
    }
    
    static double GetTouchZone(ENUM_TIMEFRAMES timeframe)
    {
        if(!m_initialized) Initialize();
        return timeframe < ArraySize(m_forexTouchZones) ? m_forexTouchZones[timeframe] * _Point : 5.0 * _Point;
    }
    
    static double GetBounceMinSize(ENUM_TIMEFRAMES timeframe)
    {
        if(!m_initialized) Initialize();
        return timeframe < ArraySize(m_forexBounceMinSizes) ? m_forexBounceMinSizes[timeframe] * _Point : 10.0 * _Point;
    }
    
    static int GetMinTouches(ENUM_TIMEFRAMES timeframe)
    {
        if(!m_initialized) Initialize();
        return timeframe < ArraySize(m_forexMinTouches) ? m_forexMinTouches[timeframe] : 3;
    }
    
    static double GetMinStrength(ENUM_TIMEFRAMES timeframe)
    {
        if(!m_initialized) Initialize();
        return timeframe < ArraySize(m_forexMinStrengths) ? m_forexMinStrengths[timeframe] : 0.65;
    }
    
    static int GetLookback(ENUM_TIMEFRAMES timeframe)
    {
        if(!m_initialized) Initialize();
        return timeframe < ArraySize(m_forexLookbacks) ? m_forexLookbacks[timeframe] : 200;
    }
    
    static int GetMaxBounceDelay(ENUM_TIMEFRAMES timeframe)
    {
        if(!m_initialized) Initialize();
        return timeframe < ArraySize(m_forexMaxBounceDelays) ? m_forexMaxBounceDelays[timeframe] : 8;
    }
    
    // Session-specific volume adjustments
    static double GetSessionVolumeFactor()
    {
        int hourET = CVSolUtils::GetCurrentHourET();
        
        bool isAsianSession = CVSolUtils::IsWithinSession(hourET, 0, 8);   // 00:00-08:00 ET
        bool isLondonSession = CVSolUtils::IsWithinSession(hourET, 3, 11); // 03:00-11:00 ET
        bool isNYSession = CVSolUtils::IsWithinSession(hourET, 8, 17);     // 08:00-17:00 ET
        
        if(isLondonSession && isNYSession) return 1.3;  // London-NY overlap
        if(isAsianSession && isLondonSession) return 1.2;  // Asian-London overlap
        if(isLondonSession) return 1.1;  // London session
        if(isNYSession) return 1.1;  // NY session
        if(isAsianSession) return 1.0;  // Asian session
        return 0.8;  // Off-hours
    }
    
    /**
     * @brief Override base class strength calculation for Forex.
     */
    double CalculateStrength(const SKeyLevel &level, const STouch &touches[]) override
    {
        return CalculateForexStrength(level, touches);
    }
    
    /**
     * @brief Override base class level validation for Forex.
     */
    bool ValidateLevel(const double price, const double level, ENUM_TIMEFRAMES timeframe) override
    {
        return ValidateForexTouch(price, level, timeframe);
    }
    
    /**
     * @brief Override base class key level detection for Forex.
     */
    bool FindKeyLevels(string symbol, SKeyLevel &outStrongestLevel) override
    {
        return FindForexKeyLevels(symbol, outStrongestLevel);
    }
    
    /**
     * @brief Override base class session factor for Forex.
     */
    double GetSessionFactor() override
    {
        return GetSessionVolumeFactor();
    }
};

// Initialize static members
double CVSolForexData::m_forexTouchZones[];
double CVSolForexData::m_forexBounceMinSizes[];
int    CVSolForexData::m_forexMinTouches[];
double CVSolForexData::m_forexMinStrengths[];
int    CVSolForexData::m_forexLookbacks[];
int    CVSolForexData::m_forexMaxBounceDelays[];
double CVSolForexData::m_pipValue;
int    CVSolForexData::m_pipDigits;
double CVSolForexData::m_lastSpread;
datetime CVSolForexData::m_lastSpreadUpdate;
double CVSolForexData::m_maxAllowedSpread;
bool   CVSolForexData::m_initialized = false;

#endif // __VSOL_MARKET_FOREX_MQH__ 