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
input int    EMAPeriodFast   = 8;     // Fast EMA Period
input int    EMAPeriodMid    = 23;    // Mid EMA Period
input int    EMAPeriodSlow   = 22;    // Slow EMA Period
input int    MACDFast        = 15;    // MACD Fast EMA Period
input int    MACDSlow        = 17;    // MACD Slow EMA Period
input int    MACDSignal      = 13;     // MACD Signal SMA Period
input double RiskPercentage  = 5;     // Risk Percentage per Trade
input int    RiskMonth1     = 4;    // Month to modify risk (1-12)
input double RiskMultiplier1 = 2.4;  // Risk multiplier for Month1
input int    RiskMonth2     = 5;     // Second month to modify risk (0=disabled)
input double RiskMultiplier2 = 2.6;  // Risk multiplier for Month2
input int    RiskMonth3     = 1;     // Third month to modify risk (0=disabled)
input double RiskMultiplier3 = 5;  // Risk multiplier for Month3
input int    ATRPeriod       = 19;    // ATR Period
input double ATRMultiplierSL = 8.4;   // ATR Multiplier for Stop Loss
input double ATRMultiplierTP = 6.0;   // ATR Multiplier for Take Profit
input double MACDThreshold   = 0.00006; // Minimum MACD difference for signal
input int    EntryTimeoutBars = 8;    // Bars to wait for entry sequence
input double SLBufferPips    = 5.0;   // Stop-Loss Buffer in Pips
//--- Trading Time Parameters
input int    NoTradeStartHour = 6;     // No Trading Start Hour 
input int    NoTradeEndHour   = 7;     // No Trading End Hour
input int    HaltMinutesBefore = 30;   // Minutes before news event to halt trading
input int    HaltMinutesAfter  = 30;   // Minutes after news event to halt trading
input bool   HaltOnCPI        = true;  // Halt on CPI announcements
input bool   HaltOnNFP        = true;  // Halt on Non-Farm Payrolls
input bool   HaltOnFOMC       = true;  // Halt on FOMC meetings
input bool   HaltOnGDP        = true;  // Halt on GDP reports
input bool   HaltOnPPI        = true;  // Halt on PPI announcements
input bool   HaltOnCentralBank = true; // Halt on Central Bank speeches

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

// Trade object
CTrade      trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize EMA indicators
    handleEmaFast = iMA(_Symbol, PERIOD_H2, EMAPeriodFast, 0, MODE_EMA, PRICE_CLOSE);
    handleEmaMid  = iMA(_Symbol, PERIOD_H2, EMAPeriodMid,  0, MODE_EMA, PRICE_CLOSE);
    handleEmaSlow = iMA(_Symbol, PERIOD_H2, EMAPeriodSlow, 0, MODE_EMA, PRICE_CLOSE);
    
    // Initialize MACD indicator
    handleMacd = iMACD(_Symbol, PERIOD_H2, MACDFast, MACDSlow, MACDSignal, PRICE_CLOSE);
    
    // Initialize ATR indicator
    handleATR = iATR(_Symbol, PERIOD_H2, ATRPeriod);
    
    // Check if indicators are initialized successfully
    if(handleEmaFast == INVALID_HANDLE || handleEmaMid == INVALID_HANDLE || 
       handleEmaSlow == INVALID_HANDLE || handleMacd == INVALID_HANDLE || 
       handleATR == INVALID_HANDLE)
    {
        Print("Error initializing indicators.");
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
                        
                    events[count].currencyCode = countryCode;
                    events[count].importance = (int)event.importance;
                    events[count].id = event.id;
                    count++;
                }
            }
        }
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
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
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
        
    // Adjust risk for December
    double currentRisk = RiskPercentage;
    if(dt_struct.mon == 12)  // December
        currentRisk *= 2;  // Double the risk
    
    // Check for take profit on existing positions first
    CheckTakeProfit();
    
    //--- Check for new 2-hour bar
    datetime currentBar = iTime(_Symbol, PERIOD_H2, 0);
    if(currentBar <= lastBarTime)
        return; // No new bar yet
    
    // Once we detect a new bar, update lastBarTime
    lastBarTime = currentBar;
    
    // Check for entry sequence timeout
    if(inEntrySequence && currentBar > tradeEntryBar + (EntryTimeoutBars * PeriodSeconds(PERIOD_H2)))
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
    
    //--- Handle Signal Detection and Trade Direction
    if(isBullishCross && tradeDirection <= 0)  // Only take bullish signal if not already in a buy position
    {
        // Check for existing sell positions first
        if(!HasOpenPositions(ORDER_TYPE_SELL))
        {
            Print("=== BULLISH SIGNAL DETECTED ===");
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
            double currentClose = iClose(_Symbol, PERIOD_H2, 0);
            double previousClose = iClose(_Symbol, PERIOD_H2, 1);
            double previousHigh = iHigh(_Symbol, PERIOD_H2, 1);
            double previousLow = iLow(_Symbol, PERIOD_H2, 1);
            
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
            double currentClose = iClose(_Symbol, PERIOD_H2, 0);
            double previousClose = iClose(_Symbol, PERIOD_H2, 1);
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            
            // Calculate drawdown from the highest/lowest point since trade entry
            double maxDrawdown = 0;
            double highestPrice = currentClose;
            double lowestPrice = currentClose;
            
            for(int i = 0; i < 100; i++) // Look back up to 100 bars
            {
                datetime barTime = iTime(_Symbol, PERIOD_H2, i);
                if(barTime < tradeEntryBar) break;
                
                double high = iHigh(_Symbol, PERIOD_H2, i);
                double low = iLow(_Symbol, PERIOD_H2, i);
                
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
                    lastEntryBar = iTime(_Symbol, PERIOD_H2, 0); // Update last entry time after successful entry
                }
            }
        }
        
        // Check for entry sequence timeout using EntryTimeoutBars parameter
        datetime timeoutReference = (lastEntryBar > 0) ? lastEntryBar : tradeEntryBar;
        if(iTime(_Symbol, PERIOD_H2, 0) > timeoutReference + (EntryTimeoutBars * PeriodSeconds(PERIOD_H2)))
        {
            // Only timeout if we have at least one position open
            if(entryPositions > 0)
            {
                inEntrySequence = false;  // Only set to false if we have positions
                Print("=== ENTRY SEQUENCE TIMEOUT ===");
                Print("Could not find confirmation for all entries within ", EntryTimeoutBars, " bars");
                Print("Reason: Have ", entryPositions, " active position(s), stopping sequence for additional entries");
                Print("Time since last entry: ", (iTime(_Symbol, PERIOD_H2, 0) - timeoutReference) / PeriodSeconds(PERIOD_H2), " bars");
            }
            else if(tradeDirection != 0)  // If we have a direction but no positions yet
            {
                // Check if EMAs are still aligned in the right direction with tolerance
                if(CheckEMAAlignment(tradeDirection))
                {
                    // Reset the entry bar time to give more time for first entry
                    tradeEntryBar = iTime(_Symbol, PERIOD_H2, 0);
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
    MqlDateTime dt_struct;
    TimeToStruct(TimeCurrent(), dt_struct);
    double adjustedRisk = RiskPercentage;
    
    // Apply month-specific risk multipliers
    if(dt_struct.mon == RiskMonth1 && RiskMonth1 > 0 && RiskMonth1 <= 12)
        adjustedRisk *= RiskMultiplier1;
    else if(dt_struct.mon == RiskMonth2 && RiskMonth2 > 0 && RiskMonth2 <= 12)
        adjustedRisk *= RiskMultiplier2;
    else if(dt_struct.mon == RiskMonth3 && RiskMonth3 > 0 && RiskMonth3 <= 12)
        adjustedRisk *= RiskMultiplier3;
    
    riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (adjustedRisk / 100.0);
    
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
    
    if(orderType == ORDER_TYPE_BUY)
    {
        double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        Print("Opening BUY Order - Price:", price, " Lots:", lots);
        result = trade.Buy(lots, _Symbol, 0, 0, 0, comment);
    }
    else if(orderType == ORDER_TYPE_SELL)
    {
        double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        Print("Opening SELL Order - Price:", price, " Lots:", lots);
        result = trade.Sell(lots, _Symbol, 0, 0, 0, comment);
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
    double previousHigh = iHigh(_Symbol, PERIOD_H2, 1);
    double previousLow  = iLow(_Symbol, PERIOD_H2, 1);
    
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