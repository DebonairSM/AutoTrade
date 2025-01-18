//+------------------------------------------------------------------+
//|                                                    PivotEA.mq4 |
//|                           YourName - http://yourlink.com         |
//+------------------------------------------------------------------+
#property strict

//--- External Inputs
extern int      MagicNumber          = 12345;

// RSI Settings (H4)
extern int      RSI_Period           = 14;
extern int      RSI_OverBought       = 70;
extern int      RSI_OverSold         = 30;
extern bool     TwoBarConfirmation   = true;

// Timeframes
extern ENUM_TIMEFRAMES SignalTF    = PERIOD_H4; // For RSI signals
extern ENUM_TIMEFRAMES TrendTF     = PERIOD_D1; // For daily pivot and trend

// Daily Trend Filter (50 vs 200 SMA)
extern int      MA_Fast_Period       = 50;
extern int      MA_Slow_Period       = 200;

// Risk Management
extern double   RiskPercent          = 1.0;    // % of account risk per trade

// Buffer settings (in points)
// Use separate buffers for Stop Loss and Take Profit.
extern double   BufferPointsSL       = 50.0;
extern double   BufferPointsTP       = 50.0;

// Partial Exits - using percentages (first partial exit is 50%)
extern double   PartialExitPerc      = 0.5;    

//--- Global Variables for pivot levels (recalculated once per day)
double g_pivot, g_r1, g_r2, g_r3, g_s1, g_s2, g_s3;

//--- Global time trackers
datetime g_lastH4BarTime   = 0;
datetime g_lastDailyBarTime= 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   return(INIT_SUCCEEDED);
  }
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // 1. Check for a new H4 bar (for RSI condition checking)
   if(IsNewBar(SignalTF))
     {
      // RSI conditions are handled further down in pivot recalculation.
      // This block can be used if you want per-H4-bar logic.
     }
     
   // 2. Check for a new Daily bar (for pivot recalculation)
   if(IsNewDailyBar())
     {
      // Recalculate pivots (with a check for Sunday candle)
      RecalcPivotAndPlaceOrders();
     }

   // 3. Manage open positions for partial exits.
   ManageOpenPositions();
  }
  
//+------------------------------------------------------------------+
//| Check if new bar on given timeframe                              |
//+------------------------------------------------------------------+
bool IsNewBar(ENUM_TIMEFRAMES tf)
  {
   datetime currentBarTime = iTime(NULL, tf, 0);
   static datetime savedH4 = 0;
   if(tf==SignalTF)
     {
      if(currentBarTime != savedH4)
        {
         savedH4 = currentBarTime;
         return(true);
        }
     }
   return(false);
  }
  
//+------------------------------------------------------------------+
//| Check if a new daily bar has formed                              |
//+------------------------------------------------------------------+
bool IsNewDailyBar()
  {
   datetime currentDailyTime = iTime(NULL, TrendTF, 0);
   if(currentDailyTime != g_lastDailyBarTime)
     {
      g_lastDailyBarTime = currentDailyTime;
      return(true);
     }
   return(false);
  }
  
//+------------------------------------------------------------------+
//| Recalculate daily pivots and place pending orders                |
//+------------------------------------------------------------------+
void RecalcPivotAndPlaceOrders()
  {
   // Remove any pending orders from previous day
   CloseOldPendingOrders();

   // Calculate daily pivots using yesterday's candle.
   CalculateDailyPivotLevels();
   
   // Check if the previous candle is a Sunday candle; if so, use Friday's data.
   int dayOfWeek = TimeDayOfWeek(iTime(NULL, TrendTF, 1));
   if(dayOfWeek == 0) // Sunday
     {
      // Use candle with shift=2 (which should be Friday)
      double prevHigh   = iHigh(NULL, TrendTF, 2);
      double prevLow    = iLow(NULL, TrendTF, 2);
      double prevClose  = iClose(NULL, TrendTF, 2);
      g_pivot  = (prevHigh + prevLow + prevClose) / 3.0;
      g_r1     = 2.0*g_pivot - prevLow;
      g_s1     = 2.0*g_pivot - prevHigh;
      g_r2     = g_pivot + (prevHigh - prevLow);
      g_s2     = g_pivot - (prevHigh - prevLow);
      g_r3     = prevHigh + 2.0*(g_pivot - prevLow);
      g_s3     = prevLow - 2.0*(prevHigh - g_pivot);
     }

   // Check Daily Trend using 50/200 SMA
   bool dailyBullish = IsDailyTrendBullish();
   bool dailyBearish = !dailyBullish;
   
   // Check for price-action strength using a simple higher-high / higher-low test.
   bool strongTrend = CheckPriceActionTrend(TrendTF);
   
   // Check RSI on H4 for two consecutive bars
   bool isOversold = IsOversoldForTwoBars();
   bool isOverbought = IsOverboughtForTwoBars();
   
   // Now, if RSI confirms and based on the daily trend, place pending orders:
   // For bullish setups: place Buy Limits at S1, S2 and, for a strong trend, aim at S3.
   if(dailyBullish && isOversold)
     {
      PlaceBuyLimitPivotOrder(g_s1);
      PlaceBuyLimitPivotOrder(g_s2);
      // For a strong bullish trend, also use S3 as an order level.
      if(strongTrend)
         PlaceBuyLimitPivotOrder(g_s3);
     }
   // For bearish setups: place Sell Limits at R1, R2 and, for a strong trend, aim at R3.
   else if(dailyBearish && isOverbought)
     {
      PlaceSellLimitPivotOrder(g_r1);
      PlaceSellLimitPivotOrder(g_r2);
      if(strongTrend)
         PlaceSellLimitPivotOrder(g_r3);
     }
  }
  
//+------------------------------------------------------------------+
//| Close old pivot-based pending orders                             |
//+------------------------------------------------------------------+
void CloseOldPendingOrders()
  {
   for(int i = OrdersTotal()-1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderMagicNumber() == MagicNumber &&
            (OrderType()==OP_BUYLIMIT || OrderType()==OP_SELLLIMIT))
           {
            OrderDelete(OrderTicket());
           }
        }
     }
  }
  
//+------------------------------------------------------------------+
//| Calculate Daily Pivot Levels using previous candle               |
//+------------------------------------------------------------------+
void CalculateDailyPivotLevels()
  {
   double prevHigh   = iHigh(NULL, TrendTF, 1);
   double prevLow    = iLow(NULL, TrendTF, 1);
   double prevClose  = iClose(NULL, TrendTF, 1);
   
   g_pivot = (prevHigh + prevLow + prevClose) / 3.0;
   g_r1    = 2.0*g_pivot - prevLow;
   g_s1    = 2.0*g_pivot - prevHigh;
   g_r2    = g_pivot + (prevHigh - prevLow);
   g_s2    = g_pivot - (prevHigh - prevLow);
   g_r3    = prevHigh + 2.0*(g_pivot - prevLow);
   g_s3    = prevLow - 2.0*(prevHigh - g_pivot);
  }
  
//+------------------------------------------------------------------+
//| Determine if Daily Trend is Bullish (50 SMA > 200 SMA)           |
//+------------------------------------------------------------------+
bool IsDailyTrendBullish()
  {
   double maFast = iMA(NULL, TrendTF, MA_Fast_Period, 0, MODE_SMA, PRICE_CLOSE, 0);
   double maSlow = iMA(NULL, TrendTF, MA_Slow_Period, 0, MODE_SMA, PRICE_CLOSE, 0);
   return (maFast > maSlow);
  }
  
//+------------------------------------------------------------------+
//| Check for RSI oversold for two consecutive H4 bars               |
//+------------------------------------------------------------------+
bool IsOversoldForTwoBars()
  {
   double rsi0 = iRSI(NULL, SignalTF, RSI_Period, PRICE_CLOSE, 0);
   double rsi1 = iRSI(NULL, SignalTF, RSI_Period, PRICE_CLOSE, 1);
   if(TwoBarConfirmation)
      return (rsi0 < RSI_OverSold && rsi1 < RSI_OverSold);
   else
      return (rsi0 < RSI_OverSold);
  }
  
//+------------------------------------------------------------------+
//| Check for RSI overbought for two consecutive H4 bars             |
//+------------------------------------------------------------------+
bool IsOverboughtForTwoBars()
  {
   double rsi0 = iRSI(NULL, SignalTF, RSI_Period, PRICE_CLOSE, 0);
   double rsi1 = iRSI(NULL, SignalTF, RSI_Period, PRICE_CLOSE, 1);
   if(TwoBarConfirmation)
      return (rsi0 > RSI_OverBought && rsi1 > RSI_OverBought);
   else
      return (rsi0 > RSI_OverBought);
  }
  
//+------------------------------------------------------------------+
//| Price-Action Trend Check: Compare last 2 daily candles             |
//| Returns true if yesterday's high and low are higher than those of   |
//| the day before (bullish price action) and vice-versa for bearish.    |
//+------------------------------------------------------------------+
bool CheckPriceActionTrend(ENUM_TIMEFRAMES tf)
  {
   double high1 = iHigh(NULL, tf, 1);
   double high2 = iHigh(NULL, tf, 2);
   double low1  = iLow(NULL, tf, 1);
   double low2  = iLow(NULL, tf, 2);
   // For bullish strong trend, require both higher high and higher low.
   if(high1 > high2 && low1 > low2)
      return(true);
   // For bearish strong trend, check the reverse.
   if(high1 < high2 && low1 < low2)
      return(true);
   return(false);
  }
  
//+------------------------------------------------------------------+
//| Place Buy Limit pending order at given price (pivot support)     |
//+------------------------------------------------------------------+
void PlaceBuyLimitPivotOrder(double entryPrice)
  {
   if(entryPrice <= 0) return;
   // Define SL and TP:
   // For Buy: SL = S2 (with BufferPointsSL) and TP = R1 (with BufferPointsTP)
   double sl = g_s2 - (BufferPointsSL * Point);
   double tp = g_r1 + (BufferPointsTP * Point);
   
   // In a strong trend, if we are placing an order at S3 then we might want to
   // use a further TP (i.e. R3) for the final exit. Here we simply check:
   bool strongTrend = CheckPriceActionTrend(TrendTF);
   if(strongTrend && entryPrice == g_s3)
      tp = g_r3 + (BufferPointsTP * Point);
   
   double lotSize = CalculateLotSizeByRisk(entryPrice, sl);
   
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action     = TRADE_ACTION_PENDING;
   request.magic      = MagicNumber;
   request.symbol     = _Symbol;
   request.volume     = lotSize;
   request.price      = NormalizeDouble(entryPrice,Digits);
   request.sl         = NormalizeDouble(sl,Digits);
   request.tp         = NormalizeDouble(tp,Digits);
   request.type       = ORDER_TYPE_BUY_LIMIT;
   request.deviation  = 10;
   request.comment    = "PivotEA_BuyLimit";
   request.expiration = TimeCurrent() + 24*60*60; // 24 hours expiry
   
   OrderSend(request, result);
   if(result.retcode != 10009)
      Print("Buy Limit order failed, retcode=", result.retcode);
  }
  
//+------------------------------------------------------------------+
//| Place Sell Limit pending order at given price (pivot resistance) |
//+------------------------------------------------------------------+
void PlaceSellLimitPivotOrder(double entryPrice)
  {
   if(entryPrice <= 0) return;
   // Define SL and TP:
   // For Sell: SL = R2 (with BufferPointsSL) and TP = S1 (with BufferPointsTP)
   double sl = g_r2 + (BufferPointsSL * Point);
   double tp = g_s1 - (BufferPointsTP * Point);
   
   bool strongTrend = CheckPriceActionTrend(TrendTF);
   if(strongTrend && entryPrice == g_r3)
      tp = g_s3 - (BufferPointsTP * Point);
   
   double lotSize = CalculateLotSizeByRisk(entryPrice, sl);
   
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action     = TRADE_ACTION_PENDING;
   request.magic      = MagicNumber;
   request.symbol     = _Symbol;
   request.volume     = lotSize;
   request.price      = NormalizeDouble(entryPrice,Digits);
   request.sl         = NormalizeDouble(sl,Digits);
   request.tp         = NormalizeDouble(tp,Digits);
   request.type       = ORDER_TYPE_SELL_LIMIT;
   request.deviation  = 10;
   request.comment    = "PivotEA_SellLimit";
   request.expiration = TimeCurrent() + 24*60*60; // 24 hours expiry
   
   OrderSend(request, result);
   if(result.retcode != 10009)
      Print("Sell Limit order failed, retcode=", result.retcode);
  }
  
//+------------------------------------------------------------------+
//| Dynamic Lot Size Calculation based on Risk                       |
//| Uses RiskPercent of AccountBalance, distance (in points) to SL     |
//+------------------------------------------------------------------+
double CalculateLotSizeByRisk(double entryPrice, double stopLoss)
  {
   double accountBalance = AccountBalance();
   double riskAmount = (RiskPercent / 100.0) * accountBalance;
   
   double tickValue = MarketInfo(_Symbol, MODE_TICKVALUE);
   double tickSize  = MarketInfo(_Symbol, MODE_TICKSIZE);
   
   double distancePoints = MathAbs(entryPrice - stopLoss) / tickSize;
   if(distancePoints < 1.0) distancePoints = 1.0;
   
   double costPerLot = distancePoints * tickValue;
   if(costPerLot <= 0) return(MarketInfo(_Symbol, MODE_MINLOT));
   
   double lotSize = riskAmount / costPerLot;
   lotSize = NormalizeLotSize(lotSize);
   return(lotSize);
  }
  
//+------------------------------------------------------------------+
//| Normalize Lot Size to Broker Requirements                        |
//+------------------------------------------------------------------+
double NormalizeLotSize(double lots)
  {
   double minLot  = MarketInfo(_Symbol, MODE_MINLOT);
   double lotStep = MarketInfo(_Symbol, MODE_LOTSTEP);
   double maxLot  = MarketInfo(_Symbol, MODE_MAXLOT);
   
   double steps = MathFloor(lots / lotStep + 0.5);
   double normalized = steps * lotStep;
   
   if(normalized < minLot)
      normalized = minLot;
   if(normalized > maxLot)
      normalized = maxLot;
      
   return(normalized);
  }
  
//+------------------------------------------------------------------+
//| Manage Open Positions with Partial Exits                         |
//| For Buy positions:                                                        |
//|   - Normal trend: Partial exit when price >= R1, final exit when price >= R2.  |
//|   - Strong trend: final exit moves to R3.                           |
//| For Sell positions: similar, with S1/S2 vs. S3.                     |
//+------------------------------------------------------------------+
void ManageOpenPositions()
  {
   for(int i = OrdersTotal()-1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderMagicNumber() != MagicNumber || OrderSymbol() != _Symbol)
            continue;
         
         int orderType = OrderType();
         double lots = OrderLots();
         double strong = CheckPriceActionTrend(TrendTF) ? 1.0 : 0.0; // flag for strong trend
         
         // For Buy positions.
         if(orderType == OP_BUY)
           {
            double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            // Use different targets based on strength.
            double target1 = g_r1 + (BufferPointsTP*Point); // partial exit trigger for normal
            double target2 = strong ? (g_r3 + (BufferPointsTP*Point)) : (g_r2 + (BufferPointsTP*Point)); // final exit target
            
            // If price reaches first target and no partial exit has been done:
            if(bidPrice >= target1 && !OrderCommentContains("Partial1"))
              {
               ClosePartial(OrderTicket(), PartialExitPerc, "Partial1");
              }
            // Then if price reaches final target, close remaining position.
            if(bidPrice >= target2 && !OrderCommentContains("Partial2"))
              {
               ClosePartial(OrderTicket(), 1.0, "Partial2");
              }
           }
         else if(orderType == OP_SELL)
           {
            double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double target1 = g_s1 - (BufferPointsTP*Point);
            double target2 = strong ? (g_s3 - (BufferPointsTP*Point)) : (g_s2 - (BufferPointsTP*Point));
            
            if(askPrice <= target1 && !OrderCommentContains("Partial1"))
              {
               ClosePartial(OrderTicket(), PartialExitPerc, "Partial1");
              }
            if(askPrice <= target2 && !OrderCommentContains("Partial2"))
              {
               ClosePartial(OrderTicket(), 1.0, "Partial2");
              }
           }
        }
     }
  }
  
//+------------------------------------------------------------------+
//| Helper: Check if order comment contains a substring              |
//+------------------------------------------------------------------+
bool OrderCommentContains(string substring)
  {
   string cmt = OrderComment();
   if(StringFind(cmt, substring, 0) != -1)
      return(true);
   return(false);
  }
  
//+------------------------------------------------------------------+
//| Helper: Close a portion of an order                              |
//+------------------------------------------------------------------+
void ClosePartial(int ticket, double percent, string partialTag)
  {
   if(OrderSelect(ticket, SELECT_BY_TICKET))
     {
      double lotToClose = OrderLots() * percent;
      lotToClose = NormalizeLotSize(lotToClose);
      if(lotToClose < MarketInfo(_Symbol, MODE_MINLOT))
         return;
         
      double closePrice = (OrderType() == OP_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(OrderClose(ticket, lotToClose, closePrice, 10, clrRed))
        {
         // Append partial tag to comment.
         string newComment = OrderComment() + "_" + partialTag;
         // In MQL4, OrderModify() cannot change the comment on a partially closed order,
         // so we simply print a log for tracking.
         Print("Partial close executed on ticket=", ticket, " Tag=", partialTag);
        }
      else
         Print("Partial close failed on ticket=", ticket);
     }
  }
  
//+------------------------------------------------------------------+
