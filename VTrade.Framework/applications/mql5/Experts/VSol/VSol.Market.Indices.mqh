//+------------------------------------------------------------------+
//|                                           VSol.Market.Indices.mqh |
//|                        US500-Specific Configuration Parameters    |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.01"
#property strict

#ifndef __VSOL_MARKET_INDICES_MQH__
#define __VSOL_MARKET_INDICES_MQH__

#include "VSol.Market.mqh"

//+------------------------------------------------------------------+
//| US500-specific market data analysis class                          |
//+------------------------------------------------------------------+
class CVSolIndicesData : public CVSolMarketBase
{
private:
    //--- US500 Specific Settings
    static double m_us500TouchZones[];      // Touch zones in points per timeframe
    static double m_us500BounceMinSizes[];  // Minimum bounce sizes
    static int    m_us500MinTouches[];      // Minimum number of touches
    static double m_us500MinStrengths[];    // Minimum acceptable strength
    static int    m_us500Lookbacks[];       // Lookback periods
    static int    m_us500MaxBounceDelays[]; // Maximum allowed bounce delays
    
    static bool   m_initialized;            // Initialization state
    
    //--- Helper Methods
    static double GetIndicesSetting(const double &settings[], ENUM_TIMEFRAMES timeframe)
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
    
    static int GetIndicesIntSetting(const int &settings[], ENUM_TIMEFRAMES timeframe)
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
    
    static double CalculateIndicesStrength(const SKeyLevel &level, const STouch &touches[])
    {
        ENUM_TIMEFRAMES tf = Period();
        
        // Base strength from touch count
        double touchBase = 0;
        switch(level.touchCount) {
            case 2: touchBase = 0.55; break;  // Higher base for indices
            case 3: touchBase = 0.70; break;
            case 4: touchBase = 0.80; break;
            case 5: touchBase = 0.90; break;
            default: touchBase = MathMin(0.95 + ((level.touchCount - 6) * 0.01), 0.98);
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
        
        if(barsElapsed <= GetLookback(tf) / 8)
            recencyMod = 0.20;  // Very recent
        else if(barsElapsed <= GetLookback(tf) / 4)
            recencyMod = 0.10;  // Recent
        else if(barsElapsed <= GetLookback(tf) / 2)
            recencyMod = 0;     // Neutral
        else
            recencyMod = -0.30; // Old
            
        // Calculate final strength with market hours factor
        double marketHoursMod = GetMarketHoursFactor() - 1.0;  // Convert to modifier
        double strength = touchBase * (1.0 + avgBounceStrength * 0.2 + recencyMod + marketHoursMod);
        
        // Ensure bounds
        return MathMin(MathMax(strength, 0.50), 0.98);  // Higher minimum for indices
    }
    
    static bool ValidateIndicesLevel(const double price, const double level, ENUM_TIMEFRAMES timeframe)
    {
        // Get touch zone in points
        double touchZone = GetTouchZone(timeframe);
        
        // Add market hours factor for more conservative validation during off-hours
        double marketHoursFactor = GetMarketHoursFactor();
        if(marketHoursFactor < 1.0)
            touchZone *= (2.0 - marketHoursFactor);  // Increase zone size in off-hours
            
        return IsTouchValid(price, level, touchZone);
    }
    
public:
    //--- Initialization
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
    
    //--- Indices Specific Methods
    static void InitIndices(bool showDebugPrints=false)
    {
        Init(showDebugPrints);  // Initialize base class
        Initialize();           // Initialize Indices settings
        
        // Configure base class with indices-specific settings
        ENUM_TIMEFRAMES tf = Period();
        ConfigureLevelDetection(
            GetLookback(tf),           // Lookback period
            GetMinStrength(tf),        // Minimum strength
            GetTouchZone(tf),          // Touch zone
            GetMinTouches(tf),         // Minimum touches
            0.5,                       // Touch score weight
            0.3,                       // Recency weight
            0.2,                       // Duration weight
            12                         // Minimum duration hours
        );
        
        // Configure volume analysis with higher threshold for indices
        ConfigureVolumeAnalysis(2.0, VOLUME_TICK);  // Require 2.0x average volume
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
        int hourET = CVSolUtils::GetCurrentHourET();
        
        // Regular market hours (9:30 AM - 4:00 PM ET)
        if(CVSolUtils::IsWithinSession(hourET, 9, 16))
            return 1.0;
            
        // Pre-market (4:00 AM - 9:30 AM ET)
        if(CVSolUtils::IsWithinSession(hourET, 4, 9))
            return 0.7;
            
        // After-hours (4:00 PM - 8:00 PM ET)
        if(CVSolUtils::IsWithinSession(hourET, 16, 20))
            return 0.7;
            
        // Overnight
        return 0.5;
    }
    
    static bool FindIndicesKeyLevels(string symbol, SKeyLevel &outStrongestLevel)
    {
        // Get price data
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        
        int bars = GetLookback(Period());
        if(CopyRates(symbol, Period(), 0, bars, rates) != bars)
        {
            Print("❌ Failed to copy price data for indices level detection");
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
            Print("❌ Failed to get volume data for indices level detection");
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
                    
                    if(level.strength >= GetMinStrength(Period()))
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
                    
                    if(level.strength >= GetMinStrength(Period()))
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
    
    /**
     * @brief Override base class strength calculation for Indices.
     */
    double CalculateStrength(const SKeyLevel &level, const STouch &touches[]) override
    {
        return CalculateIndicesStrength(level, touches);
    }
    
    /**
     * @brief Override base class level validation for Indices.
     */
    bool ValidateLevel(const double price, const double level, ENUM_TIMEFRAMES timeframe) override
    {
        return ValidateIndicesLevel(price, level, timeframe);
    }
    
    /**
     * @brief Override base class key level detection for Indices.
     */
    bool FindKeyLevels(string symbol, SKeyLevel &outStrongestLevel) override
    {
        return FindIndicesKeyLevels(symbol, outStrongestLevel);
    }
    
    /**
     * @brief Override base class session factor for Indices.
     */
    double GetSessionFactor() override
    {
        return GetMarketHoursFactor();
    }
};

// Initialize static members
double CVSolIndicesData::m_us500TouchZones[];
double CVSolIndicesData::m_us500BounceMinSizes[];
int    CVSolIndicesData::m_us500MinTouches[];
double CVSolIndicesData::m_us500MinStrengths[];
int    CVSolIndicesData::m_us500Lookbacks[];
int    CVSolIndicesData::m_us500MaxBounceDelays[];
bool   CVSolIndicesData::m_initialized = false;

#endif // __VSOL_MARKET_INDICES_MQH__ 