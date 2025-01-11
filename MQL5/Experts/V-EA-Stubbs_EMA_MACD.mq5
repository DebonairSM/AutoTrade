//+------------------------------------------------------------------+
//|                                                      StubbsEA.mq5 |
//|                        Your Name or Company                       |
//|                                                                  |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
#include <Tools\DateTime.mqh>
#include <Arrays\ArrayObj.mqh>

// Economic Calendar structures
struct CalendarEvent
{
    string name;
    datetime time;
    string currencyCode;
    int importance;
    ulong id;
};

//--- Input Parameters
input ENUM_TIMEFRAMES MainTimeframe = PERIOD_H2;  // Main Trading Timeframe
input int    EMAPeriodFast   = 7;     // Fast EMA Period
input int    EMAPeriodMid    = 32;    // Mid EMA Period
input int    EMAPeriodSlow   = 33;    // Slow EMA Period
input int    MACDFast        = 14;    // MACD Fast EMA Period
input int    MACDSlow        = 19;    // MACD Slow EMA Period
input int    MACDSignal      = 13;     // MACD Signal SMA Period
input double RiskPercentage  = 7;     // Risk Percentage per Trade
input int    ATRPeriod       = 20;    // ATR Period
input double ATRMultiplierSL = 9;   // ATR Multiplier for Stop Loss
input double ATRMultiplierTP = 10.2;   // ATR Multiplier for Take Profit
input double MACDThreshold   = 0.0002; // Minimum MACD difference for signal
input int    EntryTimeoutBars = 11;    // Bars to wait for entry sequence
input double SLBufferPips    = 6.0;   // Stop-Loss Buffer in Pips
//--- Trading Time Parameters
input int    NoTradeStartHour = 12;     // No Trading Start Hour 
input int    NoTradeEndHour   = 4;     // No Trading End Hour
input int    HaltMinutesBefore = 30;   // Minutes before news event to halt trading
input int    HaltMinutesAfter  = 30;   // Minutes after news event to halt trading
input bool   HaltOnCPI        = true;  // Halt on CPI announcements
input bool   HaltOnNFP        = true;  // Halt on Non-Farm Payrolls
input bool   HaltOnFOMC       = true;  // Halt on FOMC meetings
input bool   HaltOnGDP        = true;  // Halt on GDP reports
input bool   HaltOnPPI        = true;  // Halt on PPI announcements
input bool   HaltOnCentralBank = true; // Halt on Central Bank speeches

//--- Pivot Point Parameters
input ENUM_TIMEFRAMES PivotTimeframe = PERIOD_D1;  // Timeframe for Pivot Points
input bool   UsePivotPoints = true;     // Use Pivot Points for Trading
input double PivotBufferPips = 2.0;     // Buffer around pivot levels (pips)
input bool   UseR1AsTP = true;          // Use R1 as Take Profit for longs
input bool   UseS1AsTP = true;          // Use S1 as Take Profit for shorts
input bool   UseS1AsSL = true;          // Use S1 as Stop Loss for longs
input bool   UseR1AsSL = true;          // Use R1 as Stop Loss for shorts

//--- Add new input parameters
input bool   UseHybridExits = true;    // Use both Pivot and ATR for exits
input double PivotWeight    = 0.5;     // Weight for Pivot Points (0.0-1.0)
input double ATRWeight      = 0.5;     // Weight for ATR-based exits (0.0-1.0)
input int    ATR_MA_Period    = 20;    // Period for Average ATR calculation
input double SL_ATR_Mult     = 0.5;    // ATR multiplier for SL buffer
input double TP_ATR_Mult     = 0.3;    // ATR multiplier for TP buffer
input double SL_Dist_Mult    = 0.1;    // Distance multiplier for SL buffer (10%)
input double TP_Dist_Mult    = 0.08;   // Distance multiplier for TP buffer (8%)
input double Max_Buffer_Pips = 50.0;   // Maximum buffer size in pips

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

//+------------------------------------------------------------------+
//| Calculate Pivot Points and Support/Resistance Levels               |
//+------------------------------------------------------------------+
void CalculatePivotPoints()
{
    // Only recalculate at the start of a new period
    datetime currentPeriodStart = iTime(_Symbol, PivotTimeframe, 0);
    if(currentPeriodStart == lastPivotCalc) return;
    
    lastPivotCalc = currentPeriodStart;
    
    // Get previous period's high, low, and close
    double prevHigh = iHigh(_Symbol, PivotTimeframe, 1);
    double prevLow = iLow(_Symbol, PivotTimeframe, 1);
    double prevClose = iClose(_Symbol, PivotTimeframe, 1);
    
    // Calculate pivot point
    pivotPoint = (prevHigh + prevLow + prevClose) / 3.0;
    
    // Calculate resistance levels
    r1Level = (2 * pivotPoint) - prevLow;
    r2Level = pivotPoint + (prevHigh - prevLow);
    r3Level = r2Level + (prevHigh - prevLow);
    
    // Calculate support levels
    s1Level = (2 * pivotPoint) - prevHigh;
    s2Level = pivotPoint - (prevHigh - prevLow);
    s3Level = s2Level - (prevHigh - prevLow);
    
    Print("=== PIVOT POINTS UPDATED ===");
    Print("Timeframe: ", EnumToString(PivotTimeframe));
    Print("Pivot: ", pivotPoint);
    Print("R1: ", r1Level, " R2: ", r2Level, " R3: ", r3Level);
    Print("S1: ", s1Level, " S2: ", s2Level, " S3: ", s3Level);
}

//+------------------------------------------------------------------+
//| Check if price is near a pivot level                              |
//+------------------------------------------------------------------+
bool IsPriceNearLevel(double price, double level)
{
    double bufferInPoints = PivotBufferPips * 10.0; // Convert pips to points
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
    
    if(isBuy && UseR1AsTP && currentPrice < r1Level)
        return r1Level;
    else if(!isBuy && UseS1AsTP && currentPrice > s1Level)
        return s1Level;
        
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
    
    if(isBuy && UseS1AsSL && currentPrice > s1Level)
        return s1Level;
    else if(!isBuy && UseR1AsSL && currentPrice < r1Level)
        return r1Level;
        
    return defaultSL;
}

//+------------------------------------------------------------------+
//| Get nearest pivot level (support or resistance)                    |
//+------------------------------------------------------------------+
double GetNearestLevel(double price, bool resistance)
{
    if(!UsePivotPoints) return 0.0;
    
    if(resistance)
    {
        // Find nearest resistance level
        double levels[] = {r1Level, r2Level, r3Level};
        double nearestLevel = r1Level;
        double minDistance = MathAbs(price - r1Level);
        
        for(int i = 1; i < ArraySize(levels); i++)
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
        // Find nearest support level
        double levels[] = {s1Level, s2Level, s3Level};
        double nearestLevel = s1Level;
        double minDistance = MathAbs(price - s1Level);
        
        for(int i = 1; i < ArraySize(levels); i++)
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
    handleEmaFast = iMA(_Symbol, MainTimeframe, EMAPeriodFast, 0, MODE_EMA, PRICE_CLOSE);
    handleEmaMid  = iMA(_Symbol, MainTimeframe, EMAPeriodMid,  0, MODE_EMA, PRICE_CLOSE);
    handleEmaSlow = iMA(_Symbol, MainTimeframe, EMAPeriodSlow, 0, MODE_EMA, PRICE_CLOSE);
    
    // Initialize MACD indicator
    handleMacd = iMACD(_Symbol, MainTimeframe, MACDFast, MACDSlow, MACDSignal, PRICE_CLOSE);
    
    // Initialize ATR indicator
    handleATR = iATR(_Symbol, MainTimeframe, ATRPeriod);
    
    // Initialize Average ATR indicator
    handleAverageATR = iMA(_Symbol, MainTimeframe, ATR_MA_Period, 0, MODE_SMA, handleATR);
    
    // Check if indicators are initialized successfully
    if(handleEmaFast == INVALID_HANDLE || handleEmaMid == INVALID_HANDLE || 
       handleEmaSlow == INVALID_HANDLE || handleMacd == INVALID_HANDLE || 
       handleATR == INVALID_HANDLE)
    {
        Print("Error initializing indicators.");
        return(INIT_FAILED);
    }
    
    if(handleAverageATR == INVALID_HANDLE)
    {
        Print("Error initializing Average ATR indicator");
        return(INIT_FAILED);
    }
    
    Print("EA Initialized Successfully.");
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
    
    Print("EA Deinitialized.");
}

//+------------------------------------------------------------------+
//| Check if event name matches major news events                     |
//+------------------------------------------------------------------+
bool IsHighImpactNews(string eventName)
{
    string eventUpper = StringToUpper(eventName);
    
    if(HaltOnCPI && (StringFind(eventUpper, "CPI") != -1 || 
       StringFind(eventUpper, "CONSUMER PRICE") != -1))
        return true;
        
    if(HaltOnNFP && (StringFind(eventUpper, "NON-FARM") != -1 || 
       StringFind(eventUpper, "NONFARM") != -1 ||
       StringFind(eventUpper, "NFP") != -1))
        return true;
        
    if(HaltOnFOMC && (StringFind(eventUpper, "FOMC") != -1 || 
       StringFind(eventUpper, "FED") != -1 ||
       StringFind(eventUpper, "FEDERAL RESERVE") != -1))
        return true;
        
    if(HaltOnGDP && StringFind(eventUpper, "GDP") != -1)
        return true;
        
    if(HaltOnPPI && (StringFind(eventUpper, "PPI") != -1 ||
       StringFind(eventUpper, "PRODUCER PRICE") != -1))
        return true;
        
    if(HaltOnCentralBank && (
       StringFind(eventUpper, "ECB") != -1 ||
       StringFind(eventUpper, "BOE") != -1 ||
       StringFind(eventUpper, "BOJ") != -1 ||
       StringFind(eventUpper, "BANK OF JAPAN") != -1 ||
       StringFind(eventUpper, "BANK OF ENGLAND") != -1 ||
       StringFind(eventUpper, "EUROPEAN CENTRAL BANK") != -1))
        return true;
        
    return false;
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
                        Print("=== CALENDAR ERROR ===\nFailed to get country data for event ID: ", event.country_id, "\nError code: ", GetLastError());
                        
                    events[count].currencyCode = countryCode;
                    events[count].importance = (int)event.importance;
                    events[count].id = event.id;
                    count++;
                }
            }
            else
            {
                Print("=== CALENDAR ERROR ===\nFailed to get event details for event ID: ", values[i].event_id, "\nError code: ", GetLastError());
            }
        }
    }
    else
    {
        Print("=== CALENDAR ERROR ===\nFailed to retrieve calendar history\nPeriod: ", TimeToString(currentTime), " to ", TimeToString(endTime), "\nError code: ", GetLastError());
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
            Print("=== TRADING HALTED ===");
            Print("Reason: High-impact news event active");
            Print("Event: ", events[i].name);
            Print("Event Time: ", TimeToString(events[i].time));
            Print("Halt Period: ", TimeToString(events[i].time - HaltMinutesBefore * 60), 
                  " to ", TimeToString(events[i].time + HaltMinutesAfter * 60));
            
            string impact = "";
            switch(events[i].importance)
            {
                case 3: impact = "High";   break;
                case 2: impact = "Medium"; break;
                case 1: impact = "Low";    break;
                default: impact = "None";  break;
            }
            Print("Event Impact: ", impact);
            Print("Country Code: ", events[i].currencyCode);
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
    Print("=== HOURLY TREND REPORT ===");
    Print("Time: ", TimeToString(currentTime));
    Print("EMA Analysis:");
    Print("  - Alignment: ", emaAlignment);
    Print("  - Trend Strength: ", DoubleToString(emaTrendStrength, 2), " basis points");
    Print("MACD Analysis:");
    Print("  - Direction: ", macdTrend);
    Print("  - Signal Strength: ", DoubleToString(MathAbs(macdStrength), 2), " basis points");
    Print("Overall Trend Score: ", DoubleToString(trendScore, 1), "/100");
    Print("  - Above 70: Strong Bullish");
    Print("  - 55-70: Moderate Bullish");
    Print("  - 45-55: Neutral");
    Print("  - 30-45: Moderate Bearish");
    Print("  - Below 30: Strong Bearish");
    
    // Add trading suggestion based on score
    string suggestion = "";
    if(trendScore >= 70) suggestion = "Consider LONG positions on pullbacks";
    else if(trendScore >= 55) suggestion = "Look for LONG opportunities with confirmation";
    else if(trendScore > 45) suggestion = "Wait for clearer directional signals";
    else if(trendScore > 30) suggestion = "Look for SHORT opportunities with confirmation";
    else suggestion = "Consider SHORT positions on rallies";
    
    Print("Trading Suggestion: ", suggestion);
    Print("========================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
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
        Print("=== ENTRY SEQUENCE TIMEOUT ===");
        Print("Could not find confirmation for all entries within ", EntryTimeoutBars, " bars");
    }
    
    //--- Retrieve EMA values for the previous and current closed bars
    double emaFastPrev = GetIndicatorValue(handleEmaFast, 1);
    double emaMidPrev  = GetIndicatorValue(handleEmaMid,  1);
    double emaSlowPrev = GetIndicatorValue(handleEmaSlow, 1);
    
    double emaFastCurr = GetIndicatorValue(handleEmaFast, 0);
    double emaMidCurr  = GetIndicatorValue(handleEmaMid,  0);
    double emaSlowCurr = GetIndicatorValue(handleEmaSlow, 0);
    
    //--- Retrieve MACD values for the previous and current closed bars
    double macdMainPrev   = GetIndicatorValue(handleMacd, 1, 0); // MACD Main Line
    double macdSignalPrev = GetIndicatorValue(handleMacd, 1, 1); // MACD Signal Line
    double macdMainCurr   = GetIndicatorValue(handleMacd, 0, 0);
    double macdSignalCurr = GetIndicatorValue(handleMacd, 0, 1);
    
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
        // Check for existing sell positions first
        if(!HasOpenPositions(ORDER_TYPE_SELL))
        {
            Print("=== BULLISH SIGNAL DETECTED ===");
            if(UsePivotPoints)
            {
                Print("Pivot Point Analysis:");
                Print("Current Price: ", currentPrice);
                Print("Nearest Support: ", GetNearestLevel(currentPrice, false));
                Print("Nearest Resistance: ", GetNearestLevel(currentPrice, true));
            }
            Print("Trigger: Fast EMA crossed above Slow EMA with Mid EMA confirmation");
            Print("Previous Bar - Fast:", emaFastPrev, " Mid:", emaMidPrev, " Slow:", emaSlowPrev);
            Print("Current Bar  - Fast:", emaFastCurr, " Mid:", emaMidCurr, " Slow:", emaSlowCurr);
            Print("MACD Values  - Main:", macdMainCurr, " Signal:", macdSignalCurr);
            Print("Trade Direction changed from ", tradeDirection, " to 1 (Buy)");
            
            // Reset entry sequence and set direction
            entryPositions = 0;
            inEntrySequence = true;
            tradeEntryBar = currentBar;
            tradeDirection = 1; // Set direction to Buy
            
            // Since we took a bullish signal, ignore any bearish signal on this bar
            isBearishCross = false;
        }
        else
        {
            Print("=== BULLISH SIGNAL IGNORED ===");
            Print("Reason: Existing SELL positions are still open");
        }
    }
    
    if(isBearishCross && tradeDirection >= 0)  // Only take bearish signal if not already in a sell position
    {
        // Check for existing buy positions first
        if(!HasOpenPositions(ORDER_TYPE_BUY))
        {
            Print("=== BEARISH SIGNAL DETECTED ===");
            if(UsePivotPoints)
            {
                Print("Pivot Point Analysis:");
                Print("Current Price: ", currentPrice);
                Print("Nearest Support: ", GetNearestLevel(currentPrice, false));
                Print("Nearest Resistance: ", GetNearestLevel(currentPrice, true));
            }
            Print("Trigger: Fast EMA crossed below Slow EMA with Mid EMA confirmation");
            Print("Previous Bar - Fast:", emaFastPrev, " Mid:", emaMidPrev, " Slow:", emaSlowPrev);
            Print("Current Bar  - Fast:", emaFastCurr, " Mid:", emaMidCurr, " Slow:", emaSlowCurr);
            Print("MACD Values  - Main:", macdMainCurr, " Signal:", macdSignalCurr);
            Print("Trade Direction changed from ", tradeDirection, " to -1 (Sell)");
            
            // Reset entry sequence and set direction
            entryPositions = 0;
            inEntrySequence = true;
            tradeEntryBar = currentBar;
            tradeDirection = -1; // Set direction to Sell
        }
        else
        {
            Print("=== BEARISH SIGNAL IGNORED ===");
            Print("Reason: Existing BUY positions are still open");
        }
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
            Print("=== ENTRY SEQUENCE CANCELLED ===");
            Print("Reason: No valid trade direction set");
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
            Print("=== ENTRY CONFIRMATION #", (entryPositions + 1), " ===");
            Print("Direction:", (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"));
            Print("Reason:", entryReason);
            Print("EMA Values - Fast:", emaFastCurr, " Mid:", emaMidCurr, " Slow:", emaSlowCurr);
            Print("MACD Values - Main:", macdMainCurr, " Signal:", macdSignalCurr);
            
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
                Print("=== ENTRY SEQUENCE TIMEOUT ===");
                Print("Could not find confirmation for all entries within ", EntryTimeoutBars, " bars");
                Print("Reason: Have ", entryPositions, " active position(s), stopping sequence for additional entries");
                Print("Time since last entry: ", (iTime(_Symbol, MainTimeframe, 0) - timeoutReference) / PeriodSeconds(MainTimeframe), " bars");
            }
            else if(tradeDirection != 0)  // If we have a direction but no positions yet
            {
                // Check if EMAs are still aligned in the right direction with tolerance
                if(CheckEMAAlignment(tradeDirection))
                {
                    // Reset the entry bar time to give more time for first entry
                    tradeEntryBar = iTime(_Symbol, MainTimeframe, 0);
                    Print("=== ENTRY SEQUENCE EXTENDED ===");
                    Print("No positions yet, resetting entry timer to allow more time for first entry");
                }
                else
                {
                    // EMAs no longer aligned, cancel the trade direction
                    tradeDirection = 0;
                    inEntrySequence = false;
                    Print("=== ENTRY SEQUENCE CANCELLED ===");
                    Print("Reason: EMAs no longer aligned with original trade direction");
                }
            }
        }
    }
    
    //--- Check for MACD Exit Signals (Partial Exit)
    if(IsMACDCrossOver(macdMainPrev, macdSignalPrev, macdMainCurr, macdSignalCurr) && (currentBar > tradeEntryBar))
    {
        Print("=== MACD EXIT SIGNAL DETECTED ===");
        Print("Trigger: MACD line crossed Signal line");
        Print("Previous Bar - MACD:", macdMainPrev, " Signal:", macdSignalPrev);
        Print("Current Bar  - MACD:", macdMainCurr, " Signal:", macdSignalCurr);
        
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
                Print("All positions closed - Trade direction reset to 0");
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
        
        Print("=== OPENING BUY ORDER ===");
        Print("Entry Price:", price);
        Print("Stop Loss:", stopLoss, " (Distance:", (price - stopLoss) / _Point, " pips)");
        Print("Take Profit:", takeProfit, " (Distance:", (takeProfit - price) / _Point, " pips)");
        
        result = trade.Buy(lots, _Symbol, 0, stopLoss, takeProfit, comment);
    }
    else if(orderType == ORDER_TYPE_SELL)
    {
        double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double stopLoss = GetPivotBasedSL(false, sl);
        double takeProfit = GetPivotBasedTP(false, tp);
        
        Print("=== OPENING SELL ORDER ===");
        Print("Entry Price:", price);
        Print("Stop Loss:", stopLoss, " (Distance:", (stopLoss - price) / _Point, " pips)");
        Print("Take Profit:", takeProfit, " (Distance:", (price - takeProfit) / _Point, " pips)");
        
        result = trade.Sell(lots, _Symbol, 0, stopLoss, takeProfit, comment);
    }
    
    if(!result)
        Print("Trade Error:", trade.ResultRetcode(), ":", trade.CheckResultRetcodeDescription());
    
    return result;
}

//+------------------------------------------------------------------+
//| Close one open position of the specified type                    |
//+------------------------------------------------------------------+
bool CloseOnePosition(ENUM_ORDER_TYPE orderType)
{
    int totalPositions = PositionsTotal();
    bool closed = false;
    
    for(int i = totalPositions - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        // Check if the position belongs to this EA
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
                    Print("Closed position #", ticket, " successfully.");
                    closed = true;
                    
                    // Check if this was the last position
                    if(!HasOpenPositions(ORDER_TYPE_BUY) && !HasOpenPositions(ORDER_TYPE_SELL))
                    {
                        tradeDirection = 0;
                        inEntrySequence = false;
                        entryPositions = 0;
                        Print("=== TRADE DIRECTION RESET ===");
                        Print("Reason: All positions have been closed");
                    }
                    break; // Close only one position
                }
                else
                {
                    Print("Failed to close position #", ticket, ". Error: ", GetLastError());
                }
            }
        }
    }
    return closed;
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
                    Print("Closed position #", ticket, " successfully.");
                }
                else
                {
                    Print("Failed to close position #", ticket, ". Error: ", GetLastError());
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
        Print("=== TRADE DIRECTION RESET ===");
        Print("Reason: All positions have been closed");
    }
    
    return allClosed;
}

//+------------------------------------------------------------------+
//| Check if there are any open positions of a specific type         |
//+------------------------------------------------------------------+
bool HasOpenPositions(ENUM_ORDER_TYPE orderType)
{
    int totalPositions = PositionsTotal();
    
    for(int i = 0; i < totalPositions; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            bool matchingType = (orderType == ORDER_TYPE_BUY && posType == POSITION_TYPE_BUY) ||
                                (orderType == ORDER_TYPE_SELL && posType == POSITION_TYPE_SELL);
            
            if(matchingType)
                return true;
        }
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
        Print("Failed to copy buffer for handle ", handle, ". Error: ", GetLastError());
        return 0.0;
    }
}

//+------------------------------------------------------------------+
//| Detect MACD Crossover                                           |
//+------------------------------------------------------------------+
bool IsMACDCrossOver(double macdMainPrev, double macdSignalPrev, double macdMainCurr, double macdSignalCurr)
{
    // Check if the difference between MACD and Signal is significant enough
    if(MathAbs(macdMainCurr - macdSignalCurr) < MACDThreshold)
        return false;
        
    // Check for bullish crossover
    if(macdMainPrev <= macdSignalPrev && macdMainCurr > macdSignalCurr)
        return true;
    
    // Check for bearish crossover
    if(macdMainPrev >= macdSignalPrev && macdMainCurr < macdSignalCurr)
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
    int totalPositions = PositionsTotal();
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double currentATR = GetIndicatorValue(handleATR, 0);
    
    for(int i = totalPositions - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            double profitPips = 0;
            
            if(posType == POSITION_TYPE_BUY)
                profitPips = (currentPrice - openPrice) / point;
            else if(posType == POSITION_TYPE_SELL)
                profitPips = (openPrice - currentPrice) / point;
            
            // Calculate ATR-based exit levels in pips
            double atrPips = currentATR / point;
            double tpLevel = atrPips * ATRMultiplierTP;
            double slLevel = atrPips * ATRMultiplierSL;
            
            // Check for Take Profit
            if(profitPips >= tpLevel)
            {
                Print("=== TAKE PROFIT EXIT TRIGGERED ===");
                Print("Position Type: ", EnumToString(posType));
                Print("Entry Price: ", openPrice);
                Print("Current Price: ", currentPrice);
                Print("Profit in Pips: ", profitPips);
                Print("ATR in Pips: ", atrPips);
                Print("TP Level: ", tpLevel);
                
                if(trade.PositionClose(ticket))
                {
                    Print("Successfully closed position #", ticket, " at take profit");
                    
                    // Check if this was the last position
                    if(!HasOpenPositions(ORDER_TYPE_BUY) && !HasOpenPositions(ORDER_TYPE_SELL))
                    {
                        tradeDirection = 0;
                        inEntrySequence = false;
                        entryPositions = 0;
                        Print("=== TRADE DIRECTION RESET ===");
                        Print("Reason: All positions have been closed after take profit");
                    }
                }
            }
            // Check for Stop Loss
            else if(profitPips <= -slLevel)
            {
                Print("=== STOP LOSS EXIT TRIGGERED ===");
                Print("Position Type: ", EnumToString(posType));
                Print("Entry Price: ", openPrice);
                Print("Current Price: ", currentPrice);
                Print("Loss in Pips: ", profitPips);
                Print("ATR in Pips: ", atrPips);
                Print("SL Level: ", slLevel);
                
                if(trade.PositionClose(ticket))
                {
                    Print("Successfully closed position #", ticket, " at stop loss");
                    
                    // Check if this was the last position
                    if(!HasOpenPositions(ORDER_TYPE_BUY) && !HasOpenPositions(ORDER_TYPE_SELL))
                    {
                        tradeDirection = 0;
                        inEntrySequence = false;
                        entryPositions = 0;
                        Print("=== TRADE DIRECTION RESET ===");
                        Print("Reason: All positions have been closed after stop loss");
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Get hybrid take profit level                                       |
//+------------------------------------------------------------------+
double GetHybridTP(bool isBuy, double price, double atrPoints)
{
    double atrTP = price + (isBuy ? 1 : -1) * (atrPoints * ATRMultiplierTP) * _Point;
    double pivotTP = GetPivotBasedTP(isBuy, atrTP);
    
    if(!UseHybridExits)
        return UsePivotPoints ? pivotTP : atrTP;
        
    // If price is very close to a pivot level, prefer the pivot target
    if(IsPriceNearLevel(price, isBuy ? r1Level : s1Level))
        return pivotTP;
        
    // Calculate weighted average if both targets are valid
    if(pivotTP > 0)
    {
        double weightedTP = (atrTP * ATRWeight + pivotTP * PivotWeight) / (ATRWeight + PivotWeight);
        
        // Add logic to snap to nearest pivot if very close
        double nearestPivot = GetNearestLevel(weightedTP, isBuy);
        if(MathAbs(weightedTP - nearestPivot) < PivotBufferPips * _Point)
            return nearestPivot;
            
        return weightedTP;
    }
    
    return atrTP;
}

//+------------------------------------------------------------------+
//| Get hybrid stop loss level                                         |
//+------------------------------------------------------------------+
double GetHybridSL(bool isBuy, double price, double atrPoints)
{
    double atrSL = price - (isBuy ? 1 : -1) * (atrPoints * ATRMultiplierSL) * _Point;
    double pivotSL = GetPivotBasedSL(isBuy, atrSL);
    
    if(!UseHybridExits)
        return UsePivotPoints ? pivotSL : atrSL;
        
    // If price is very close to a pivot level, prefer the pivot stop
    if(IsPriceNearLevel(price, isBuy ? s1Level : r1Level))
        return pivotSL;
        
    // Calculate weighted average if both stops are valid
    if(pivotSL > 0)
    {
        double weightedSL = (atrSL * ATRWeight + pivotSL * PivotWeight) / (ATRWeight + PivotWeight);
        
        // Add logic to snap to nearest pivot if very close
        double nearestPivot = GetNearestLevel(weightedSL, !isBuy);
        if(MathAbs(weightedSL - nearestPivot) < PivotBufferPips * _Point)
            return nearestPivot;
            
        return weightedSL;
    }
    
    return atrSL;
}

//+------------------------------------------------------------------+
//| Calculate volatility ratio                                         |
//+------------------------------------------------------------------+
double GetVolatilityRatio()
{
    double currentATR = GetIndicatorValue(handleATR, 0);
    averageATR = GetIndicatorValue(handleAverageATR, 0);
    
    if(averageATR == 0) return 1.0; // Prevent division by zero
    
    double ratio = currentATR / averageATR;
    
    Print("=== VOLATILITY RATIO ===");
    Print("Current ATR: ", currentATR);
    Print("Average ATR: ", averageATR);
    Print("Ratio: ", ratio);
    
    return ratio;
}

//+------------------------------------------------------------------+
//| Calculate buffer size based on ATR and distance to pivot           |
//+------------------------------------------------------------------+
double CalculateBuffer(double price, double pivotLevel, bool isTP)
{
    double atrValue = GetIndicatorValue(handleATR, 0);
    double distanceToPivot = MathAbs(price - pivotLevel);
    
    // Calculate both types of buffers
    double atrBuffer = atrValue * (isTP ? TP_ATR_Mult : SL_ATR_Mult);
    double distanceBuffer = distanceToPivot * (isTP ? TP_Dist_Mult : SL_Dist_Mult);
    
    // Take the larger of the two
    double baseBuffer = MathMax(atrBuffer, distanceBuffer);
    
    // Apply volatility ratio
    double volatilityRatio = GetVolatilityRatio();
    double finalBuffer = baseBuffer * volatilityRatio;
    
    // Limit to maximum buffer size
    double maxBuffer = Max_Buffer_Pips * _Point;
    finalBuffer = MathMin(finalBuffer, maxBuffer);
    
    Print("=== BUFFER CALCULATION ===");
    Print("Price: ", price, " Pivot Level: ", pivotLevel);
    Print("ATR Buffer: ", atrBuffer, " Distance Buffer: ", distanceBuffer);
    Print("Base Buffer: ", baseBuffer);
    Print("Volatility Adjusted: ", finalBuffer);
    Print("Final Buffer: ", finalBuffer);
    
    return finalBuffer;
}

//+------------------------------------------------------------------+