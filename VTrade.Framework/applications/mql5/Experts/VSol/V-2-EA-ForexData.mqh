//+------------------------------------------------------------------+
//|                                           V-2-EA-ForexData.mqh   |
//|                   Forex-Specific Configuration Parameters        |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.00"
#property strict

#ifndef __V2_EA_FOREXDATA_MQH__
#define __V2_EA_FOREXDATA_MQH__

#include "V-2-EA-MarketData.mqh"
#include "V-2-EA-Utils.mqh"

//+------------------------------------------------------------------+
//| Forex Configuration Class                                        |
//+------------------------------------------------------------------+
class CV2EAForexData : public CV2EAMarketDataBase
{
private:
    static double m_forexTouchZones[];
    static double m_forexBounceMinSizes[];
    static int    m_forexMinTouches[];
    static double m_forexMinStrengths[];
    static int    m_forexLookbacks[];
    static int    m_forexMaxBounceDelays[];
    static double m_maxAllowedSpread;
    static double m_lastSpread;
    static datetime m_lastSpreadUpdate;
    static double m_pipValue;
    static int    m_pipDigits;
    static bool   m_initialized;

public:
    //--- Reset static variables for deterministic behavior
    static void Reset()
    {
        m_initialized = false;  // Force reinitialization
        m_lastSpread = 0;
        m_lastSpreadUpdate = 0;
        m_pipValue = 0;
        m_pipDigits = 0;
        m_maxAllowedSpread = 0;
        
        // Clear all arrays to force reinitialization
        ArrayFree(m_forexTouchZones);
        ArrayFree(m_forexBounceMinSizes);
        ArrayFree(m_forexMinTouches);
        ArrayFree(m_forexMinStrengths);
        ArrayFree(m_forexLookbacks);
        ArrayFree(m_forexMaxBounceDelays);
    }

    static int GetTimeframeIndex(ENUM_TIMEFRAMES tf)
    {
        switch(tf) {
            case PERIOD_MN1: return 0;
            case PERIOD_W1:  return 1;
            case PERIOD_D1:  return 2;
            case PERIOD_H4:  return 3;
            case PERIOD_H1:  return 4;
            case PERIOD_M30: return 5;
            case PERIOD_M15: return 6;
            case PERIOD_M5:  return 7;
            case PERIOD_M1:  return 8;
            default:         return -1;
        }
    }

public:
    //--- Initialization ---
    static void Initialize()
    {
        if(m_initialized) return;
        
        // Initialize arrays with proper indices
        ArrayResize(m_forexTouchZones, 9);
        ArrayResize(m_forexBounceMinSizes, 9);
        ArrayResize(m_forexMinTouches, 9);
        ArrayResize(m_forexMinStrengths, 9);
        ArrayResize(m_forexLookbacks, 9);
        ArrayResize(m_forexMaxBounceDelays, 9);

        // Use GetTimeframeIndex() for proper array indexing
        m_forexTouchZones[GetTimeframeIndex(PERIOD_MN1)] = 200.0;
        m_forexTouchZones[GetTimeframeIndex(PERIOD_W1)]  = 100.0;
        m_forexTouchZones[GetTimeframeIndex(PERIOD_D1)]  = 60.0;
        m_forexTouchZones[GetTimeframeIndex(PERIOD_H4)]  = 40.0;
        m_forexTouchZones[GetTimeframeIndex(PERIOD_H1)]  = 25.0;
        m_forexTouchZones[GetTimeframeIndex(PERIOD_M30)] = 10.0;
        m_forexTouchZones[GetTimeframeIndex(PERIOD_M15)] = 7.0;
        m_forexTouchZones[GetTimeframeIndex(PERIOD_M5)]  = 3.0;
        m_forexTouchZones[GetTimeframeIndex(PERIOD_M1)]  = 2.0;

        // Minimum bounce sizes (pips)
        m_forexBounceMinSizes[GetTimeframeIndex(PERIOD_MN1)] = 200.0;
        m_forexBounceMinSizes[GetTimeframeIndex(PERIOD_W1)]  = 150.0;
        m_forexBounceMinSizes[GetTimeframeIndex(PERIOD_D1)]  = 100.0;
        m_forexBounceMinSizes[GetTimeframeIndex(PERIOD_H4)]  = 50.0;
        m_forexBounceMinSizes[GetTimeframeIndex(PERIOD_H1)]  = 25.0;
        m_forexBounceMinSizes[GetTimeframeIndex(PERIOD_M30)] = 15.0;
        m_forexBounceMinSizes[GetTimeframeIndex(PERIOD_M15)] = 10.0;
        m_forexBounceMinSizes[GetTimeframeIndex(PERIOD_M5)]  = 7.0;
        m_forexBounceMinSizes[GetTimeframeIndex(PERIOD_M1)]  = 5.0;

        // Minimum touches
        m_forexMinTouches[GetTimeframeIndex(PERIOD_MN1)] = 2;
        m_forexMinTouches[GetTimeframeIndex(PERIOD_W1)]  = 2;
        m_forexMinTouches[GetTimeframeIndex(PERIOD_D1)]  = 3;
        m_forexMinTouches[GetTimeframeIndex(PERIOD_H4)]  = 3;
        m_forexMinTouches[GetTimeframeIndex(PERIOD_H1)]  = 4;
        m_forexMinTouches[GetTimeframeIndex(PERIOD_M30)] = 4;
        m_forexMinTouches[GetTimeframeIndex(PERIOD_M15)] = 4;
        m_forexMinTouches[GetTimeframeIndex(PERIOD_M5)]  = 5;
        m_forexMinTouches[GetTimeframeIndex(PERIOD_M1)]  = 5;

        // Minimum strength thresholds
        m_forexMinStrengths[GetTimeframeIndex(PERIOD_MN1)] = 0.50;
        m_forexMinStrengths[GetTimeframeIndex(PERIOD_W1)]  = 0.55;
        m_forexMinStrengths[GetTimeframeIndex(PERIOD_D1)]  = 0.60;
        m_forexMinStrengths[GetTimeframeIndex(PERIOD_H4)]  = 0.65;
        m_forexMinStrengths[GetTimeframeIndex(PERIOD_H1)]  = 0.70;
        m_forexMinStrengths[GetTimeframeIndex(PERIOD_M30)] = 0.75;
        m_forexMinStrengths[GetTimeframeIndex(PERIOD_M15)] = 0.75;
        m_forexMinStrengths[GetTimeframeIndex(PERIOD_M5)]  = 0.80;
        m_forexMinStrengths[GetTimeframeIndex(PERIOD_M1)]  = 0.85;

        m_forexLookbacks[GetTimeframeIndex(PERIOD_MN1)] = 2;
        m_forexLookbacks[GetTimeframeIndex(PERIOD_W1)]  = 2;
        m_forexLookbacks[GetTimeframeIndex(PERIOD_D1)]  = 3;
        m_forexLookbacks[GetTimeframeIndex(PERIOD_H4)]  = 3;
        m_forexLookbacks[GetTimeframeIndex(PERIOD_H1)]  = 4;
        m_forexLookbacks[GetTimeframeIndex(PERIOD_M30)] = 4;
        m_forexLookbacks[GetTimeframeIndex(PERIOD_M15)] = 4;
        m_forexLookbacks[GetTimeframeIndex(PERIOD_M5)]  = 5;
        m_forexLookbacks[GetTimeframeIndex(PERIOD_M1)]  = 5;

        m_forexMaxBounceDelays[GetTimeframeIndex(PERIOD_MN1)] = 2;
        m_forexMaxBounceDelays[GetTimeframeIndex(PERIOD_W1)]  = 2;
        m_forexMaxBounceDelays[GetTimeframeIndex(PERIOD_D1)]  = 3;
        m_forexMaxBounceDelays[GetTimeframeIndex(PERIOD_H4)]  = 3;
        m_forexMaxBounceDelays[GetTimeframeIndex(PERIOD_H1)]  = 4;
        m_forexMaxBounceDelays[GetTimeframeIndex(PERIOD_M30)] = 4;
        m_forexMaxBounceDelays[GetTimeframeIndex(PERIOD_M15)] = 4;
        m_forexMaxBounceDelays[GetTimeframeIndex(PERIOD_M5)]  = 5;
        m_forexMaxBounceDelays[GetTimeframeIndex(PERIOD_M1)]  = 5;

        m_maxAllowedSpread = 2.5;
        m_lastSpread = 0.0;
        m_lastSpreadUpdate = 0;
        m_pipValue = 0.0;
        m_pipDigits = 0;

        m_initialized = true;
    }

    //--- Timeframe Bonus ---
    static double GetTimeframeBonus(ENUM_TIMEFRAMES tf)
    {
        if(!m_initialized) Initialize();
        
        switch(tf) {
            case PERIOD_MN1: return 0.12;
            case PERIOD_W1:  return 0.10;
            case PERIOD_D1:  return 0.08;
            case PERIOD_H4:  return 0.06;
            case PERIOD_H1:  return 0.04;
            case PERIOD_M30: return 0.02;
            case PERIOD_M15: return 0.015;
            case PERIOD_M5:  return 0.01;
            case PERIOD_M1:  return 0.005;
            default:         return 0.0;
        }
    }

    //--- Getters ---
    static double GetTouchZone(ENUM_TIMEFRAMES tf) 
    {
        if(!m_initialized) Initialize();
        int index = GetTimeframeIndex(tf);
        return (index != -1) ? m_forexTouchZones[index] * _Point * 10 : 5.0 * _Point;
    }

    static int GetMinTouches(ENUM_TIMEFRAMES tf)
    {
        if(!m_initialized) Initialize();
        int index = GetTimeframeIndex(tf);
        return (index != -1) ? m_forexMinTouches[index] : 2;
    }

    static double GetMinStrength(ENUM_TIMEFRAMES tf)
    {
        if(!m_initialized) Initialize();
        int index = GetTimeframeIndex(tf);
        return (index != -1) ? m_forexMinStrengths[index] : 0.55;
    }
};

// Initialize static members
double CV2EAForexData::m_forexTouchZones[];
double CV2EAForexData::m_forexBounceMinSizes[];
int    CV2EAForexData::m_forexMinTouches[];
double CV2EAForexData::m_forexMinStrengths[];
int    CV2EAForexData::m_forexLookbacks[];
int    CV2EAForexData::m_forexMaxBounceDelays[];
double CV2EAForexData::m_maxAllowedSpread = 2.5;
double CV2EAForexData::m_lastSpread = 0.0;
datetime CV2EAForexData::m_lastSpreadUpdate = 0;
double CV2EAForexData::m_pipValue = 0.0;
int    CV2EAForexData::m_pipDigits = 0;
bool   CV2EAForexData::m_initialized = false;

//+------------------------------------------------------------------+
//| Global reset function for Forex data statics                     |
//+------------------------------------------------------------------+
void ResetForexDataStatics()
{
    CV2EAForexData::Reset();
}

#endif // __V2_EA_FOREXDATA_MQH__ 