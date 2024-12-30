//+------------------------------------------------------------------+
//|                 V-EA-Stubbs_EMA_MACD.mq5                         |
//|             Forex Strategies Ebook MQL5 EA for EURUSD              |
//|                                                                  |
//|   Description:                                                   |
//|   This Expert Advisor implements a trading strategy based on      |
//|   three Exponential Moving Averages (EMAs) and the MACD indicator. |
//|   It is specifically fine-tuned for the EURUSD currency pair,    |
//|   taking into account its unique volatility and liquidity traits.  |
//|                                                                  |
//|   Features:                                                      |
//|     - 3 EMA (Fast: 3, Mid: 25, Slow: 30) on a 2-hour chart        |
//|     - MACD (12, 26, 9) for exit signals                          |
//|     - Strict money management (1% risk per trade)                |
//|     - Partial exits based on MACD crossovers                      |
//|     - **Prevents simultaneous Buy and Sell positions**            |
//|                                                                  |
//|   Usage Instructions:                                            |
//|     1. Compile and attach to a 2-hour EURUSD chart in MetaTrader 5. |
//|     2. Adjust input parameters if necessary to better fit broker |
//|        conditions and trading preferences.                       |
//|     3. Perform backtesting using the Strategy Tester to verify    |
//|        performance.                                              |
//|     4. Forward test on a demo account before deploying live.     |
//|                                                                  |
//|   Author: [Your Name or Your Company]                            |
//|   Version: 1.02                                                  |
//|   Last Updated: [Date]                                           |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.02"
#property script_show_inputs
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

//--- Input parameters
input double RiskPercentage     = 1.0;      // Risk per trade (total) as % of account
input int    EMAPeriodFast      = 3;        // Fast EMA
input int    EMAPeriodMid       = 25;       // Mid EMA (optional filter)
input int    EMAPeriodSlow      = 30;       // Slow EMA
input int    MACDFast           = 12;       // MACD fast EMA
input int    MACDSlow           = 26;       // MACD slow EMA
input int    MACDSignal         = 9;        // MACD signal line
input int    MagicNumber        = 12345;    // Magic number to identify trades
input double MaxLotSize = 1.0;  // Maximum lot size per position

//--- Global variables / handles
CTrade trade;
CSymbolInfo symbolInfo;
int    handleEmaFast; 
int    handleEmaMid;
int    handleEmaSlow;
int    handleMacd;
double lotPerPosition = 0.0; // Each of the 3 positions will be this size
datetime lastBarTime = 0;   // To track new H2 bar updates

//+------------------------------------------------------------------+
//| Expert initialization function                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize symbolInfo
   if(!symbolInfo.Name(_Symbol))
   {
      Print("Failed to initialize symbol info");
      return INIT_FAILED;
   }
   
   //--- Create indicator handles
   handleEmaFast = iMA(_Symbol, PERIOD_H2, EMAPeriodFast, 0, MODE_EMA, PRICE_CLOSE);
   handleEmaMid  = iMA(_Symbol, PERIOD_H2, EMAPeriodMid,  0, MODE_EMA, PRICE_CLOSE);
   handleEmaSlow = iMA(_Symbol, PERIOD_H2, EMAPeriodSlow, 0, MODE_EMA, PRICE_CLOSE);

   // MACD is typically loaded as: iMACD(symbol,period,fastEMA,slowEMA,signalPrice,applied_price)
   handleMacd    = iMACD(_Symbol, PERIOD_H2, MACDFast, MACDSlow, MACDSignal, PRICE_CLOSE);

   if(handleEmaFast == INVALID_HANDLE || handleEmaMid == INVALID_HANDLE ||
      handleEmaSlow == INVALID_HANDLE || handleMacd == INVALID_HANDLE)
   {
      Print("Failed to create one or more indicator handles.");
      return INIT_FAILED;
   }
   
   Print("Account Balance: ", AccountInfoDouble(ACCOUNT_BALANCE));
   Print("Minimum Lot Size: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles
   IndicatorRelease(handleEmaFast);
   IndicatorRelease(handleEmaMid);
   IndicatorRelease(handleEmaSlow);
   IndicatorRelease(handleMacd);
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for new 2-hour bar
   datetime currentBar = iTime(_Symbol, PERIOD_H2, 0);
   if(currentBar <= lastBarTime)
      return; // No new bar yet

   // Once we detect a new bar, update lastBarTime
   lastBarTime = currentBar;

   //--- Retrieve indicator values for the *previous* completed bar (index = 1)
   double emaFastPrev = GetIndicatorValue(handleEmaFast, 1);
   double emaMidPrev  = GetIndicatorValue(handleEmaMid,  1);
   double emaSlowPrev = GetIndicatorValue(handleEmaSlow, 1);

   double emaFastCurr = GetIndicatorValue(handleEmaFast, 2);
   double emaMidCurr  = GetIndicatorValue(handleEmaMid,  2);
   double emaSlowCurr = GetIndicatorValue(handleEmaSlow, 2);

   // MACD values: main line and signal line
   double macdMainPrev   = GetIndicatorValue(handleMacd, 1, 0); // Main line
   double macdSignalPrev = GetIndicatorValue(handleMacd, 1, 1); // Signal line
   double macdMainCurr   = GetIndicatorValue(handleMacd, 2, 0);
   double macdSignalCurr = GetIndicatorValue(handleMacd, 2, 1);

   //--- Check for new trade signals (3 EMA crossing 30 EMA)
   // We'll compare previous bar's EMAs to see if a bullish or bearish cross just happened.
   bool wasBullish = (emaFastCurr > emaSlowCurr);
   bool wasBearish = (emaFastCurr < emaSlowCurr);
   bool isBullishCross = false;
   bool isBearishCross = false;

   // Confirm a cross from one bar to the next
   if(emaFastCurr > emaSlowCurr && emaFastPrev <= emaSlowPrev)
   {
      // Potential bullish cross
      // Optional: confirm with the mid EMA (emaFast > emaMid)
      if(emaFastCurr > emaMidCurr) 
         isBullishCross = true;
   }
   else if(emaFastCurr < emaSlowCurr && emaFastPrev >= emaSlowPrev)
   {
      // Potential bearish cross
      // Optional: confirm with the mid EMA (emaFast < emaMid)
      if(emaFastCurr < emaMidCurr)
         isBearishCross = true;
   }

   //--- Handle Bullish Cross
   if(isBullishCross)
   {
      Print("Bullish EMA crossover detected.");

      // **Close any existing SELL positions before opening BUYs**
      if(CloseAllPositions(ORDER_TYPE_SELL))
      {
         Print("Existing SELL positions closed successfully.");
      }
      else
      {
         Print("No SELL positions to close or failed to close them.");
      }

      // Proceed with opening BUY trades only if no SELL positions remain
      if(!HasOpenPositions(ORDER_TYPE_SELL))
      {
         // Calculate position size for total 1% risk across 3 trades
         double stopLossPrice = GetStopLossPrice(true);
         double entryPrice   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double riskPerTrade = AccountInfoDouble(ACCOUNT_BALANCE) * (RiskPercentage / 100.0);
         double pipsDistance = MathAbs(entryPrice - stopLossPrice) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);

         // Calculate total lots (will be divisible by 3 and step size)
         double totalLots = CalculateLotSize(riskPerTrade, pipsDistance);
         
         // Only proceed if we got a valid lot size
         if(totalLots > 0)
         {
            // Calculate per-position lot size
            lotPerPosition = NormalizeDouble(totalLots / 3.0, 2);
            
            Print("Opening 3 BUY positions with lot size: ", DoubleToString(lotPerPosition, 2));

            bool allTradesSuccessful = true;
            // Open 3 buy positions
            for(int i=0; i<3; i++)
            {
               if(!OpenTrade(ORDER_TYPE_BUY, lotPerPosition, stopLossPrice, 0, "3->30 EMA Bullish Cross"))
               {
                  allTradesSuccessful = false;
                  break;
               }
            }
            
            if(!allTradesSuccessful)
            {
               Print("Failed to open all BUY positions. Closing any that were opened.");
               CloseAllPositions(ORDER_TYPE_BUY);
            }
         }
         else
         {
            Print("Invalid lot size calculated. Skipping trade entry.");
         }
      }
      else
      {
         Print("Failed to close all SELL positions. Aborting BUY orders.");
      }
   }

   //--- Handle Bearish Cross
   if(isBearishCross)
   {
      Print("Bearish EMA crossover detected.");

      // **Close any existing BUY positions before opening SELLs**
      if(CloseAllPositions(ORDER_TYPE_BUY))
      {
         Print("Existing BUY positions closed successfully.");
      }
      else
      {
         Print("No BUY positions to close or failed to close them.");
      }

      // Proceed with opening SELL trades only if no BUY positions remain
      if(!HasOpenPositions(ORDER_TYPE_BUY))
      {
         double stopLossPrice = GetStopLossPrice(false);
         double entryPrice   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double riskPerTrade = AccountInfoDouble(ACCOUNT_BALANCE) * (RiskPercentage / 100.0);
         double pipsDistance = MathAbs(stopLossPrice - entryPrice) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);

         double totalLots = CalculateLotSize(riskPerTrade, pipsDistance);
         
         // Only proceed if we got a valid lot size
         if(totalLots > 0)
         {
            lotPerPosition = NormalizeDouble(totalLots / 3.0, 2);
            
            Print("Opening 3 SELL positions with lot size: ", DoubleToString(lotPerPosition, 2));

            bool allTradesSuccessful = true;
            // Open 3 sell positions
            for(int i=0; i<3; i++)
            {
               if(!OpenTrade(ORDER_TYPE_SELL, lotPerPosition, stopLossPrice, 0, "3->30 EMA Bearish Cross"))
               {
                  allTradesSuccessful = false;
                  break;
               }
            }
            
            if(!allTradesSuccessful)
            {
               Print("Failed to open all SELL positions. Closing any that were opened.");
               CloseAllPositions(ORDER_TYPE_SELL);
            }
         }
         else
         {
            Print("Invalid lot size calculated. Skipping trade entry.");
         }
      }
      else
      {
         Print("Failed to close all BUY positions. Aborting SELL orders.");
      }
   }

   //--- Check for MACD exit signal: if MACD main crosses signal line => partial or final exit
   // We'll do a simple check if it changes direction from prev bar to current bar
   if( (macdMainCurr > macdSignalCurr && macdMainPrev <= macdSignalPrev) ||
       (macdMainCurr < macdSignalCurr && macdMainPrev >= macdSignalPrev) )
   {
      Print("MACD crossover detected. Initiating partial exits.");
      // Cross occurred: close 2 out of 3 open positions
      ClosePartialPositions();
   }
}

//+------------------------------------------------------------------+
//| GetIndicatorValue - Overload for 2D arrays (e.g. MACD)          |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int shift, int buffer=0)
{
   double value[]; 
   if(CopyBuffer(handle, buffer, shift, 1, value) <= 0)
      return 0;
   return value[0];
}

double CalculateLotSize(double riskAmount, double pipsDistance)
{
   // Logging for clarity
   Print("Initial Risk Amount: ", riskAmount);
   Print("Pips Distance: ", pipsDistance);

   // Retrieve tick data for pip value calculation
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   Print("Tick Size: ", DoubleToString(tickSize, 5));
   Print("Tick Value: ", DoubleToString(tickValue, 2));

   if(tickSize == 0.0)
   {
      Print("Error: Tick Size is zero for symbol ", _Symbol);
      return 0.0;
   }

   // 1 pip = (0.0001 / tickSize) * tickValue
   double pipValue = (0.0001 / tickSize) * tickValue;
   Print("Calculated Pip Value: ", DoubleToString(pipValue, 2));

   // Convert riskAmount to base currency (if needed)
   double riskAmountBase = riskAmount / SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Basic lot size calculation: risk / (pipDistance * pipValue)
   double lotSize = 0.0;
   if(pipsDistance > 0.0)
      lotSize = riskAmountBase / (pipsDistance * pipValue);

   Print("Initial calculated lot size: ", DoubleToString(lotSize, 3));

   // Broker constraints
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   Print("Broker constraints - Min Lot: ", DoubleToString(minLot, 2), 
         " Max Lot: ", DoubleToString(maxLot, 2), 
         " Step: ", DoubleToString(stepLot, 2));

   // Round down to nearest step to avoid overstepping risk or broker rules
   double steps = MathFloor(lotSize / stepLot);
   lotSize = steps * stepLot;

   // Enforce min/max
   if(lotSize < minLot) lotSize = minLot;
   if(lotSize > maxLot) lotSize = maxLot;

   // (Optional) margin check can be done here, or in OpenTrade:
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   // Example check for buy side margin:
   double requiredMargin = trade.CalculateMargin(ORDER_TYPE_BUY, _Symbol, lotSize, SymbolInfoDouble(_Symbol, SYMBOL_ASK));

   Print("Required margin for total position: ", DoubleToString(requiredMargin, 2));
   Print("Available free margin: ", DoubleToString(freeMargin, 2));

   Print("Final total lot size: ", DoubleToString(lotSize, 2));
   return lotSize;
}


//+------------------------------------------------------------------+
//| GetStopLossPrice - Basic method to place SL near previous candle |
//+------------------------------------------------------------------+
double GetStopLossPrice(bool isBuy)
{
   // For EURUSD on H2, a buffer of 2 pips is generally sufficient
   double highPrev = iHigh(_Symbol, PERIOD_H2, 1);
   double lowPrev  = iLow(_Symbol, PERIOD_H2, 1);

   // Add a buffer to prevent stop-loss from being hit by minor fluctuations
   double bufferPips = 2.0;
   double pip = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(isBuy)
      return NormalizeDouble((lowPrev - bufferPips * pip), (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
   else
      return NormalizeDouble((highPrev + bufferPips * pip), (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}



//+------------------------------------------------------------------+
//| ClosePartialPositions - closes 2 of 3 positions in direction    |
//+------------------------------------------------------------------+
void ClosePartialPositions()
{
   // The logic: For each direction (BUY or SELL), check how many open positions 
   // with our magic number exist. If >= 3, close 2 of them, keep 1 running.

   // We'll do a simple approach: if we find 2 or more trades in the same direction, close exactly 2.

   // Gather tickets
   int totalPositions = PositionsTotal();
   if(totalPositions <= 0) return;

   // Count how many buy/sell positions we have with our magic
   int buyCount=0, sellCount=0;
   ulong buyTicketArray[], sellTicketArray[];
   ArrayResize(buyTicketArray, totalPositions);
   ArrayResize(sellTicketArray, totalPositions);

   for(int i=0; i<totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC)==MagicNumber)
         {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               buyTicketArray[buyCount] = ticket; 
               buyCount++;
            }
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            {
               sellTicketArray[sellCount] = ticket;
               sellCount++;
            }
         }
      }
   }

   // If at least 2 buy positions -> close 2
   if(buyCount >= 2)
   {
      Print("MACD exit signal: Closing 2 buy positions.");
      for(int i=0; i<2 && i<buyCount; i++)
      {
         if(ClosePosition(buyTicketArray[i]))
            Print("Buy position ", buyTicketArray[i], " closed successfully.");
         else
            Print("Failed to close buy position ", buyTicketArray[i], ".");
      }
   }
   // If at least 2 sell positions -> close 2
   if(sellCount >= 2)
   {
      Print("MACD exit signal: Closing 2 sell positions.");
      for(int i=0; i<2 && i<sellCount; i++)
      {
         if(ClosePosition(sellTicketArray[i]))
            Print("Sell position ", sellTicketArray[i], " closed successfully.");
         else
            Print("Failed to close sell position ", sellTicketArray[i], ".");
      }
   }
}

//+------------------------------------------------------------------+
//| ClosePosition - close a specific open position by ticket        |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
      return false;

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetTypeFillingBySymbol(Symbol());
   
   if(trade.PositionClose(ticket))
   {
      Print("Position ", ticket, " closed successfully.");
      return true;
   }
   else
   {
      Print("Failed to close position ", ticket, ". Error: ", trade.ResultRetcode(), ": ", trade.CheckResultRetcodeDescription());
      return false;  
   }
}

//+------------------------------------------------------------------+
//| CloseAllPositions - closes all positions of a specific type      |
//+------------------------------------------------------------------+
bool CloseAllPositions(ENUM_ORDER_TYPE typeToClose)
{
   bool allClosed = true;
   int totalPositions = PositionsTotal();

   for(int i = totalPositions - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         long posMagic = PositionGetInteger(POSITION_MAGIC);

         // Check if position matches the type to close and has the correct magic number
         if(posMagic == MagicNumber)
         {
            bool isBuy = (posType == POSITION_TYPE_BUY);
            bool isSell = (posType == POSITION_TYPE_SELL);

            if( (typeToClose == ORDER_TYPE_BUY && isBuy) ||
                (typeToClose == ORDER_TYPE_SELL && isSell) )
            {
               if(!ClosePosition(ticket))
               {
                  Print("Failed to close position ", ticket, ".");
                  allClosed = false;
               }
            }
         }
      }
   }

   return allClosed;
}

//+------------------------------------------------------------------+
//| HasOpenPositions - checks if there are open positions of a type |
//+------------------------------------------------------------------+
bool HasOpenPositions(ENUM_ORDER_TYPE typeToCheck)
{
   int totalPositions = PositionsTotal();

   for(int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         long posMagic = PositionGetInteger(POSITION_MAGIC);

         // Check if position matches the type to check and has the correct magic number
         if(posMagic == MagicNumber)
         {
            if( (typeToCheck == ORDER_TYPE_BUY && posType == POSITION_TYPE_BUY) ||
                (typeToCheck == ORDER_TYPE_SELL && posType == POSITION_TYPE_SELL) )
            {
               return true;
            }
         }
      }
   }

   return false;
}

bool OpenTrade(ENUM_ORDER_TYPE orderType, double lots, double sl, double tp, string comment="")
{
    // Get broker's lot constraints
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    // Simple rounding to nearest valid lot size
    lots = NormalizeDouble(MathRound(lots / stepLot) * stepLot, 2);
    
    // Enforce min/max limits
    lots = MathMax(minLot, MathMin(lots, maxLot));
    
    Print("Final lot size: ", DoubleToString(lots, 2));

    // Check margin requirements
    double margin;
    if(!symbolInfo.MarginCalcOrder(orderType, lots, (orderType == ORDER_TYPE_BUY) ? symbolInfo.Ask() : symbolInfo.Bid(), margin))
    {
        Print("Failed to calculate margin requirements");
        return false;
    }

    if(margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
    {
        Print("Insufficient margin. Required: ", margin, ", Available: ", AccountInfoDouble(ACCOUNT_MARGIN_FREE));
        return false;
    }

    // Place the order
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    trade.SetTypeFillingBySymbol(Symbol());

    bool tradeResult = false;
    if(orderType == ORDER_TYPE_BUY)
        tradeResult = trade.Buy(lots, _Symbol, symbolInfo.Ask(), sl, tp, comment);
    else if(orderType == ORDER_TYPE_SELL)
        tradeResult = trade.Sell(lots, _Symbol, symbolInfo.Bid(), sl, tp, comment);

    if(tradeResult)
    {
        Print(EnumToString(orderType), " order opened successfully. Ticket: ", trade.ResultOrder());
        return true;
    }
    
    Print("Failed to open ", EnumToString(orderType), " order. Error: ", 
          trade.ResultRetcode(), ": ", trade.CheckResultRetcodeDescription());
    return false;
}

//+------------------------------------------------------------------+
