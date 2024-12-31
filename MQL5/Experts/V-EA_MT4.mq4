//+------------------------------------------------------------------+
//|                                                      StubbsEA.mq4 |
//|                        Your Name or Company                       |
//|                                                                  |
//+------------------------------------------------------------------+
#property strict

// Define H2 timeframe as 120 minutes (if available)
// If not available, consider using PERIOD_H1 and managing two bars as one
#define PERIOD_H2 120

//--- Helper function to convert timeframe to seconds
int PERIOD_SECONDS(int period)
{
    return period * 60;  // Convert minutes to seconds
}

//--- Input Parameters
extern int    EMAPeriodFast     = 5;     // Fast EMA Period
extern int    EMAPeriodMid      = 25;    // Mid EMA Period
extern int    EMAPeriodSlow     = 30;    // Slow EMA Period
extern int    MACDFast          = 12;    // MACD Fast EMA Period
extern int    MACDSlow          = 26;    // MACD Slow EMA Period
extern int    MACDSignal        = 9;     // MACD Signal SMA Period
extern double RiskPercentage    = 45;     // Risk Percentage per Trade (5%)
extern int    ATRPeriod         = 17;    // ATR Period
extern double ATRMultiplierSL   = 4.4;   // ATR Multiplier for Stop Loss
extern double ATRMultiplierTP   = 7.2;   // ATR Multiplier for Take Profit (3:1 ratio)
extern double MACDThreshold     = 0.0002; // Minimum MACD difference for signal
extern int    EntryTimeoutBars  = 8;    // Bars to wait for entry sequence
extern double SLBufferPips      = 2.0;   // Stop-Loss Buffer in Pips

//--- Global Variables
int          MagicNumber       = 123456; // Unique identifier for EA's trades
datetime     lastBarTime       = 0;       // Tracks the last processed bar time
datetime     tradeEntryBar     = 0;       // Tracks the bar time when trades were opened
datetime     lastEntryBar      = 0;       // Tracks the bar time of the last successful entry
int          partialClosures   = 0;       // Tracks the number of partial closures done
int          entryPositions    = 0;       // Tracks how many positions we've entered
bool         inEntrySequence   = false;   // Whether we're in the middle of entering positions
int          tradeDirection    = 0;       // 0 = No position, 1 = Buy, -1 = Sell

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
{
    // Check if there are enough bars to initialize
    if(Bars < EMAPeriodSlow + 1)
    {
        Print("Not enough bars to initialize EA.");
        return(INIT_FAILED);
    }
    
    Print("EA Initialized Successfully.");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
{
    // No specific deinitialization required in MQL4
    Print("EA Deinitialized.");
    return(0);
}

//+------------------------------------------------------------------+
//| Custom function to compare two doubles with a tolerance          |
//+------------------------------------------------------------------+
int DoubleCompare(double a, double b, double tol = 1e-10)
{
    if(MathAbs(a - b) < tol)
        return 0;
    else if(a > b)
        return 1;
    else
        return -1;
}

//+------------------------------------------------------------------+
//| Expert start function (replaces OnTick in MQL4)                  |
//+------------------------------------------------------------------+
int start()
{
    // The start function is called on every tick
    
    // Check for take profit or stop loss on existing positions first
    CheckTakeProfit();
    
    //--- Check for new 2-hour bar
    datetime currentBar = iTime(Symbol(), PERIOD_H2, 0);
    if(currentBar <= lastBarTime)
        return(0); // No new bar yet
    
    // Once a new bar is detected, update lastBarTime
    lastBarTime = currentBar;
    
    // Check for entry sequence timeout
    if(inEntrySequence && currentBar > tradeEntryBar + (EntryTimeoutBars * PERIOD_SECONDS(PERIOD_H2)))
    {
        inEntrySequence = false;
        Print("=== ENTRY SEQUENCE TIMEOUT ===");
        Print("Could not find confirmation for all entries within ", EntryTimeoutBars, " bars");
    }
    
    //--- Retrieve EMA values for the previous and current closed bars
    double emaFastPrev = iMA(Symbol(), PERIOD_H2, EMAPeriodFast, 0, MODE_EMA, PRICE_CLOSE, 1);
    double emaMidPrev  = iMA(Symbol(), PERIOD_H2, EMAPeriodMid,  0, MODE_EMA, PRICE_CLOSE, 1);
    double emaSlowPrev = iMA(Symbol(), PERIOD_H2, EMAPeriodSlow, 0, MODE_EMA, PRICE_CLOSE, 1);
    
    double emaFastCurr = iMA(Symbol(), PERIOD_H2, EMAPeriodFast, 0, MODE_EMA, PRICE_CLOSE, 0);
    double emaMidCurr  = iMA(Symbol(), PERIOD_H2, EMAPeriodMid,  0, MODE_EMA, PRICE_CLOSE, 0);
    double emaSlowCurr = iMA(Symbol(), PERIOD_H2, EMAPeriodSlow, 0, MODE_EMA, PRICE_CLOSE, 0);
    
    //--- Retrieve MACD values for the previous and current closed bars
    double macdMainPrev   = iMACD(Symbol(), PERIOD_H2, MACDFast, MACDSlow, MACDSignal, PRICE_CLOSE, MODE_MAIN, 1);
    double macdSignalPrev = iMACD(Symbol(), PERIOD_H2, MACDFast, MACDSlow, MACDSignal, PRICE_CLOSE, MODE_SIGNAL, 1);
    double macdMainCurr   = iMACD(Symbol(), PERIOD_H2, MACDFast, MACDSlow, MACDSignal, PRICE_CLOSE, MODE_MAIN, 0);
    double macdSignalCurr = iMACD(Symbol(), PERIOD_H2, MACDFast, MACDSlow, MACDSignal, PRICE_CLOSE, MODE_SIGNAL, 0);
    
    //--- Validate MACD values
    if(DoubleCompare(macdMainPrev, 0.0) == 0 || DoubleCompare(macdSignalPrev, 0.0) == 0 ||
       DoubleCompare(macdMainCurr, 0.0) == 0 || DoubleCompare(macdSignalCurr, 0.0) == 0)
    {
        Print("Invalid MACD values retrieved. Skipping this tick.");
        return(0);
    }
    
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
        if(!HasOpenPositions(OP_SELL))
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
            
            // Since a bullish signal was taken, ignore any bearish signal on this bar
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
        if(!HasOpenPositions(OP_BUY))
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
        int orderType;
        if(tradeDirection == 1)
            orderType = OP_BUY;
        else if(tradeDirection == -1)
            orderType = OP_SELL;
        else
        {
            Print("=== ENTRY SEQUENCE CANCELLED ===");
            Print("Reason: No valid trade direction set");
            inEntrySequence = false;
            return(0);
        }
        
        bool shouldEnter = false;
        string entryReason = "";
        
        // First position: Initial crossover with multiple confirmations
        if(entryPositions == 0)
        {
            if(orderType == OP_BUY)
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
            double currentClose = iClose(Symbol(), PERIOD_H2, 0);
            double previousClose = iClose(Symbol(), PERIOD_H2, 1);
            double previousHigh = iHigh(Symbol(), PERIOD_H2, 1);
            double previousLow = iLow(Symbol(), PERIOD_H2, 1);
            
            if(orderType == OP_BUY)
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
            double currentClose = iClose(Symbol(), PERIOD_H2, 0);
            double previousClose = iClose(Symbol(), PERIOD_H2, 1);
            double point = Point;
            
            // Calculate drawdown from the highest/lowest point since trade entry
            double maxDrawdown = 0;
            double highestPrice = currentClose;
            double lowestPrice = currentClose;
            
            int lookBackBars = 100; // Look back up to 100 bars
            for(int iBar = 0; iBar < lookBackBars; iBar++)
            {
                datetime barTime = iTime(Symbol(), PERIOD_H2, iBar);
                if(barTime < tradeEntryBar) break;
                
                double high = iHigh(Symbol(), PERIOD_H2, iBar);
                double low = iLow(Symbol(), PERIOD_H2, iBar);
                
                if(high > highestPrice) highestPrice = high;
                if(low < lowestPrice) lowestPrice = low;
            }
            
            if(orderType == OP_BUY)
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
                    if(maxDrawdown >= 150.0)
                        entryReason = StringFormat("Third Entry - Bullish Drawdown Entry (%.1f pips drawdown, EMAs aligned, positive momentum)", maxDrawdown);
                    else
                        entryReason = "Third Entry - Strong Bullish Continuation (Price up, EMAs aligned, MACD strength)";
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
                    if(maxDrawdown >= 150.0)
                        entryReason = StringFormat("Third Entry - Bearish Drawdown Entry (%.1f pips drawdown, EMAs aligned, negative momentum)", maxDrawdown);
                    else
                        entryReason = "Third Entry - Strong Bearish Continuation (Price down, EMAs aligned, MACD strength)";
                }
            }
        }
        
        if(shouldEnter)
        {
            Print("=== ENTRY CONFIRMATION #", (entryPositions + 1), " ===");
            Print("Direction:", (orderType == OP_BUY ? "BUY" : "SELL"));
            Print("Reason:", entryReason);
            Print("EMA Values - Fast:", emaFastCurr, " Mid:", emaMidCurr, " Slow:", emaSlowCurr);
            Print("MACD Values - Main:", macdMainCurr, " Signal:", macdSignalCurr);
            
            double stopLossPrice = GetStopLossPrice(orderType == OP_BUY);
            double riskPerTrade = AccountBalance() * (RiskPercentage / 100.0);
            double pipsDistance;
            
            if(orderType == OP_BUY)
                pipsDistance = MathAbs(Ask - stopLossPrice) / Point;
            else
                pipsDistance = MathAbs(stopLossPrice - Bid) / Point;
            
            double lotSize = CalculateLotSize(riskPerTrade, pipsDistance);
            if(lotSize > 0.0)
            {
                if(OpenTrade(orderType, lotSize, stopLossPrice, 0, 
                            StringFormat("%s Entry #%d", (orderType == OP_BUY ? "Bullish" : "Bearish"), entryPositions + 1)))
                {
                    entryPositions++;
                    lastEntryBar = iTime(Symbol(), PERIOD_H2, 0); // Update last entry time after successful entry
                }
            }
        }
        
        // Check for entry sequence timeout using EntryTimeoutBars parameter
        datetime timeoutReference = (lastEntryBar > 0) ? lastEntryBar : tradeEntryBar;
        if(iTime(Symbol(), PERIOD_H2, 0) > timeoutReference + (EntryTimeoutBars * PERIOD_SECONDS(PERIOD_H2)))
        {
            // Only timeout if we have at least one position open
            if(entryPositions > 0)
            {
                inEntrySequence = false;  // Only set to false if we have positions
                Print("=== ENTRY SEQUENCE TIMEOUT ===");
                Print("Could not find confirmation for all entries within ", EntryTimeoutBars, " bars");
                Print("Reason: Have ", entryPositions, " active position(s), stopping sequence for additional entries");
                Print("Time since last entry: ", (iTime(Symbol(), PERIOD_H2, 0) - timeoutReference) / PERIOD_SECONDS(PERIOD_H2), " bars");
            }
            else if(tradeDirection != 0)  // If we have a direction but no positions yet
            {
                // Check if EMAs are still aligned in the right direction with tolerance
                if(CheckEMAAlignment(tradeDirection))
                {
                    // Reset the entry bar time to give more time for first entry
                    tradeEntryBar = iTime(Symbol(), PERIOD_H2, 0);
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
        
        int buyCount = 0, sellCount = 0;
        for(int iPos = 0; iPos < OrdersTotal(); iPos++)
        {
            if(OrderSelect(iPos, SELECT_BY_POS, MODE_TRADES))
            {
                if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
                {
                    if(OrderType() == OP_BUY) buyCount++;
                    if(OrderType() == OP_SELL) sellCount++;
                }
            }
        }
        
        // Determine which type to close based on higher count
        int orderTypeToClose;
        if(buyCount > sellCount)
            orderTypeToClose = OP_BUY;
        else
            orderTypeToClose = OP_SELL;
        
        if(CloseOnePosition(orderTypeToClose))
        {
            partialClosures++;
            // Update trade direction if all positions are closed
            if(!HasOpenPositions(OP_BUY) && !HasOpenPositions(OP_SELL))
            {
                tradeDirection = 0; // Reset direction when no positions are open
                Print("All positions closed - Trade direction reset to 0");
            }
        }
    }
    
    return(0);
}

//+------------------------------------------------------------------+
//| Calculate Lot Size based on risk and pip distance                |
//+------------------------------------------------------------------+
double CalculateLotSize(double riskAmount, double pipsDistance)
{
    double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
    double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    
    if(tickSize == 0.0)
        return 0.0;
    
    double pipValue = (0.0001 / tickSize) * tickValue;
    double bidPrice = MarketInfo(Symbol(), MODE_BID);
    
    if(bidPrice == 0.0)
        return 0.0;
    
    double riskAmountBase = riskAmount / bidPrice;
    double lotSize = 0.0;
    
    if(pipsDistance > 0.0)
        lotSize = riskAmountBase / (pipsDistance * pipValue);
    
    double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
    double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
    double stepLot = MarketInfo(Symbol(), MODE_LOTSTEP);
    
    double steps = MathFloor(lotSize / stepLot);
    lotSize = steps * stepLot;
    
    if(lotSize < minLot)
        lotSize = minLot;
    if(lotSize > maxLot)
        lotSize = maxLot;
    
    lotSize = NormalizeDouble(lotSize, 2);
    return lotSize;
}

//+------------------------------------------------------------------+
//| Open Trade with specified parameters                              |
//+------------------------------------------------------------------+
bool OpenTrade(int orderType, double lots, double sl, double tp, string comment="")
{
    double price, slPrice, tpPrice;
    int ticket;
    
    if(orderType == OP_BUY)
    {
        price = Ask;
        slPrice = sl;
        tpPrice = tp; // 0 indicates no TP
        ticket = OrderSend(Symbol(), OP_BUY, lots, price, 10, slPrice, tpPrice, comment, MagicNumber, 0, Green);
    }
    else if(orderType == OP_SELL)
    {
        price = Bid;
        slPrice = sl;
        tpPrice = tp; // 0 indicates no TP
        ticket = OrderSend(Symbol(), OP_SELL, lots, price, 10, slPrice, tpPrice, comment, MagicNumber, 0, Red);
    }
    else
    {
        Print("Invalid order type.");
        return false;
    }
    
    if(ticket < 0)
    {
        Print("Error opening ", (orderType == OP_BUY ? "BUY" : "SELL"), " order. Error: ", GetLastError());
        return false;
    }
    else
    {
        Print("Opened ", (orderType == OP_BUY ? "BUY" : "SELL"), " order #", ticket, " at price ", price, " with lot size ", lots);
        return true;
    }
}

//+------------------------------------------------------------------+
//| Close one open position of the specified type                    |
//+------------------------------------------------------------------+
bool CloseOnePosition(int orderType)
{
    for(int i = OrdersTotal()-1; i >=0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol() && OrderType() == orderType)
            {
                bool result;
                double closePrice;
                if(orderType == OP_BUY)
                {
                    closePrice = Bid;
                    result = OrderClose(OrderTicket(), OrderLots(), closePrice, 10, Red);
                }
                else if(orderType == OP_SELL)
                {
                    closePrice = Ask;
                    result = OrderClose(OrderTicket(), OrderLots(), closePrice, 10, Green);
                }
                else
                {
                    Print("Invalid order type for closing.");
                    return false;
                }
                
                if(result)
                {
                    Print("Closed ", (orderType == OP_BUY ? "BUY" : "SELL"), " order #", OrderTicket(), " successfully.");
                    // Check if this was the last position
                    if(!HasOpenPositions(OP_BUY) && !HasOpenPositions(OP_SELL))
                    {
                        tradeDirection = 0;
                        inEntrySequence = false;
                        entryPositions = 0;
                        Print("=== TRADE DIRECTION RESET ===");
                        Print("Reason: All positions have been closed");
                    }
                    return true;
                }
                else
                {
                    Print("Failed to close ", (orderType == OP_BUY ? "BUY" : "SELL"), " order #", OrderTicket(), ". Error: ", GetLastError());
                }
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Close all open positions of a specific type                      |
//+------------------------------------------------------------------+
bool CloseAllPositions(int orderType)
{
    bool allClosed = true;
    for(int i = OrdersTotal()-1; i >=0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol() && OrderType() == orderType)
            {
                bool result;
                double closePrice;
                if(orderType == OP_BUY)
                {
                    closePrice = Bid;
                    result = OrderClose(OrderTicket(), OrderLots(), closePrice, 10, Red);
                }
                else if(orderType == OP_SELL)
                {
                    closePrice = Ask;
                    result = OrderClose(OrderTicket(), OrderLots(), closePrice, 10, Green);
                }
                else
                {
                    Print("Invalid order type for closing.");
                    allClosed = false;
                    continue;
                }
                
                if(result)
                {
                    Print("Closed ", (orderType == OP_BUY ? "BUY" : "SELL"), " order #", OrderTicket(), " successfully.");
                }
                else
                {
                    Print("Failed to close ", (orderType == OP_BUY ? "BUY" : "SELL"), " order #", OrderTicket(), ". Error: ", GetLastError());
                    allClosed = false;
                }
            }
        }
    }
    
    // After closing all positions of the specified type, check if any positions remain
    if(allClosed && !HasOpenPositions(OP_BUY) && !HasOpenPositions(OP_SELL))
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
bool HasOpenPositions(int orderType)
{
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol() && OrderType() == orderType)
                return true;
        }
    }
    return false;
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
    double previousHigh = iHigh(Symbol(), PERIOD_H2, 1);
    double previousLow  = iLow(Symbol(), PERIOD_H2, 1);
    
    // Define a buffer in pips to account for spread and volatility
    double bufferPips = SLBufferPips; // Adjustable buffer
    double pointSize   = Point;
    
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
    double emaFastCurr = iMA(Symbol(), PERIOD_H2, EMAPeriodFast, 0, MODE_EMA, PRICE_CLOSE, 0);
    double emaMidCurr  = iMA(Symbol(), PERIOD_H2, EMAPeriodMid,  0, MODE_EMA, PRICE_CLOSE, 0);
    double emaSlowCurr = iMA(Symbol(), PERIOD_H2, EMAPeriodSlow, 0, MODE_EMA, PRICE_CLOSE, 0);
    
    if(direction == 1) // Bullish alignment
    {
        // Allow some tolerance in the alignment (0.5 pip tolerance)
        double tolerance = 0.00005;
        return (emaFastCurr > (emaMidCurr - tolerance) && emaMidCurr > (emaSlowCurr - tolerance));
    }
    else if(direction == -1) // Bearish alignment
    {
        double tolerance = 0.00005;
        return (emaFastCurr < (emaMidCurr + tolerance) && emaMidCurr < (emaSlowCurr + tolerance));
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check positions for take profit or stop loss                      |
//+------------------------------------------------------------------+
void CheckTakeProfit()
{
    int totalOrders = OrdersTotal();
    double point = Point;
    double currentATR = iATR(Symbol(), PERIOD_H2, ATRPeriod, 0);
    
    for(int i = totalOrders - 1; i >=0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
            {
                double openPrice = OrderOpenPrice();
                double currentPrice = (OrderType() == OP_BUY) ? Bid : Ask;
                int posType = OrderType();
                
                double profitPips = 0;
                
                if(posType == OP_BUY)
                    profitPips = (currentPrice - openPrice) / point;
                else if(posType == OP_SELL)
                    profitPips = (openPrice - currentPrice) / point;
                
                // Calculate ATR-based exit levels in pips
                double atrPips = currentATR / point;
                double tpLevel = atrPips * ATRMultiplierTP;
                double slLevel = atrPips * ATRMultiplierSL;
                
                // Check for Take Profit
                if(profitPips >= tpLevel)
                {
                    Print("=== TAKE PROFIT EXIT TRIGGERED ===");
                    Print("Position Type: ", (posType == OP_BUY ? "BUY" : "SELL"));
                    Print("Entry Price: ", openPrice);
                    Print("Current Price: ", currentPrice);
                    Print("Profit in Pips: ", profitPips);
                    Print("ATR in Pips: ", atrPips);
                    Print("TP Level: ", tpLevel);
                    
                    if(OrderClose(OrderTicket(), OrderLots(), currentPrice, 10, (posType == OP_BUY ? Red : Green)))
                    {
                        Print("Successfully closed order #", OrderTicket(), " at take profit");
                        
                        // Check if this was the last position
                        if(!HasOpenPositions(OP_BUY) && !HasOpenPositions(OP_SELL))
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
                    Print("Position Type: ", (posType == OP_BUY ? "BUY" : "SELL"));
                    Print("Entry Price: ", openPrice);
                    Print("Current Price: ", currentPrice);
                    Print("Loss in Pips: ", profitPips);
                    Print("ATR in Pips: ", atrPips);
                    Print("SL Level: ", slLevel);
                    
                    if(OrderClose(OrderTicket(), OrderLots(), currentPrice, 10, (posType == OP_BUY ? Red : Green)))
                    {
                        Print("Successfully closed order #", OrderTicket(), " at stop loss");
                        
                        // Check if this was the last position
                        if(!HasOpenPositions(OP_BUY) && !HasOpenPositions(OP_SELL))
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
}

//+------------------------------------------------------------------+

