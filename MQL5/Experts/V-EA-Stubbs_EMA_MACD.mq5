//+------------------------------------------------------------------+
//|                                                      StubbsEA.mq5 |
//|                        Your Name or Company                       |
//|                                                                  |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>

//--- Input Parameters
input int    EMAPeriodFast   = 8;     // Fast EMA Period
input int    EMAPeriodMid    = 23;    // Mid EMA Period
input int    EMAPeriodSlow   = 22;    // Slow EMA Period
input int    MACDFast        = 15;    // MACD Fast EMA Period
input int    MACDSlow        = 17;    // MACD Slow EMA Period
input int    MACDSignal      = 13;     // MACD Signal SMA Period
input double RiskPercentage  = 23;     // Risk Percentage per Trade
input int    RiskMonth1     = 12;    // Month to modify risk (1-12)
input double RiskMultiplier1 = 2.0;  // Risk multiplier for Month1
input int    RiskMonth2     = 0;     // Second month to modify risk (0=disabled)
input double RiskMultiplier2 = 1.0;  // Risk multiplier for Month2
input int    RiskMonth3     = 0;     // Third month to modify risk (0=disabled)
input double RiskMultiplier3 = 1.0;  // Risk multiplier for Month3
input int    ATRPeriod       = 19;    // ATR Period
input double ATRMultiplierSL = 8.4;   // ATR Multiplier for Stop Loss
input double ATRMultiplierTP = 6.0;   // ATR Multiplier for Take Profit
input double MACDThreshold   = 0.00088; // Minimum MACD difference for signal
input int    EntryTimeoutBars = 8;    // Bars to wait for entry sequence
input double SLBufferPips    = 5.0;   // Stop-Loss Buffer in Pips
//--- Trading Time Parameters
input int    NoTradeStartHour = 1;     // No Trading Start Hour 
input int    NoTradeEndHour   = 2;     // No Trading End Hour

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
//| Error Checking Functions                                           |
//+------------------------------------------------------------------+

//--- Check if indicator handle is valid
bool IsIndicatorValid(int handle, string indicatorName)
{
    if(handle == INVALID_HANDLE)
    {
        string errorMsg = StringFormat("Failed to create %s indicator handle. Error: %d", indicatorName, GetLastError());
        Print(errorMsg);
        return false;
    }
    return true;
}

//--- Check if position operations are allowed
bool IsTradeAllowed()
{
    if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
    {
        Print("Trading is not allowed. Please enable AutoTrading.");
        return false;
    }
    
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
    {
        Print("Trading is not allowed in the terminal.");
        return false;
    }
    
    if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
    {
        Print("Trading is not allowed for this account.");
        return false;
    }
    
    if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
    {
        Print("Automated trading is not allowed for this account.");
        return false;
    }
    
    return true;
}

//--- Check if symbol is valid and trading is allowed for it
bool IsSymbolValid()
{
    // Check if symbol exists and is selected in Market Watch
    if(!SymbolInfoInteger(_Symbol, SYMBOL_SELECT))
    {
        Print("Symbol ", _Symbol, " is not selected in Market Watch.");
        return false;
    }
    
    // Check if trading is allowed for this symbol
    if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE))
    {
        Print("Trading is not allowed for symbol ", _Symbol);
        return false;
    }
    
    // Check trading mode
    long trade_mode;
    if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE, trade_mode))
    {
        Print("Failed to get trading mode for symbol ", _Symbol);
        return false;
    }
    
    if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
    {
        Print("Trading is disabled for symbol ", _Symbol);
        return false;
    }
    
    // Check filling modes
    long filling_mode;
    if(!SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE, filling_mode))
    {
        Print("Failed to get filling mode for symbol ", _Symbol);
        return false;
    }
    
    if((filling_mode & SYMBOL_FILLING_FOK) == 0 && (filling_mode & SYMBOL_FILLING_IOC) == 0)
    {
        Print("Symbol ", _Symbol, " does not support required filling modes (FOK or IOC)");
        return false;
    }
    
    // Check if we can get basic price information
    MqlTick last_tick;
    if(!SymbolInfoTick(_Symbol, last_tick))
    {
        Print("Cannot get price information for symbol ", _Symbol);
        return false;
    }
    
    return true;
}

//--- Check if current time is within allowed trading hours
bool IsWithinTradingHours()
{
    MqlDateTime dt_struct;
    TimeToStruct(TimeCurrent(), dt_struct);
    
    // Check if it's Sunday
    if(dt_struct.day_of_week == 0)
        return false;
        
    // Check if current time is within no-trade hours
    int currentHour = dt_struct.hour;
    if(currentHour >= NoTradeStartHour && currentHour < NoTradeEndHour)
        return false;
        
    return true;
}

//--- Validate trade parameters
bool ValidateTradeParameters(double lots, double sl, double tp)
{
    if(lots <= 0)
    {
        Print("Invalid lot size: ", lots);
        return false;
    }
    
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    
    if(lots < minLot || lots > maxLot)
    {
        Print("Lot size ", lots, " is outside allowed range [", minLot, ", ", maxLot, "]");
        return false;
    }
    
    if(sl < 0 || tp < 0)
    {
        Print("Invalid SL or TP values: SL=", sl, " TP=", tp);
        return false;
    }
    
    return true;
}

//--- Check if there's enough free margin for the trade
bool HasSufficientMargin(double lots, ENUM_ORDER_TYPE orderType)
{
    double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double margin;
    if(!OrderCalcMargin(orderType, _Symbol, lots, price, margin))
    {
        Print("Failed to calculate margin. Error: ", GetLastError());
        return false;
    }
    
    if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) < margin)
    {
        Print("Insufficient free margin. Required: ", margin, " Available: ", AccountInfoDouble(ACCOUNT_MARGIN_FREE));
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Check if trading is allowed
    if(!IsTradeAllowed())
        return(INIT_FAILED);
        
    // Check if symbol is valid
    if(!IsSymbolValid())
        return(INIT_FAILED);
    
    // Initialize EMA indicators
    handleEmaFast = iMA(_Symbol, PERIOD_H2, EMAPeriodFast, 0, MODE_EMA, PRICE_CLOSE);
    handleEmaMid  = iMA(_Symbol, PERIOD_H2, EMAPeriodMid,  0, MODE_EMA, PRICE_CLOSE);
    handleEmaSlow = iMA(_Symbol, PERIOD_H2, EMAPeriodSlow, 0, MODE_EMA, PRICE_CLOSE);
    
    // Initialize MACD indicator
    handleMacd = iMACD(_Symbol, PERIOD_H2, MACDFast, MACDSlow, MACDSignal, PRICE_CLOSE);
    
    // Initialize ATR indicator
    handleATR = iATR(_Symbol, PERIOD_H2, ATRPeriod);
    
    // Check if indicators are initialized successfully
    if(!IsIndicatorValid(handleEmaFast, "Fast EMA") ||
       !IsIndicatorValid(handleEmaMid, "Mid EMA") ||
       !IsIndicatorValid(handleEmaSlow, "Slow EMA") ||
       !IsIndicatorValid(handleMacd, "MACD") ||
       !IsIndicatorValid(handleATR, "ATR"))
    {
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
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if trading is allowed
    if(!IsTradeAllowed())
        return;
        
    // Check if we're within trading hours
    if(!IsWithinTradingHours())
        return;
        
    // Check if current time is within no-trade hours (1 AM - 9 AM)
    MqlDateTime dt_struct;
    TimeToStruct(TimeCurrent(), dt_struct);
    int currentHour = dt_struct.hour;
    if(currentHour >= NoTradeStartHour && currentHour < NoTradeEndHour)
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
    // Check if trading is allowed
    if(!IsTradeAllowed())
        return false;
        
    // Check if we're within trading hours
    if(!IsWithinTradingHours())
    {
        Print("Cannot open trade outside trading hours");
        return false;
    }
    
    // Validate trade parameters
    if(!ValidateTradeParameters(lots, sl, tp))
        return false;
        
    // Check margin
    if(!HasSufficientMargin(lots, orderType))
        return false;
    
    double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double steps = MathFloor(lots / stepLot);
    lots = NormalizeDouble(steps * stepLot, 2);
    
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    if(lots < minLot)
        return false;
    
    // Calculate distance to stop-loss in pips for logging
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double currentPrice = (orderType == ORDER_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double slDistance = MathAbs(currentPrice - sl) / point;
    
    // Add emergency stop-loss info to comment
    string fullComment = StringFormat("%s [EmergSL=%.1f pips]", 
                                    comment,
                                    slDistance);
    
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    trade.SetTypeFillingBySymbol(_Symbol);
    
    bool result = false;
    
    if(orderType == ORDER_TYPE_BUY)
    {
        Print("=== OPENING BUY ORDER WITH EMERGENCY STOP-LOSS ===");
        Print("Price:", currentPrice);
        Print("Lots:", lots);
        Print("Emergency Stop-Loss Distance:", slDistance, " pips");
        Print("Emergency Stop-Loss Price:", sl);
        result = trade.Buy(lots, _Symbol, 0, sl, tp, fullComment);
    }
    else if(orderType == ORDER_TYPE_SELL)
    {
        Print("=== OPENING SELL ORDER WITH EMERGENCY STOP-LOSS ===");
        Print("Price:", currentPrice);
        Print("Lots:", lots);
        Print("Emergency Stop-Loss Distance:", slDistance, " pips");
        Print("Emergency Stop-Loss Price:", sl);
        result = trade.Sell(lots, _Symbol, 0, sl, tp, fullComment);
    }
    
    if(!result)
    {
        int error = trade.ResultRetcode();
        Print("Trade Error:", error, ":", trade.CheckResultRetcodeDescription());
        return false;
    }
    
    return true;
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
//| Get Stop Loss Price with buffer for emergency/catastrophic stops  |
//+------------------------------------------------------------------+
double GetStopLossPrice(bool isBuy)
{
    // Get current ATR value for volatility-based buffer
    double currentATR = GetIndicatorValue(handleATR, 0);
    if(currentATR == 0) currentATR = GetIndicatorValue(handleATR, 1); // Fallback to previous ATR
    
    // Calculate a dynamic buffer based on ATR and fixed pips
    // Using 2x ATR plus fixed buffer for catastrophic scenarios
    double dynamicBuffer = (2 * currentATR) + (SLBufferPips * SymbolInfoDouble(_Symbol, SYMBOL_POINT));
    
    // Look back several bars to find swing high/low
    int lookbackBars = 5; // Adjust based on your timeframe
    double swingHigh = 0, swingLow = DBL_MAX;
    
    for(int i = 1; i <= lookbackBars; i++)
    {
        double high = iHigh(_Symbol, PERIOD_H2, i);
        double low = iLow(_Symbol, PERIOD_H2, i);
        
        if(high > swingHigh) swingHigh = high;
        if(low < swingLow) swingLow = low;
    }
    
    if(isBuy)
    {
        // For buy orders: Stop loss below the lowest low minus dynamic buffer
        return swingLow - dynamicBuffer;
    }
    else
    {
        // For sell orders: Stop loss above the highest high plus dynamic buffer
        return swingHigh + dynamicBuffer;
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
            double stopLoss = PositionGetDouble(POSITION_SL);
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
            
            // Check if emergency stop-loss is hit or about to be hit
            bool isEmergencyStopHit = false;
            if(posType == POSITION_TYPE_BUY && currentPrice <= stopLoss)
                isEmergencyStopHit = true;
            else if(posType == POSITION_TYPE_SELL && currentPrice >= stopLoss)
                isEmergencyStopHit = true;
            
            if(isEmergencyStopHit)
            {
                Print("!!! EMERGENCY STOP-LOSS HIT !!!");
                Print("=================================");
                Print("Position Type: ", EnumToString(posType));
                Print("Entry Price: ", openPrice);
                Print("Stop-Loss Price: ", stopLoss);
                Print("Current Price: ", currentPrice);
                Print("Loss in Pips: ", profitPips);
                Print("ATR in Pips: ", atrPips);
                Print("Position Comment: ", PositionGetString(POSITION_COMMENT));
                Print("=================================");
                
                if(trade.PositionClose(ticket))
                {
                    Print("Successfully closed position #", ticket, " at EMERGENCY STOP-LOSS");
                    
                    // Check if this was the last position
                    if(!HasOpenPositions(ORDER_TYPE_BUY) && !HasOpenPositions(ORDER_TYPE_SELL))
                    {
                        tradeDirection = 0;
                        inEntrySequence = false;
                        entryPositions = 0;
                        Print("=== TRADE DIRECTION RESET ===");
                        Print("Reason: All positions closed after emergency stop-loss hit");
                    }
                }
                continue; // Move to next position after emergency stop-loss
            }
            
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
        }
    }
}

//+------------------------------------------------------------------+