//+------------------------------------------------------------------+
//|                                               V-2-EA-ForexData.mqh |
//|                 Forex-Specific Market Data Analysis Module         |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.00"
#property strict

#ifndef __V2_EA_FOREXDATA_MQH__
#define __V2_EA_FOREXDATA_MQH__

#include "V-2-EA-MarketData.mqh"

//+------------------------------------------------------------------+
//| Forex-specific market data analysis class                          |
//+------------------------------------------------------------------+
class CV2EAForexData : public CV2EAMarketDataBase
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
//| Initialize static members                                          |
//+------------------------------------------------------------------+
double CV2EAForexData::m_forexTouchZones[] = {
    50.0,   // PERIOD_MN1  (5.0 pips)
    30.0,   // PERIOD_W1   (3.0 pips)
    20.0,   // PERIOD_D1   (2.0 pips)
    15.0,   // PERIOD_H4   (1.5 pips)
    10.0,   // PERIOD_H1   (1.0 pips)
    7.5,    // PERIOD_M30  (0.75 pips)
    5.0,    // PERIOD_M15  (0.5 pips)
    3.0,    // PERIOD_M5   (0.3 pips)
    2.0     // PERIOD_M1   (0.2 pips)
};

double CV2EAForexData::m_forexBounceMinSizes[] = {
    100.0,  // PERIOD_MN1  (10.0 pips)
    70.0,   // PERIOD_W1   (7.0 pips)
    50.0,   // PERIOD_D1   (5.0 pips)
    30.0,   // PERIOD_H4   (3.0 pips)
    20.0,   // PERIOD_H1   (2.0 pips)
    15.0,   // PERIOD_M30  (1.5 pips)
    10.0,   // PERIOD_M15  (1.0 pips)
    7.5,    // PERIOD_M5   (0.75 pips)
    5.0     // PERIOD_M1   (0.5 pips)
};

int CV2EAForexData::m_forexMinTouches[] = {
    2,      // PERIOD_MN1
    2,      // PERIOD_W1
    2,      // PERIOD_D1
    3,      // PERIOD_H4
    3,      // PERIOD_H1
    3,      // PERIOD_M30
    4,      // PERIOD_M15
    4,      // PERIOD_M5
    5       // PERIOD_M1
};

double CV2EAForexData::m_forexMinStrengths[] = {
    0.50,   // PERIOD_MN1
    0.50,   // PERIOD_W1
    0.55,   // PERIOD_D1
    0.60,   // PERIOD_H4
    0.65,   // PERIOD_H1
    0.70,   // PERIOD_M30
    0.75,   // PERIOD_M15
    0.80,   // PERIOD_M5
    0.85    // PERIOD_M1
};

int CV2EAForexData::m_forexLookbacks[] = {
    36,     // PERIOD_MN1 (3 years)
    52,     // PERIOD_W1  (1 year)
    90,     // PERIOD_D1  (3 months)
    180,    // PERIOD_H4  (30 days)
    120,    // PERIOD_H1  (5 days)
    240,    // PERIOD_M30 (5 days)
    480,    // PERIOD_M15 (5 days)
    720,    // PERIOD_M5  (2.5 days)
    1440    // PERIOD_M1  (1 day)
};

int CV2EAForexData::m_forexMaxBounceDelays[] = {
    8,      // PERIOD_MN1
    7,      // PERIOD_W1
    6,      // PERIOD_D1
    6,      // PERIOD_H4
    5,      // PERIOD_H1
    5,      // PERIOD_M30
    4,      // PERIOD_M15
    4,      // PERIOD_M5
    3       // PERIOD_M1
};

double   CV2EAForexData::m_pipValue = 0;
int      CV2EAForexData::m_pipDigits = 0;
double   CV2EAForexData::m_lastSpread = 0;
datetime CV2EAForexData::m_lastSpreadUpdate = 0;
double   CV2EAForexData::m_maxAllowedSpread = 20.0;

//+------------------------------------------------------------------+
//| Initialize Forex specific settings                                 |
//+------------------------------------------------------------------+
void CV2EAForexData::InitializeForexSettings()
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
double CV2EAForexData::GetForexSetting(const double &settings[], ENUM_TIMEFRAMES timeframe)
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
int CV2EAForexData::GetForexIntSetting(const int &settings[], ENUM_TIMEFRAMES timeframe)
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
double CV2EAForexData::GetForexTouchZone(ENUM_TIMEFRAMES timeframe)
{
    return GetForexSetting(m_forexTouchZones, timeframe);
}

int CV2EAForexData::GetForexMinTouches(ENUM_TIMEFRAMES timeframe)
{
    return GetForexIntSetting(m_forexMinTouches, timeframe);
}

double CV2EAForexData::GetForexMinStrength(ENUM_TIMEFRAMES timeframe)
{
    return GetForexSetting(m_forexMinStrengths, timeframe);
}

int CV2EAForexData::GetForexLookback(ENUM_TIMEFRAMES timeframe)
{
    return GetForexIntSetting(m_forexLookbacks, timeframe);
}

int CV2EAForexData::GetForexMaxBounceDelay(ENUM_TIMEFRAMES timeframe)
{
    return GetForexIntSetting(m_forexMaxBounceDelays, timeframe);
}

//+------------------------------------------------------------------+
//| Update pip values for the current symbol                          |
//+------------------------------------------------------------------+
void CV2EAForexData::UpdatePipValues(string symbol)
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
double CV2EAForexData::PipsToPrice(double pips)
{
    if(m_pipValue == 0)
        UpdatePipValues(_Symbol);
        
    return pips * m_pipValue;
}

//+------------------------------------------------------------------+
//| Convert price to pips for the current symbol                      |
//+------------------------------------------------------------------+
double CV2EAForexData::PriceToPips(double price)
{
    if(m_pipValue == 0)
        UpdatePipValues(_Symbol);
        
    return price / m_pipValue;
}

//+------------------------------------------------------------------+
//| Get current spread and validate against maximum allowed           |
//+------------------------------------------------------------------+
double CV2EAForexData::GetCurrentSpread(string symbol)
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
bool CV2EAForexData::IsSpreadAcceptable(string symbol)
{
    return GetCurrentSpread(symbol) <= m_maxAllowedSpread;
}

//+------------------------------------------------------------------+
//| Validate if price is a valid touch for Forex                      |
//+------------------------------------------------------------------+
bool CV2EAForexData::ValidateForexTouch(const double price, const double level, ENUM_TIMEFRAMES timeframe)
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
double CV2EAForexData::CalculateForexStrength(const SKeyLevel &level, const STouch &touches[])
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
bool CV2EAForexData::FindForexKeyLevels(string symbol, SKeyLevel &outStrongestLevel)
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

#endif // __V2_EA_FOREXDATA_MQH__ 