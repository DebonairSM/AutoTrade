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
    //--- Constants
    static const int TIMEFRAME_COUNT;  // Total number of timeframes we support
    
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
    static bool     m_forexDebugPrints;       // Debug print flag for forex operations
    
    //--- Helper Methods
    static void InitializeForexSettings();
    static void UpdatePipValues(string symbol);
    static double CalculateForexStrength(const SKeyLevel &level, const STouch &touches[]);
    static bool ValidateForexTouch(const double price, const double level, ENUM_TIMEFRAMES timeframe);
    static double GetCurrentSpread(string symbol);
    
    //--- Settings Access Methods
    static double GetForexSetting(const double &settings[], ENUM_TIMEFRAMES timeframe);
    static int GetForexIntSetting(const int &settings[], ENUM_TIMEFRAMES timeframe);
    
public:
    //--- Initialization
    static void Initialize()
    {
        if(m_initialized) return;
        
        // Initialize arrays with safe size
        ArrayResize(m_forexTouchZones, TIMEFRAME_COUNT);
        ArrayResize(m_forexBounceMinSizes, TIMEFRAME_COUNT);
        ArrayResize(m_forexMinTouches, TIMEFRAME_COUNT);
        ArrayResize(m_forexMinStrengths, TIMEFRAME_COUNT);
        ArrayResize(m_forexLookbacks, TIMEFRAME_COUNT);
        ArrayResize(m_forexMaxBounceDelays, TIMEFRAME_COUNT);
        
        // Initialize with default values first
        for(int i = 0; i < TIMEFRAME_COUNT; i++)
        {
            m_forexTouchZones[i] = 5.0;        // Default 5 pips
            m_forexBounceMinSizes[i] = 10.0;   // Default 10 pips
            m_forexMinTouches[i] = 3;          // Default 3 touches
            m_forexMinStrengths[i] = 0.65;     // Default 0.65 strength
            m_forexLookbacks[i] = 200;         // Default 200 bars
            m_forexMaxBounceDelays[i] = 8;     // Default 8 bars
        }
        
        // Now set specific values
        // Touch zones in pips
        m_forexTouchZones[0] = 50.0;   // MN1: 50 pips
        m_forexTouchZones[1] = 30.0;   // W1:  30 pips
        m_forexTouchZones[2] = 20.0;   // D1:  20 pips
        m_forexTouchZones[3] = 15.0;   // H4:  15 pips
        m_forexTouchZones[4] = 10.0;   // H1:  10 pips
        m_forexTouchZones[5] = 7.5;    // M30: 7.5 pips
        m_forexTouchZones[6] = 5.0;    // M15: 5 pips
        m_forexTouchZones[7] = 3.0;    // M5:  3 pips
        m_forexTouchZones[8] = 2.0;    // M1:  2 pips
        
        // Minimum bounce sizes (in pips)
        m_forexBounceMinSizes[0] = 100.0;  // MN1
        m_forexBounceMinSizes[1] = 70.0;   // W1
        m_forexBounceMinSizes[2] = 50.0;   // D1
        m_forexBounceMinSizes[3] = 30.0;   // H4
        m_forexBounceMinSizes[4] = 20.0;   // H1
        m_forexBounceMinSizes[5] = 15.0;   // M30
        m_forexBounceMinSizes[6] = 10.0;   // M15
        m_forexBounceMinSizes[7] = 7.0;    // M5
        m_forexBounceMinSizes[8] = 5.0;    // M1
        
        // Minimum touches required
        m_forexMinTouches[0] = 2;  // MN1
        m_forexMinTouches[1] = 2;  // W1
        m_forexMinTouches[2] = 2;  // D1
        m_forexMinTouches[3] = 3;  // H4
        m_forexMinTouches[4] = 3;  // H1
        m_forexMinTouches[5] = 3;  // M30
        m_forexMinTouches[6] = 4;  // M15
        m_forexMinTouches[7] = 4;  // M5
        m_forexMinTouches[8] = 5;  // M1
        
        // Minimum strength thresholds
        m_forexMinStrengths[0] = 0.50;  // MN1
        m_forexMinStrengths[1] = 0.50;  // W1
        m_forexMinStrengths[2] = 0.55;  // D1
        m_forexMinStrengths[3] = 0.60;  // H4
        m_forexMinStrengths[4] = 0.65;  // H1
        m_forexMinStrengths[5] = 0.70;  // M30
        m_forexMinStrengths[6] = 0.70;  // M15
        m_forexMinStrengths[7] = 0.75;  // M5
        m_forexMinStrengths[8] = 0.80;  // M1
        
        // Lookback periods
        m_forexLookbacks[0] = 24;   // MN1: 24 months
        m_forexLookbacks[1] = 52;   // W1:  52 weeks
        m_forexLookbacks[2] = 200;  // D1:  200 days
        m_forexLookbacks[3] = 200;  // H4:  200 4h bars
        m_forexLookbacks[4] = 200;  // H1:  200 1h bars
        m_forexLookbacks[5] = 200;  // M30: 200 30m bars
        m_forexLookbacks[6] = 200;  // M15: 200 15m bars
        m_forexLookbacks[7] = 200;  // M5:  200 5m bars
        m_forexLookbacks[8] = 200;  // M1:  200 1m bars
        
        // Maximum bounce delays (in bars)
        m_forexMaxBounceDelays[0] = 3;   // MN1
        m_forexMaxBounceDelays[1] = 4;   // W1
        m_forexMaxBounceDelays[2] = 5;   // D1
        m_forexMaxBounceDelays[3] = 6;   // H4
        m_forexMaxBounceDelays[4] = 8;   // H1
        m_forexMaxBounceDelays[5] = 10;  // M30
        m_forexMaxBounceDelays[6] = 12;  // M15
        m_forexMaxBounceDelays[7] = 15;  // M5
        m_forexMaxBounceDelays[8] = 20;  // M1
        
        m_initialized = true;
        
        if(m_forexDebugPrints)
            Print("Forex settings initialized with debug prints enabled");
    }
    
    //--- Forex Specific Methods
    static void InitForex(bool showDebugPrints=false)
    {
        m_forexDebugPrints = showDebugPrints;  // Set debug flag first
        Init(showDebugPrints);  // Initialize base class
        Initialize();           // Initialize Forex settings
        
        // Update pip values before setting spreads
        UpdatePipValues(_Symbol);
        
        // Set max spread based on pip value
        m_maxAllowedSpread = 20.0 * m_pipValue;  // Default max spread of 20 pips
        m_lastSpread = 0;
        m_lastSpreadUpdate = 0;
        
        if(m_forexDebugPrints)
            Print("InitForex: Symbol=", _Symbol, ", PipValue=", m_pipValue, ", Digits=", m_pipDigits);
    }
    
    static double GetTouchZone(ENUM_TIMEFRAMES timeframe)
    {
        if(!m_initialized) Initialize();
        
        // Get base touch zone in pips (unscaled)
        double touchZone = timeframe < ArraySize(m_forexTouchZones) ? 
                          m_forexTouchZones[timeframe] : 5.0;
        
        // Convert to points based on pip value
        // For JPY pairs (2-3 digits), multiply by 100 to get correct scaling
        // For other pairs (4-5 digits), multiply by 10 for standard scaling
        double touchZonePoints = touchZone * (m_pipDigits == 2 || m_pipDigits == 3 ? 100.0 : 10.0);
        
        if(m_forexDebugPrints)
            Print("Touch zone for ", _Symbol, " ", EnumToString(timeframe), ": ", 
                  touchZone, " pips = ", touchZonePoints, " points",
                  " (PipDigits=", m_pipDigits, ", PipValue=", m_pipValue, ")");
            
        return touchZonePoints * _Point;
    }
    
    static double GetBounceMinSize(ENUM_TIMEFRAMES timeframe)
    {
        if(!m_initialized) Initialize();
        
        // Get base bounce size in pips (unscaled)
        double bounceSize = timeframe < ArraySize(m_forexBounceMinSizes) ? 
                           m_forexBounceMinSizes[timeframe] : 10.0;
        
        // Convert to points based on pip value
        // For JPY pairs (2-3 digits), multiply by 100 to get correct scaling
        // For other pairs (4-5 digits), multiply by 10 for standard scaling
        double bounceSizePoints = bounceSize * (m_pipDigits == 2 || m_pipDigits == 3 ? 100.0 : 10.0);
        
        if(m_forexDebugPrints)
            Print("Bounce size for ", _Symbol, " ", EnumToString(timeframe), ": ",
                  bounceSize, " pips = ", bounceSizePoints, " points",
                  " (PipDigits=", m_pipDigits, ", PipValue=", m_pipValue, ")");
            
        return bounceSizePoints * _Point;
    }
    
    /**
     * @brief Convert a pip value to price value based on symbol digits
     */
    static double PipsToPrice(double pips)
    {
        // For JPY pairs (2-3 digits), 1 pip = 0.01
        // For other pairs (4-5 digits), 1 pip = 0.0001
        return pips * m_pipValue;
    }
    
    /**
     * @brief Convert a price value to pips based on symbol digits
     */
    static double PriceToPips(double price)
    {
        // For JPY pairs (2-3 digits), 1 pip = 0.01
        // For other pairs (4-5 digits), 1 pip = 0.0001
        return price / m_pipValue;
    }
    
    /**
     * @brief Configure forex settings with pip-based input values
     */
    static void ConfigureForex(double touchZonePips, double minBouncePips)
    {
        if(!m_initialized) Initialize();
        
        // Convert pip values to price values based on symbol digits
        double touchZonePrice = PipsToPrice(touchZonePips);
        double minBouncePrice = PipsToPrice(minBouncePips);
        
        if(m_forexDebugPrints)
            Print("Configuring Forex settings: ",
                  "TouchZone=", touchZonePips, " pips (", touchZonePrice, " price), ",
                  "MinBounce=", minBouncePips, " pips (", minBouncePrice, " price)");
        
        // Store the values in the arrays (they will be scaled appropriately in GetTouchZone/GetBounceMinSize)
        for(int i = 0; i < TIMEFRAME_COUNT; i++)
        {
            m_forexTouchZones[i] = touchZonePips;
            m_forexBounceMinSizes[i] = minBouncePips;
        }
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
        return 1.0;
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
    
    static bool FindForexKeyLevels(string symbol, SKeyLevel &outStrongestLevel)
    {
        if(m_forexDebugPrints)
            Print("Starting FindForexKeyLevels for ", symbol, " on ", EnumToString(Period()),
                  ", TouchZone=", GetTouchZone(Period()),
                  ", MinBounce=", GetBounceMinSize(Period()),
                  ", MinTouches=", GetMinTouches(Period()),
                  ", MinStrength=", GetMinStrength(Period()));
        
        // Get price data
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        
        int bars = GetLookback(Period());
        if(CopyRates(symbol, Period(), 0, bars, rates) != bars)
        {
            Print("❌ Failed to copy price data for forex level detection");
            return false;
        }
        
        if(m_forexDebugPrints)
            Print("Copied ", bars, " bars of price data for ", symbol,
                  ", First bar=", TimeToString(rates[bars-1].time),
                  ", Last bar=", TimeToString(rates[0].time));
        
        // Initialize arrays for high/low prices and volume
        double highs[], lows[];
        datetime times[];
        long volumes[];
        ArrayResize(highs, bars);
        ArrayResize(lows, bars);
        ArrayResize(times, bars);
        ArraySetAsSeries(highs, true);
        ArraySetAsSeries(lows, true);
        ArraySetAsSeries(times, true);
        
        // Get volume data for validation
        if(!GetVolumeData(symbol, volumes, bars))
        {
            Print("❌ Failed to get volume data for forex level detection");
            return false;
        }
        
        // Fill arrays
        for(int i = 0; i < bars; i++)
        {
            highs[i] = rates[i].high;
            lows[i] = rates[i].low;
            times[i] = rates[i].time;
        }
        
        if(m_forexDebugPrints)
            Print("Processing swing points for ", symbol, " with lookback=", bars);
        
        // Find potential levels
        SKeyLevel levels[];
        int levelCount = 0;
        
        // Process swing highs and lows
        for(int i = 2; i < bars - 2; i++)
        {
            // Check swing high
            if(highs[i] > highs[i-1] && highs[i] > highs[i-2] &&
               highs[i] > highs[i+1] && highs[i] > highs[i+2])
            {
                if(m_forexDebugPrints)
                    Print("Found swing high at ", TimeToString(times[i]), " price=", highs[i]);
                    
                SKeyLevel level;
                level.price = highs[i];
                level.isResistance = true;
                level.firstTouch = times[i];
                level.lastTouch = times[i];
                
                // Add volume validation
                if(IsVolumeSpike(volumes, i))
                {
                    level.volumeConfirmed = true;
                    if(m_forexDebugPrints)
                        Print("Volume confirmed at swing high");
                }
                
                if(CountTouchesEnhanced(symbol, highs, lows, times, level.price, level))
                {
                    if(m_forexDebugPrints)
                        Print("Level validated: Price=", level.price, ", Touches=", level.touchCount, 
                              ", Strength=", level.strength);
                              
                    // Add volume strength bonus if confirmed by volume
                    if(level.volumeConfirmed)
                        level.strength += GetVolumeStrengthBonus(volumes, i);
                    
                    if(level.strength >= GetMinStrength(Period()))
                    {
                        ArrayResize(levels, levelCount + 1);
                        levels[levelCount++] = level;
                    }
                }
            }
            
            // Check swing low with similar debug prints
            if(lows[i] < lows[i-1] && lows[i] < lows[i-2] &&
               lows[i] < lows[i+1] && lows[i] < lows[i+2])
            {
                if(m_forexDebugPrints)
                    Print("Found swing low at ", TimeToString(times[i]), " price=", lows[i]);
                    
                SKeyLevel level;
                level.price = lows[i];
                level.isResistance = false;
                level.firstTouch = times[i];
                level.lastTouch = times[i];
                
                if(IsVolumeSpike(volumes, i))
                {
                    level.volumeConfirmed = true;
                    if(m_forexDebugPrints)
                        Print("Volume confirmed at swing low");
                }
                
                if(CountTouchesEnhanced(symbol, highs, lows, times, level.price, level))
                {
                    if(m_forexDebugPrints)
                        Print("Level validated: Price=", level.price, ", Touches=", level.touchCount,
                              ", Strength=", level.strength);
                              
                    if(level.volumeConfirmed)
                        level.strength += GetVolumeStrengthBonus(volumes, i);
                    
                    if(level.strength >= GetMinStrength(Period()))
                    {
                        ArrayResize(levels, levelCount + 1);
                        levels[levelCount++] = level;
                    }
                }
            }
        }
        
        if(m_forexDebugPrints)
            Print("Found ", levelCount, " valid levels for ", symbol);
        
        // Find strongest level
        if(levelCount > 0)
        {
            int strongestIdx = 0;
            double maxStrength = levels[0].strength;
            
            for(int i = 1; i < levelCount; i++)
            {
                if(levels[i].strength > maxStrength)
                {
                    maxStrength = levels[i].strength;
                    strongestIdx = i;
                }
            }
            
            outStrongestLevel = levels[strongestIdx];
            
            if(m_forexDebugPrints)
                Print("Selected strongest level: Price=", outStrongestLevel.price,
                      ", Strength=", outStrongestLevel.strength,
                      ", Touches=", outStrongestLevel.touchCount,
                      ", Type=", (outStrongestLevel.isResistance ? "Resistance" : "Support"));
                      
            return true;
        }
        
        if(m_forexDebugPrints)
            Print("No valid levels found for ", symbol);
            
        return false;
    }
};

// Initialize static constant
const int CVSolForexData::TIMEFRAME_COUNT = 9;

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
bool   CVSolForexData::m_forexDebugPrints = false;

//--- Helper Method Implementations
void CVSolForexData::UpdatePipValues(string symbol)
{
    // Get symbol digits
    m_pipDigits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    // Calculate pip value based on digits
    // For JPY pairs (2-3 digits), 1 pip = 0.01
    // For other pairs (4-5 digits), 1 pip = 0.0001
    m_pipValue = (m_pipDigits == 2 || m_pipDigits == 3) ? 0.01 : 0.0001;
    
    // We no longer scale the arrays here since the scaling will be done in GetTouchZone and GetBounceMinSize
    // This prevents double-scaling for JPY pairs
    
    if(m_forexDebugPrints)
        Print("UpdatePipValues: Symbol=", symbol, 
              ", Digits=", m_pipDigits, 
              ", PipValue=", m_pipValue, 
              ", Point=", _Point, 
              ", Bid=", SymbolInfoDouble(symbol, SYMBOL_BID),
              ", TouchZone[M15]=", m_forexTouchZones[6], " pips",
              ", BounceSize[M15]=", m_forexBounceMinSizes[6], " pips",
              ", 1 pip = ", m_pipValue, " (", m_pipValue/_Point, " points)");
}

double CVSolForexData::GetForexSetting(const double &settings[], ENUM_TIMEFRAMES timeframe)
{
    int index = 6;  // Default to M15 settings (index 6)
    
    switch(timeframe) {
        case PERIOD_MN1: index = 0; break;
        case PERIOD_W1:  index = 1; break;
        case PERIOD_D1:  index = 2; break;
        case PERIOD_H4:  index = 3; break;
        case PERIOD_H1:  index = 4; break;
        case PERIOD_M30: index = 5; break;
        case PERIOD_M15: index = 6; break;
        case PERIOD_M5:  index = 7; break;
        case PERIOD_M1:  index = 8; break;
    }
    
    if(index >= ArraySize(settings))
        index = 6;  // Fallback to M15 settings if index out of range
        
    return settings[index];
}

int CVSolForexData::GetForexIntSetting(const int &settings[], ENUM_TIMEFRAMES timeframe)
{
    int index = 6;  // Default to M15 settings (index 6)
    
    switch(timeframe) {
        case PERIOD_MN1: index = 0; break;
        case PERIOD_W1:  index = 1; break;
        case PERIOD_D1:  index = 2; break;
        case PERIOD_H4:  index = 3; break;
        case PERIOD_H1:  index = 4; break;
        case PERIOD_M30: index = 5; break;
        case PERIOD_M15: index = 6; break;
        case PERIOD_M5:  index = 7; break;
        case PERIOD_M1:  index = 8; break;
    }
    
    if(index >= ArraySize(settings))
        index = 6;  // Fallback to M15 settings if index out of range
        
    return settings[index];
}

#endif // __VSOL_MARKET_FOREX_MQH__ 