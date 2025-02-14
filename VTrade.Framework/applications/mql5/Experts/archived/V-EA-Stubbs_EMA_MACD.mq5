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

// Economic Calendar structures
struct CalendarEvent
{
    string name;
    datetime time;
    string currencyCode;
    int importance;
    ulong id;
};

//--- EA Parameters
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES MainTimeframe = PERIOD_H2;  // Main Trading Timeframe (Standard: H1-H4)

input group "=== EMA Parameters ==="
input int      EmaFastPeriod = 13;        // Fast EMA Period (Standard: 12-13) [5-15, Step: 2]
input int      EmaMidPeriod = 24;        // Mid EMA Period (Standard: 34) [20-40, Step: 4]
input int      EmaSlowPeriod = 33;       // Slow EMA Period (Standard: 50) [21-41, Step: 4]

input group "=== MACD Parameters ==="
input int      MacdFastPeriod = 20;      // MACD Fast Period (Standard: 12) [12-24, Step: 4]
input int      MacdSlowPeriod = 34;      // MACD Slow Period (Standard: 26) [26-38, Step: 4]
input int      MacdSignalPeriod = 15;     // MACD Signal Period (Standard: 9) [9-15, Step: 2]

input group "=== Risk Management ==="
input double   RiskPercentage = 3.0;     // Risk per trade (Standard: 1-2%) [1.0-3.0, Step: 0.5]
input double   MACDThreshold = 0.0010;   // MACD Crossover Threshold (Standard: 0.0003) [0.0002-0.001, Step: 0.0002]
input double   SLBufferPips = 6.0;       // Stop-Loss Buffer in Pips (Standard: 5.0) [4.0-8.0, Step: 0.5]

input group "=== ATR Settings ==="
input int      ATRPeriod = 18;           // ATR Period (Standard: 14-21) [14-26, Step: 2]
input double   ATRMultiplierSL = 10.0;    // ATR Multiplier for Stop Loss (Standard: 2-3) [7.0-11.0, Step: 0.5]
input double   ATRMultiplierTP = 10.5;    // ATR Multiplier for Take Profit (Standard: 3-4) [8.0-12.0, Step: 0.5]

input group "=== Pivot Points & Buffers ==="
input ENUM_TIMEFRAMES PivotTimeframe = PERIOD_D1;  // Timeframe for Pivot Points (Standard: D1)
input bool    UsePivotPoints = true;     // Use Pivot Points for Trading (Standard: true)
input double  PivotBufferPips = 3.0;     // Buffer around pivot levels (Standard: 2-3) [1.0-5.0, Step: 0.5]
input int     ATR_MA_Period = 20;        // Period for Average ATR calculation (Standard: 20) [15-25, Step: 5]
input double  SL_ATR_Mult = 0.5;         // ATR multiplier for SL buffer (Standard: 0.5) [0.3-0.7, Step: 0.1]
input double  TP_ATR_Mult = 0.25;        // ATR multiplier for TP buffer (Standard: 0.3) [0.2-0.4, Step: 0.05]
input double  SL_Dist_Mult = 0.09;       // Distance multiplier for SL buffer (Standard: 0.1) [0.05-0.15, Step: 0.02]
input double  TP_Dist_Mult = 0.06;       // Distance multiplier for TP buffer (Standard: 0.1) [0.04-0.12, Step: 0.02]
input double  Max_Buffer_Pips = 50.0;    // Maximum buffer size in pips (Standard: 40-50) [30-70, Step: 10]

input group "=== Trade Management ==="
input int      EntryTimeoutBars = 12;    // Bars to wait for entry sequence (Standard: 10) [8-14, Step: 2]
input int      HaltMinutesBefore = 60;   // Minutes to halt before news (Standard: 30-60) [30-90, Step: 15]
input int      HaltMinutesAfter = 60;    // Minutes to halt after news (Standard: 30-60) [30-90, Step: 15]

input group "=== Trading Hours ==="
input int      NoTradeStartHour = 21;    // Hour to stop trading (Standard: 22) [21-23, Step: 1]
input int      NoTradeEndHour = 4;       // Hour to resume trading (Standard: 3) [2-4, Step: 1]

input group "=== News Trading ==="
input bool   HaltOnCPI        = true;  // Halt on CPI announcements (Standard: true)
input bool   HaltOnNFP        = true;  // Halt on Non-Farm Payrolls (Standard: true)
input bool   HaltOnFOMC       = true;  // Halt on FOMC meetings (Standard: true)
input bool   HaltOnGDP        = true;  // Halt on GDP reports (Standard: true)
input bool   HaltOnPPI        = true;  // Halt on PPI announcements (Standard: true)
input bool   HaltOnCentralBank = true; // Halt on Central Bank speeches (Standard: true)

//--- Global Variables
int          MagicNumber       = 123456; // Unique identifier for EA's trades
datetime     lastBarTime       = 0;       // Tracks the last processed bar time
datetime     tradeEntryBar     = 0;       // Tracks the bar time when trades were opened
datetime     lastEntryBar      = 0;       // Tracks the bar time of the last successful entry
int          partialClosures   = 0;       // Tracks the number of partial closures done
int          entryPositions    = 0;       // Tracks how many positions we've entered
bool         inEntrySequence   = false;   // Whether we're in the middle of entering positions

// Indicator handles
int          handleEmaFast;
int          handleEmaMid;
int          handleEmaSlow;
int          handleMacd;
int          handleATR;      // ATR indicator handle
int          tradeDirection = 0;   // 0 = No position, 1 = Buy, -1 = Sell

// Pivot Point levels
double       pivotPoint = 0;
double       r1Level = 0;
double       r2Level = 0;
double       r3Level = 0;
double       s1Level = 0;
double       s2Level = 0;
double       s3Level = 0;
datetime     lastPivotCalc = 0;

// Trade object
CTrade      trade;

// Add these as global variables
double averageATR = 0;
int handleAverageATR;

// Add new global variables for caching
double g_lastEmaFast = 0;
double g_lastEmaMid = 0;
double g_lastEmaSlow = 0;
double g_lastMacdMain = 0;
double g_lastMacdSignal = 0;
datetime g_lastCacheTime = 0;

// Add new global variables for pivot caching
double g_lastPivotPoint = 0;
double g_lastR1 = 0, g_lastR2 = 0, g_lastR3 = 0;
double g_lastS1 = 0, g_lastS2 = 0, g_lastS3 = 0;
datetime g_lastPivotCalcTime = 0;

// Add new global variables for position tracking
struct PositionInfo {
    ulong ticket;
    double openPrice;
    datetime openTime;
    double lots;
    ENUM_POSITION_TYPE type;
    double stopLoss;
    double takeProfit;
};

PositionInfo g_positions[];
int g_positionCount = 0;

//+------------------------------------------------------------------+
//| Calculate Pivot Points and Support/Resistance Levels               |
//+------------------------------------------------------------------+
void CalculatePivotPoints()
{
    // Only recalculate at the start of a new period
    datetime currentPeriodStart = iTime(_Symbol, PivotTimeframe, 0);
    if(currentPeriodStart == g_lastPivotCalcTime) return;
    
    g_lastPivotCalcTime = currentPeriodStart;
    
    // Get previous period's high, low, and close
    double prevHigh = iHigh(_Symbol, PivotTimeframe, 1);
    double prevLow = iLow(_Symbol, PivotTimeframe, 1);
    double prevClose = iClose(_Symbol, PivotTimeframe, 1);
    
    // Calculate pivot point
    g_lastPivotPoint = (prevHigh + prevLow + prevClose) / 3.0;
    
    // Calculate resistance levels
    g_lastR1 = (2 * g_lastPivotPoint) - prevLow;
    g_lastR2 = g_lastPivotPoint + (prevHigh - prevLow);
    g_lastR3 = g_lastR2 + (prevHigh - prevLow);
    
    // Calculate support levels
    g_lastS1 = (2 * g_lastPivotPoint) - prevHigh;
    g_lastS2 = g_lastPivotPoint - (prevHigh - prevLow);
    g_lastS3 = g_lastS2 - (prevHigh - prevLow);
    
    pivotPoint = g_lastPivotPoint;
    r1Level = g_lastR1;
    r2Level = g_lastR2;
    r3Level = g_lastR3;
    s1Level = g_lastS1;
    s2Level = g_lastS2;
    s3Level = g_lastS3;
    
    CV2EAUtils::LogInfo("=== PIVOT POINTS UPDATED ===");
    CV2EAUtils::LogInfo(StringFormat("Timeframe: %s", EnumToString(PivotTimeframe)));
    CV2EAUtils::LogInfo(StringFormat("Pivot: %.5f", pivotPoint));
    CV2EAUtils::LogInfo(StringFormat("R1: %.5f R2: %.5f R3: %.5f", r1Level, r2Level, r3Level));
    CV2EAUtils::LogInfo(StringFormat("S1: %.5f S2: %.5f S3: %.5f", s1Level, s2Level, s3Level));
}

//+------------------------------------------------------------------+
//| Check if price is near a pivot level                              |
//+------------------------------------------------------------------+
bool IsPriceNearLevel(const double price, const double level)
{
    static double bufferInPoints = PivotBufferPips * 10.0; // Convert pips to points once
    return (MathAbs(price - level) <= bufferInPoints * _Point);
}

//+------------------------------------------------------------------+
//| Get modified take profit based on pivot levels                     |
//+------------------------------------------------------------------+
double GetPivotBasedTP(bool isBuy, double defaultTP)
{
    if(!UsePivotPoints) return defaultTP;
    
    double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) 
                               : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Find nearest pivot level in profit direction
    double pivotLevel = GetNearestLevel(currentPrice, isBuy);
    if(pivotLevel != 0.0)
        return pivotLevel;
        
    return defaultTP;
}

//+------------------------------------------------------------------+
//| Get modified stop loss based on pivot levels                       |
//+------------------------------------------------------------------+
double GetPivotBasedSL(bool isBuy, double defaultSL)
{
    if(!UsePivotPoints) return defaultSL;
    
    double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) 
                               : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Find nearest pivot level in loss direction
    double pivotLevel = GetNearestLevel(currentPrice, !isBuy);
    if(pivotLevel != 0.0)
        return pivotLevel;
        
    return defaultSL;
}

//+------------------------------------------------------------------+
//| Get nearest pivot level (support or resistance)                    |
//+------------------------------------------------------------------+
double GetNearestLevel(const double price, const bool resistance)
{
    if(!UsePivotPoints) return 0.0;
    
    if(resistance)
    {
        // Find nearest resistance level using cached values
        double levels[3] = {g_lastR1, g_lastR2, g_lastR3};
        double nearestLevel = g_lastR1;
        double minDistance = MathAbs(price - g_lastR1);
        
        for(int i = 1; i < 3; i++)
        {
            double distance = MathAbs(price - levels[i]);
            if(distance < minDistance && levels[i] > price)
            {
                minDistance = distance;
                nearestLevel = levels[i];
            }
        }
        return nearestLevel;
    }
    else
    {
        // Find nearest support level using cached values
        double levels[3] = {g_lastS1, g_lastS2, g_lastS3};
        double nearestLevel = g_lastS1;
        double minDistance = MathAbs(price - g_lastS1);
        
        for(int i = 1; i < 3; i++)
        {
            double distance = MathAbs(price - levels[i]);
            if(distance < minDistance && levels[i] < price)
            {
                minDistance = distance;
                nearestLevel = levels[i];
            }
        }
        return nearestLevel;
    }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize EMA indicators
    handleEmaFast = iMA(_Symbol, MainTimeframe, EmaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
    handleEmaMid  = iMA(_Symbol, MainTimeframe, EmaMidPeriod,  0, MODE_EMA, PRICE_CLOSE);
    handleEmaSlow = iMA(_Symbol, MainTimeframe, EmaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
    
    // Initialize MACD indicator
    handleMacd = iMACD(_Symbol, MainTimeframe, MacdFastPeriod, MacdSlowPeriod, MacdSignalPeriod, PRICE_CLOSE);
    
    // Initialize ATR indicator
    handleATR = iATR(_Symbol, MainTimeframe, ATR_MA_Period);
    
    // Initialize Average ATR indicator
    handleAverageATR = iMA(_Symbol, MainTimeframe, ATR_MA_Period, 0, MODE_SMA, handleATR);
    
    // Check if indicators are initialized successfully
    if(handleEmaFast == INVALID_HANDLE || handleEmaMid == INVALID_HANDLE || 
       handleEmaSlow == INVALID_HANDLE || handleMacd == INVALID_HANDLE || 
       handleATR == INVALID_HANDLE)
    {
        CV2EAUtils::LogError("Failed to initialize indicators");
        return(INIT_FAILED);
    }
    
    if(handleAverageATR == INVALID_HANDLE)
    {
        CV2EAUtils::LogError("Failed to initialize Average ATR indicator");
        return(INIT_FAILED);
    }
    
    // Set magic number and trade settings
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetMarginMode();
    trade.SetTypeFillingBySymbol(_Symbol);
    
    CV2EAUtils::LogSuccess(StringFormat("EA initialized successfully on %s %s", _Symbol, EnumToString(MainTimeframe)));
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
    IndicatorRelease(handleMacd);
    IndicatorRelease(handleATR);
    
    CV2EAUtils::LogInfo("EA Deinitialized.");
}

//+------------------------------------------------------------------+
//| Check if event name matches major news events                     |
//+------------------------------------------------------------------+
bool IsHighImpactNews(string eventName)
{
    string eventUpper = StringToUpper(eventName);
    string impact;
    
    switch(eventUpper)
    {
        case "CPI": impact = "High"; break;
        case "NFP": impact = "High"; break;
        case "FOMC": impact = "High"; break;
        case "GDP": impact = "Medium"; break;
        default: impact = "None"; break;
    }
    CV2EAUtils::LogInfo(StringFormat("Event Impact: %s", impact));
    CV2EAUtils::LogInfo(StringFormat("Country Code: %s", events[i].currencyCode));
    return true;
}

//+------------------------------------------------------------------+
//| Get upcoming calendar events                                      |
//+------------------------------------------------------------------+
int GetUpcomingEvents(CalendarEvent &events[])
{
    datetime currentTime = TimeCurrent();
    datetime endTime = currentTime + 24*60*60; // Look 24 hours ahead
    
    int count = 0;
    MqlCalendarValue values[];
    MqlCalendarEvent calendarEvents[];
    
    // Get calendar events for the next 24 hours
    if(CalendarValueHistory(values, currentTime, endTime, NULL, NULL))
    {
        for(int i = 0; i < ArraySize(values); i++)
        {
            MqlCalendarEvent event;
            if(CalendarEventById(values[i].event_id, event))
            {
                if(IsHighImpactNews(event.name))
                {
                    ArrayResize(events, count + 1);
                    events[count].name = event.name;
                    events[count].time = values[i].time;
                    
                    // Get the event source country
                    string countryCode = "";
                    MqlCalendarCountry country;
                    if(CalendarCountryById(event.country_id, country))
                        countryCode = country.code;
                    else
                        CV2EAUtils::LogError(StringFormat("Failed to get country data for event ID: %d\nError code: %d", event.country_id, GetLastError()));
                        
                    events[count].currencyCode = countryCode;
                    events[count].importance = (int)event.importance;
                    events[count].id = event.id;
                    count++;
                }
            }
            else
            {
                CV2EAUtils::LogError(StringFormat("Failed to get event details for event ID: %d\nError code: %d", values[i].event_id, GetLastError()));
            }
        }
    }
    else
    {
        CV2EAUtils::LogError(StringFormat("Failed to retrieve calendar history\nPeriod: %s to %s\nError code: %d", TimeToString(currentTime), TimeToString(endTime), GetLastError()));
    }
    
    return count;
}

//+------------------------------------------------------------------+
//| Check if trading should be halted due to economic events          |
//+------------------------------------------------------------------+
bool ShouldHaltTrading()
{
    datetime currentTime = TimeCurrent();
    CalendarEvent events[];
    
    int eventCount = GetUpcomingEvents(events);
    
    for(int i = 0; i < eventCount; i++)
    {
        if(currentTime >= (events[i].time - HaltMinutesBefore * 60) &&
           currentTime <= (events[i].time + HaltMinutesAfter * 60))
        {
            CV2EAUtils::LogInfo("=== TRADING HALTED ===");
            CV2EAUtils::LogInfo(StringFormat("Reason: High-impact news event active\nEvent: %s\nEvent Time: %s", events[i].name, TimeToString(events[i].time)));
            CV2EAUtils::LogInfo(StringFormat("Halt Period: %s to %s", TimeToString(events[i].time - HaltMinutesBefore * 60), TimeToString(events[i].time + HaltMinutesAfter * 60)));
            
            string impact = "";
            switch(events[i].importance)
            {
                case 3: impact = "High";   break;
                case 2: impact = "Medium"; break;
                case 1: impact = "Low";    break;
                default: impact = "None";  break;
            }
            CV2EAUtils::LogInfo(StringFormat("Event Impact: %s", impact));
            CV2EAUtils::LogInfo(StringFormat("Country Code: %s", events[i].currencyCode));
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Generate Hourly Trend Report                                       |
//+------------------------------------------------------------------+
void GenerateHourlyReport()
{
    static datetime lastReportTime = 0;
    datetime currentTime = TimeCurrent();
    
    // Only generate report at the start of each hour
    MqlDateTime dt_struct;
    TimeToStruct(currentTime, dt_struct);
    
    // Changed condition to ensure we only report once per hour
    if(dt_struct.min != 0 || dt_struct.sec != 0 || currentTime <= lastReportTime)
        return;
        
    lastReportTime = currentTime;
    
    // Get current indicator values
    double emaFastCurr = GetIndicatorValue(handleEmaFast, 0);
    double emaMidCurr = GetIndicatorValue(handleEmaMid, 0);
    double emaSlowCurr = GetIndicatorValue(handleEmaSlow, 0);
    double macdMainCurr = GetIndicatorValue(handleMacd, 0, 0);
    double macdSignalCurr = GetIndicatorValue(handleMacd, 0, 1);
    
    // Calculate trend strength based on EMA alignment
    double emaTrendStrength = 0;
    string emaAlignment = "";
    
    if(emaFastCurr > emaMidCurr && emaMidCurr > emaSlowCurr)
    {
        emaTrendStrength = ((emaFastCurr - emaSlowCurr) / emaSlowCurr) * 10000; // Convert to basis points
        emaAlignment = "BULLISH";
    }
    else if(emaFastCurr < emaMidCurr && emaMidCurr < emaSlowCurr)
    {
        emaTrendStrength = ((emaSlowCurr - emaFastCurr) / emaSlowCurr) * 10000; // Convert to basis points
        emaAlignment = "BEARISH";
    }
    else
    {
        emaAlignment = "MIXED";
    }
    
    // Calculate MACD signal strength
    double macdStrength = (macdMainCurr - macdSignalCurr) * 10000; // Convert to basis points
    string macdTrend = macdStrength > 0 ? "BULLISH" : "BEARISH";
    
    // Calculate overall trend score (0-100)
    double trendScore = 50; // Start at neutral
    
    // Add EMA contribution (up to ±30 points)
    if(emaAlignment != "MIXED")
    {
        double emaContribution = MathMin(MathAbs(emaTrendStrength), 30);
        trendScore += (emaAlignment == "BULLISH" ? emaContribution : -emaContribution);
    }
    
    // Add MACD contribution (up to ±20 points)
    double macdContribution = MathMin(MathAbs(macdStrength), 20);
    trendScore += (macdStrength > 0 ? macdContribution : -macdContribution);
    
    // Print the report
    CV2EAUtils::LogInfo("=== HOURLY TREND REPORT ===");
    CV2EAUtils::LogInfo(StringFormat("Time: %s", TimeToString(currentTime)));
    CV2EAUtils::LogInfo("EMA Analysis:");
    CV2EAUtils::LogInfo(StringFormat("  - Alignment: %s", emaAlignment));
    CV2EAUtils::LogInfo(StringFormat("  - Trend Strength: %.2f basis points", emaTrendStrength));
    CV2EAUtils::LogInfo("MACD Analysis:");
    CV2EAUtils::LogInfo(StringFormat("  - Direction: %s", macdTrend));
    CV2EAUtils::LogInfo(StringFormat("  - Signal Strength: %.2f basis points", MathAbs(macdStrength)));
    CV2EAUtils::LogInfo(StringFormat("Overall Trend Score: %.1f/100", trendScore));
    CV2EAUtils::LogInfo("  - Above 70: Strong Bullish");
    CV2EAUtils::LogInfo("  - 55-70: Moderate Bullish");
    CV2EAUtils::LogInfo("  - 45-55: Neutral");
    CV2EAUtils::LogInfo("  - 30-45: Moderate Bearish");
    CV2EAUtils::LogInfo("  - Below 30: Strong Bearish");
    
    // Add trading suggestion based on score
    string suggestion = "";
    if(trendScore >= 70) suggestion = "Consider LONG positions on pullbacks";
    else if(trendScore >= 55) suggestion = "Look for LONG opportunities with confirmation";
    else if(trendScore > 45) suggestion = "Wait for clearer directional signals";
    else if(trendScore > 30) suggestion = "Look for SHORT opportunities with confirmation";
    else suggestion = "Consider SHORT positions on rallies";
    
    CV2EAUtils::LogInfo(StringFormat("Trading Suggestion: %s", suggestion));
    CV2EAUtils::LogInfo("========================");
}

//+------------------------------------------------------------------+
//| Get cached indicator values                                        |
//+------------------------------------------------------------------+
bool GetCachedIndicatorValues(datetime currentTime, int shift,
    double &emaFast, double &emaMid, double &emaSlow,
    double &macdMain, double &macdSignal)
{
    // Only recalculate if we're on a new bar or values not cached
    if(currentTime != g_lastCacheTime || shift > 0)
    {
        emaFast = GetIndicatorValue(handleEmaFast, shift);
        emaMid = GetIndicatorValue(handleEmaMid, shift);
        emaSlow = GetIndicatorValue(handleEmaSlow, shift);
        macdMain = GetIndicatorValue(handleMacd, shift, 0);
        macdSignal = GetIndicatorValue(handleMacd, shift, 1);
        
        if(shift == 0)
        {
            g_lastEmaFast = emaFast;
            g_lastEmaMid = emaMid;
            g_lastEmaSlow = emaSlow;
            g_lastMacdMain = macdMain;
            g_lastMacdSignal = macdSignal;
            g_lastCacheTime = currentTime;
        }
    }
    else
    {
        emaFast = g_lastEmaFast;
        emaMid = g_lastEmaMid;
        emaSlow = g_lastEmaSlow;
        macdMain = g_lastMacdMain;
        macdSignal = g_lastMacdSignal;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Update position tracking at the start of each tick
    UpdatePositionTracking();
    
    // Calculate pivot points if enabled
    if(UsePivotPoints)
        CalculatePivotPoints();
    
    // Generate hourly report first
    GenerateHourlyReport();
    
    // Check if it's Sunday - never trade on Sundays
    MqlDateTime dt_struct;
    TimeToStruct(TimeCurrent(), dt_struct);
    if(dt_struct.day_of_week == 0)  // Sunday
        return;
        
    // Check if current time is within no-trade hours
    int currentHour = dt_struct.hour;
    if(currentHour >= NoTradeStartHour && currentHour < NoTradeEndHour)
        return;
        
    // Check for economic events that should halt trading
    if(ShouldHaltTrading())
        return;
        
    // Check for take profit on existing positions first
    CheckTakeProfit();
    
    //--- Check for new 2-hour bar
    datetime currentBar = iTime(_Symbol, MainTimeframe, 0);
    if(currentBar <= lastBarTime)
        return; // No new bar yet
    
    // Once we detect a new bar, update lastBarTime
    lastBarTime = currentBar;
    
    // Check for entry sequence timeout
    if(inEntrySequence && currentBar > tradeEntryBar + (EntryTimeoutBars * PeriodSeconds(MainTimeframe)))
    {
        inEntrySequence = false;
        CV2EAUtils::LogInfo("=== ENTRY SEQUENCE TIMEOUT ===");
        CV2EAUtils::LogInfo(StringFormat("Could not find confirmation for all entries within %d bars", EntryTimeoutBars));
    }
    
    //--- Retrieve EMA values for the previous and current closed bars
    double emaFastPrev, emaMidPrev, emaSlowPrev;
    double emaFastCurr, emaMidCurr, emaSlowCurr;
    double macdMainPrev, macdSignalPrev;
    double macdMainCurr, macdSignalCurr;
    
    // Get cached indicator values for current bar
    if(!GetCachedIndicatorValues(currentBar, 0,
        emaFastCurr, emaMidCurr, emaSlowCurr,
        macdMainCurr, macdSignalCurr))
        return;
        
    // Get cached indicator values for previous bar
    if(!GetCachedIndicatorValues(currentBar, 1,
        emaFastPrev, emaMidPrev, emaSlowPrev,
        macdMainPrev, macdSignalPrev))
        return;
    
    //--- Check for EMA Crossovers
    bool isBullishCross = false;
    bool isBearishCross = false;
    
    // Get current price
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Additional pivot point checks for trade direction
    if(UsePivotPoints)
    {
        // Strengthen bullish signal if price is near support levels
        if(IsPriceNearLevel(currentPrice, s1Level) || 
           IsPriceNearLevel(currentPrice, s2Level) || 
           IsPriceNearLevel(currentPrice, s3Level))
        {
            if(emaFastCurr > emaMidCurr && macdMainCurr > macdSignalCurr)
                isBullishCross = true;
        }
        
        // Strengthen bearish signal if price is near resistance levels
        if(IsPriceNearLevel(currentPrice, r1Level) || 
           IsPriceNearLevel(currentPrice, r2Level) || 
           IsPriceNearLevel(currentPrice, r3Level))
        {
            if(emaFastCurr < emaMidCurr && macdMainCurr < macdSignalCurr)
                isBearishCross = true;
        }
    }
    
    // Standard EMA crossover checks if not already triggered by pivot points
    if(!isBullishCross && !isBearishCross)
    {
        // Detect Bullish EMA Crossover
        if(emaFastCurr > emaSlowCurr && emaFastPrev <= emaSlowPrev)
        {
            // Optional Confirmation with Mid EMA
            if(emaFastCurr > emaMidCurr)
                isBullishCross = true;
        }
        
        // Detect Bearish EMA Crossover
        if(emaFastCurr < emaSlowCurr && emaFastPrev >= emaSlowPrev)
        {
            // Optional Confirmation with Mid EMA
            if(emaFastCurr < emaMidCurr)
                isBearishCross = true;
        }
    }
    
    //--- Handle Signal Detection and Trade Direction
    if(isBullishCross && tradeDirection <= 0)  // Only take bullish signal if not already in a buy position
    {
        // Close any existing sell positions first
        if(HasOpenPositions(ORDER_TYPE_SELL))
        {
            CV2EAUtils::LogInfo("=== CLOSING SELL POSITIONS ===");
            CV2EAUtils::LogInfo("Reason: Signal changed to bullish");
            CloseAllPositions(ORDER_TYPE_SELL);
        }

        CV2EAUtils::LogInfo("=== BULLISH SIGNAL DETECTED ===");
        if(UsePivotPoints)
        {
            CV2EAUtils::LogInfo("Pivot Point Analysis:");
            CV2EAUtils::LogInfo(StringFormat("Current Price: %.5f", currentPrice));
            CV2EAUtils::LogInfo(StringFormat("Nearest Support: %.5f", GetNearestLevel(currentPrice, false)));
            CV2EAUtils::LogInfo(StringFormat("Nearest Resistance: %.5f", GetNearestLevel(currentPrice, true)));
        }
        CV2EAUtils::LogInfo("Trigger: Fast EMA crossed above Slow EMA with Mid EMA confirmation");
        CV2EAUtils::LogInfo(StringFormat("Previous Bar - Fast: %.5f Mid: %.5f Slow: %.5f", emaFastPrev, emaMidPrev, emaSlowPrev));
        CV2EAUtils::LogInfo(StringFormat("Current Bar  - Fast: %.5f Mid: %.5f Slow: %.5f", emaFastCurr, emaMidCurr, emaSlowCurr));
        CV2EAUtils::LogInfo(StringFormat("MACD Values  - Main: %.5f Signal: %.5f", macdMainCurr, macdSignalCurr));
        CV2EAUtils::LogInfo(StringFormat("Trade Direction changed from %d to 1 (Buy)", tradeDirection));
        
        // Reset entry sequence and set direction
        entryPositions = 0;
        inEntrySequence = true;
        tradeEntryBar = currentBar;
        tradeDirection = 1; // Set direction to Buy
        
        // Since we took a bullish signal, ignore any bearish signal on this bar
        isBearishCross = false;
    }

    if(isBearishCross && tradeDirection >= 0)  // Only take bearish signal if not already in a sell position
    {
        // Close any existing buy positions first
        if(HasOpenPositions(ORDER_TYPE_BUY))
        {
            CV2EAUtils::LogInfo("=== CLOSING BUY POSITIONS ===");
            CV2EAUtils::LogInfo("Reason: Signal changed to bearish");
            CloseAllPositions(ORDER_TYPE_BUY);
        }

        CV2EAUtils::LogInfo("=== BEARISH SIGNAL DETECTED ===");
        if(UsePivotPoints)
        {
            CV2EAUtils::LogInfo("Pivot Point Analysis:");
            CV2EAUtils::LogInfo(StringFormat("Current Price: %.5f", currentPrice));
            CV2EAUtils::LogInfo(StringFormat("Nearest Support: %.5f", GetNearestLevel(currentPrice, false)));
            CV2EAUtils::LogInfo(StringFormat("Nearest Resistance: %.5f", GetNearestLevel(currentPrice, true)));
        }
        CV2EAUtils::LogInfo("Trigger: Fast EMA crossed below Slow EMA with Mid EMA confirmation");
        CV2EAUtils::LogInfo(StringFormat("Previous Bar - Fast: %.5f Mid: %.5f Slow: %.5f", emaFastPrev, emaMidPrev, emaSlowPrev));
        CV2EAUtils::LogInfo(StringFormat("Current Bar  - Fast: %.5f Mid: %.5f Slow: %.5f", emaFastCurr, emaMidCurr, emaSlowCurr));
        CV2EAUtils::LogInfo(StringFormat("MACD Values  - Main: %.5f Signal: %.5f", macdMainCurr, macdSignalCurr));
        CV2EAUtils::LogInfo(StringFormat("Trade Direction changed from %d to -1 (Sell)", tradeDirection));
        
        // Reset entry sequence and set direction
        entryPositions = 0;
        inEntrySequence = true;
        tradeEntryBar = currentBar;
        tradeDirection = -1; // Set direction to Sell
    }
    
    //--- Check for Additional Entry Confirmations
    if(inEntrySequence && entryPositions < 3)
    {
        // Determine order type based on trade direction
        ENUM_ORDER_TYPE orderType;
        if(tradeDirection == 1)
            orderType = ORDER_TYPE_BUY;
        else if(tradeDirection == -1)
            orderType = ORDER_TYPE_SELL;
        else
        {
            CV2EAUtils::LogInfo("=== ENTRY SEQUENCE CANCELLED ===");
            CV2EAUtils::LogInfo("Reason: No valid trade direction set");
            inEntrySequence = false;
            return;
        }
        
        bool shouldEnter = false;
        string entryReason = "";
        
        // First position: Initial crossover with multiple confirmations
        if(entryPositions == 0)
        {
            if(orderType == ORDER_TYPE_BUY)
            {
                if(emaFastCurr > emaMidCurr && // Fast above Mid
                   emaMidCurr > emaSlowCurr && // Mid above Slow
                   macdMainCurr > macdSignalCurr && // MACD above Signal
                   macdMainCurr > macdMainPrev) // MACD increasing
                {
                    shouldEnter = true;
                    entryReason = "Initial Entry - Strong Bullish Setup (EMAs aligned, MACD momentum positive)";
                }
            }
            else // SELL
            {
                if(emaFastCurr < emaMidCurr && // Fast below Mid
                   emaMidCurr < emaSlowCurr && // Mid below Slow
                   macdMainCurr < macdSignalCurr && // MACD below Signal
                   macdMainCurr < macdMainPrev) // MACD decreasing
                {
                    shouldEnter = true;
                    entryReason = "Initial Entry - Strong Bearish Setup (EMAs aligned, MACD momentum negative)";
                }
            }
        }
        // Second position: Price action and MACD confirmation
        else if(entryPositions == 1)
        {
            double currentClose = iClose(_Symbol, MainTimeframe, 0);
            double previousClose = iClose(_Symbol, MainTimeframe, 1);
            double previousHigh = iHigh(_Symbol, MainTimeframe, 1);
            double previousLow = iLow(_Symbol, MainTimeframe, 1);
            
            if(orderType == ORDER_TYPE_BUY)
            {
                if(currentClose > previousHigh * 0.99 && // Allowing a slight buffer below previous high
                   macdMainCurr > 0 && // MACD in positive territory
                   macdMainCurr > macdMainPrev && // MACD still increasing
                   emaFastCurr > emaMidCurr && // EMAs still aligned
                   emaMidCurr > emaSlowCurr)
                {
                    shouldEnter = true;
                    entryReason = "Second Entry - Bullish Breakout (Price above prev high, Strong MACD)";
                }
            }
            else // SELL
            {
                if(currentClose < previousLow * 1.01 && // Allowing a slight buffer above previous low
                   macdMainCurr < 0 && // MACD in negative territory
                   macdMainCurr < macdMainPrev && // MACD still decreasing
                   emaFastCurr < emaMidCurr && // EMAs still aligned
                   emaMidCurr < emaSlowCurr)
                {
                    shouldEnter = true;
                    entryReason = "Second Entry - Bearish Breakout (Price below prev low, Strong MACD)";
                }
            }
        }
        // Third position: Strong trend continuation with volume OR drawdown entry
        else if(entryPositions == 2)
        {
            double currentClose = iClose(_Symbol, MainTimeframe, 0);
            double previousClose = iClose(_Symbol, MainTimeframe, 1);
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            
            // Calculate drawdown from the highest/lowest point since trade entry
            double maxDrawdown = 0;
            double highestPrice = currentClose;
            double lowestPrice = currentClose;
            
            for(int i = 0; i < 100; i++) // Look back up to 100 bars
            {
                datetime barTime = iTime(_Symbol, MainTimeframe, i);
                if(barTime < tradeEntryBar) break;
                
                double high = iHigh(_Symbol, MainTimeframe, i);
                double low = iLow(_Symbol, MainTimeframe, i);
                
                if(high > highestPrice) highestPrice = high;
                if(low < lowestPrice) lowestPrice = low;
            }
            
            if(orderType == ORDER_TYPE_BUY)
            {
                maxDrawdown = (highestPrice - currentClose) / point;
                
                if((currentClose > previousClose * 1.01 && // Original condition: Strong continuation
                    emaFastCurr > emaMidCurr && 
                    emaMidCurr > emaSlowCurr &&
                    macdMainCurr > macdMainPrev && 
                    macdMainCurr > macdSignalCurr) ||
                   (maxDrawdown >= 150.0 && // New condition: Drawdown entry
                    emaFastCurr > emaMidCurr && // Still maintain EMA alignment
                    emaMidCurr > emaSlowCurr &&
                    macdMainCurr > macdSignalCurr)) // Maintain positive momentum
                {
                    shouldEnter = true;
                    entryReason = maxDrawdown >= 150.0 ? 
                        StringFormat("Third Entry - Bullish Drawdown Entry (%.1f pips drawdown, EMAs aligned, positive momentum)", maxDrawdown) :
                        "Third Entry - Strong Bullish Continuation (Price up, EMAs aligned, MACD strength)";
                }
            }
            else // SELL
            {
                maxDrawdown = (currentClose - lowestPrice) / point;
                
                if((currentClose < previousClose * 0.99 && // Original condition: Strong continuation
                    emaFastCurr < emaMidCurr && 
                    emaMidCurr < emaSlowCurr &&
                    macdMainCurr < macdMainPrev && 
                    macdMainCurr < macdSignalCurr) ||
                   (maxDrawdown >= 150.0 && // New condition: Drawdown entry
                    emaFastCurr < emaMidCurr && // Still maintain EMA alignment
                    emaMidCurr < emaSlowCurr &&
                    macdMainCurr < macdSignalCurr)) // Maintain negative momentum
                {
                    shouldEnter = true;
                    entryReason = maxDrawdown >= 150.0 ? 
                        StringFormat("Third Entry - Bearish Drawdown Entry (%.1f pips drawdown, EMAs aligned, negative momentum)", maxDrawdown) :
                        "Third Entry - Strong Bearish Continuation (Price down, EMAs aligned, MACD strength)";
                }
            }
        }
        
        if(shouldEnter)
        {
            CV2EAUtils::LogInfo(StringFormat("=== ENTRY CONFIRMATION #%d ===", (entryPositions + 1)));
            CV2EAUtils::LogInfo(StringFormat("Direction: %s", (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL")));
            CV2EAUtils::LogInfo(StringFormat("Reason: %s", entryReason));
            CV2EAUtils::LogInfo(StringFormat("EMA Values - Fast: %.5f Mid: %.5f Slow: %.5f", emaFastCurr, emaMidCurr, emaSlowCurr));
            CV2EAUtils::LogInfo(StringFormat("MACD Values - Main: %.5f Signal: %.5f", macdMainCurr, macdSignalCurr));
            
            double stopLossPrice = GetStopLossPrice(orderType == ORDER_TYPE_BUY);
            double riskPerTrade = AccountInfoDouble(ACCOUNT_BALANCE) * (RiskPercentage / 100.0);
            double pipsDistance;
            
            if(orderType == ORDER_TYPE_BUY)
                pipsDistance = fabs(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - stopLossPrice) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            else
                pipsDistance = fabs(stopLossPrice - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            
            double lotSize = CalculateLotSize(riskPerTrade, pipsDistance);
            if(lotSize > 0.0)
            {
                if(OpenTrade(orderType, lotSize, stopLossPrice, 0, 
                            StringFormat("%s Entry #%d", orderType == ORDER_TYPE_BUY ? "Bullish" : "Bearish", entryPositions + 1)))
                {
                    entryPositions++;
                    lastEntryBar = iTime(_Symbol, MainTimeframe, 0); // Update last entry time after successful entry
                }
            }
        }
        
        // Check for entry sequence timeout using EntryTimeoutBars parameter
        datetime timeoutReference = (lastEntryBar > 0) ? lastEntryBar : tradeEntryBar;
        if(iTime(_Symbol, MainTimeframe, 0) > timeoutReference + (EntryTimeoutBars * PeriodSeconds(MainTimeframe)))
        {
            // Only timeout if we have at least one position open
            if(entryPositions > 0)
            {
                inEntrySequence = false;  // Only set to false if we have positions
                CV2EAUtils::LogInfo("=== ENTRY SEQUENCE TIMEOUT ===");
                CV2EAUtils::LogInfo(StringFormat("Could not find confirmation for all entries within %d bars", EntryTimeoutBars));
                CV2EAUtils::LogInfo(StringFormat("Reason: Have %d active position(s), stopping sequence for additional entries", entryPositions));
                CV2EAUtils::LogInfo(StringFormat("Time since last entry: %.1f bars", (iTime(_Symbol, MainTimeframe, 0) - timeoutReference) / PeriodSeconds(MainTimeframe)));
            }
            else if(tradeDirection != 0)  // If we have a direction but no positions yet
            {
                // Check if EMAs are still aligned in the right direction with tolerance
                if(CheckEMAAlignment(tradeDirection))
                {
                    // Reset the entry bar time to give more time for first entry
                    tradeEntryBar = iTime(_Symbol, MainTimeframe, 0);
                    CV2EAUtils::LogInfo("=== ENTRY SEQUENCE EXTENDED ===");
                    CV2EAUtils::LogInfo("No positions yet, resetting entry timer to allow more time for first entry");
                }
                else
                {
                    // EMAs no longer aligned, cancel the trade direction
                    tradeDirection = 0;
                    inEntrySequence = false;
                    CV2EAUtils::LogInfo("=== ENTRY SEQUENCE CANCELLED ===");
                    CV2EAUtils::LogInfo("Reason: EMAs no longer aligned with original trade direction");
                }
            }
        }
    }
    
    //--- Check for MACD Exit Signals (Partial Exit)
    if(IsMACDCrossedOver(macdMainPrev, macdSignalPrev, macdMainCurr, macdSignalCurr) && (currentBar > tradeEntryBar))
    {
        CV2EAUtils::LogInfo("=== MACD EXIT SIGNAL DETECTED ===");
        CV2EAUtils::LogInfo("Trigger: MACD line crossed Signal line");
        CV2EAUtils::LogInfo(StringFormat("Previous Bar - MACD: %.5f Signal: %.5f", macdMainPrev, macdSignalPrev));
        CV2EAUtils::LogInfo(StringFormat("Current Bar  - MACD: %.5f Signal: %.5f", macdMainCurr, macdSignalCurr));
        
        ENUM_ORDER_TYPE orderTypeToClose;
        int buyCount = 0, sellCount = 0;
        
        for(int i = 0; i < PositionsTotal(); i++)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket <= 0) continue;
            
            if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
                ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                if(posType == POSITION_TYPE_BUY) buyCount++;
                if(posType == POSITION_TYPE_SELL) sellCount++;
            }
        }
        
        orderTypeToClose = (buyCount > sellCount) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
        
        if(CloseOnePosition(orderTypeToClose))
        {
            partialClosures++;
            // Update trade direction if all positions are closed
            if(!HasOpenPositions(ORDER_TYPE_BUY) && !HasOpenPositions(ORDER_TYPE_SELL))
            {
                tradeDirection = 0; // Reset direction when no positions are open
                CV2EAUtils::LogInfo("All positions closed - Trade direction reset to 0");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size based on risk and pip distance                |
//+------------------------------------------------------------------+
double CalculateLotSize(double riskAmount, double pipsDistance)
{
    double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    
    if(tickSize == 0.0)
        return 0.0;
    
    double pipValue = (0.0001 / tickSize) * tickValue;
    double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    if(bidPrice == 0.0)
        return 0.0;
    
    double riskAmountBase = riskAmount / bidPrice;
    double lotSize = 0.0;
    
    if(pipsDistance > 0.0)
        lotSize = riskAmountBase / (pipsDistance * pipValue);
    
    double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    double steps = MathFloor(lotSize / stepLot);
    lotSize = steps * stepLot;
    
    if(lotSize < minLot)
        lotSize = minLot;
    if(lotSize > maxLot)
        lotSize = maxLot;
    
    return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Open Trade with specified parameters                              |
//+------------------------------------------------------------------+
bool OpenTrade(ENUM_ORDER_TYPE orderType, double lots, double sl, double tp, string comment="")
{
    double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double steps = MathFloor(lots / stepLot);
    lots = NormalizeDouble(steps * stepLot, 2);
    
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    if(lots < minLot)
        return false;
    
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    trade.SetTypeFillingBySymbol(_Symbol);
    
    bool result = false;
    
    // Get current ATR value for dynamic SL/TP if pivot points are not used
    double currentATR = GetIndicatorValue(handleATR, 0);
    double atrPoints = currentATR / _Point;
    
    if(orderType == ORDER_TYPE_BUY)
    {
        double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double stopLoss = GetPivotBasedSL(true, sl);
        double takeProfit = GetPivotBasedTP(true, tp);
        
        CV2EAUtils::LogInfo("=== OPENING BUY ORDER ===");
        CV2EAUtils::LogInfo(StringFormat("Entry Price: %.5f", price));
        CV2EAUtils::LogInfo(StringFormat("Stop Loss: %.5f (Distance: %.1f pips)", stopLoss, (price - stopLoss) / _Point));
        CV2EAUtils::LogInfo(StringFormat("Take Profit: %.5f (Distance: %.1f pips)", takeProfit, (takeProfit - price) / _Point));
        
        result = trade.Buy(lots, _Symbol, 0, stopLoss, takeProfit, comment);
    }
    else if(orderType == ORDER_TYPE_SELL)
    {
        double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double stopLoss = GetPivotBasedSL(false, sl);
        double takeProfit = GetPivotBasedTP(false, tp);
        
        CV2EAUtils::LogInfo("=== OPENING SELL ORDER ===");
        CV2EAUtils::LogInfo(StringFormat("Entry Price: %.5f", price));
        CV2EAUtils::LogInfo(StringFormat("Stop Loss: %.5f (Distance: %.1f pips)", stopLoss, (stopLoss - price) / _Point));
        CV2EAUtils::LogInfo(StringFormat("Take Profit: %.5f (Distance: %.1f pips)", takeProfit, (price - takeProfit) / _Point));
        
        result = trade.Sell(lots, _Symbol, 0, stopLoss, takeProfit, comment);
    }
    
    if(!result)
        CV2EAUtils::LogError(StringFormat("Trade Error: %d: %s", trade.ResultRetcode(), trade.CheckResultRetcodeDescription()));
    
    return result;
}

//+------------------------------------------------------------------+
//| Close one open position of the specified type                    |
//+------------------------------------------------------------------+
bool CloseOnePosition(ENUM_ORDER_TYPE orderType)
{
    for(int i = g_positionCount - 1; i >= 0; i--)
    {
        bool matchingType = (orderType == ORDER_TYPE_BUY && g_positions[i].type == POSITION_TYPE_BUY) ||
                           (orderType == ORDER_TYPE_SELL && g_positions[i].type == POSITION_TYPE_SELL);
        
        if(matchingType)
        {
            bool result = trade.PositionClose(g_positions[i].ticket);
            
            if(result)
            {
                CV2EAUtils::LogSuccess(StringFormat("Closed position #%d successfully.", g_positions[i].ticket));
                
                // Update position tracking
                UpdatePositionTracking();
                
                // Check if this was the last position
                if(g_positionCount == 0)
                {
                    tradeDirection = 0;
                    inEntrySequence = false;
                    entryPositions = 0;
                    CV2EAUtils::LogInfo("=== TRADE DIRECTION RESET ===");
                    CV2EAUtils::LogInfo("Reason: All positions have been closed");
                }
                return true;
            }
            else
            {
                CV2EAUtils::LogError(StringFormat("Failed to close position #%d. Error: %d", g_positions[i].ticket, GetLastError()));
                return false;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Close all open positions of a specific type                      |
//+------------------------------------------------------------------+
bool CloseAllPositions(ENUM_ORDER_TYPE orderType)
{
    bool allClosed = true;
    int totalPositions = PositionsTotal();
    
    for(int i = totalPositions - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            bool matchingType = (orderType == ORDER_TYPE_BUY && posType == POSITION_TYPE_BUY) ||
                                (orderType == ORDER_TYPE_SELL && posType == POSITION_TYPE_SELL);
            
            if(matchingType)
            {
                bool result = trade.PositionClose(ticket);
                
                if(result)
                {
                    CV2EAUtils::LogSuccess(StringFormat("Closed position #%d successfully.", ticket));
                }
                else
                {
                    CV2EAUtils::LogError(StringFormat("Failed to close position #%d. Error: %d", ticket, GetLastError()));
                    allClosed = false;
                }
            }
        }
    }
    
    // After closing all positions of the specified type, check if any positions remain
    if(allClosed && !HasOpenPositions(ORDER_TYPE_BUY) && !HasOpenPositions(ORDER_TYPE_SELL))
    {
        tradeDirection = 0;
        inEntrySequence = false;
        entryPositions = 0;
        CV2EAUtils::LogInfo("=== TRADE DIRECTION RESET ===");
        CV2EAUtils::LogInfo("Reason: All positions have been closed");
    }
    
    return allClosed;
}

//+------------------------------------------------------------------+
//| Check if there are any open positions of a specific type         |
//+------------------------------------------------------------------+
bool HasOpenPositions(ENUM_ORDER_TYPE orderType)
{
    for(int i = 0; i < g_positionCount; i++)
    {
        bool matchingType = (orderType == ORDER_TYPE_BUY && g_positions[i].type == POSITION_TYPE_BUY) ||
                           (orderType == ORDER_TYPE_SELL && g_positions[i].type == POSITION_TYPE_SELL);
        
        if(matchingType)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Retrieve Indicator Buffer Value                                 |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int shift, int buffer = 0)
{
    double value[];
    if(CopyBuffer(handle, buffer, shift, 1, value) > 0)
        return value[0];
    else
    {
        CV2EAUtils::LogError(StringFormat("Failed to copy buffer for handle %d. Error: %d", handle, GetLastError()));
        return 0.0;
    }
}

//+------------------------------------------------------------------+
//| Detect MACD Crossover                                           |
//+------------------------------------------------------------------+
bool IsMACDCrossedOver(double macdMainPrev, double macdSignalPrev, double macdMainCurr, double macdSignalCurr)
{
    // Check if the difference between MACD and Signal is significant enough
    if(MathAbs(macdMainCurr - macdSignalCurr) < MACDThreshold)
        return false;
        
    // For bullish positions: Exit when MACD is below signal
    if(tradeDirection == 1 && macdMainCurr < macdSignalCurr)
        return true;
    
    // For bearish positions: Exit when MACD is above signal
    if(tradeDirection == -1 && macdMainCurr > macdSignalCurr)
        return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Get Stop Loss Price with buffer                                  |
//+------------------------------------------------------------------+
double GetStopLossPrice(bool isBuy)
{
    // Fetch the previous bar's high and low
    double previousHigh = iHigh(_Symbol, MainTimeframe, 1);
    double previousLow  = iLow(_Symbol, MainTimeframe, 1);
    
    // Define a buffer in pips to account for spread and volatility
    double bufferPips = SLBufferPips; // Adjustable buffer
    double pointSize   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    if(isBuy)
    {
        // Stop-loss just below the previous bar's low minus buffer
        return previousLow - (bufferPips * pointSize);
    }
    else
    {
        // Stop-loss just above the previous bar's high plus buffer
        return previousHigh + (bufferPips * pointSize);
    }
}

//+------------------------------------------------------------------+
//| Check if EMAs are aligned with trade direction                    |
//+------------------------------------------------------------------+
bool CheckEMAAlignment(int direction)
{
    double emaFastCurr = GetIndicatorValue(handleEmaFast, 0);
    double emaMidCurr = GetIndicatorValue(handleEmaMid, 0);
    double emaSlowCurr = GetIndicatorValue(handleEmaSlow, 0);
    
    if(direction == 1) // Bullish alignment
    {
        // Allow some tolerance in the alignment (0.5 pip tolerance)
        double tolerance = 0.00005;
        return (emaFastCurr > emaMidCurr - tolerance && emaMidCurr > emaSlowCurr - tolerance);
    }
    else if(direction == -1) // Bearish alignment
    {
        double tolerance = 0.00005;
        return (emaFastCurr < emaMidCurr + tolerance && emaMidCurr < emaSlowCurr + tolerance);
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check positions for take profit or stop loss                       |
//+------------------------------------------------------------------+
void CheckTakeProfit()
{
    if(g_positionCount == 0) return;
    
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double currentATR = GetIndicatorValue(handleATR, 0);
    
    // Calculate ATR-based exit levels in pips once
    double atrPips = currentATR / point;
    double tpLevel = atrPips * ATRMultiplierTP;
    double slLevel = atrPips * ATRMultiplierSL;
    
    for(int i = g_positionCount - 1; i >= 0; i--)
    {
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double profitPips = 0;
        
        if(g_positions[i].type == POSITION_TYPE_BUY)
            profitPips = (currentPrice - g_positions[i].openPrice) / point;
        else
            profitPips = (g_positions[i].openPrice - currentPrice) / point;
        
        string exitType = "";
        string exitReason = "";
        string pivotInfo = "";
        
        bool shouldClose = false;
        
        // Check for Take Profit
        if(profitPips >= tpLevel)
        {
            exitType = "TAKE PROFIT";
            exitReason = StringFormat("ATR-based TP reached (%.1f pips profit)", profitPips);
            shouldClose = true;
        }
        // Check for Stop Loss
        else if(profitPips <= -slLevel)
        {
            exitType = "STOP LOSS";
            exitReason = StringFormat("ATR-based SL reached (%.1f pips loss)", MathAbs(profitPips));
            shouldClose = true;
        }
        
        if(shouldClose)
        {
            // Add pivot point information if enabled
            if(UsePivotPoints)
            {
                double nearestPivot = GetNearestLevel(currentPrice, g_positions[i].type == POSITION_TYPE_BUY);
                if(nearestPivot != 0.0)
                {
                    pivotInfo = StringFormat("\nNearest Pivot Level: %.5f\nDistance to Pivot: %.1f pips", 
                                           nearestPivot, 
                                           MathAbs(currentPrice - nearestPivot) / point);
                }
            }
            
            CV2EAUtils::LogInfo(StringFormat("=== %s EXIT TRIGGERED ===", exitType));
            CV2EAUtils::LogInfo(StringFormat("Position Type: %s", EnumToString(g_positions[i].type)));
            CV2EAUtils::LogInfo(StringFormat("Entry Price: %.5f", g_positions[i].openPrice));
            CV2EAUtils::LogInfo(StringFormat("Current Price: %.5f", currentPrice));
            CV2EAUtils::LogInfo(StringFormat("Exit Reason: %s", exitReason));
            CV2EAUtils::LogInfo(StringFormat("ATR Value: %.5f", currentATR));
            CV2EAUtils::LogInfo(StringFormat("ATR in Pips: %.1f", atrPips));
            
            if(exitType == "TAKE PROFIT")
                CV2EAUtils::LogInfo(StringFormat("TP Level: %.1f", tpLevel));
            else
                CV2EAUtils::LogInfo(StringFormat("SL Level: %.1f", slLevel));
            
            if(pivotInfo != "") 
                CV2EAUtils::LogInfo(pivotInfo);
            
            if(trade.PositionClose(g_positions[i].ticket))
            {
                CV2EAUtils::LogSuccess(StringFormat("Successfully closed position #%d at %s", 
                    g_positions[i].ticket, exitType));
                
                // Update position tracking
                UpdatePositionTracking();
                
                // Check if this was the last position
                if(g_positionCount == 0)
                {
                    tradeDirection = 0;
                    inEntrySequence = false;
                    entryPositions = 0;
                    CV2EAUtils::LogInfo("=== TRADE DIRECTION RESET ===");
                    CV2EAUtils::LogInfo("Reason: All positions have been closed after " + exitType);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update tracked positions                                           |
//+------------------------------------------------------------------+
void UpdatePositionTracking()
{
    // Reset position array
    ArrayResize(g_positions, 0);
    g_positionCount = 0;
    
    int totalPositions = PositionsTotal();
    for(int i = 0; i < totalPositions; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
            ArrayResize(g_positions, g_positionCount + 1);
            g_positions[g_positionCount].ticket = ticket;
            g_positions[g_positionCount].openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            g_positions[g_positionCount].openTime = (datetime)PositionGetInteger(POSITION_TIME);
            g_positions[g_positionCount].lots = PositionGetDouble(POSITION_VOLUME);
            g_positions[g_positionCount].type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            g_positions[g_positionCount].stopLoss = PositionGetDouble(POSITION_SL);
            g_positions[g_positionCount].takeProfit = PositionGetDouble(POSITION_TP);
            g_positionCount++;
        }
    }
}


//+------------------------------------------------------------------+