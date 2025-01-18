//+------------------------------------------------------------------+
//|                                                      StubbsEA.mq4 |
//|                        Adapted from MQL5 for MetaTrader 4        |
//+------------------------------------------------------------------+
#property strict

// Input Parameters
input int    EMAPeriodFast   = 8;     // Fast EMA Period
input int    EMAPeriodMid    = 23;    // Mid EMA Period
input int    EMAPeriodSlow   = 22;    // Slow EMA Period
input int    MACDFast        = 15;    // MACD Fast EMA Period
input int    MACDSlow        = 17;    // MACD Slow EMA Period
input int    MACDSignal      = 13;    // MACD Signal SMA Period
input double RiskPercentage  = 1.0;   // Risk Percentage per Trade
input int    ATRPeriod       = 19;    // ATR Period
input double MACDThreshold   = 0.00006; // Minimum MACD difference for signal
input int    EntryTimeoutBars = 8;    // Bars to wait for entry sequence

// Global Variables
int          MagicNumber       = 123456; // Unique identifier for EA's trades
datetime     lastBarTime       = 0;       // Tracks the last processed bar time
int          tradeDirection    = 0;       // 0 = No position, 1 = Buy, -1 = Sell
int          entryPositions    = 0;       // Tracks the number of open positions
bool         inEntrySequence   = false;   // Whether we're in the middle of entering positions

//+------------------------------------------------------------------+
//| Initialization function                                          |
//+------------------------------------------------------------------+
int init()
{
    Print("EA Initialized Successfully.");
    return(0);
}

//+------------------------------------------------------------------+
//| De-initialization function                                       |
//+------------------------------------------------------------------+
int deinit()
{
    Print("EA Deinitialized.");
    return(0);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
int start()
{
    datetime currentBar = iTime(NULL, PERIOD_H1, 0);
    if(currentBar <= lastBarTime) return(0); // Ensure only one tick per bar
    lastBarTime = currentBar;

    // Retrieve EMA values
    double emaFast = iMA(NULL, PERIOD_H1, EMAPeriodFast, 0, MODE_EMA, PRICE_CLOSE, 0);
    double emaMid  = iMA(NULL, PERIOD_H1, EMAPeriodMid, 0, MODE_EMA, PRICE_CLOSE, 0);
    double emaSlow = iMA(NULL, PERIOD_H1, EMAPeriodSlow, 0, MODE_EMA, PRICE_CLOSE, 0);

    // Retrieve MACD values
    double macdMain = iCustom(NULL, PERIOD_H1, "MACD", MACDFast, MACDSlow, MACDSignal, 0, 0);
    double macdSignal = iCustom(NULL, PERIOD_H1, "MACD", MACDFast, MACDSlow, MACDSignal, 1, 0);

    // Check for exit signals
    CheckExitSignals();

    // Check for new entries if not already in sequence
    if(!inEntrySequence && entryPositions < 3)
    {
        // Detect Bullish Crossover
        if(emaFast > emaSlow && macdMain > macdSignal && tradeDirection <= 0)
        {
            tradeDirection = 1;
            inEntrySequence = true;
            entryPositions = 0;
            Print("Bullish signal detected. Starting entry sequence.");
        }

        // Detect Bearish Crossover
        else if(emaFast < emaSlow && macdMain < macdSignal && tradeDirection >= 0)
        {
            tradeDirection = -1;
            inEntrySequence = true;
            entryPositions = 0;
            Print("Bearish signal detected. Starting entry sequence.");
        }
    }

    // Handle entry sequence
    if(inEntrySequence && entryPositions < 3)
    {
        OpenTrade();
    }

    return(0);
}

//+------------------------------------------------------------------+
//| Open a new position based on trade direction                     |
//+------------------------------------------------------------------+
void OpenTrade()
{
    double lotSize = CalculateLotSize();
    if(lotSize == 0.0) return; // Skip if lot size is invalid

    int type = (tradeDirection == 1) ? OP_BUY : OP_SELL;
    double price = (type == OP_BUY) ? Ask : Bid;

    if(OrderSend(Symbol(), type, lotSize, price, 3, 0, 0, "Stubbs Trade", MagicNumber, 0, (type == OP_BUY) ? Blue : Red) > 0)
    {
        entryPositions++;
        Print("Successfully opened ", (type == OP_BUY ? "BUY" : "SELL"), " trade.");
    }
    else
    {
        Print("Failed to open trade. Error: ", GetLastError());
    }

    // Stop sequence if entry timeout exceeds
    if(entryPositions >= EntryTimeoutBars)
    {
        inEntrySequence = false;
        Print("Entry sequence timeout. Stopping further entries.");
    }
}

//+------------------------------------------------------------------+
//| Check exit signals based on MACD crossover                       |
//+------------------------------------------------------------------+
void CheckExitSignals()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
            {
                double macdMainPrev = iCustom(NULL, PERIOD_H1, "MACD", MACDFast, MACDSlow, MACDSignal, 0, 1);
                double macdSignalPrev = iCustom(NULL, PERIOD_H1, "MACD", MACDFast, MACDSlow, MACDSignal, 1, 1);
                double macdMainCurr = iCustom(NULL, PERIOD_H1, "MACD", MACDFast, MACDSlow, MACDSignal, 0, 0);
                double macdSignalCurr = iCustom(NULL, PERIOD_H1, "MACD", MACDFast, MACDSlow, MACDSignal, 1, 0);

                // Exit on MACD crossover
                if((OrderType() == OP_BUY && macdMainPrev > macdSignalPrev && macdMainCurr < macdSignalCurr) ||
                   (OrderType() == OP_SELL && macdMainPrev < macdSignalPrev && macdMainCurr > macdSignalCurr))
                {
                    if(OrderClose(OrderTicket(), OrderLots(), (OrderType() == OP_BUY ? Bid : Ask), 3, Yellow))
                    {
                        entryPositions--;
                        Print("Closed ", (OrderType() == OP_BUY ? "BUY" : "SELL"), " position due to MACD exit signal.");
                    }
                    else
                    {
                        Print("Failed to close position. Error: ", GetLastError());
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                      |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    double riskAmount = AccountBalance() * (RiskPercentage / 100.0);
    double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE) / MarketInfo(Symbol(), MODE_TICKSIZE);
    double lotSize = riskAmount / pipValue;

    // Broker constraints
    double minLot = MarketInfo(Symbol(), MODE_MINLOT);
    double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
    double stepLot = MarketInfo(Symbol(), MODE_LOTSTEP);

    // Normalize lot size to broker increments
    lotSize = MathFloor(lotSize / stepLot) * stepLot;

    // Ensure lot size respects broker limits
    if (lotSize < minLot) lotSize = minLot;
    if (lotSize > maxLot) lotSize = maxLot;

    Print("Calculated Lot Size: ", lotSize, " | Min Lot: ", minLot, " | Max Lot: ", maxLot, " | Step Lot: ", stepLot);

    return lotSize;
}
