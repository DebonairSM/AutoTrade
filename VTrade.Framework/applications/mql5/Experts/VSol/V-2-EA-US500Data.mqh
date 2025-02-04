//+------------------------------------------------------------------+
//|                                              V-2-EA-US500Data.mqh |
//|                        US500-Specific Market Data Analysis Module |
//+------------------------------------------------------------------+
#property copyright "Your Company Name"
#property link      "https://www.yourwebsite.com"
#property version   "1.01"
#property description "US500-specific market data analysis module"

#include "V-2-EA-MarketData.mqh"

//+------------------------------------------------------------------+
//| US500-Specific Market Data Analysis Class                          |
//+------------------------------------------------------------------+
class CV2EAUS500Data : public CV2EAMarketData
{
private:
    //--- US500 Specific Settings
    static double   m_us500TouchZones[];      // Touch zones by timeframe
    static double   m_us500BounceMinSizes[];  // Minimum bounce sizes by timeframe
    static int      m_us500MinTouches[];      // Minimum touches by timeframe
    static double   m_us500MinStrengths[];    // Minimum strengths by timeframe
    static int      m_us500Lookbacks[];       // Lookback periods by timeframe
    static int      m_us500MaxBounceDelays[]; // Maximum bounce delays by timeframe
    
    //--- US500 Market State
    static double   m_lastATR;                // Last calculated ATR value
    static datetime m_lastATRUpdate;          // Last ATR update time
    static int      m_atrPeriod;             // ATR calculation period
    
    //--- Helper Methods
    static void InitializeUS500Settings();
    static double GetUS500Setting(const double &settings[], ENUM_TIMEFRAMES timeframe);
    static int GetUS500IntSetting(const int &settings[], ENUM_TIMEFRAMES timeframe);
    static double CalculateUS500Strength(const SKeyLevel &level, const STouch &touches[]);
    static bool ValidateUS500Touch(const double price, const double level, ENUM_TIMEFRAMES timeframe);
    static double GetUS500ATR(string symbol, ENUM_TIMEFRAMES timeframe, int period=14);

public:
    //--- Initialization
    static void InitUS500(bool showDebugPrints=false)
    {
        Init(showDebugPrints);  // Initialize base class
        InitializeUS500Settings();
        m_atrPeriod = 14;
        m_lastATR = 0;
        m_lastATRUpdate = 0;
    }
    
    //--- US500 Specific Methods
    static bool FindUS500KeyLevels(string symbol, SKeyLevel &outStrongestLevel);
    static bool IsUS500Touch(const double price, const double level, ENUM_TIMEFRAMES timeframe);
    static double GetUS500TouchZone(ENUM_TIMEFRAMES timeframe);
    static int GetUS500MinTouches(ENUM_TIMEFRAMES timeframe);
    static double GetUS500MinStrength(ENUM_TIMEFRAMES timeframe);
    static int GetUS500Lookback(ENUM_TIMEFRAMES timeframe);
    static int GetUS500MaxBounceDelay(ENUM_TIMEFRAMES timeframe);
};

//+------------------------------------------------------------------+
//| Initialize static members                                          |
//+------------------------------------------------------------------+
double CV2EAUS500Data::m_us500TouchZones[] = {
    50.0,   // PERIOD_MN1
    30.0,   // PERIOD_W1
    20.0,   // PERIOD_D1
    15.0,   // PERIOD_H4
    10.0,   // PERIOD_H1
    7.5,    // PERIOD_M30
    5.0,    // PERIOD_M15
    3.0,    // PERIOD_M5
    2.0     // PERIOD_M1
};

double CV2EAUS500Data::m_us500BounceMinSizes[] = {
    70.0,   // PERIOD_MN1
    40.0,   // PERIOD_W1
    30.0,   // PERIOD_D1
    20.0,   // PERIOD_H4
    15.0,   // PERIOD_H1
    10.0,   // PERIOD_M30
    7.5,    // PERIOD_M15
    5.0,    // PERIOD_M5
    3.0     // PERIOD_M1
};

int CV2EAUS500Data::m_us500MinTouches[] = {
    2,      // PERIOD_MN1
    2,      // PERIOD_W1
    2,      // PERIOD_D1
    3,      // PERIOD_H4
    3,      // PERIOD_H1
    3,      // PERIOD_M30
    3,      // PERIOD_M15
    4,      // PERIOD_M5
    4       // PERIOD_M1
};

double CV2EAUS500Data::m_us500MinStrengths[] = {
    0.50,   // PERIOD_MN1
    0.50,   // PERIOD_W1
    0.55,   // PERIOD_D1
    0.60,   // PERIOD_H4
    0.65,   // PERIOD_H1
    0.70,   // PERIOD_M30
    0.70,   // PERIOD_M15
    0.75,   // PERIOD_M5
    0.80    // PERIOD_M1
};

int CV2EAUS500Data::m_us500Lookbacks[] = {
    36,     // PERIOD_MN1 (3 years)
    52,     // PERIOD_W1 (1 year)
    90,     // PERIOD_D1 (3 months)
    180,    // PERIOD_H4 (30 days)
    120,    // PERIOD_H1 (5 days)
    240,    // PERIOD_M30 (5 days)
    480,    // PERIOD_M15 (5 days)
    720,    // PERIOD_M5 (2.5 days)
    1440    // PERIOD_M1 (1 day)
};

int CV2EAUS500Data::m_us500MaxBounceDelays[] = {
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

//+------------------------------------------------------------------+
//| Initialize US500 specific settings                                 |
//+------------------------------------------------------------------+
void CV2EAUS500Data::InitializeUS500Settings()
{
    // Current timeframe settings
    ENUM_TIMEFRAMES tf = Period();
    
    // Configure base class with US500 specific settings
    ConfigureLevelDetection(
        GetUS500Lookback(tf),           // Lookback period
        GetUS500MinStrength(tf),        // Minimum strength
        GetUS500TouchZone(tf),          // Touch zone
        GetUS500MinTouches(tf),         // Minimum touches
        0.5,                            // Touch score weight
        0.3,                            // Recency weight
        0.2,                            // Duration weight
        12                              // Minimum duration hours
    );
    
    // Configure volume analysis
    ConfigureVolumeAnalysis(1.5, VOLUME_TICK);  // Require 1.5x average volume
}

//+------------------------------------------------------------------+
//| Get US500 setting based on timeframe                              |
//+------------------------------------------------------------------+
double CV2EAUS500Data::GetUS500Setting(const double &settings[], ENUM_TIMEFRAMES timeframe)
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
//| Get US500 integer setting based on timeframe                       |
//+------------------------------------------------------------------+
int CV2EAUS500Data::GetUS500IntSetting(const int &settings[], ENUM_TIMEFRAMES timeframe)
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
//| Public getter methods for US500 settings                           |
//+------------------------------------------------------------------+
double CV2EAUS500Data::GetUS500TouchZone(ENUM_TIMEFRAMES timeframe)
{
    return GetUS500Setting(m_us500TouchZones, timeframe);
}

int CV2EAUS500Data::GetUS500MinTouches(ENUM_TIMEFRAMES timeframe)
{
    return GetUS500IntSetting(m_us500MinTouches, timeframe);
}

double CV2EAUS500Data::GetUS500MinStrength(ENUM_TIMEFRAMES timeframe)
{
    return GetUS500Setting(m_us500MinStrengths, timeframe);
}

int CV2EAUS500Data::GetUS500Lookback(ENUM_TIMEFRAMES timeframe)
{
    return GetUS500IntSetting(m_us500Lookbacks, timeframe);
}

int CV2EAUS500Data::GetUS500MaxBounceDelay(ENUM_TIMEFRAMES timeframe)
{
    return GetUS500IntSetting(m_us500MaxBounceDelays, timeframe);
}

//+------------------------------------------------------------------+
//| Calculate US500-specific ATR                                       |
//+------------------------------------------------------------------+
double CV2EAUS500Data::GetUS500ATR(string symbol, ENUM_TIMEFRAMES timeframe, int period=14)
{
    datetime current_time = TimeCurrent();
    
    // Return cached value if recent enough
    if(current_time - m_lastATRUpdate < PeriodSeconds(timeframe) && m_lastATR > 0)
        return m_lastATR;
    
    // Calculate new ATR
    double atr = iATR(symbol, timeframe, period, 0);
    if(atr > 0)
    {
        m_lastATR = atr;
        m_lastATRUpdate = current_time;
    }
    
    return atr;
}

//+------------------------------------------------------------------+
//| Validate if price is a valid touch for US500                       |
//+------------------------------------------------------------------+
bool CV2EAUS500Data::ValidateUS500Touch(const double price, const double level, ENUM_TIMEFRAMES timeframe)
{
    double touchZone = GetUS500TouchZone(timeframe);
    double atr = GetUS500ATR(_Symbol, timeframe);
    
    // Adjust touch zone based on current volatility
    if(atr > 0)
        touchZone = MathMax(touchZone, atr * 0.1);  // Use at least 10% of ATR
        
    return MathAbs(price - level) <= touchZone;
}

//+------------------------------------------------------------------+
//| Calculate strength for US500 level                                 |
//+------------------------------------------------------------------+
double CV2EAUS500Data::CalculateUS500Strength(const SKeyLevel &level, const STouch &touches[])
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
    
    if(barsElapsed <= GetUS500Lookback(tf) / 8)
        recencyMod = 0.20;  // Very recent
    else if(barsElapsed <= GetUS500Lookback(tf) / 4)
        recencyMod = 0.10;  // Recent
    else if(barsElapsed <= GetUS500Lookback(tf) / 2)
        recencyMod = 0;     // Neutral
    else
        recencyMod = -0.30; // Old
        
    // Calculate final strength
    double strength = touchBase * (1.0 + avgBounceStrength * 0.2 + recencyMod);
    
    // Ensure bounds
    return MathMin(MathMax(strength, 0.45), 0.98);
}

//+------------------------------------------------------------------+
//| Find key levels specific to US500                                  |
//+------------------------------------------------------------------+
bool CV2EAUS500Data::FindUS500KeyLevels(string symbol, SKeyLevel &outStrongestLevel)
{
    ENUM_TIMEFRAMES tf = Period();
    
    // Get price data
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    
    int bars = GetUS500Lookback(tf);
    if(CopyRates(symbol, tf, 0, bars, rates) != bars)
    {
        Print("❌ Failed to copy price data for US500 level detection");
        return false;
    }
    
    // Initialize arrays for high/low prices
    double highs[], lows[];
    datetime times[];
    ArrayResize(highs, bars);
    ArrayResize(lows, bars);
    ArrayResize(times, bars);
    ArraySetAsSeries(highs, true);
    ArraySetAsSeries(lows, true);
    ArraySetAsSeries(times, true);
    
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
            
            if(CountTouchesEnhanced(symbol, highs, lows, times, level.price, level))
            {
                if(level.strength >= GetUS500MinStrength(tf))
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
            
            if(CountTouchesEnhanced(symbol, highs, lows, times, level.price, level))
            {
                if(level.strength >= GetUS500MinStrength(tf))
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