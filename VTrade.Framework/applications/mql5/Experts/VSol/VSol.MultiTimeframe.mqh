//+------------------------------------------------------------------+
//|                                         VSol.MultiTimeframe.mqh    |
//|                     Multi-Timeframe Analysis Implementation        |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "1.01"

#include "VSol.Market.mqh"
#include "VSol.Utils.mqh"

// Multi-timeframe analysis constants
#define H1_LOOKBACK_PERIODS    30     // Number of H1 periods to analyze
#define H1_SWING_MIN_STRENGTH  0.6    // Minimum strength for H1 swing points
#define H1_SMA_PERIOD         50      // Period for H1 trend SMA
#define SWING_POINT_COUNT      3      // Number of swing points to confirm trend
#define LEVEL_MERGE_THRESHOLD  5      // Pips threshold to merge nearby levels

// Trend definition
enum ENUM_TREND_TYPE
{
    TREND_BULLISH,    // Bullish trend
    TREND_BEARISH,    // Bearish trend
    TREND_NEUTRAL     // No clear trend
};

// Structure for key level
struct SH1Level
{
    double price;           // Level price
    bool isResistance;     // true for resistance, false for support
    datetime firstTouch;    // First time level was touched
    datetime lastTouch;     // Last time level was touched
    int touchCount;        // Number of times level was tested
    double strength;       // Level strength (0.0-1.0)
    bool vsolConfirmed;    // Whether level is confirmed by VSol
    
    void Reset()
    {
        price = 0;
        isResistance = true;
        firstTouch = 0;
        lastTouch = 0;
        touchCount = 0;
        strength = 0;
        vsolConfirmed = false;
    }
};

class CVSolMultiTimeframe : public CVSolMarketBase
{
private:
    // Cached calculations
    double m_h1Sma;
    double m_h1Atr;
    ENUM_TREND_TYPE m_h1Trend;
    SH1Level m_h1Levels[];
    int m_levelCount;
    datetime m_lastUpdate;
    
    // Swing point tracking
    double m_recentSwingHighs[];
    double m_recentSwingLows[];
    datetime m_swingTimes[];
    
    // Utility functions
    bool IsSwingHigh(int shift)
    {
        double high1 = iHigh(_Symbol, PERIOD_H1, shift + 1);
        double high2 = iHigh(_Symbol, PERIOD_H1, shift);
        double high3 = iHigh(_Symbol, PERIOD_H1, shift - 1);
        return (high2 > high1 && high2 > high3);
    }
    
    bool IsSwingLow(int shift)
    {
        double low1 = iLow(_Symbol, PERIOD_H1, shift + 1);
        double low2 = iLow(_Symbol, PERIOD_H1, shift);
        double low3 = iLow(_Symbol, PERIOD_H1, shift - 1);
        return (low2 < low1 && low2 < low3);
    }
    
    void UpdateSwingPoints()
    {
        ArrayResize(m_recentSwingHighs, SWING_POINT_COUNT);
        ArrayResize(m_recentSwingLows, SWING_POINT_COUNT);
        ArrayResize(m_swingTimes, SWING_POINT_COUNT);
        
        int highCount = 0, lowCount = 0;
        
        for(int i = 1; i < H1_LOOKBACK_PERIODS && (highCount < SWING_POINT_COUNT || lowCount < SWING_POINT_COUNT); i++)
        {
            if(highCount < SWING_POINT_COUNT && IsSwingHigh(i))
            {
                m_recentSwingHighs[highCount] = iHigh(_Symbol, PERIOD_H1, i);
                m_swingTimes[highCount] = iTime(_Symbol, PERIOD_H1, i);
                highCount++;
            }
            
            if(lowCount < SWING_POINT_COUNT && IsSwingLow(i))
            {
                m_recentSwingLows[lowCount] = iLow(_Symbol, PERIOD_H1, i);
                m_swingTimes[lowCount] = iTime(_Symbol, PERIOD_H1, i);
                lowCount++;
            }
        }
    }
    
    bool IsHigherHighs()
    {
        for(int i = 1; i < SWING_POINT_COUNT; i++)
            if(m_recentSwingHighs[i] >= m_recentSwingHighs[i-1])
                return false;
        return true;
    }
    
    bool IsLowerLows()
    {
        for(int i = 1; i < SWING_POINT_COUNT; i++)
            if(m_recentSwingLows[i] <= m_recentSwingLows[i-1])
                return false;
        return true;
    }
    
public:
    void UpdateH1Analysis()
    {
        // Update SMA
        double sma[];
        ArraySetAsSeries(sma, true);
        int maHandle = iMA(_Symbol, PERIOD_H1, H1_SMA_PERIOD, 0, MODE_SMA, PRICE_CLOSE);
        if(CopyBuffer(maHandle, 0, 0, 1, sma) > 0)
            m_h1Sma = sma[0];
            
        // Update ATR
        double atr[];
        ArraySetAsSeries(atr, true);
        int atrHandle = iATR(_Symbol, PERIOD_H1, H1_LOOKBACK_PERIODS);
        if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
            m_h1Atr = atr[0];
            
        // Update swing points
        UpdateSwingPoints();
        
        // Determine trend using both SMA and swing points
        double currentPrice = iClose(_Symbol, PERIOD_H1, 1);
        bool aboveSma = currentPrice > m_h1Sma;
        bool hasHigherHighs = IsHigherHighs();
        bool hasLowerLows = IsLowerLows();
        
        if(aboveSma && hasHigherHighs)
            m_h1Trend = TREND_BULLISH;
        else if(!aboveSma && hasLowerLows)
            m_h1Trend = TREND_BEARISH;
        else
            m_h1Trend = TREND_NEUTRAL;
            
        m_lastUpdate = TimeCurrent();
    }
    
    ENUM_TREND_TYPE GetH1Trend() const { return m_h1Trend; }
    double GetH1ATR() const { return m_h1Atr; }
    double GetH1SMA() const { return m_h1Sma; }
    
    bool IsBreakoutValid(bool isLong, double price, double volume)
    {
        // First check trend alignment
        if(isLong && m_h1Trend != TREND_BULLISH) return false;
        if(!isLong && m_h1Trend != TREND_BEARISH) return false;
        
        // Then check if we've broken any H1 levels
        for(int i = 0; i < m_levelCount; i++)
        {
            if(isLong && price > m_h1Levels[i].price && m_h1Levels[i].isResistance)
                return true;
            if(!isLong && price < m_h1Levels[i].price && !m_h1Levels[i].isResistance)
                return true;
        }
        
        return false;
    }
    
    void DrawH1Levels()
    {
        for(int i = 0; i < m_levelCount; i++)
        {
            string objName = StringFormat("H1_Level_%d", i);
            ObjectCreate(0, objName, OBJ_HLINE, 0, 0, m_h1Levels[i].price);
            ObjectSetInteger(0, objName, OBJPROP_COLOR, m_h1Levels[i].isResistance ? clrRed : clrGreen);
            ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
        }
        
        // Draw trend label
        string trendText = "H1 Trend: " + EnumToString(m_h1Trend);
        string labelName = "H1_Trend_Label";
        ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
        ObjectSetString(0, labelName, OBJPROP_TEXT, trendText);
        ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 20);
    }
}; 