//+------------------------------------------------------------------+
//|  V-EA-ScalpMaster.mq5                                            |
//|  Universal Scalping EA for MQL5                                  |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;  // MQL5 trade class

//--- EA Inputs
input string InpSymbol = "";            // Trading Symbol (empty = current chart)
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT;  // Trading Timeframe
input double InpBreakoutThresholdPips = 5.0;    // Breakout threshold in pips [3.0-7.0:0.5]
input double InpATRSpikePercent       = 2.0;    // ATR Spike threshold % [1.0-5.0:0.5]
input int    InpATRPeriod             = 14;     // ATR Period [10-20:2]
input int    InpCandleLookback        = 14;     // Lookback candles [10-20:2]
input double InpRiskPercent           = 1.0;    // Risk % per trade [0.5-2.0:0.25]
input double InpTakeProfitPips        = 10.0;   // Take Profit in pips [5.0-15.0:1.0]
input int    InpCooldownMinutes       = 1;      // Cooldown minutes [1-5:1]
input bool   InpCloseBeforeEOD        = true;   // Whether to close all trades before end-of-day
input int    InpCloseHour             = 23;     // Hour to close (23 = 11 PM broker time)
input int    InpCloseMinute           = 59;     // Minute to close

// Performance Optimization Settings
input group "Performance Settings"
input bool   InpOptimizeBacktest      = true;   // Enable backtest optimizations
input int    InpTickSkip              = 5;      // Process every Nth tick [1-10]
input bool   InpUseOnBarClose         = true;   // Only check signals on bar close
input bool   InpCacheIndicators       = true;   // Cache indicator values

//--- Global / Static Variables
datetime g_lastTradeTime = 0;            // Tracks last trade time for cooldown
double   g_lastATRValue  = 0;            // For storing ATR (optional usage if needed)
int      g_magicNumber   = 12345;        // Unique ID for this EA's trades
datetime g_lastBarTime   = 0;            // Last processed bar time
int      g_tickCounter   = 0;            // Counter for tick skipping
int      g_atrHandle    = INVALID_HANDLE; // ATR indicator handle

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // If no symbol specified, use current chart symbol
   string symbol = (InpSymbol == "") ? Symbol() : InpSymbol;
   
   // Validate symbol
   if(!SymbolSelect(symbol, true))
   {
      Print("Error: Symbol ", symbol, " is not available!");
      return INIT_FAILED;
   }
   
   // Initialize indicator handles if caching is enabled
   if(InpCacheIndicators)
   {
      g_atrHandle = iATR(symbol, InpTimeframe, InpATRPeriod);
      if(g_atrHandle == INVALID_HANDLE)
      {
         Print("Error initializing ATR indicator!");
         return INIT_FAILED;
      }
   }
   
   // Print initialization info
   Print("V-EA-ScalpMaster initialized on ", symbol, ", ", 
         EnumToString(InpTimeframe), " timeframe");
         
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up indicator handles
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
      
   string symbol = (InpSymbol == "") ? Symbol() : InpSymbol;
   Print("V-EA-ScalpMaster deinitialized on ", symbol);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Performance optimization: Skip ticks
   if(InpOptimizeBacktest)
   {
      g_tickCounter++;
      if(g_tickCounter < InpTickSkip)
         return;
      g_tickCounter = 0;
   }

   // Get active symbol
   string symbol = (InpSymbol == "") ? Symbol() : InpSymbol;
   
   // Check if we should only process on bar close
   if(InpUseOnBarClose)
   {
      datetime currentBarTime = iTime(symbol, InpTimeframe, 0);
      if(currentBarTime == g_lastBarTime)
         return;
      g_lastBarTime = currentBarTime;
   }

   // 2. Close trades before end-of-day if enabled
   if(InpCloseBeforeEOD)
      CloseAllTradesBeforeEOD();

   // 3. Check if we're still on cooldown
   if(IsOnCooldown()) return;

   // 4. Check for breakout OR volatility spike conditions
   bool breakoutSignal   = CheckBreakout();
   bool volatilitySignal = CheckVolatilitySpike();

   // 5. If either condition is true, place a new trade
   if(breakoutSignal || volatilitySignal)
   {
      TradeDirection direction = DetermineDirection();

      if(direction == TRADE_DIRECTION_BUY)
         PlaceOrder(ORDER_TYPE_BUY);
      else if(direction == TRADE_DIRECTION_SELL)
         PlaceOrder(ORDER_TYPE_SELL);
   }
}

//+------------------------------------------------------------------+
//| Check if on cooldown                                             |
//+------------------------------------------------------------------+
bool IsOnCooldown()
{
   // Compare current time with g_lastTradeTime + cooldown in minutes
   datetime cutoff = g_lastTradeTime + (InpCooldownMinutes * 60);
   if(TimeCurrent() < cutoff)
      return(true);

   return(false);
}

//+------------------------------------------------------------------+
//| Close all trades before end-of-day                               |
//+------------------------------------------------------------------+
void CloseAllTradesBeforeEOD()
{
   // If current hour >= close hour and current minute >= close minute, close everything
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int currentHour = dt.hour;
   int currentMinute = dt.min;

   if(currentHour > InpCloseHour || (currentHour == InpCloseHour && currentMinute >= InpCloseMinute))
   {
      // Close all open positions for this symbol & magic number
      for(int i = PositionsTotal()-1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
         {
            if(PositionGetString(POSITION_SYMBOL) == Symbol() &&
               PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
            {
               // Close this position
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                  trade.PositionClose(ticket);
               else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                  trade.PositionClose(ticket);

               Print("Trade closed due to end-of-day logic.");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Breakout Condition                                         |
//+------------------------------------------------------------------+
bool CheckBreakout()
{
   string symbol = (InpSymbol == "") ? Symbol() : InpSymbol;
   
   // Get previous candle's high/low
   double prevHigh = iHigh(symbol, InpTimeframe, 1);
   double prevLow  = iLow(symbol, InpTimeframe, 1);

   // Current Bid/Ask
   double ask = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_ASK), _Digits);
   double bid = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_BID), _Digits);

   // Convert pip threshold to points
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double thresholdInPoints = InpBreakoutThresholdPips * point * 10;

   // Check for breakout above
   if(ask > (prevHigh + thresholdInPoints))
      return(true);

   // Check for breakout below
   if(bid < (prevLow - thresholdInPoints))
      return(true);

   return(false);
}

//+------------------------------------------------------------------+
//| Check Volatility Spike                                           |
//+------------------------------------------------------------------+
bool CheckVolatilitySpike()
{
   string symbol = (InpSymbol == "") ? Symbol() : InpSymbol;
   
   //--- Candle size spike
   double currentCandleHigh = iHigh(symbol, InpTimeframe, 0);
   double currentCandleLow  = iLow(symbol, InpTimeframe, 0);
   double currentRange      = MathAbs(currentCandleHigh - currentCandleLow);

   // Calculate average range of last N closed candles
   double sumRanges = 0.0;
   for(int i=1; i<=InpCandleLookback; i++)
   {
      double barHigh = iHigh(symbol, InpTimeframe, i);
      double barLow  = iLow(symbol, InpTimeframe, i);
      sumRanges += MathAbs(barHigh - barLow);
   }
   double avgRange = sumRanges / InpCandleLookback;

   // Condition #1: Candle range spike
   bool candleSpike = (currentRange > avgRange);

   //--- ATR spike
   double currentATR[];
   ArraySetAsSeries(currentATR, true);
   
   if(InpCacheIndicators && g_atrHandle != INVALID_HANDLE)
   {
      // Use cached indicator
      CopyBuffer(g_atrHandle, 0, 0, 1, currentATR);
   }
   else
   {
      // Calculate on demand
      int atrHandle = iATR(symbol, InpTimeframe, InpATRPeriod);
      CopyBuffer(atrHandle, 0, 0, 1, currentATR);
      if(!InpCacheIndicators)
         IndicatorRelease(atrHandle);
   }

   // Calculate average ATR
   double sumATR = 0.0;
   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   
   if(InpCacheIndicators && g_atrHandle != INVALID_HANDLE)
   {
      CopyBuffer(g_atrHandle, 0, 1, InpCandleLookback, atrValues);
   }
   else
   {
      int atrHandle = iATR(symbol, InpTimeframe, InpATRPeriod);
      CopyBuffer(atrHandle, 0, 1, InpCandleLookback, atrValues);
      if(!InpCacheIndicators)
         IndicatorRelease(atrHandle);
   }

   for(int i=0; i<InpCandleLookback; i++)
   {
      sumATR += atrValues[i];
   }
   double avgATR = sumATR / InpCandleLookback;

   double spikeThreshold = avgATR * (1.0 + InpATRSpikePercent/100.0);
   bool atrSpike = (currentATR[0] > spikeThreshold);

   return (candleSpike || atrSpike);
}

//+------------------------------------------------------------------+
//| Determine Trade Direction (Buy or Sell)                          |
//+------------------------------------------------------------------+
enum TradeDirection
{
   TRADE_DIRECTION_NONE = 0,
   TRADE_DIRECTION_BUY,
   TRADE_DIRECTION_SELL
};

TradeDirection DetermineDirection()
{
   string symbol = (InpSymbol == "") ? Symbol() : InpSymbol;
   
   double prevHigh = iHigh(symbol, InpTimeframe, 1);
   double prevLow  = iLow(symbol, InpTimeframe, 1);
   double ask      = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid      = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point    = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double thresholdInPoints = InpBreakoutThresholdPips * point * 10;

   if(ask > (prevHigh + thresholdInPoints)) return(TRADE_DIRECTION_BUY);
   if(bid < (prevLow  - thresholdInPoints)) return(TRADE_DIRECTION_SELL);

   return(TRADE_DIRECTION_NONE);
}

//+------------------------------------------------------------------+
//| Place Market Order (Buy or Sell)                                 |
//+------------------------------------------------------------------+
void PlaceOrder(int orderType)
{
   string symbol = (InpSymbol == "") ? Symbol() : InpSymbol;
   
   // 1. Calculate lot size based on risk
   double lots = CalculateLotSize();

   // 2. Calculate stop-loss and take-profit distances in points
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double slDistance = 10.0 * point * 10;  // 10 pips
   double tpDistance = InpTakeProfitPips * point * 10;  // User-defined pips

   // Current Bid/Ask
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);

   // Determine actual SL/TP prices
   double slPrice = 0.0, tpPrice = 0.0;

   if(orderType == ORDER_TYPE_BUY)
   {
      slPrice = bid - slDistance;
      tpPrice = bid + tpDistance;
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      slPrice = ask + slDistance;
      tpPrice = ask - tpDistance;
   }

   // 3. Place the trade
   MqlTradeRequest  request;
   MqlTradeResult   result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action         = TRADE_ACTION_DEAL;
   request.symbol         = symbol;
   request.volume         = lots;
   request.type           = (ENUM_ORDER_TYPE)orderType;
   request.price          = (orderType == ORDER_TYPE_BUY) ? ask : bid;
   request.sl             = NormalizeDouble(slPrice, _Digits);
   request.tp             = NormalizeDouble(tpPrice, _Digits);
   request.deviation      = 5;  // max slippage
   request.magic          = g_magicNumber;
   request.comment        = "V-EA-ScalpMaster";
   
   // Send the order
   if(!OrderSend(request, result))
   {
      Print("OrderSend failed. Error: ", GetLastError());
      return;
   }

   // If successful, record the trade time to start cooldown
   if(result.retcode == TRADE_RETCODE_DONE)
   {
      g_lastTradeTime = TimeCurrent();
      Print("Trade placed successfully: ", 
            (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"), 
            " Symbol=", symbol,
            " Lots=", DoubleToString(lots,2),
            " SL=", DoubleToString(request.sl, _Digits), 
            " TP=", DoubleToString(request.tp, _Digits));
   }
   else
   {
      Print("OrderSend returned retcode=", result.retcode);
   }
}

//+------------------------------------------------------------------+
//| Calculate Dynamic Lot Size                                       |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   string symbol = (InpSymbol == "") ? Symbol() : InpSymbol;
   
   // 1. Determine risk in money
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskInMoney    = accountBalance * (InpRiskPercent / 100.0);

   // 2. Suppose we standardize a 10-pip SL for this example:
   double slPips = 10.0;  // Or you can parse from your logic
   double pipValuePerLot = GetPipValuePerLot(symbol);

   // 3. Calculate how many lots that riskInMoney represents with a 10-pip SL
   double lotSize = 0.0;
   if(pipValuePerLot <= 0.0)
   {
      Print("Pip value calculation returned 0. Using fallback lot=0.01");
      return(0.01);
   }

   lotSize = riskInMoney / (slPips * pipValuePerLot);

   // Some brokers require a minimum lot step, typically 0.01
   double minLot      = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double lotStep     = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double maxLot      = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

   // Round lot to the nearest valid step
   lotSize = MathFloor(lotSize / lotStep) * lotStep;

   // Enforce min/max
   if(lotSize < minLot) lotSize = minLot;
   if(lotSize > maxLot) lotSize = maxLot;

   return(lotSize);
}

//+------------------------------------------------------------------+
//| Get Pip Value per 1.0 lot for the specified symbol               |
//+------------------------------------------------------------------+
double GetPipValuePerLot(string symbol)
{
   double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double tickValue    = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize     = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point        = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // Calculate pip size based on digits
   double pipSize = point * 10; // Standard pip size is 10 points
   
   // For JPY pairs or 3-digit pairs, adjust pip size
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      pipSize = point * 100;  // For 3 or 5 decimal places, pip is 100 points
      
   // Convert pip size to number of ticks
   double pipInTicks = pipSize / tickSize;
   // Calculate pip value
   double pipValueOneLot = pipInTicks * tickValue;

   return pipValueOneLot;
}
