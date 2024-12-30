//+------------------------------------------------------------------+
//|                                                      StubbsEA.mq5 |
//|                        Your Name or Company                       |
//|                                                                  |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>

//--- Input Parameters
input int    EMAPeriodFast   = 5;     // Fast EMA Period
input int    EMAPeriodMid    = 25;    // Mid EMA Period
input int    EMAPeriodSlow   = 30;    // Slow EMA Period
input int    MACDFast        = 12;    // MACD Fast EMA Period
input int    MACDSlow        = 26;    // MACD Slow EMA Period
input int    MACDSignal      = 9;     // MACD Signal SMA Period
input double RiskPercentage  = 5;   // Risk Percentage per Trade (1%)
input double SLBufferPips    = 2.0;   // Stop-Loss Buffer in Pips
input double TPPips          = 500.0;  // Take Profit in Pips
input double MACDThreshold   = 0.0002; // Minimum MACD difference for signal
input int    EntryTimeoutBars = 12;    // Bars to wait for entry sequence
input double MinDrawdownPips = 250.0;  // Minimum drawdown in pips before checking exit conditions

//--- Global Variables
int          MagicNumber       = 123456; // Unique identifier for EA's trades
datetime     lastBarTime       = 0;       // Tracks the last processed bar time
datetime     tradeEntryBar     = 0;       // Tracks the bar time when trades were opened
int          partialClosures   = 0;       // Tracks the number of partial closures done
int          entryPositions    = 0;       // Tracks how many positions we've entered
bool         inEntrySequence   = false;   // Whether we're in the middle of entering positions

// Indicator handles
int          handleEmaFast;
int          handleEmaMid;
int          handleEmaSlow;
int          handleMacd;
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
    
    // Check if indicators are initialized successfully
    if(handleEmaFast == INVALID_HANDLE || handleEmaMid == INVALID_HANDLE || handleEmaSlow == INVALID_HANDLE || handleMacd == INVALID_HANDLE)
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
    
    Print("EA Deinitialized.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
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
        // Third position: Strong trend continuation with volume
        else if(entryPositions == 2)
        {
            double currentClose = iClose(_Symbol, PERIOD_H2, 0);
            double previousClose = iClose(_Symbol, PERIOD_H2, 1);
            
            if(orderType == ORDER_TYPE_BUY)
            {
                if(currentClose > previousClose * 1.01 && // Allowing a slight increase from previous close
                   emaFastCurr > emaMidCurr && // EMAs still aligned
                   emaMidCurr > emaSlowCurr &&
                   macdMainCurr > macdMainPrev && // MACD still increasing
                   macdMainCurr > macdSignalCurr) // MACD above signal
                {
                    shouldEnter = true;
                    entryReason = "Third Entry - Strong Bullish Continuation (Price up, EMAs aligned, MACD strength)";
                }
            }
            else // SELL
            {
                if(currentClose < previousClose * 0.99 && // Allowing a slight decrease from previous close
                   emaFastCurr < emaMidCurr && // EMAs still aligned
                   emaMidCurr < emaSlowCurr &&
                   macdMainCurr < macdMainPrev && // MACD still decreasing
                   macdMainCurr < macdSignalCurr) // MACD below signal
                {
                    shouldEnter = true;
                    entryReason = "Third Entry - Strong Bearish Continuation (Price down, EMAs aligned, MACD strength)";
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
                }
            }
        }
        
        // Check for entry sequence timeout using EntryTimeoutBars parameter
        if(iTime(_Symbol, PERIOD_H2, 0) > tradeEntryBar + (EntryTimeoutBars * PeriodSeconds(PERIOD_H2)))
        {
            // Only timeout if we have at least one position open
            if(entryPositions > 0)
            {
                inEntrySequence = false;
                Print("=== ENTRY SEQUENCE TIMEOUT ===");
                Print("Could not find confirmation for all entries within ", EntryTimeoutBars, " bars");
                Print("Reason: Have ", entryPositions, " active position(s), stopping sequence for additional entries");
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
//| Check for strong momentum change exit                             |
//+------------------------------------------------------------------+
bool IsStrongMomentumChange(double macdMainPrev, double macdSignalPrev, double macdMainCurr, double macdSignalCurr)
{
    // Check if the difference between MACD and Signal is significant enough
    if(MathAbs(macdMainCurr - macdSignalCurr) < MACDThreshold * 2) // Using 2x threshold for stronger signal
        return false;
        
    // Check for strong bullish momentum change (for exiting shorts)
    if(macdMainPrev <= macdSignalPrev && macdMainCurr > macdSignalCurr &&
       macdMainCurr > macdMainPrev * 1.5) // Requiring 50% increase in MACD
        return true;
    
    // Check for strong bearish momentum change (for exiting longs)
    if(macdMainPrev >= macdSignalPrev && macdMainCurr < macdSignalCurr &&
       macdMainCurr < macdMainPrev * 1.5) // Requiring 50% decrease in MACD
        return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Check positions for take profit or momentum exit                  |
//+------------------------------------------------------------------+
void CheckTakeProfit()
{
    int totalPositions = PositionsTotal();
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double maxProfitPips = 0;
    double maxLossPips = 0;
    ulong bestTicket = 0;
    ENUM_POSITION_TYPE bestPosType = POSITION_TYPE_BUY; // Default value
    double bestOpenPrice = 0;
    double bestCurrentPrice = 0;
    
    // First find the position with the highest profit or significant loss
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
            
            // Track position with highest profit
            if(profitPips > maxProfitPips)
            {
                maxProfitPips = profitPips;
                bestTicket = ticket;
                bestPosType = posType;
                bestOpenPrice = openPrice;
                bestCurrentPrice = currentPrice;
            }
            
            // Track maximum loss
            if(profitPips < maxLossPips)
                maxLossPips = profitPips;
        }
    }
    
    // If we have significant drawdown, check for momentum-based exit
    if(maxLossPips <= -MinDrawdownPips)
    {
        double macdMainPrev = GetIndicatorValue(handleMacd, 1, 0);
        double macdSignalPrev = GetIndicatorValue(handleMacd, 1, 1);
        double macdMainCurr = GetIndicatorValue(handleMacd, 0, 0);
        double macdSignalCurr = GetIndicatorValue(handleMacd, 0, 1);
        
        if(IsStrongMomentumChange(macdMainPrev, macdSignalPrev, macdMainCurr, macdSignalCurr))
        {
            Print("=== MOMENTUM EXIT SIGNAL DETECTED ===");
            Print("Trigger: Strong momentum change after significant drawdown");
            Print("Maximum Loss in Pips: ", maxLossPips);
            Print("Previous Bar - MACD:", macdMainPrev, " Signal:", macdSignalPrev);
            Print("Current Bar  - MACD:", macdMainCurr, " Signal:", macdSignalCurr);
            
            // Close all positions when momentum changes significantly
            CloseAllPositions(ORDER_TYPE_BUY);
            CloseAllPositions(ORDER_TYPE_SELL);
            return;
        }
    }
    
    // Check for take profit exit
    if(maxProfitPips >= TPPips && bestTicket > 0)
    {
        Print("=== TAKE PROFIT EXIT TRIGGERED ===");
        Print("Trigger: Profit exceeded ", TPPips, " pips target");
        Print("Position Type: ", EnumToString(bestPosType));
        Print("Entry Price: ", bestOpenPrice);
        Print("Current Price: ", bestCurrentPrice);
        Print("Profit in Pips: ", maxProfitPips);
        
        if(trade.PositionClose(bestTicket))
        {
            Print("Successfully closed position #", bestTicket);
            partialClosures++;
            
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

//+------------------------------------------------------------------+