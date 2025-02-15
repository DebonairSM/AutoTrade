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
//| Forex Configuration Class                                          |
//+------------------------------------------------------------------+
class CVSolForexData
{
private:
    static double m_forexTouchZones[];      // Touch zones in pips per timeframe
    static double m_forexBounceMinSizes[];  // Minimum bounce sizes
    static int    m_forexMinTouches[];      // Minimum number of touches
    static double m_forexMinStrengths[];    // Minimum acceptable strength
    static int    m_forexLookbacks[];       // Lookback periods
    static int    m_forexMaxBounceDelays[]; // Maximum allowed bounce delays
    
    static bool   m_initialized;            // Initialization state
    
public:
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
};

// Initialize static members
double CVSolForexData::m_forexTouchZones[];
double CVSolForexData::m_forexBounceMinSizes[];
int    CVSolForexData::m_forexMinTouches[];
double CVSolForexData::m_forexMinStrengths[];
int    CVSolForexData::m_forexLookbacks[];
int    CVSolForexData::m_forexMaxBounceDelays[];
bool   CVSolForexData::m_initialized = false;

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
    static void InitForex(bool showDebugPrints=false)
    {
        Init(showDebugPrints);  // Initialize base class
        InitializeForexSettings();
        m_maxAllowedSpread = 20.0;  // Default max spread of 2.0 pips
        m_lastSpread = 0;
        m_lastSpreadUpdate = 0;
        m_pipValue = 0;
        m_pipDigits = 0;
    }
    
    //--- Forex Specific Methods
    static bool FindForexKeyLevels(string symbol, SKeyLevel &outStrongestLevel);
    static bool IsForexTouch(const double price, const double level, ENUM_TIMEFRAMES timeframe);
    static double GetForexTouchZone(ENUM_TIMEFRAMES timeframe);
    static int GetForexMinTouches(ENUM_TIMEFRAMES timeframe);
    static double GetForexMinStrength(ENUM_TIMEFRAMES timeframe);
    static int GetForexLookback(ENUM_TIMEFRAMES timeframe);
    static int GetForexMaxBounceDelay(ENUM_TIMEFRAMES timeframe);
    static double PipsToPrice(double pips);
    static double PriceToPips(double price);
    static bool IsSpreadAcceptable(string symbol);
};

//+------------------------------------------------------------------+
//| Initialize Forex specific settings                                 |
//+------------------------------------------------------------------+
void CVSolForexData::InitializeForexSettings()
{
    // Current timeframe settings
    ENUM_TIMEFRAMES tf = Period();
    
    // Configure base class with Forex specific settings
    ConfigureLevelDetection(
        GetForexLookback(tf),           // Lookback period
        GetForexMinStrength(tf),        // Minimum strength
        GetForexTouchZone(tf),          // Touch zone
        GetForexMinTouches(tf),         // Minimum touches
        0.5,                            // Touch score weight
        0.3,                            // Recency weight
        0.2,                            // Duration weight
        12                              // Minimum duration hours
    );
    
    // Configure volume analysis
    ConfigureVolumeAnalysis(1.5, VOLUME_TICK);  // Require 1.5x average volume
}

//+------------------------------------------------------------------+
//| Get Forex setting based on timeframe                              |
//+------------------------------------------------------------------+
double CVSolForexData::GetForexSetting(const double &settings[], ENUM_TIMEFRAMES timeframe)
{
    int index = 0;
    
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
        default: return settings[6];  // Default to M15 settings
    }
    
    return settings[index];
}

//+------------------------------------------------------------------+
//| Get Forex integer setting based on timeframe                       |
//+------------------------------------------------------------------+
int CVSolForexData::GetForexIntSetting(const int &settings[], ENUM_TIMEFRAMES timeframe)
{
    int index = 0;
    
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
        default: return settings[6];  // Default to M15 settings
    }
    
    return settings[index];
}

//+------------------------------------------------------------------+
//| Public getter methods for Forex settings                           |
//+------------------------------------------------------------------+
double CVSolForexData::GetForexTouchZone(ENUM_TIMEFRAMES timeframe)
{
    return GetForexSetting(m_forexTouchZones, timeframe);
}

int CVSolForexData::GetForexMinTouches(ENUM_TIMEFRAMES timeframe)
{
    return GetForexIntSetting(m_forexMinTouches, timeframe);
}

double CVSolForexData::GetForexMinStrength(ENUM_TIMEFRAMES timeframe)
{
    return GetForexSetting(m_forexMinStrengths, timeframe);
}

int CVSolForexData::GetForexLookback(ENUM_TIMEFRAMES timeframe)
{
    return GetForexIntSetting(m_forexLookbacks, timeframe);
}

int CVSolForexData::GetForexMaxBounceDelay(ENUM_TIMEFRAMES timeframe)
{
    return GetForexIntSetting(m_forexMaxBounceDelays, timeframe);
}

//+------------------------------------------------------------------+
//| Update pip values for the current symbol                          |
//+------------------------------------------------------------------+
void CVSolForexData::UpdatePipValues(string symbol)
{
    // Get symbol digits and calculate pip position
    m_pipDigits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    // For Forex pairs, usually:
    // 5 digits = 0.0001 point value (4 digit broker)
    // 3 digits = 0.01 point value (2 digit broker)
    if(m_pipDigits == 5 || m_pipDigits == 3)
        m_pipDigits--;
        
    m_pipValue = MathPow(10, -m_pipDigits);
}

//+------------------------------------------------------------------+
//| Convert pips to price for the current symbol                      |
//+------------------------------------------------------------------+
double CVSolForexData::PipsToPrice(double pips)
{
    if(m_pipValue == 0)
        UpdatePipValues(_Symbol);
        
    return pips * m_pipValue;
}

//+------------------------------------------------------------------+
//| Convert price to pips for the current symbol                      |
//+------------------------------------------------------------------+
double CVSolForexData::PriceToPips(double price)
{
    if(m_pipValue == 0)
        UpdatePipValues(_Symbol);
        
    return price / m_pipValue;
}

//+------------------------------------------------------------------+
//| Get current spread and validate against maximum allowed           |
//+------------------------------------------------------------------+
double CVSolForexData::GetCurrentSpread(string symbol)
{
    datetime current_time = TimeCurrent();
    
    // Return cached value if recent enough
    if(current_time - m_lastSpreadUpdate < PeriodSeconds(PERIOD_M1) && m_lastSpread > 0)
        return m_lastSpread;
        
    // Calculate new spread in pips
    double spread = PriceToPips(SymbolInfoDouble(symbol, SYMBOL_ASK) - 
                               SymbolInfoDouble(symbol, SYMBOL_BID));
                               
    if(spread > 0)
    {
        m_lastSpread = spread;
        m_lastSpreadUpdate = current_time;
    }
    
    return spread;
}

//+------------------------------------------------------------------+
//| Check if current spread is acceptable                             |
//+------------------------------------------------------------------+
bool CVSolForexData::IsSpreadAcceptable(string symbol)
{
    return GetCurrentSpread(symbol) <= m_maxAllowedSpread;
}

//+------------------------------------------------------------------+
//| Validate if price is a valid touch for Forex                      |
//+------------------------------------------------------------------+
bool CVSolForexData::ValidateForexTouch(const double price, const double level, ENUM_TIMEFRAMES timeframe)
{
    // Convert touch zone from pips to price
    double touchZone = PipsToPrice(GetForexTouchZone(timeframe));
    
    // Add spread to touch zone for more conservative validation
    if(m_lastSpread > 0)
        touchZone += PipsToPrice(m_lastSpread);
        
    return IsTouchValid(price, level, touchZone);
}

//+------------------------------------------------------------------+
//| Calculate strength for Forex level                                |
//+------------------------------------------------------------------+
double CVSolForexData::CalculateForexStrength(const SKeyLevel &level, const STouch &touches[])
{
    ENUM_TIMEFRAMES tf = Period();
    
    // Base strength from touch count
    double touchBase = 0;
    switch(level.touchCount) {
        case 2: touchBase = 0.50; break;
        case 3: touchBase = 0.65; break;
        case 4: touchBase = 0.75; break;
        case 5: touchBase = 0.85; break;
        default: touchBase = MathMin(0.90 + ((level.touchCount - 6) * 0.01), 0.95);
    }
    
    // Calculate average bounce strength
    double totalBounceStrength = 0;
    double bounceCount = 0;
    
    for(int i = 0; i < ArraySize(touches); i++)
    {
        if(touches[i].isValid)
        {
            totalBounceStrength += touches[i].strength;
            bounceCount++;
        }
    }
    
    double avgBounceStrength = (bounceCount > 0) ? totalBounceStrength / bounceCount : 0;
    
    // Time-based decay
    double recencyMod = 0;
    int barsElapsed = (int)((TimeCurrent() - level.lastTouch) / PeriodSeconds(tf));
    
    if(barsElapsed <= GetForexLookback(tf) / 8)
        recencyMod = 0.20;  // Very recent
    else if(barsElapsed <= GetForexLookback(tf) / 4)
        recencyMod = 0.10;  // Recent
    else if(barsElapsed <= GetForexLookback(tf) / 2)
        recencyMod = 0;     // Neutral
    else
        recencyMod = -0.30; // Old
        
    // Calculate final strength
    double strength = touchBase * (1.0 + avgBounceStrength * 0.2 + recencyMod);
    
    // Ensure bounds
    return MathMin(MathMax(strength, 0.45), 0.98);
}

//+------------------------------------------------------------------+
//| Find key levels specific to Forex                                 |
//+------------------------------------------------------------------+
bool CVSolForexData::FindForexKeyLevels(string symbol, SKeyLevel &outStrongestLevel)
{
    // Update pip values for the symbol
    UpdatePipValues(symbol);
    
    // Check spread
    if(!IsSpreadAcceptable(symbol))
    {
        if(m_showDebugPrints)
            Print("❌ Spread too high for Forex level detection: ", m_lastSpread, " pips");
        return false;
    }
    
    // Get price data
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    
    int bars = GetForexLookback(Period());
    if(CopyRates(symbol, Period(), 0, bars, rates) != bars)
    {
        Print("❌ Failed to copy price data for Forex level detection");
        return false;
    }
    
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
        Print("❌ Failed to get volume data for Forex level detection");
        return false;
    }
    
    // Fill arrays
    for(int i = 0; i < bars; i++)
    {
        highs[i] = rates[i].high;
        lows[i] = rates[i].low;
        times[i] = rates[i].time;
    }
    
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
            SKeyLevel level;
            level.price = highs[i];
            level.isResistance = true;
            level.firstTouch = times[i];
            level.lastTouch = times[i];
            
            // Add volume validation
            if(IsVolumeSpike(volumes, i))
                level.volumeConfirmed = true;
            
            if(CountTouchesEnhanced(symbol, highs, lows, times, level.price, level))
            {
                // Add volume strength bonus if confirmed by volume
                if(level.volumeConfirmed)
                    level.strength += GetVolumeStrengthBonus(volumes, i);
                
                if(level.strength >= GetForexMinStrength(Period()))
                {
                    ArrayResize(levels, levelCount + 1);
                    levels[levelCount++] = level;
                }
            }
        }
        
        // Check swing low
        if(lows[i] < lows[i-1] && lows[i] < lows[i-2] &&
           lows[i] < lows[i+1] && lows[i] < lows[i+2])
        {
            SKeyLevel level;
            level.price = lows[i];
            level.isResistance = false;
            level.firstTouch = times[i];
            level.lastTouch = times[i];
            
            // Add volume validation
            if(IsVolumeSpike(volumes, i))
                level.volumeConfirmed = true;
            
            if(CountTouchesEnhanced(symbol, highs, lows, times, level.price, level))
            {
                // Add volume strength bonus if confirmed by volume
                if(level.volumeConfirmed)
                    level.strength += GetVolumeStrengthBonus(volumes, i);
                
                if(level.strength >= GetForexMinStrength(Period()))
                {
                    ArrayResize(levels, levelCount + 1);
                    levels[levelCount++] = level;
                }
            }
        }
    }
    
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
        return true;
    }
    
    return false;
}

#endif // __VSOL_MARKET_FOREX_MQH__ 