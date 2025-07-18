//+------------------------------------------------------------------+
//|                                                     StubbsEA.mq5 |
//|                        VSol Software                             |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "VSol Software"
#property link      ""
#property version   "2.00"
#property strict
#property description "Stubbs EA with EMA and MACD Strategy"

#include <Trade\Trade.mqh>
#include <Tools\DateTime.mqh>
#include <Arrays\ArrayObj.mqh>
#include "V-2-EA-Utils.mqh"  // Add centralized logging utilities

//--- EA Parameters
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES MainTimeframe = PERIOD_H2;  // Main Trading Timeframe [H1,H2,H4,D1]

input group "=== EMA Parameters ==="
input int EmaFastPeriod = 9;        // Fast EMA Period [8-21, step=1]
input int EmaMidPeriod = 55;         // Mid EMA Period [21-55, step=1]
input int EmaSlowPeriod = 77;        // Slow EMA Period [34-89, step=1]

input group "=== ATR Settings ==="
input int ATRPeriod = 10;            // ATR Period [10-30, step=2]
input double SLMultiplier = 5.0;     // SL Multiplier [5.0-12.0, step=0.5]
input double TPMultiplier = 5.0;     // TP Multiplier [4.0-12.0, step=0.5]
input double SLBufferPips = 2.0;     // SL Buffer in Pips [2.0-8.0, step=0.5]

input group "=== Trailing Stop Settings ==="
input double MinimumProfitToTrail = 2.25;  // Minimum profit (ATR) before trailing [0.5-3.0, step=0.25]
input double TrailMultiplier = 3.00;       // Trail distance as ATR multiplier [1.0-3.0, step=0.25]
input bool UseFixedTrailStep = false;     // Use fixed step for trailing
input double TrailStepPips = 35.0;        // Fixed trail step in pips [10.0-50.0, step=5.0]

input group "=== Risk Management ==="
input double RiskPercentage = 5.0;   // Risk per trade (%) [0.5-5.0, step=0.5]

input group "=== Breakout Strategy Settings ==="
input int LookbackPeriod = 15;        // Bars to look back for key levels [10-50, step=5]
input int MinSwingStrength = 2;       // Minimum bars for swing confirmation [2-5, step=1]
input double LevelTolerance = 0.001;   // Level tolerance in price [0.0001-0.001, step=0.0001]
input int MinTouchPoints = 2;         // Minimum times price must touch level [2-5, step=1]
input int MaxBarsBetweenTouches = 15; // Maximum bars between touches [5-20, step=1]

input group "=== Breakout Validation ==="
input double MinBreakoutATR = 0.05;     // Minimum breakout distance in ATR [0.05-2.0, step=0.1]
input int MinBreakoutBars = 1;         // Minimum bars to confirm breakout [1-5, step=1]
input int MaxBreakoutBars = 8;         // Maximum bars to wait for breakout confirmation [3-10, step=1]
input int BarsAfterTouch = 3;          // Bars to analyze after touch [3-10, step=1]

input group "=== Retest Validation ==="
input int MinRetestBars = 1;           // Minimum bars for retest confirmation [1-5, step=1]
input int MaxRetestBars = 12;           // Maximum bars to wait for retest [5-15, step=1]
input double RetestATRThreshold = 0.8;  // Maximum distance from level for retest (in ATR) [0.2-1.0, step=0.1]
input double MinRetestVolume = 0.4;     // Minimum volume ratio for retest vs breakout [0.4-1.5, step=0.1]

input group "=== Take Profit Settings ==="
input double MinRiskRewardRatio = 1.5; // Lowered minimum Risk/Reward ratio [1.5-5.0, step=0.5]
input bool UseFibonacciTargets = true;     // Use Fibonacci extension targets
input double Fib1Level = 1.618;            // First Fibonacci extension level [1.618-2.0, step=0.382]
input double Fib2Level = 2.618;            // Second Fibonacci extension level [2.618-3.0, step=0.382]
input int SwingLookback = 20;              // Bars to look back for swing points [10-50, step=5]

input group "=== Session Settings ==="
input bool RestrictTradingHours = false;    // Restrict trading to specific hours
input int LondonStartHour = 3;             // London session start (NY time) [0-23]
input int LondonEndHour = 11;              // London session end (NY time) [0-23]
input int NewYorkStartHour = 8;            // New York session start (NY time) [0-23]
input int NewYorkEndHour = 17;             // New York session end (NY time) [0-23]

input group "=== Retest Settings ==="
input bool UseRetest = false;  // Enable or disable retest logic

// Global variables
datetime lastBarTime = 0;            // Tracks the last processed bar time
int tradeDirection = 0;              // 0 = No position, 1 = Buy, -1 = Sell

//--- Global Variables
int MagicNumber = 123456;            // Unique identifier for EA's trades

// Strategy Types
enum ENUM_STRATEGY_TYPE
{
    STRAT_EMA_CROSS,    // EMA Crossover Strategy
    STRAT_BREAKOUT_RETEST,  // Breakout and Retest Strategy
    STRAT_CUSTOM        // Custom Strategy (TBD)
};

input group "=== Strategy Settings ==="
input ENUM_STRATEGY_TYPE StrategyType = STRAT_BREAKOUT_RETEST;  // Trading Strategy

// Indicator handles
int handleEmaFast;
int handleEmaMid;
int handleEmaSlow;
int handleATR;

// Trade object
CTrade trade;

// Global variables for breakout strategy
double lastKeyLevel = 0;              // Last identified key level
datetime lastKeyLevelTime = 0;        // Time when key level was identified
bool isKeyLevelResistance = false;    // True if key level is resistance, false if support

// Structure to track potential zones
struct PriceZone {
    double level;           // Price level
    int touchCount;        // Number of times price has touched this level
    int lastTouchBar;      // Bar index of last touch
    bool isResistance;     // True if resistance, false if support
    datetime firstTouch;   // Time of first touch
    datetime lastTouch;    // Time of last touch
};

// Global variables for breakout strategy
PriceZone currentZone;     // Current active price zone
bool zoneActive = false;   // Whether we have an active zone

// Add these to the global variables section
enum ENUM_BREAKOUT_STATE
{
    NO_BREAKOUT,     // No breakout detected
    BREAKOUT_BULL,   // Bullish breakout confirmed
    BREAKOUT_BEAR,   // Bearish breakout confirmed
    RETEST_BULL,     // Bullish retest in progress
    RETEST_BEAR      // Bearish retest in progress
};

// Global variables for breakout strategy
ENUM_BREAKOUT_STATE breakoutState = NO_BREAKOUT;  // Current breakout state
datetime breakoutTime = 0;                         // When breakout occurred
double breakoutLevel = 0;                          // Price level of the breakout

// Add to global variables
datetime retestStartTime = 0;           // When retest phase started
double retestVolume = 0;               // Average volume during retest
int retestBars = 0;                    // Number of bars in retest
bool retestConfirmed = false;          // Whether retest is confirmed

// Add to global variables after retestConfirmed
int retestCandleIndex = -1;           // Index of the candle where retest was confirmed

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize EMA indicators
    handleEmaFast = iMA(_Symbol, MainTimeframe, EmaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
    handleEmaMid  = iMA(_Symbol, MainTimeframe, EmaMidPeriod,  0, MODE_EMA, PRICE_CLOSE);
    handleEmaSlow = iMA(_Symbol, MainTimeframe, EmaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
    
    // Initialize ATR indicator
    handleATR = iATR(_Symbol, MainTimeframe, ATRPeriod);
    
    // Check if indicators are initialized successfully
    if(handleEmaFast == INVALID_HANDLE || handleEmaMid == INVALID_HANDLE || 
       handleEmaSlow == INVALID_HANDLE || handleATR == INVALID_HANDLE)
    {
        string errorMsg = "Failed to initialize indicators: ";
        if(handleEmaFast == INVALID_HANDLE) errorMsg += "Fast EMA, ";
        if(handleEmaMid == INVALID_HANDLE) errorMsg += "Mid EMA, ";
        if(handleEmaSlow == INVALID_HANDLE) errorMsg += "Slow EMA, ";
        if(handleATR == INVALID_HANDLE) errorMsg += "ATR, ";
        CV2EAUtils::LogError(errorMsg);
        return(INIT_FAILED);
    }
    
    // Set magic number and trade settings
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetMarginMode();
    trade.SetTypeFillingBySymbol(_Symbol);
    
    CV2EAUtils::LogSuccess(StringFormat("V-EA-Stubbs-Simple initialized successfully on %s %s", 
        _Symbol, EnumToString(MainTimeframe)));
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles
    IndicatorRelease(handleEmaFast);
    IndicatorRelease(handleEmaMid);
    IndicatorRelease(handleEmaSlow);
    IndicatorRelease(handleATR);
    
    CV2EAUtils::LogInfo("EA Deinitialized.");
}

//+------------------------------------------------------------------+
//| EMA Cross Strategy                                                 |
//+------------------------------------------------------------------+
bool EMACrossStrategy(bool isBuy, string &signalReason)
{
    // Get current and previous indicator values
    double emaFast = GetIndicatorValue(handleEmaFast, 0);
    double emaMid = GetIndicatorValue(handleEmaMid, 0);
    double emaSlow = GetIndicatorValue(handleEmaSlow, 0);
    
    double emaFastPrev = GetIndicatorValue(handleEmaFast, 1);
    double emaMidPrev = GetIndicatorValue(handleEmaMid, 1);
    double emaSlowPrev = GetIndicatorValue(handleEmaSlow, 1);
    
    if(isBuy)
    {
        // Buy signal: Fast EMA crosses above Mid EMA AND Fast EMA is above Slow EMA
        bool fastCrossesMid = emaFastPrev <= emaMidPrev && emaFast > emaMid;
        bool aboveSlow = emaFast > emaSlow;
        
        if(fastCrossesMid && aboveSlow)
        {
            signalReason = StringFormat("📈 Fast EMA crossed above Mid EMA (Fast: %.2f > Mid: %.2f) & Above Slow: %.2f", 
                                      emaFast, emaMid, emaSlow);
            CV2EAUtils::LogInfo(signalReason);
            return true;
        }
    }
    else
    {
        // Sell signal: Fast EMA crosses below Mid EMA AND Fast EMA is below Slow EMA
        bool fastCrossesMid = emaFastPrev >= emaMidPrev && emaFast < emaMid;
        bool belowSlow = emaFast < emaSlow;
        
        if(fastCrossesMid && belowSlow)
        {
            signalReason = StringFormat("📉 Fast EMA crossed below Mid EMA (Fast: %.2f < Mid: %.2f) & Below Slow: %.2f", 
                                      emaFast, emaMid, emaSlow);
            CV2EAUtils::LogInfo(signalReason);
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Find Key Level                                                     |
//+------------------------------------------------------------------+
bool FindKeyLevel(double &keyLevel, bool &isResistance)
{
    double highs[], lows[], closes[];
    ArraySetAsSeries(highs, true);
    ArraySetAsSeries(lows, true);
    ArraySetAsSeries(closes, true);
    
    // Copy price data
    if(CopyHigh(_Symbol, MainTimeframe, 0, LookbackPeriod, highs) <= 0 ||
       CopyLow(_Symbol, MainTimeframe, 0, LookbackPeriod, lows) <= 0 ||
       CopyClose(_Symbol, MainTimeframe, 0, LookbackPeriod, closes) <= 0)
    {
        Print("Failed to copy price data");
        return false;
    }
    
    // Arrays to store potential zones
    PriceZone zones[];
    int zoneCount = 0;
    
    // Look for potential zones where price has stalled
    for(int i = MinSwingStrength; i < LookbackPeriod-MinSwingStrength; i++)
    {
        // Check for resistance zone
        if(IsSignificantHigh(highs, closes, i))
        {
            double level = highs[i];
            bool foundExisting = false;
            
            // Check if this level is near an existing zone
            for(int z = 0; z < zoneCount; z++)
            {
                if(MathAbs(zones[z].level - level) <= LevelTolerance)
                {
                    // Update existing zone if touch is within allowed bar range
                    if(zones[z].lastTouchBar - i <= MaxBarsBetweenTouches)
                    {
                        zones[z].touchCount++;
                        zones[z].lastTouchBar = i;
                        zones[z].lastTouch = iTime(_Symbol, MainTimeframe, i);
                    }
                    foundExisting = true;
                    break;
                }
            }
            
            // Create new zone if not found
            if(!foundExisting)
            {
                ArrayResize(zones, zoneCount + 1);
                zones[zoneCount].level = level;
                zones[zoneCount].touchCount = 1;
                zones[zoneCount].lastTouchBar = i;
                zones[zoneCount].isResistance = true;
                zones[zoneCount].firstTouch = iTime(_Symbol, MainTimeframe, i);
                zones[zoneCount].lastTouch = zones[zoneCount].firstTouch;
                zoneCount++;
            }
        }
        
        // Check for support zone
        if(IsSignificantLow(lows, closes, i))
        {
            double level = lows[i];
            bool foundExisting = false;
            
            // Check if this level is near an existing zone
            for(int z = 0; z < zoneCount; z++)
            {
                if(MathAbs(zones[z].level - level) <= LevelTolerance)
                {
                    // Update existing zone if touch is within allowed bar range
                    if(zones[z].lastTouchBar - i <= MaxBarsBetweenTouches)
                    {
                        zones[z].touchCount++;
                        zones[z].lastTouchBar = i;
                        zones[z].lastTouch = iTime(_Symbol, MainTimeframe, i);
                    }
                    foundExisting = true;
                    break;
                }
            }
            
            // Create new zone if not found
            if(!foundExisting)
            {
                ArrayResize(zones, zoneCount + 1);
                zones[zoneCount].level = level;
                zones[zoneCount].touchCount = 1;
                zones[zoneCount].lastTouchBar = i;
                zones[zoneCount].isResistance = false;
                zones[zoneCount].firstTouch = iTime(_Symbol, MainTimeframe, i);
                zones[zoneCount].lastTouch = zones[zoneCount].firstTouch;
                zoneCount++;
            }
        }
    }
    
    // Find the strongest zone (most touches)
    int bestZoneIndex = -1;
    int maxTouches = MinTouchPoints - 1;
    
    for(int z = 0; z < zoneCount; z++)
    {
        if(zones[z].touchCount > maxTouches)
        {
            maxTouches = zones[z].touchCount;
            bestZoneIndex = z;
        }
    }
    
    // Return the strongest zone if found
    if(bestZoneIndex >= 0)
    {
        keyLevel = zones[bestZoneIndex].level;
        isResistance = zones[bestZoneIndex].isResistance;
        
        // Update current zone if it's different
        if(!zoneActive || MathAbs(currentZone.level - keyLevel) > LevelTolerance)
        {
            currentZone = zones[bestZoneIndex];
            zoneActive = true;
            Print("New key zone identified: ", keyLevel, 
                  " (", (isResistance ? "Resistance" : "Support"), 
                  ") with ", currentZone.touchCount, " touches");
        }
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if a high point is significant                               |
//+------------------------------------------------------------------+
bool IsSignificantHigh(const double &highs[], const double &closes[], int index)
{
    // Price must form a peak
    if(highs[index] <= highs[index+1] || highs[index] <= highs[index-1])
        return false;
        
    // Track both reversal and stalling patterns
    bool hasReversal = false;
    bool hasStalled = false;
    double rangeThreshold = LevelTolerance * 2;
    
    // Check for reversal (significant move down after the high)
    if(index + 3 < ArraySize(closes))
    {
        // Look for bearish follow-through
        double moveAfterHigh = highs[index] - MathMin(closes[index+1], closes[index+2]);
        double continuedMove = highs[index] - MathMin(closes[index+2], closes[index+3]);
        
        // Reversal confirmed if price continues lower
        hasReversal = (moveAfterHigh > rangeThreshold * 2) && (continuedMove >= moveAfterHigh);
    }
    
    // Look for stalling pattern (multiple small bodies near the level)
    int stallCount = 0;
    for(int i = -2; i <= 2; i++)
    {
        if(index + i >= 0 && index + i < ArraySize(closes) - 1)  // Ensure index+i+1 is within bounds
        {
            double bodySize = MathAbs(closes[index+i] - closes[index+i+1]);
            double highDiff = MathAbs(highs[index+i] - highs[index]);
            
            // Count bars that stay near the level with small bodies
            if(bodySize < rangeThreshold && highDiff < rangeThreshold * 1.5)
                stallCount++;
        }
    }
    
    // Need at least 3 bars stalling near the level
    hasStalled = (stallCount >= 3);
    
    // Return true if we have EITHER a clear reversal OR a stalling pattern
    return hasReversal || hasStalled;
}

//+------------------------------------------------------------------+
//| Check if a low point is significant                                |
//+------------------------------------------------------------------+
bool IsSignificantLow(const double &lows[], const double &closes[], int index)
{
    // Price must form a trough
    if(lows[index] >= lows[index+1] || lows[index] >= lows[index-1])
        return false;
        
    // Track both reversal and stalling patterns
    bool hasReversal = false;
    bool hasStalled = false;
    double rangeThreshold = LevelTolerance * 2;
    
    // Check for reversal (significant move up after the low)
    if(index + 3 < ArraySize(closes))
    {
        // Look for bullish follow-through
        double moveAfterLow = MathMax(closes[index+1], closes[index+2]) - lows[index];
        double continuedMove = MathMax(closes[index+2], closes[index+3]) - lows[index];
        
        // Reversal confirmed if price continues higher
        hasReversal = (moveAfterLow > rangeThreshold * 2) && (continuedMove >= moveAfterLow);
    }
    
    // Look for stalling pattern (multiple small bodies near the level)
    int stallCount = 0;
    for(int i = -2; i <= 2; i++)
    {
        if(index + i >= 0 && index + i < ArraySize(closes) - 1)  // Ensure index+i+1 is within bounds
        {
            double bodySize = MathAbs(closes[index+i] - closes[index+i+1]);
            double lowDiff = MathAbs(lows[index+i] - lows[index]);
            
            // Count bars that stay near the level with small bodies
            if(bodySize < rangeThreshold && lowDiff < rangeThreshold * 1.5)
                stallCount++;
        }
    }
    
    // Need at least 3 bars stalling near the level
    hasStalled = (stallCount >= 3);
    
    // Return true if we have EITHER a clear reversal OR a stalling pattern
    return hasReversal || hasStalled;
}

//+------------------------------------------------------------------+
//| Check if price is consolidating between touches                     |
//+------------------------------------------------------------------+
bool IsConsolidationBetweenTouches(const PriceZone &zone)
{
    double highs[], lows[];
    long volumeData[];
    double volumes[];
    ArraySetAsSeries(highs, true);
    ArraySetAsSeries(lows, true);
    ArraySetAsSeries(volumeData, true);
    ArraySetAsSeries(volumes, true);
    
    // Get enough bars to cover the zone period
    int barsNeeded = (int)((zone.lastTouch - zone.firstTouch) / PeriodSeconds(MainTimeframe)) + 1;
    if(barsNeeded <= 0) return false;
    
    if(CopyHigh(_Symbol, MainTimeframe, 0, barsNeeded, highs) <= 0 ||
       CopyLow(_Symbol, MainTimeframe, 0, barsNeeded, lows) <= 0 ||
       CopyTickVolume(_Symbol, MainTimeframe, 0, barsNeeded, volumeData) <= 0)
        return false;
        
    // Convert volume data to double array
    ArrayResize(volumes, ArraySize(volumeData));
    for(int i = 0; i < ArraySize(volumeData); i++)
    {
        volumes[i] = (double)volumeData[i];
    }

    double maxDeviation = LevelTolerance * 3;  // Maximum allowed range around level
    int sidewaysBars = 0;
    double avgVolume = 0;
    
    // Calculate average volume first
    for(int i = 0; i < barsNeeded; i++)
        avgVolume += volumes[i];
    avgVolume /= barsNeeded;
    
    // Check if price mostly stayed within the zone with normal volume
    for(int i = 0; i < barsNeeded; i++)
    {
        bool priceInZone = MathAbs(highs[i] - zone.level) <= maxDeviation &&
                          MathAbs(lows[i] - zone.level) <= maxDeviation;
        bool normalVolume = volumes[i] <= avgVolume * 1.5; // No volume spikes
        
        if(priceInZone && normalVolume)
            sidewaysBars++;
    }
    
    // Return true if at least 60% of bars were sideways with normal volume
    return (double)sidewaysBars / barsNeeded >= 0.6;
}

//+------------------------------------------------------------------+
//| Validate breakout volume pattern                                   |
//+------------------------------------------------------------------+
bool IsBreakoutVolume(const double &volumes[], int bars, bool increasing = true)
{
    if(bars < 3) return false;
    
    // Calculate volume moving average using raw volumes
    double volumeMA = 0;
    for(int i = 0; i < bars; i++)
        volumeMA += volumes[i];
    volumeMA /= bars;
    
    // Check for volume spike and pattern
    bool hasVolumeSpike = volumes[0] > volumeMA * 1.5;  // 50% above average
    
    // Check if volume is increasing on breakout
    if(increasing)
    {
        bool progressiveIncrease = volumes[0] > volumes[1] && volumes[1] > volumes[2];
        bool sustainedVolume = volumes[1] > volumeMA * 1.2;  // Second bar also strong
        
        return hasVolumeSpike && (progressiveIncrease || sustainedVolume);
    }
    
    return hasVolumeSpike;  // For non-increasing, just need the spike
}

//+------------------------------------------------------------------+
//| Validate breakout price structure                                  |
//+------------------------------------------------------------------+
bool ValidateBreakoutStructure(const double &highs[], const double &lows[], 
                             const double &closes[], bool isResistance)
{
    // Always return true for testing
    return true;
}

//+------------------------------------------------------------------+
//| Calculate directional momentum                                     |
//+------------------------------------------------------------------+
double CalculateDirectionalMomentum(const double &closes[], const double &volumes[], 
                                  bool isResistance, int bars)
{
    double momentum = 0;
    
    for(int i = 0; i < bars-1; i++)
    {
        double move = closes[i] - closes[i+1];
        momentum += move * volumes[i] * (isResistance ? 1 : -1);
    }
    
    return momentum;
}

//+------------------------------------------------------------------+
//| Analyze price action quality                                        |
//+------------------------------------------------------------------+
bool IsPriceActionClean(const double &highs[], const double &lows[], const double &closes[],
                       bool isResistance, int bars, double level, double atr)
{
    if(bars < 3) return false;
    
    double maxWick = atr * 2.0;  // Further increased maximum acceptable wick size
    int strongBars = 0;          // Count of strong momentum bars
    bool hasRetracement = false;  // Track if price retraced significantly
    
    for(int i = 0; i < bars; i++)
    {
        double bodySize = MathAbs(closes[i] - closes[i+1]);
        double upperWick = highs[i] - MathMax(closes[i], closes[i+1]);
        double lowerWick = MathMin(closes[i], closes[i+1]) - lows[i];
        
        // Check for strong momentum bars
        if(bodySize > atr * 0.1)  // Further reduced requirement for strong bars
        {
            if((isResistance && closes[i] > closes[i+1]) ||  // Strong up bars for resistance break
               (!isResistance && closes[i] < closes[i+1]))   // Strong down bars for support break
            {
                strongBars++;
            }
        }
        
        // Check for significant retracements
        if(i > 0)
        {
            if(isResistance)
            {
                if(lows[i] < lows[i+1] && MathAbs(lows[i] - lows[i+1]) > 0.5 * MathAbs(closes[i] - closes[i+1]))
                    hasRetracement = true;
            }
            else
            {
                if(highs[i] > highs[i+1] && MathAbs(highs[i] - highs[i+1]) > 0.5 * MathAbs(closes[i] - closes[i+1]))
                    hasRetracement = true;
            }
        }
        
        // Reject if wicks are too long
        if(isResistance && upperWick > maxWick) return false;
        if(!isResistance && lowerWick > maxWick) return false;
    }
    
    // No longer require strong bars or retracement checks
    return true;
}

//+------------------------------------------------------------------+
//| Analyze volume patterns                                            |
//+------------------------------------------------------------------+
bool AnalyzeVolume(const double &volumes[], int bars, double &volumeRatio, double &avgVolume)
{
    if(bars < 3) return false;
    
    // Calculate pre-breakout volume metrics (last 10 bars before breakout)
    double preBreakoutAvg = 0;
    int preBreakoutBars = MathMin(10, ArraySize(volumes) - bars);
    for(int i = bars; i < bars + preBreakoutBars; i++)
        preBreakoutAvg += volumes[i];
    preBreakoutAvg /= preBreakoutBars;
    
    // Calculate breakout volume metrics
    avgVolume = 0;
    double maxVolume = volumes[0];
    double minVolume = volumes[0];
    double volumeSum = 0;
    
    for(int i = 0; i < bars; i++)
    {
        avgVolume += volumes[i];
        maxVolume = MathMax(maxVolume, volumes[i]);
        minVolume = MathMin(minVolume, volumes[i]);
        volumeSum += volumes[i];
    }
    avgVolume /= bars;
    
    // Calculate volume increase ratio compared to pre-breakout
    volumeRatio = avgVolume / preBreakoutAvg;
    
    // Volume should be increasing and above pre-breakout average
    bool hasVolumeSpike = volumes[0] > preBreakoutAvg * 0.5;  // Significantly lowered from 0.8
    bool hasProgressiveVolume = true;  // Allow any volume pattern
    bool hasConsistentVolume = minVolume > preBreakoutAvg * 0.3;  // Significantly lowered from 0.5
    
    // Check if volume is expanding with price movement
    bool hasExpandingVolume = true;
    double volumeMA = volumeSum / bars;
    int volumeExpansionCount = 0;
    
    for(int i = 0; i < bars-1; i++)
    {
        if(volumes[i] > volumeMA)
            volumeExpansionCount++;
    }
    
    hasExpandingVolume = (double)volumeExpansionCount / bars >= 0.2;  // Significantly lowered from 0.3
    
    return (hasVolumeSpike && hasExpandingVolume) && 
           (hasProgressiveVolume || hasConsistentVolume);
}

//+------------------------------------------------------------------+
//| Validate pattern type and strength                                  |
//+------------------------------------------------------------------+
bool ValidatePatternType(const PriceZone &zone, bool &isStallPattern, string &patternDesc)
{
    double highs[], lows[], closes[];
    long volumeData[];
    double volumes[];
    ArraySetAsSeries(highs, true);
    ArraySetAsSeries(lows, true);
    ArraySetAsSeries(closes, true);
    ArraySetAsSeries(volumeData, true);
    ArraySetAsSeries(volumes, true);
    
    // Get enough bars to cover the zone period plus buffer
    int barsNeeded = (int)((zone.lastTouch - zone.firstTouch) / PeriodSeconds(MainTimeframe)) + 10;
    
    if(CopyHigh(_Symbol, MainTimeframe, 0, barsNeeded, highs) <= 0 ||
       CopyLow(_Symbol, MainTimeframe, 0, barsNeeded, lows) <= 0 ||
       CopyClose(_Symbol, MainTimeframe, 0, barsNeeded, closes) <= 0 ||
       CopyTickVolume(_Symbol, MainTimeframe, 0, barsNeeded, volumeData) <= 0)
        return false;
        
    // Convert volume data to double array
    ArrayResize(volumes, ArraySize(volumeData));
    for(int i = 0; i < ArraySize(volumeData); i++)
    {
        volumes[i] = (double)volumeData[i];
    }

    // Track touch characteristics
    struct TouchPoint {
        int bar;           // Bar index
        double price;      // Price at touch
        double moveAfter;  // Price movement after touch
        bool isReversal;   // Whether it reversed
        bool isStall;      // Whether it stalled
        double volume;     // Volume at touch
    };
    
    TouchPoint touches[];
    int touchCount = 0;
    double rangeThreshold = LevelTolerance * 2;
    double avgVolume = ArrayAverage(volumes, barsNeeded);
    
    // First pass: identify all touches
    for(int i = 1; i < barsNeeded-5; i++)
    {
        bool isTouchBar = false;
        double touchPrice = 0;
        
        if(zone.isResistance)
        {
            if(MathAbs(highs[i] - zone.level) <= LevelTolerance)
            {
                isTouchBar = true;
                touchPrice = highs[i];
            }
        }
        else
        {
            if(MathAbs(lows[i] - zone.level) <= LevelTolerance)
            {
                isTouchBar = true;
                touchPrice = lows[i];
            }
        }
        
        if(isTouchBar)
        {
            // Check if this touch is far enough from previous touch
            bool isNewTouch = true;
            if(touchCount > 0)
            {
                int lastTouchBar = touches[touchCount-1].bar;
                if(i - lastTouchBar < 3)  // Minimum 3 bars between touches
                    isNewTouch = false;
            }
            
            if(isNewTouch)
            {
                ArrayResize(touches, touchCount + 1);
                touches[touchCount].bar = i;
                touches[touchCount].price = touchPrice;
                touches[touchCount].volume = volumes[i];
                
                // Analyze price action after touch
                double moveAfter = 0;
                bool hasReversal = false;
                bool hasStall = false;
                
                // Check next 5 bars after touch
                int smallBodies = 0;
                double maxMove = 0;
                
                for(int j = 1; j <= 5; j++)
                {
                    if(i+j >= barsNeeded) break;
                    
                    double move = zone.isResistance ? 
                                zone.level - MathMin(lows[i+j], closes[i+j]) :
                                MathMax(highs[i+j], closes[i+j]) - zone.level;
                                
                    maxMove = MathMax(maxMove, MathAbs(move));
                    
                    // Check for small bodies indicating stall
                    double bodySize = MathAbs(closes[i+j] - closes[i+j-1]);
                    if(bodySize < rangeThreshold)
                        smallBodies++;
                }
                
                // Classify the touch
                if(maxMove > rangeThreshold * 2)
                {
                    hasReversal = true;
                    moveAfter = maxMove;
                }
                else if(smallBodies >= 3)
                {
                    hasStall = true;
                    moveAfter = maxMove;
                }
                
                touches[touchCount].moveAfter = moveAfter;
                touches[touchCount].isReversal = hasReversal;
                touches[touchCount].isStall = hasStall;
                
                touchCount++;
            }
        }
    }
    
    // Second pass: analyze touch patterns
    if(touchCount >= MinTouchPoints)
    {
        int reversalCount = 0;
        int stallCount = 0;
        int strongVolumeTouches = 0;
        double maxReversalMove = 0;
        
        for(int i = 0; i < touchCount; i++)
        {
            if(touches[i].isReversal)
            {
                reversalCount++;
                maxReversalMove = MathMax(maxReversalMove, touches[i].moveAfter);
            }
            if(touches[i].isStall)
                stallCount++;
            if(touches[i].volume > avgVolume * 1.2)
                strongVolumeTouches++;
        }
        
        // Determine pattern type based on touch characteristics
        if(reversalCount >= 2 && maxReversalMove > rangeThreshold * 3)
        {
            isStallPattern = false;
            patternDesc = StringFormat("Strong Reversal Zone (%d reversals, max: %.1f pips, vol: %d)", 
                                     reversalCount, maxReversalMove/Point(), strongVolumeTouches);
            return true;
        }
        else if(stallCount >= 2 && touchCount >= 3)
        {
            isStallPattern = true;
            patternDesc = StringFormat("Established Stall Zone (%d stalls of %d touches, vol: %d)", 
                                     stallCount, touchCount, strongVolumeTouches);
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Validate retest conditions                                          |
//+------------------------------------------------------------------+
bool ValidateRetest(const double &highs[], const double &lows[], const double &closes[], 
                   const double &volumes[], bool isBullish, double atr, string &retestDesc)
{
    if(retestBars >= MaxRetestBars)
    {
        retestDesc = "Retest failed - Exceeded maximum bars";
        return false;
    }
    
    // Get open prices for candlestick pattern analysis
    double opens[];
    ArraySetAsSeries(opens, true);
    if(CopyOpen(_Symbol, MainTimeframe, 0, retestBars + 1, opens) <= 0)
    {
        retestDesc = "Failed to get open prices";
        return false;
    }
    
    // Calculate average volume during retest
    double avgVolume = 0;
    for(int i = 0; i < retestBars; i++)
        avgVolume += volumes[i];
    avgVolume /= retestBars;
    
    // Check if price is near the breakout level
    double distanceFromLevel = isBullish ? 
                             MathAbs(breakoutLevel - lows[0]) :
                             MathAbs(highs[0] - breakoutLevel);
                             
    bool isNearLevel = distanceFromLevel <= atr * RetestATRThreshold;
    
    // Check for reversal candlestick patterns
    bool hasReversalPattern = false;
    if(retestBars >= 2)
    {
        if(isBullish)  // Looking for bullish reversal at support
        {
            // Bullish engulfing or hammer
            bool isHammer = (closes[0] > opens[0] && 
                           (closes[0] - lows[0]) > (highs[0] - closes[0]) * 2 &&
                           (closes[0] - lows[0]) > MathAbs(closes[0] - closes[1]));
                           
            bool isBullishEngulfing = (closes[0] > closes[1] &&
                                     closes[0] > opens[0] &&
                                     opens[0] < closes[1] &&
                                     (closes[0] - opens[0]) > MathAbs(closes[1] - opens[1]));
                                     
            hasReversalPattern = isHammer || isBullishEngulfing;
        }
        else  // Looking for bearish reversal at resistance
        {
            // Bearish engulfing or shooting star
            bool isShootingStar = (closes[0] < opens[0] && 
                                 (highs[0] - closes[0]) > (closes[0] - lows[0]) * 2 &&
                                 (highs[0] - closes[0]) > MathAbs(closes[0] - closes[1]));
                                 
            bool isBearishEngulfing = (closes[0] < closes[1] &&
                                     closes[0] < opens[0] &&
                                     opens[0] > closes[1] &&
                                     (opens[0] - closes[0]) > MathAbs(closes[1] - opens[1]));
                                     
            hasReversalPattern = isShootingStar || isBearishEngulfing;
        }
    }
    
    // Check volume conditions
    bool hasAdequateVolume = avgVolume >= (retestVolume * MinRetestVolume);
    
    // Check momentum
    double momentum = 0;
    for(int i = 0; i < retestBars; i++)
    {
        double move = closes[i] - closes[i+1];
        momentum += move * volumes[i] * (isBullish ? 1 : -1);
    }
    
    bool hasMomentum = isBullish ? (momentum > 0) : (momentum < 0);
    
    // Build description
    retestDesc = StringFormat("Retest %s | Near Level: %s | Pattern: %s | Volume: %s | Momentum: %s",
                            (retestBars >= MinRetestBars ? "Complete" : "Building"),
                            (isNearLevel ? "Yes" : "No"),
                            (hasReversalPattern ? "Valid" : "None"),
                            (hasAdequateVolume ? "Adequate" : "Low"),
                            (hasMomentum ? "Aligned" : "Weak"));
                            
    // Return true if all conditions are met
    if(retestBars >= MinRetestBars && isNearLevel && hasReversalPattern && 
       hasAdequateVolume && hasMomentum)
    {
        retestCandleIndex = 0;  // Store the confirmation candle index
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Breakout and Retest Strategy                                       |
//+------------------------------------------------------------------+
bool BreakoutRetestStrategy(bool isBuy, string &signalReason)
{
    // Get current and previous values
    double currentClose = iClose(_Symbol, MainTimeframe, 0);
    double currentHigh = iHigh(_Symbol, MainTimeframe, 0);
    double currentLow = iLow(_Symbol, MainTimeframe, 0);
    
    // Calculate ATR early for validation
    double atr = GetIndicatorValue(handleATR, 0);
    if(atr == 0) 
    {
        Print("❌ Strategy Check Failed: Zero ATR value");
        return false;  
    }
    
    // Add opens array declaration with other arrays
    double volumes[], highs[], lows[], closes[], opens[];
    ArraySetAsSeries(volumes, true);
    ArraySetAsSeries(highs, true);
    ArraySetAsSeries(lows, true);
    ArraySetAsSeries(closes, true);
    ArraySetAsSeries(opens, true);

    // Get enough data for analysis
    int barsNeeded = MathMax(MaxBreakoutBars, MaxRetestBars) + 10;

    // Fix CopyTickVolume calls to use long array
    long volumeData[];
    ArraySetAsSeries(volumeData, true);

    if(CopyTickVolume(_Symbol, MainTimeframe, 0, barsNeeded, volumeData) <= 0 ||
       CopyHigh(_Symbol, MainTimeframe, 0, barsNeeded, highs) <= 0 ||
       CopyLow(_Symbol, MainTimeframe, 0, barsNeeded, lows) <= 0 ||
       CopyClose(_Symbol, MainTimeframe, 0, barsNeeded, closes) <= 0 ||
       CopyOpen(_Symbol, MainTimeframe, 0, barsNeeded, opens) <= 0)
    {
        Print("❌ Strategy Check Failed: Unable to copy price/volume data");
        return false;
    }

    // Convert volume data to double array for calculations
    ArrayResize(volumes, ArraySize(volumeData));
    for(int i = 0; i < ArraySize(volumeData); i++)
    {
        volumes[i] = (double)volumeData[i];
    }
    
    // Check for retest conditions if we have a confirmed breakout
    if (UseRetest && (breakoutState == BREAKOUT_BULL || breakoutState == BREAKOUT_BEAR))
    {
        bool isBullish = (breakoutState == BREAKOUT_BULL);
        
        // Start tracking retest if price returns to level
        if(retestStartTime == 0)
        {
            double distanceFromLevel = isBullish ? 
                                     MathAbs(breakoutLevel - lows[0]) :
                                     MathAbs(highs[0] - breakoutLevel);
                                     
            if(distanceFromLevel <= atr * RetestATRThreshold)
            {
                retestStartTime = iTime(_Symbol, MainTimeframe, 0);
                retestBars = 1;
                retestVolume = volumes[0];
                breakoutState = isBullish ? RETEST_BULL : RETEST_BEAR;
                Print("📊 Retest Analysis | State: Started | Distance: ", NormalizeDouble(distanceFromLevel/Point(), 1), 
                      " pips | ATR Threshold: ", NormalizeDouble(atr * RetestATRThreshold/Point(), 1), " pips");
            }
            else
            {
                Print("📊 Retest Analysis | State: Waiting | Distance: ", NormalizeDouble(distanceFromLevel/Point(), 1),
                      " pips | Required: ", NormalizeDouble(atr * RetestATRThreshold/Point(), 1), " pips");
            }
        }
        else
        {
            // Update retest tracking
            retestBars++;
            retestVolume = (retestVolume * (retestBars - 1) + volumes[0]) / retestBars;
            
            // Validate retest conditions
            string retestDesc;
            if(ValidateRetest(highs, lows, closes, volumes, isBullish, atr, retestDesc))
            {
                // Generate signal if direction matches
                if((isBullish && isBuy) || (!isBullish && !isBuy))
                {
                    signalReason = StringFormat("%s retest confirmed | %s", 
                                              (isBullish ? "Bullish" : "Bearish"),
                                              retestDesc);
                    Print("✅ Retest Validated | ", signalReason);
                    return true;
                }
            }
            else
            {
                Print("📊 Retest Progress | ", retestDesc);
            }
        }
    }
    
    // Look for new breakouts if we haven't identified one
    if(breakoutState == NO_BREAKOUT)
    {
        double minBreakoutDistance = atr * MinBreakoutATR;
        
        // Find or update key level
        double newKeyLevel;
        bool newIsResistance;
        
        if(FindKeyLevel(newKeyLevel, newIsResistance))
        {
            // Validate level significance before proceeding
            if(MathAbs(newKeyLevel - currentClose) < minBreakoutDistance)
            {
                Print("❌ Level Check Failed | Too close to price | Distance: ", 
                      NormalizeDouble(MathAbs(newKeyLevel - currentClose)/Point(), 1), 
                      " pips | Required: ", NormalizeDouble(minBreakoutDistance/Point(), 1), " pips");
                return false;
            }
                
            // If we found a new key level that's significantly different from the last one
            if(MathAbs(newKeyLevel - lastKeyLevel) > LevelTolerance || lastKeyLevel == 0)
            {
                // Reset state before updating to new level
                breakoutState = NO_BREAKOUT;
                breakoutTime = 0;
                breakoutLevel = 0;
                retestStartTime = 0;
                retestBars = 0;
                retestVolume = 0;
                retestConfirmed = false;
                
                // Update to new level
                lastKeyLevel = newKeyLevel;
                lastKeyLevelTime = iTime(_Symbol, MainTimeframe, 0);
                isKeyLevelResistance = newIsResistance;
                
                Print("📊 Level Analysis | New Level: ", newKeyLevel, 
                      " | Type: ", (isKeyLevelResistance ? "Resistance" : "Support"),
                      " | Distance: ", NormalizeDouble(MathAbs(newKeyLevel - currentClose)/Point(), 1), " pips");
            }
            
            // Analyze potential breakout
            int consecutiveBreakoutBars = 0;
            double maxMoveFromLevel = 0;
            double totalMomentum = 0;
            
            // First pass: analyze price action and momentum
            for(int i = 0; i < MaxBreakoutBars; i++)
            {
                // Calculate bar metrics
                double barRange = highs[i] - lows[i];
                double barBody = MathAbs(closes[i] - closes[i+1]);
                
                // Check both close and high/low for breakout confirmation
                double breakoutTolerance = atr * 0.2;  // Allow small pullbacks
// Simplified check - only verify if close is beyond level
bool barBeyondLevel = isKeyLevelResistance ? 
                    (closes[i] > lastKeyLevel) :
                    (closes[i] < lastKeyLevel);
                                    
                if(!barBeyondLevel)
                {
                    Print("📊 Breakout Analysis | Bar ", i, " failed beyond level check | Close: ", closes[i],
                          " | Level: ", lastKeyLevel, " | Tolerance: ", NormalizeDouble(breakoutTolerance/Point(), 1), " pips");
                    break;
                }
                
                consecutiveBreakoutBars++;
                
                // Calculate and accumulate directional momentum
                double moveFromLevel = isKeyLevelResistance ? 
                                     closes[i] - lastKeyLevel : 
                                     lastKeyLevel - closes[i];
                                     
                maxMoveFromLevel = MathMax(maxMoveFromLevel, MathAbs(moveFromLevel));
                
                // Weight momentum by relative volume
                double volumeWeight = volumes[i] / volumes[ArrayMaximum(volumes, 0, i+1)];
                totalMomentum += (moveFromLevel / atr) * volumeWeight;
            }
            
            // Only proceed if we have enough consecutive bars and momentum
            if(consecutiveBreakoutBars < MinBreakoutBars)
            {
                if(ShowDebugPrints)
                {
                    Print("❌ Breakout Failed | Insufficient consecutive bars | Got: ", consecutiveBreakoutBars,
                          " | Required: ", MinBreakoutBars);
                }
                return false;
            }
            
            if(MathAbs(totalMomentum) <= 0.2)
            {
                if(ShowDebugPrints)
                {
                    Print("❌ Breakout Failed | momentum < 0.2");
                }
                return false;
            }
            
            // Analyze volume patterns
            double volumeRatio, avgVolume;
            bool hasVolume = true;  // Skip volume checks for testing
            
            // Check price action quality
            bool hasCleanBreakout = true;  // Skip price action checks for testing
            
            // Validate breakout conditions
            bool hasStrength = maxMoveFromLevel > minBreakoutDistance;
            bool hasStructure = true;  // Structure check already returns true
            
            // Log validation results
            if(ShowDebugPrints)
            {
                Print("📊 Breakout Validation: ",
                      "\nStrength: ", (hasStrength ? "✅" : "❌"), " (Move: ", NormalizeDouble(maxMoveFromLevel/Point(), 1), " pips)",
                      "\nMomentum: ", NormalizeDouble(totalMomentum, 2));
            }
            
            // Simplified validation - only check strength and minimum momentum
            bool isValidBreakout = hasStrength && MathAbs(totalMomentum) > 0.2;
            
            if(isValidBreakout)
            {
                bool isBullish = isKeyLevelResistance;
                
                // Only trigger if direction matches request and momentum aligns
                if((isBullish && isBuy && totalMomentum > 0) || 
                   (!isBullish && !isBuy && totalMomentum < 0))
                {
                    breakoutState = isBullish ? BREAKOUT_BULL : BREAKOUT_BEAR;
                    breakoutTime = iTime(_Symbol, MainTimeframe, 0);
                    breakoutLevel = lastKeyLevel;
                    
                    signalReason = StringFormat("%s breakout confirmed | Move: %.2f ATR | Momentum: %.2f | Bars: %d | PA: %s | Vol: %.0f%%", 
                                              (isBullish ? "Bullish" : "Bearish"),
                                              maxMoveFromLevel/atr,
                                              MathAbs(totalMomentum),
                                              (hasCleanBreakout ? "Clean" : "Choppy"),
                                              volumeRatio * 100);
                    if(ShowDebugPrints)
                    {
                        Print("✅ Breakout Validated | ", signalReason);
                    }
                    return true;
                }
                else
                {
                    if(ShowDebugPrints)
                    {
                        Print("❌ Direction Mismatch | Request: ", (isBuy ? "Buy" : "Sell"),
                              " | Breakout: ", (isBullish ? "Bullish" : "Bearish"),
                              " | Momentum: ", NormalizeDouble(totalMomentum, 2));
                    }
                }
            }
        }
        else
        {
            if(ShowDebugPrints)
            {
                Print("📊 Level Analysis | No valid key level found");
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calculate array average                                            |
//+------------------------------------------------------------------+
double ArrayAverage(const double &array[], int count)
{
    if(count <= 0) return 0;
    
    double sum = 0;
    for(int i = 0; i < count; i++)
        sum += array[i];
        
    return sum / count;
}

//+------------------------------------------------------------------+
//| Get entry signal                                                    |
//+------------------------------------------------------------------+
bool GetEntrySignal(bool isBuy, string &signalReason)
{
    switch(StrategyType)
    {
        case STRAT_EMA_CROSS:
            return EMACrossStrategy(isBuy, signalReason);
            
        case STRAT_BREAKOUT_RETEST:
            return BreakoutRetestStrategy(isBuy, signalReason);
            
        case STRAT_CUSTOM:
            // Add your custom strategy here
            signalReason = "Custom strategy not implemented yet";
            return false;
            
        default:
            signalReason = "Unknown strategy type";
            return false;
    }
}

//+------------------------------------------------------------------+
//| Find recent swing high/low                                         |
//+------------------------------------------------------------------+
bool FindSwingPoints(bool isBuy, double &swingTarget)
{
    double highs[], lows[];
    ArraySetAsSeries(highs, true);
    ArraySetAsSeries(lows, true);
    
    if(CopyHigh(_Symbol, MainTimeframe, 0, SwingLookback, highs) <= 0 ||
       CopyLow(_Symbol, MainTimeframe, 0, SwingLookback, lows) <= 0)
        return false;
        
    double extremeLevel = 0;
    if(isBuy)
    {
        // For buy trades, find recent swing high
        for(int i = 2; i < SwingLookback-2; i++)
        {
            if(highs[i] > highs[i-1] && highs[i] > highs[i-2] &&
               highs[i] > highs[i+1] && highs[i] > highs[i+2])
            {
                extremeLevel = highs[i];
                break;
            }
        }
    }
    else
    {
        // For sell trades, find recent swing low
        for(int i = 2; i < SwingLookback-2; i++)
        {
            if(lows[i] < lows[i-1] && lows[i] < lows[i-2] &&
               lows[i] < lows[i+1] && lows[i] < lows[i+2])
            {
                extremeLevel = lows[i];
                break;
            }
        }
    }
    
    if(extremeLevel != 0)
    {
        swingTarget = extremeLevel;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calculate Fibonacci extension levels                               |
//+------------------------------------------------------------------+
void CalculateFibTargets(bool isBuy, double entryPrice, double &fib1, double &fib2)
{
    double swingTarget;
    if(!FindSwingPoints(isBuy, swingTarget))
    {
        // If no swing point found, use ATR-based targets
        double atr = GetIndicatorValue(handleATR, 0);
        fib1 = isBuy ? entryPrice + (atr * Fib1Level) : entryPrice - (atr * Fib1Level);
        fib2 = isBuy ? entryPrice + (atr * Fib2Level) : entryPrice - (atr * Fib2Level);
        return;
    }
    
    double moveSize = MathAbs(swingTarget - entryPrice);
    if(isBuy)
    {
        fib1 = entryPrice + (moveSize * Fib1Level);
        fib2 = entryPrice + (moveSize * Fib2Level);
    }
    else
    {
        fib1 = entryPrice - (moveSize * Fib1Level);
        fib2 = entryPrice - (moveSize * Fib2Level);
    }
}

//+------------------------------------------------------------------+
//| Calculate dynamic SL/TP levels                                     |
//+------------------------------------------------------------------+
void GetDynamicSLTP(bool isBuy, double &sl, double &tp)
{
    double atr = GetIndicatorValue(handleATR, 0);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    // Get retest candle's high/low using the stored index
    double retestLow = iLow(_Symbol, MainTimeframe, retestCandleIndex);
    double retestHigh = iHigh(_Symbol, MainTimeframe, retestCandleIndex);
    
    // Calculate ATR-based distances
    double slDistance = atr * SLMultiplier;
    double tpDistance = slDistance * MinRiskRewardRatio;  // Base TP on minimum R:R
    double buffer = SLBufferPips * point;
    
    double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // Calculate stop loss
    if(isBuy)
    {
        double atrBasedSL = currentPrice - slDistance - buffer;
        double retestBasedSL = retestLow - buffer;
        sl = MathMax(atrBasedSL, retestBasedSL);  // Use the higher (more conservative) SL
    }
    else
    {
        double atrBasedSL = currentPrice + slDistance + buffer;
        double retestBasedSL = retestHigh + buffer;
        sl = MathMin(atrBasedSL, retestBasedSL);  // Use the lower (more conservative) SL
    }
    
    // Calculate take profit targets
    double rrBasedTP = isBuy ? currentPrice + tpDistance : currentPrice - tpDistance;
    
    if(UseFibonacciTargets)
    {
        double fib1Target, fib2Target;
        CalculateFibTargets(isBuy, currentPrice, fib1Target, fib2Target);
        
        // Use the closer of Fib1 or RR-based target as TP
        double slDistance = MathAbs(currentPrice - sl);
        double fib1Distance = MathAbs(fib1Target - currentPrice);
        double rrDistance = MathAbs(rrBasedTP - currentPrice);
        
        // Ensure minimum R:R is maintained
        if(fib1Distance >= slDistance * MinRiskRewardRatio)
        {
            tp = fib1Target;  // Use Fib target if it provides better R:R
        }
        else
        {
            tp = rrBasedTP;   // Otherwise use R:R based target
        }
        
        Print("Take Profit Analysis | RR-based: ", rrBasedTP, 
              " | Fib1: ", fib1Target,
              " | Fib2: ", fib2Target,
              " | Selected: ", tp);
    }
    else
    {
        tp = rrBasedTP;  // Use simple R:R based target if Fibonacci is disabled
    }
    
    Print((isBuy ? "BUY" : "SELL"), " Order Levels | Entry: ", currentPrice,
          " | SL: ", sl, " (", NormalizeDouble(MathAbs(currentPrice-sl)/point, 1), " pips)",
          " | TP: ", tp, " (", NormalizeDouble(MathAbs(tp-currentPrice)/point, 1), " pips)");
}

//+------------------------------------------------------------------+
//| Check if current time is within active trading sessions            |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
    if(!RestrictTradingHours)
        return true;
        
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    // First check if we're within Forex.com's trading hours (UTC)
    // Trading week: Sunday 22:00 UTC to Friday 22:00 UTC
    
    // Convert current GMT+2 to UTC (subtract 2 hours)
    int utcHour = (dt.hour - 2 + 24) % 24;
    
    // Check if it's weekend closure
    if(dt.day_of_week == 6) // Saturday
        return false;
    if(dt.day_of_week == 0 && utcHour < 22) // Sunday before 22:00 UTC
        return false;
    if(dt.day_of_week == 5 && utcHour >= 22) // Friday after 22:00 UTC
        return false;
        
    // If we want to restrict to specific sessions
    if(RestrictTradingHours)
    {
        // Get current hour in GMT+2
        int currentHour = dt.hour;
        
        // Determine if US is in DST
        bool isUSinDST = false;
        
        // US DST starts second Sunday in March
        if(dt.mon == 3 && dt.day > 7 && dt.day <= 14 && dt.day_of_week == 0)
            isUSinDST = dt.hour >= 2;
        else if(dt.mon == 3 && dt.day > 14)
            isUSinDST = true;
        // US DST ends first Sunday in November
        else if(dt.mon == 11 && dt.day <= 7 && dt.day_of_week == 0)
            isUSinDST = dt.hour < 2;
        else if(dt.mon == 11 && dt.day > 7)
            isUSinDST = false;
        else if(dt.mon > 3 && dt.mon < 11)
            isUSinDST = true;
            
        // Calculate offset from NY time to GMT+2
        int hourOffset = isUSinDST ? 6 : 7;  // GMT+2 is 6 hours ahead during DST, 7 hours ahead during standard time
        
        // Convert current GMT+2 hour to NY time
        int nyHour = (currentHour - hourOffset + 24) % 24;
        
        // Check if within London session (convert input times from NY to GMT+2)
        bool inLondon = (currentHour >= (LondonStartHour + hourOffset) % 24 && 
                        currentHour < (LondonEndHour + hourOffset) % 24);
        
        // Check if within New York session (convert input times from NY to GMT+2)
        bool inNewYork = (currentHour >= (NewYorkStartHour + hourOffset) % 24 && 
                         currentHour < (NewYorkEndHour + hourOffset) % 24);
        
        // Print session status for debugging (only once per hour)
        if(MathMod(dt.min, 60) == 0)
        {
            if(ShowDebugPrints)
            {
                Print("Session Check | GMT+2 Hour: ", currentHour, 
                      " | NY Hour: ", nyHour,
                      " | UTC Hour: ", utcHour,
                      " | DST: ", (isUSinDST ? "Yes" : "No"),
                      " | London: ", (inLondon ? "Active" : "Closed"),
                      " | NY: ", (inNewYork ? "Active" : "Closed"));
            }
        }
        
        // Return true if within either session
        return (inLondon || inNewYork);
    }
    
    // If not restricting to specific sessions, return true if within general forex trading hours
    return true;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check for new bar
    datetime currentBar = iTime(_Symbol, MainTimeframe, 0);
    if(currentBar <= lastBarTime)
        return;
        
    lastBarTime = currentBar;
    
    // Check if within trading hours
    if(!IsWithinTradingHours())
    {
        Print("Outside trading hours - No new trades");
        return;
    }
    
    // Update SL/TP for existing positions on each new bar
    if(tradeDirection != 0)
    {
        UpdatePositionSLTP();
    }
    
    // Process signals only on new bar
    if(tradeDirection == 0) // No position
    {
        OpenPositionOnSignal();
    }
    else // Have position
    {
        // Check for exit signal
        string exitSignalReason = "";
        bool buySignal = GetEntrySignal(true, exitSignalReason);
        bool sellSignal = GetEntrySignal(false, exitSignalReason);
        
        if((tradeDirection == 1 && sellSignal) ||
           (tradeDirection == -1 && buySignal))
        {
            if(CloseAllPositions())
            {
                int oldDirection = tradeDirection;
                tradeDirection = 0;
                Print("Position closed - Opposite signal detected");
                
                // Immediately open position in the new direction
                if(oldDirection == 1 && sellSignal)
                {
                    OpenNewPosition(false, exitSignalReason);  // Open sell position
                }
                else if(oldDirection == -1 && buySignal)
                {
                    OpenNewPosition(true, exitSignalReason);   // Open buy position
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Get indicator buffer value                                          |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int shift, int buffer = 0)
{
    double value[];
    ArraySetAsSeries(value, true);
    
    if(CopyBuffer(handle, buffer, shift, 1, value) > 0)
        return value[0];
        
    return 0.0;
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                             |
//+------------------------------------------------------------------+
double CalculateLotSize(double riskPercent, double slDistance)
{
    // Use equity instead of balance for more accurate risk calculation
    double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double riskAmount = accountEquity * (riskPercent / 100.0);
    
    // Add protection against negative or zero equity
    if(accountEquity <= 0)
    {
        Print("❌ Error: Invalid account equity value: ", accountEquity);
        return 0;
    }
    
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    if(tickSize == 0 || slDistance == 0)
    {
        Print("❌ Error: Invalid tick size or SL distance - Tick Size: ", tickSize, " SL Distance: ", slDistance);
        return 0;
    }
    
    // Calculate lots based on risk first
    double riskedLots = riskAmount / (slDistance * (tickValue / tickSize));
    
    // Normalize lot size
    riskedLots = MathFloor(riskedLots / lotStep) * lotStep;
    
    // Apply lot limits
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    riskedLots = MathMax(minLot, MathMin(maxLot, riskedLots));
    
    // Calculate margin requirement using contract size and price
    double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
    
    if(leverage <= 0) leverage = 100; // Default to 1:100 if leverage info not available
    
    // Calculate margin requirement per lot
    double marginPerLot = (contractSize * price) / leverage;
    
    // Calculate maximum lots based on available margin (use 30% of free margin)
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    double maxLotsMargin = (freeMargin * 0.3) / marginPerLot;
    
    // Take the smaller of risk-based and margin-based lot sizes
    double finalLots = MathMin(riskedLots, maxLotsMargin);
    finalLots = MathFloor(finalLots / lotStep) * lotStep;
    finalLots = MathMax(minLot, MathMin(maxLot, finalLots));
    
    // Final margin check
    double requiredMargin = finalLots * marginPerLot;
    
    Print("💰 Position Size Calculation:",
          "\nEquity: ", accountEquity,
          "\nRisk Amount: ", riskAmount,
          "\nSL Distance: ", slDistance,
          "\nFree Margin: ", freeMargin,
          "\nMargin per Lot: ", marginPerLot,
          "\nMax Lots (Margin): ", maxLotsMargin,
          "\nMax Lots (Risk): ", riskedLots,
          "\nFinal Lots: ", finalLots,
          "\nRequired Margin: ", requiredMargin);
    
    if(requiredMargin > freeMargin * 0.3)
    {
        Print("❌ Error: Final margin check failed - Required: ", requiredMargin,
              " Available: ", freeMargin * 0.3);
        return 0;
    }
    
    return NormalizeDouble(finalLots, 2);
}

//+------------------------------------------------------------------+
//| Close all open positions                                          |
//+------------------------------------------------------------------+
bool CloseAllPositions()
{
    bool success = true;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
            bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
            double closePrice = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double profit = PositionGetDouble(POSITION_PROFIT);
            
            if(!trade.PositionClose(ticket))
            {
                Print("❌ Failed to close position #", ticket, ". Error: ", GetLastError());
                success = false;
            }
            else
            {
                Print((isLong ? "🔵" : "🔴"), " Closed ", (isLong ? "LONG" : "SHORT"), " #", ticket,
                      " | Profit: $", NormalizeDouble(profit, 2),
                      " (", NormalizeDouble(MathAbs(closePrice-openPrice)/Point(), 1), " pips)");
            }
        }
    }

    // Reset breakout state and related variables if positions were closed successfully
    if(success)
    {
        string oldState;
        switch(breakoutState)
        {
            case BREAKOUT_BULL: oldState = "BREAKOUT_BULL"; break;
            case BREAKOUT_BEAR: oldState = "BREAKOUT_BEAR"; break;
            case RETEST_BULL: oldState = "RETEST_BULL"; break;
            case RETEST_BEAR: oldState = "RETEST_BEAR"; break;
            default: oldState = "UNKNOWN"; break;
        }
        
        // Reset all breakout-related state
        breakoutState = NO_BREAKOUT;
        breakoutTime = 0;
        breakoutLevel = 0;
        retestStartTime = 0;
        retestBars = 0;
        retestVolume = 0;
        retestConfirmed = false;
        retestCandleIndex = -1;
        lastKeyLevel = 0;
        lastKeyLevelTime = 0;
        
        // Reset zone-related state
        zoneActive = false;
        currentZone.level = 0;
        currentZone.touchCount = 0;
        currentZone.lastTouchBar = 0;
        currentZone.isResistance = false;
        currentZone.firstTouch = 0;
        currentZone.lastTouch = 0;
        
        if(ShowDebugPrints)
        {
            Print("🔄 Reset breakout state from ", oldState, " to NO_BREAKOUT & zoneActive=false | Ready for new zone detection");
        }
    }
    
    return success;
}

//+------------------------------------------------------------------+
//| Process signals and open position if needed                        |
//+------------------------------------------------------------------+
void OpenPositionOnSignal()
{
    string signalReason = "";
    bool buySignal = false;
    bool sellSignal = false;
    
    buySignal = GetEntrySignal(true, signalReason);
    if(buySignal)
    {
        OpenNewPosition(true, signalReason);
        return;
    }
    
    sellSignal = GetEntrySignal(false, signalReason);
    if(sellSignal)
    {
        OpenNewPosition(false, signalReason);
    }
}

//+------------------------------------------------------------------+
//| Open a new position based on signal                               |
//+------------------------------------------------------------------+
void OpenNewPosition(bool isBuy, const string &signalReason)
{
    double sl = 0.0, tp = 0.0;
    GetDynamicSLTP(isBuy, sl, tp);
    
    double entryPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double lotSize = CalculateLotSize(RiskPercentage, MathAbs(entryPrice - sl));
    
    if(lotSize == 0)
    {
        Print("❌ Error: Invalid lot size calculated");
        return;
    }
    
    bool success = false;
    if(isBuy)
    {
        success = trade.Buy(lotSize, _Symbol, 0, sl, tp, "Buy Signal");
        if(success)
        {
            tradeDirection = 1;
            Print("🔵 LONG Entry | ", signalReason);
            Print("💰 Price: ", entryPrice, " | SL: ", sl, " (", NormalizeDouble(MathAbs(entryPrice-sl)/Point(), 1), " pips) | ",
                  "TP: ", tp, " (", NormalizeDouble(MathAbs(tp-entryPrice)/Point(), 1), " pips) | Lots: ", lotSize);
        }
    }
    else
    {
        success = trade.Sell(lotSize, _Symbol, 0, sl, tp, "Sell Signal");
        if(success)
        {
            tradeDirection = -1;
            Print("🔴 SHORT Entry | ", signalReason);
            Print("💰 Price: ", entryPrice, " | SL: ", sl, " (", NormalizeDouble(MathAbs(entryPrice-sl)/Point(), 1), " pips) | ",
                  "TP: ", tp, " (", NormalizeDouble(MathAbs(tp-entryPrice)/Point(), 1), " pips) | Lots: ", lotSize);
        }
    }
    
    if(!success)
    {
        Print("❌ ", (isBuy ? "Buy" : "Sell"), " order failed. Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Update SL/TP levels for existing positions                         |
//+------------------------------------------------------------------+
void UpdatePositionSLTP()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
            bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
            double currentPrice = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);
            
            // Calculate current profit in ATR terms
            double atr = GetIndicatorValue(handleATR, 0);
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double profitInPrice = isLong ? (currentPrice - openPrice) : (openPrice - currentPrice);
            double profitInATR = profitInPrice / atr;
            
            // Only trail if we have minimum profit
            if(profitInATR < MinimumProfitToTrail)
                continue;
                
            // Calculate trail distance
            double trailDistance;
            if(UseFixedTrailStep)
            {
                trailDistance = TrailStepPips * point;
            }
            else
            {
                trailDistance = atr * TrailMultiplier;
            }
            
            double buffer = SLBufferPips * point;
            double newSL;
            
            if(isLong)
            {
                newSL = currentPrice - trailDistance - buffer;
                if(newSL > currentSL)
                {
                    trade.PositionModify(ticket, newSL, currentTP);
                    Print("📍 Trail Long #", ticket, " | Profit: ", NormalizeDouble(profitInATR, 2), " ATR | New SL: ", 
                          newSL, " (", NormalizeDouble(MathAbs(currentPrice-newSL)/Point(), 1), " pips from price)");
                }
            }
            else
            {
                newSL = currentPrice + trailDistance + buffer;
                if(newSL < currentSL || currentSL == 0)
                {
                    trade.PositionModify(ticket, newSL, currentTP);
                    Print("📍 Trail Short #", ticket, " | Profit: ", NormalizeDouble(profitInATR, 2), " ATR | New SL: ", 
                          newSL, " (", NormalizeDouble(MathAbs(currentPrice-newSL)/Point(), 1), " pips from price)");
                }
            }
        }
    }
}