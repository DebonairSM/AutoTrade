//+------------------------------------------------------------------+
//|                                              StubbsEA.mq4       |
//|                          Converted from MQL5                     |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      "Your Link"
#property version   "1.00"
#property strict

//--- Input Parameters
extern int    EMAPeriodFast   = 8;     // Fast EMA Period
extern int    EMAPeriodMid    = 23;    // Mid EMA Period
extern int    EMAPeriodSlow   = 22;    // Slow EMA Period
extern int    MACDFast        = 15;    // MACD Fast EMA Period
extern int    MACDSlow        = 17;    // MACD Slow EMA Period
extern int    MACDSignal      = 13;    // MACD Signal SMA Period
extern double RiskPercentage  = 23;    // Risk Percentage per Trade
extern int    RiskMonth1      = 12;    // Month to modify risk (1-12)
extern double RiskMultiplier1 = 2.0;   // Risk multiplier for Month1
extern int    RiskMonth2      = 0;     // Second month to modify risk (0=disabled)
extern double RiskMultiplier2 = 1.0;   // Risk multiplier for Month2
extern int    RiskMonth3      = 0;     // Third month to modify risk (0=disabled)
extern double RiskMultiplier3 = 1.0;   // Risk multiplier for Month3
extern int    ATRPeriod       = 19;    // ATR Period
extern double ATRMultiplierSL = 8.4;   // ATR Multiplier for Stop Loss
extern double ATRMultiplierTP = 6.0;   // ATR Multiplier for Take Profit
extern double MACDThreshold   = 0.00010; // Minimum MACD difference for signal
extern int    EntryTimeoutBars = 8;    // Bars to wait for entry sequence
extern double SLBufferPips    = 5.0;   // Stop-Loss Buffer in Pips
//--- Trading Time Parameters
extern int    NoTradeStartHour = 6;    // No Trading Start Hour 
extern int    NoTradeEndHour   = 7;    // No Trading End Hour

//--- Global Variables
int      MagicNumber      = 123456; 
datetime lastBarTime      = 0;      
datetime tradeEntryBar    = 0;      
datetime lastEntryBar     = 0;      
int      partialClosures  = 0;      
int      entryPositions   = 0;      
bool     inEntrySequence  = false;  
int      tradeDirection   = 0;      // 0 = No position, 1 = Buy, -1 = Sell

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
{
   Print("EA Initialized Successfully.");
   return(0);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
{
   Print("EA Deinitialized.");
   return(0);
}

//+------------------------------------------------------------------+
//| Expert start function (called each tick)                         |
//+------------------------------------------------------------------+
int start()
{
   //--- 1) Check if it's Sunday
   MqlDateTime dt_struct;
   TimeToStruct(TimeCurrent(), dt_struct);
   if(dt_struct.day_of_week == 0) // Sunday
      return(0);

   //--- 2) Check if current time is within no-trade hours
   int currentHour = dt_struct.hour;
   if(currentHour >= NoTradeStartHour && currentHour < NoTradeEndHour)
      return(0);

   //--- 3) Check for open positions to see if we should exit at Take Profit or Stop Loss
   CheckTakeProfit();

   //--- 4) Check for new 2-hour bar
   datetime currentBar = iTime(Symbol(), PERIOD_H2, 0);
   if(currentBar <= lastBarTime)
      return(0); // No new bar yet

   // Once a new bar is detected:
   lastBarTime = currentBar;

   //--- 5) Handle potential entry-sequence timeout
   if(inEntrySequence && currentBar > (tradeEntryBar + (EntryTimeoutBars * PeriodSeconds(PERIOD_H2))))
   {
      inEntrySequence = false;
      Print("=== ENTRY SEQUENCE TIMEOUT ===");
      Print("Could not find confirmation for all entries within ", EntryTimeoutBars, " bars");
   }

   //--- 6) Gather indicator data
   double emaFastPrev = iMA(Symbol(), PERIOD_H2, EMAPeriodFast, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaMidPrev  = iMA(Symbol(), PERIOD_H2, EMAPeriodMid , 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlowPrev = iMA(Symbol(), PERIOD_H2, EMAPeriodSlow, 0, MODE_EMA, PRICE_CLOSE, 1);

   double emaFastCurr = iMA(Symbol(), PERIOD_H2, EMAPeriodFast, 0, MODE_EMA, PRICE_CLOSE, 0);
   double emaMidCurr  = iMA(Symbol(), PERIOD_H2, EMAPeriodMid , 0, MODE_EMA, PRICE_CLOSE, 0);
   double emaSlowCurr = iMA(Symbol(), PERIOD_H2, EMAPeriodSlow, 0, MODE_EMA, PRICE_CLOSE, 0);

   // MACD in MQL4 returns 3 buffers:
   //   buffer 0 -> Main
   //   buffer 1 -> Signal
   //   buffer 2 -> Histogram
   // iMACD(Symbol(), Timeframe, FastEMA, SlowEMA, SignalSMA, Price, Mode, Shift)
   double macdMainPrev   = iMACD(Symbol(), PERIOD_H2, MACDFast, MACDSlow, MACDSignal, PRICE_CLOSE, MODE_MAIN,   1);
   double macdSignalPrev = iMACD(Symbol(), PERIOD_H2, MACDFast, MACDSlow, MACDSignal, PRICE_CLOSE, MODE_SIGNAL, 1);
   double macdMainCurr   = iMACD(Symbol(), PERIOD_H2, MACDFast, MACDSlow, MACDSignal, PRICE_CLOSE, MODE_MAIN,   0);
   double macdSignalCurr = iMACD(Symbol(), PERIOD_H2, MACDFast, MACDSlow, MACDSignal, PRICE_CLOSE, MODE_SIGNAL, 0);

   //--- 7) Detect EMA crossovers
   bool isBullishCross = false;
   bool isBearishCross = false;

   // Bullish
   if(emaFastCurr > emaSlowCurr && emaFastPrev <= emaSlowPrev)
   {
      if(emaFastCurr > emaMidCurr) // Additional condition
         isBullishCross = true;
   }
   // Bearish
   if(emaFastCurr < emaSlowCurr && emaFastPrev >= emaSlowPrev)
   {
      if(emaFastCurr < emaMidCurr) // Additional condition
         isBearishCross = true;
   }

   //--- 8) Handle new signals
   // Bullish signal if we do not already hold buys
   if(isBullishCross && tradeDirection <= 0)
   {
      if(!HasOpenPositions(OP_SELL))
      {
         Print("=== BULLISH SIGNAL DETECTED ===");
         Print("EMA crossing up + mid EMA confirmation.");
         tradeDirection  = 1;
         entryPositions  = 0;
         inEntrySequence = true;
         tradeEntryBar   = currentBar;

         // Since bullish signal is taken, ignore any possible bearish on this bar
         isBearishCross  = false;
      }
      else
      {
         Print("=== BULLISH SIGNAL IGNORED: Existing SELL positions are open. ===");
      }
   }
   // Bearish signal if we do not already hold sells
   if(isBearishCross && tradeDirection >= 0)
   {
      if(!HasOpenPositions(OP_BUY))
      {
         Print("=== BEARISH SIGNAL DETECTED ===");
         Print("EMA crossing down + mid EMA confirmation.");
         tradeDirection  = -1;
         entryPositions  = 0;
         inEntrySequence = true;
         tradeEntryBar   = currentBar;
      }
      else
      {
         Print("=== BEARISH SIGNAL IGNORED: Existing BUY positions are open. ===");
      }
   }

   //--- 9) Check for additional entries if in entry sequence
   if(inEntrySequence && entryPositions < 3)
   {
      int orderType = -1;
      if(tradeDirection == 1)      orderType = OP_BUY;
      else if(tradeDirection == -1)orderType = OP_SELL;
      else
      {
         Print("=== ENTRY SEQUENCE CANCELLED: No valid trade direction. ===");
         inEntrySequence = false;
         return(0);
      }

      bool shouldEnter   = false;
      string entryReason = "";

      // (a) First position logic
      if(entryPositions == 0)
      {
         if(orderType == OP_BUY)
         {
            if(emaFastCurr > emaMidCurr && emaMidCurr > emaSlowCurr &&
               macdMainCurr > macdSignalCurr && macdMainCurr > macdMainPrev)
            {
               shouldEnter   = true;
               entryReason   = "Initial Entry - Strong Bullish Setup";
            }
         }
         else // SELL
         {
            if(emaFastCurr < emaMidCurr && emaMidCurr < emaSlowCurr &&
               macdMainCurr < macdSignalCurr && macdMainCurr < macdMainPrev)
            {
               shouldEnter   = true;
               entryReason   = "Initial Entry - Strong Bearish Setup";
            }
         }
      }
      // (b) Second position logic
      else if(entryPositions == 1)
      {
         double currentClose  = iClose(Symbol(), PERIOD_H2, 0);
         double previousClose = iClose(Symbol(), PERIOD_H2, 1);
         double previousHigh  = iHigh(Symbol(), PERIOD_H2, 1);
         double previousLow   = iLow(Symbol(), PERIOD_H2, 1);

         if(orderType == OP_BUY)
         {
            if(currentClose > previousHigh * 0.99 &&
               macdMainCurr > 0 && 
               macdMainCurr > macdMainPrev &&
               emaFastCurr > emaMidCurr &&
               emaMidCurr > emaSlowCurr)
            {
               shouldEnter = true;
               entryReason = "Second Entry - Bullish Breakout";
            }
         }
         else // SELL
         {
            if(currentClose < previousLow * 1.01 &&
               macdMainCurr < 0 && 
               macdMainCurr < macdMainPrev &&
               emaFastCurr < emaMidCurr &&
               emaMidCurr < emaSlowCurr)
            {
               shouldEnter = true;
               entryReason = "Second Entry - Bearish Breakout";
            }
         }
      }
      // (c) Third position logic
      else if(entryPositions == 2)
      {
         double currentClose  = iClose(Symbol(), PERIOD_H2, 0);
         double previousClose = iClose(Symbol(), PERIOD_H2, 1);
         double point         = MarketInfo(Symbol(), MODE_POINT);

         // Calculate drawdown since trade entry
         double highestPrice = currentClose;
         double lowestPrice  = currentClose;
         double maxDrawdown  = 0;

         for(int i=0; i<100; i++)
         {
            datetime barTime = iTime(Symbol(), PERIOD_H2, i);
            if(barTime < tradeEntryBar) break;

            double barHigh = iHigh(Symbol(), PERIOD_H2, i);
            double barLow  = iLow(Symbol(), PERIOD_H2, i);
            if(barHigh > highestPrice) highestPrice = barHigh;
            if(barLow < lowestPrice)   lowestPrice  = barLow;
         }

         if(orderType == OP_BUY)
         {
            maxDrawdown = (highestPrice - currentClose)/point;

            bool strongContinuation = (currentClose > (previousClose * 1.01) &&
                                       emaFastCurr > emaMidCurr &&
                                       emaMidCurr > emaSlowCurr &&
                                       macdMainCurr > macdMainPrev &&
                                       macdMainCurr > macdSignalCurr);

            bool drawdownEntry = (maxDrawdown >= 150.0 &&
                                  emaFastCurr > emaMidCurr &&
                                  emaMidCurr > emaSlowCurr &&
                                  macdMainCurr > macdSignalCurr);

            if(strongContinuation || drawdownEntry)
            {
               shouldEnter = true;
               if(drawdownEntry)
                  entryReason = StringConcatenate("Third Entry - Bullish Drawdown Entry (", DoubleToStr(maxDrawdown, 1), " pips)");
               else
                  entryReason = "Third Entry - Strong Bullish Continuation";
            }
         }
         else // SELL
         {
            maxDrawdown = (currentClose - lowestPrice)/point;

            bool strongContinuation = (currentClose < (previousClose * 0.99) &&
                                       emaFastCurr < emaMidCurr &&
                                       emaMidCurr < emaSlowCurr &&
                                       macdMainCurr < macdMainPrev &&
                                       macdMainCurr < macdSignalCurr);

            bool drawdownEntry = (maxDrawdown >= 150.0 &&
                                  emaFastCurr < emaMidCurr &&
                                  emaMidCurr < emaSlowCurr &&
                                  macdMainCurr < macdSignalCurr);

            if(strongContinuation || drawdownEntry)
            {
               shouldEnter = true;
               if(drawdownEntry)
                  entryReason = StringConcatenate("Third Entry - Bearish Drawdown Entry (", DoubleToStr(maxDrawdown, 1), " pips)");
               else
                  entryReason = "Third Entry - Strong Bearish Continuation";
            }
         }
      }

      if(shouldEnter)
      {
         Print("=== ENTRY CONFIRMATION #", (entryPositions + 1), " ===");
         Print("Direction:", (orderType == OP_BUY ? "BUY" : "SELL"));
         Print("Reason:", entryReason);

         double stopLossPrice = GetStopLossPrice(orderType == OP_BUY);
         double pipsDistance  = 0.0;

         double ask           = Ask;
         double bid           = Bid;
         if(orderType == OP_BUY)
            pipsDistance = MathAbs(ask - stopLossPrice) / MarketInfo(Symbol(), MODE_POINT);
         else
            pipsDistance = MathAbs(bid - stopLossPrice) / MarketInfo(Symbol(), MODE_POINT);

         double lotSize = CalculateLotSize(pipsDistance);
         if(lotSize > 0.0)
         {
            if(OpenTrade(orderType, lotSize, stopLossPrice, 0,  /* we set TP=0 for now, EA checks ATR-based exit */
                         StringConcatenate((orderType == OP_BUY ? "Bullish" : "Bearish"), " Entry #",(entryPositions+1))))
            {
               entryPositions++;
               lastEntryBar = iTime(Symbol(), PERIOD_H2, 0);
            }
         }
      }

      //--- Check for entry timeout
      datetime timeoutReference = (lastEntryBar > 0 ? lastEntryBar : tradeEntryBar);
      if(iTime(Symbol(), PERIOD_H2, 0) > (timeoutReference + (EntryTimeoutBars * PeriodSeconds(PERIOD_H2))))
      {
         // Only stop if at least 1 position is open
         if(entryPositions > 0)
         {
            inEntrySequence = false;
            Print("=== ENTRY SEQUENCE TIMEOUT ===");
            Print("Could not find confirmation for all entries within ", EntryTimeoutBars, " bars.");
            Print("Have ", entryPositions, " position(s). No more entries for this sequence.");
         }
         else if(tradeDirection != 0)
         {
            // If no positions but we still have a direction, check if EMAs still aligned
            if(!CheckEMAAlignment(tradeDirection))
            {
               tradeDirection  = 0;
               inEntrySequence = false;
               Print("=== ENTRY SEQUENCE CANCELLED ===");
               Print("Reason: EMAs no longer aligned with the original direction");
            }
            else
            {
               // Extend time for the first entry
               tradeEntryBar = iTime(Symbol(), PERIOD_H2, 0);
               Print("=== ENTRY SEQUENCE EXTENDED ===");
               Print("No positions yet. Resetting entry timer for more time.");
            }
         }
      }
   }

   //--- 10) Check MACD exit signals (Partial Exits)
   if(IsMACDCrossOver(macdMainPrev, macdSignalPrev, macdMainCurr, macdSignalCurr) && (currentBar > tradeEntryBar))
   {
      Print("=== MACD EXIT SIGNAL DETECTED ===");
      Print("Trigger: MACD line crossed Signal line.");

      // We look at the ratio of existing buy vs. sell.
      int buyCount=0, sellCount=0;
      for(int i=0; i<OrdersTotal(); i++)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
            {
               if(OrderType() == OP_BUY)  buyCount++;
               if(OrderType() == OP_SELL) sellCount++;
            }
         }
      }
      int orderTypeToClose = (buyCount > sellCount) ? OP_BUY : OP_SELL;

      if(CloseOnePosition(orderTypeToClose))
      {
         partialClosures++;
         // If everything is closed, reset direction
         if(!HasOpenPositions(OP_BUY) && !HasOpenPositions(OP_SELL))
         {
            tradeDirection  = 0;
            Print("All positions closed - Trade direction reset to 0");
         }
      }
   }
   return(0);
}

//+------------------------------------------------------------------+
//| CalculateLotSize: risk-based lot sizing                          |
//+------------------------------------------------------------------+
double CalculateLotSize(double pipsDistance)
{
   // Adjust risk for special months
   MqlDateTime dt_struct;
   TimeToStruct(TimeCurrent(), dt_struct);

   double adjustedRisk = RiskPercentage;
   if(dt_struct.mon == RiskMonth1 && RiskMonth1 > 0 && RiskMonth1 <=12)
      adjustedRisk *= RiskMultiplier1;
   if(dt_struct.mon == RiskMonth2 && RiskMonth2 > 0 && RiskMonth2 <=12)
      adjustedRisk *= RiskMultiplier2;
   if(dt_struct.mon == RiskMonth3 && RiskMonth3 > 0 && RiskMonth3 <=12)
      adjustedRisk *= RiskMultiplier3;

   // Final risk in currency
   double accountBalance = AccountBalance();
   double riskAmount     = accountBalance * (adjustedRisk/100.0);

   if(pipsDistance <= 0.0) return(0);

   // Convert to lots
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
   if(tickSize <= 0.0) return(0);

   // pipValue approximates how much 1 pip is worth per 1 lot
   // For many brokers, 1 pip = 10 ticks on a 5-digit broker, etc.
   // This is a rough approximation and can vary with symbol type
   double pipValue     = (0.0001 / tickSize) * tickValue;
   double pricePerPip  = pipValue;
   double riskInLots   = riskAmount / (pipsDistance * pricePerPip);

   // Now clamp to broker constraints
   double minLot       = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot       = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep      = MarketInfo(Symbol(), MODE_LOTSTEP);

   if(lotStep <= 0.0) lotStep = 0.01; // fallback

   // Snap to nearest lot step
   double steps   = MathFloor(riskInLots / lotStep);
   double lotSize = steps * lotStep;

   if(lotSize < minLot) lotSize = minLot;
   if(lotSize > maxLot) lotSize = maxLot;

   // Round to 2 decimals if needed
   lotSize = NormalizeDouble(lotSize, 2);
   return(lotSize);
}

//+------------------------------------------------------------------+
//| OpenTrade: send an order in MQL4                                 |
//+------------------------------------------------------------------+
bool OpenTrade(int orderType, double lots, double sl, double tp, string comment="")
{
   double ask        = Ask;
   double bid        = Bid;
   double slippage   = 3;   // 3 pips or so for slippage
   int    ticket     = -1;

   if(lots < MarketInfo(Symbol(), MODE_MINLOT))
      return(false);

   if(orderType == OP_BUY)
   {
      double buyPrice = ask;
      double stopLoss = (sl > 0 ? sl : 0);
      // For demonstration, passing 0 for tp here, as actual ATR-based exit is done by the EA
      ticket = OrderSend(Symbol(), OP_BUY, lots, buyPrice, slippage, stopLoss, 0, comment, MagicNumber, 0, clrBlue);
      if(ticket < 0)
      {
         Print("Buy OrderSend failed. Error:", GetLastError());
         return(false);
      }
      else
         Print("Opened BUY Order #", ticket, " at ", buyPrice, " lots=", lots);
   }
   else if(orderType == OP_SELL)
   {
      double sellPrice = bid;
      double stopLoss  = (sl > 0 ? sl : 0);
      ticket = OrderSend(Symbol(), OP_SELL, lots, sellPrice, slippage, stopLoss, 0, comment, MagicNumber, 0, clrRed);
      if(ticket < 0)
      {
         Print("Sell OrderSend failed. Error:", GetLastError());
         return(false);
      }
      else
         Print("Opened SELL Order #", ticket, " at ", sellPrice, " lots=", lots);
   }
   return(true);
}

//+------------------------------------------------------------------+
//| CloseOnePosition: close one matching position                    |
//+------------------------------------------------------------------+
bool CloseOnePosition(int orderType)
{
   bool closed = false;
   int totalOrders = OrdersTotal();

   for(int i=totalOrders-1; i>=0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            if(OrderType() == orderType)
            {
               double lots       = OrderLots();
               double closePrice = (orderType == OP_BUY) ? Bid : Ask;
               int    slippage   = 3;

               if(OrderClose(OrderTicket(), lots, closePrice, slippage, clrDodgerBlue))
               {
                  Print("Closed order #", OrderTicket(), " successfully.");
                  closed = true;

                  // Check if all positions are gone
                  if(!HasOpenPositions(OP_BUY) && !HasOpenPositions(OP_SELL))
                  {
                     tradeDirection   = 0;
                     inEntrySequence  = false;
                     entryPositions   = 0;
                     Print("=== TRADE DIRECTION RESET: All positions closed. ===");
                  }
                  break; // only close one position
               }
               else
               {
                  Print("Failed to close position #", OrderTicket(), ". Error=", GetLastError());
               }
            }
         }
      }
   }
   return(closed);
}

//+------------------------------------------------------------------+
//| CloseAllPositions: closes all positions of a specific type       |
//+------------------------------------------------------------------+
bool CloseAllPositions(int orderType)
{
   bool allClosed = true;
   int totalOrders = OrdersTotal();

   for(int i=totalOrders-1; i>=0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            if(OrderType() == orderType)
            {
               double lots       = OrderLots();
               double closePrice = (orderType == OP_BUY) ? Bid : Ask;
               int    slippage   = 3;

               if(!OrderClose(OrderTicket(), lots, closePrice, slippage, clrDodgerBlue))
               {
                  Print("Failed to close position #", OrderTicket(), ". Error=", GetLastError());
                  allClosed = false;
               }
               else
                  Print("Closed position #", OrderTicket(), " successfully.");
            }
         }
      }
   }
   // After trying to close all, check if everything is truly closed
   if(allClosed && !HasOpenPositions(OP_BUY) && !HasOpenPositions(OP_SELL))
   {
      tradeDirection  = 0;
      inEntrySequence = false;
      entryPositions  = 0;
      Print("=== TRADE DIRECTION RESET: All positions closed. ===");
   }
   return(allClosed);
}

//+------------------------------------------------------------------+
//| HasOpenPositions: checks if there are any open positions of type |
//+------------------------------------------------------------------+
bool HasOpenPositions(int orderType)
{
   for(int i=0; i<OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            if(OrderType() == orderType)
               return(true);
         }
      }
   }
   return(false);
}

//+------------------------------------------------------------------+
//| Check for MACD Crossover                                         |
//+------------------------------------------------------------------+
bool IsMACDCrossOver(double macdMainPrev, double macdSignalPrev, double macdMainCurr, double macdSignalCurr)
{
   // 1) Check if difference is significant
   if(MathAbs(macdMainCurr - macdSignalCurr) < MACDThreshold)
      return false;

   // 2) Bullish crossover
   if(macdMainPrev <= macdSignalPrev && macdMainCurr > macdSignalCurr)
      return true;
   // 3) Bearish crossover
   if(macdMainPrev >= macdSignalPrev && macdMainCurr < macdSignalCurr)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| GetStopLossPrice: places SL just below/above previous bar        |
//+------------------------------------------------------------------+
double GetStopLossPrice(bool isBuy)
{
   double prevHigh = iHigh(Symbol(), PERIOD_H2, 1);
   double prevLow  = iLow(Symbol(), PERIOD_H2, 1);

   double pointSize = MarketInfo(Symbol(), MODE_POINT);
   double buffer    = SLBufferPips * pointSize;

   if(isBuy)
      return(prevLow - buffer);    // a bit below previous low
   else
      return(prevHigh + buffer);   // a bit above previous high
}

//+------------------------------------------------------------------+
//| Check if EMAs are still aligned for the current direction        |
//+------------------------------------------------------------------+
bool CheckEMAAlignment(int direction)
{
   double emaFast = iMA(Symbol(), PERIOD_H2, EMAPeriodFast, 0, MODE_EMA, PRICE_CLOSE, 0);
   double emaMid  = iMA(Symbol(), PERIOD_H2, EMAPeriodMid , 0, MODE_EMA, PRICE_CLOSE, 0);
   double emaSlow = iMA(Symbol(), PERIOD_H2, EMAPeriodSlow, 0, MODE_EMA, PRICE_CLOSE, 0);

   double tolerance = 0.00005;

   if(direction == 1)
   {
      // For bullish alignment, fast > mid > slow (within a small tolerance)
      if((emaFast > emaMid - tolerance) && (emaMid > emaSlow - tolerance))
         return(true);
      else
         return(false);
   }
   else if(direction == -1)
   {
      // For bearish alignment, fast < mid < slow (within a small tolerance)
      if((emaFast < emaMid + tolerance) && (emaMid < emaSlow + tolerance))
         return(true);
      else
         return(false);
   }
   return(false);
}

//+------------------------------------------------------------------+
//| CheckTakeProfit: ATR-based exit logic                            |
//+------------------------------------------------------------------+
void CheckTakeProfit()
{
   // We check each open order that matches our MagicNumber
   int totalOrders = OrdersTotal();
   double point = MarketInfo(Symbol(), MODE_POINT);

   // Current ATR
   double currentATR = iATR(Symbol(), PERIOD_H2, ATRPeriod, 0);
   double atrPips    = currentATR / point;
   double tpLevel    = atrPips * ATRMultiplierTP; // in pips
   double slLevel    = atrPips * ATRMultiplierSL; // in pips

   for(int i=totalOrders-1; i>=0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            double openPrice    = OrderOpenPrice();
            double currentPrice = (OrderType() == OP_BUY ? Bid : Ask);
            int    orderType    = OrderType();

            double profitPips = 0.0;
            if(orderType == OP_BUY)
               profitPips = (currentPrice - openPrice)/point;
            else if(orderType == OP_SELL)
               profitPips = (openPrice - currentPrice)/point;

            // If price has reached TP threshold
            if(profitPips >= tpLevel)
            {
               Print("=== TAKE PROFIT EXIT TRIGGERED ===");
               if(OrderClose(OrderTicket(), OrderLots(), currentPrice, 3, clrMediumAquamarine))
               {
                  Print("TP close #", OrderTicket(), " success.");
                  // Check if last position
                  if(!HasOpenPositions(OP_BUY) && !HasOpenPositions(OP_SELL))
                  {
                     tradeDirection  = 0;
                     inEntrySequence = false;
                     entryPositions  = 0;
                     Print("=== TRADE DIRECTION RESET: All positions closed at TP. ===");
                  }
               }
            }
            // If price has reached SL threshold
            else if(profitPips <= -slLevel)
            {
               Print("=== STOP LOSS EXIT TRIGGERED ===");
               if(OrderClose(OrderTicket(), OrderLots(), currentPrice, 3, clrTomato))
               {
                  Print("SL close #", OrderTicket(), " success.");
                  // Check if last position
                  if(!HasOpenPositions(OP_BUY) && !HasOpenPositions(OP_SELL))
                  {
                     tradeDirection  = 0;
                     inEntrySequence = false;
                     entryPositions  = 0;
                     Print("=== TRADE DIRECTION RESET: All positions closed at SL. ===");
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Helper: PeriodSeconds for MQL4 (approx)                          |
//+------------------------------------------------------------------+
int PeriodSeconds(int timeframe)
{
   // In MQL5, PeriodSeconds() returns # of seconds for each bar of that timeframe
   // We emulate it in MQL4 with a basic switch. H2 = 120 minutes
   // This can be extended for other timeframes if needed
   switch(timeframe)
   {
      case PERIOD_H1:  return(3600);
      case PERIOD_H2:  return(7200);
      case PERIOD_H4:  return(14400);
      case PERIOD_D1:  return(86400);
      default:         return(0);
   }
}
