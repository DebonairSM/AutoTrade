//+------------------------------------------------------------------+
//|                                               TemplateEA.mq5     |
//|                         Example EA Template (Modular)            |
//+------------------------------------------------------------------+
#property copyright "Your Company"
#property link      "Your Link"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//==================================================================
// MODULE 1: CONFIGURATION AND INITIALIZATION
// Purpose: Core EA settings, input parameters, and placeholders
//          for your own strategy logic.
//==================================================================

// Strategy type selection (placeholder for your enumerations)
enum ENUM_STRATEGY_TYPE
{
   STRAT_PLACEHOLDER = 0, 
   STRAT_OTHER       = 1
};

// Core strategy inputs (general placeholders)
input ENUM_STRATEGY_TYPE StrategyType = STRAT_PLACEHOLDER;

// -------------------- Risk Management Inputs ----------------------
input double SLMultiplier      = 1.5;   // Stop Loss multiplier (ATR/pivots)
input double TPMultiplier      = 3.0;   // Take Profit multiplier (ATR/pivots)
input double RiskPercentage    = 1.0;   // % of account balance risked per trade

// -------------------- Session Control Inputs -----------------------
input bool   RestrictTradingHours   = true;   // Toggle session control
input int    LondonOpenHour         = 3;      // London start (ET)
input int    LondonCloseHour        = 11;     // London end (ET)
input int    NewYorkOpenHour        = 9;      // NY start (ET)
input int    NewYorkCloseHour       = 16;     // NY end (ET)
input int    BrokerToLocalOffsetHours = 7;    // Offset to convert broker time -> local (ET)

// -------------------- ATR & Misc. Inputs ---------------------------
input int    ATRPeriod             = 14;      // Period for ATR
input bool   ShowDebugPrints       = true;    // Enable debug logging

//==================================================================
// MODULE 2: GLOBAL STATE MANAGEMENT
// Purpose: Maintains EA-level state variables, handles, counters.
//==================================================================

// Core state variables
datetime      g_lastBarTime      = 0;    // Tracks last bar's open time
int           g_lastBarIndex     = -1;   // Last bar index
bool          g_hasPositionOpen  = false;
int           g_magicNumber      = 12345;

// Session control state
bool          g_allowNewTrades       = true; // Manage new trade permission
bool          g_allowTradeManagement = true; // Manage trade management permission

// Timer settings
static int    TIMER_INTERVAL    = 15;   // 15-second timer interval

// ATR handle
int           g_handleATR       = INVALID_HANDLE;

// Performance monitoring
ulong         g_tickCount       = 0;    // # of ticks processed
ulong         g_calculationCount= 0;    // # of strategy calculations
double        g_maxTickTime     = 0.0;  // Max time spent on a single tick
double        g_avgTickTime     = 0.0;  // Average time spent processing a tick
double        g_totalTickTime   = 0.0;  // Sum of all processing times

//==================================================================
// MODULE 3: (Placeholder if needed)
// Purpose: If you have other global data structures or
//          advanced logic to track, create them here.
//==================================================================

// -- Intentionally left blank for your own expansions --

//==================================================================
// MODULE 4: SESSION CONTROL
// Purpose: Trading session validation and time-based filters
//==================================================================
bool IsTradeAllowedInSession()
{
   // If user does not want hour-based restrictions, always allow
   if(!RestrictTradingHours)
   {
      g_allowNewTrades       = true;
      g_allowTradeManagement = true;
      return true;
   }

   datetime now;
   MqlDateTime dt;
   now = TimeCurrent();
   TimeToStruct(now, dt);

   // Convert broker time to (for example) Eastern Time
   int currentHourET = (dt.hour - BrokerToLocalOffsetHours + 24) % 24;

   // Check if in London or New York session
   bool inLondonSession   = (currentHourET >= LondonOpenHour && currentHourET < LondonCloseHour);
   bool inNewYorkSession  = (currentHourET >= NewYorkOpenHour && currentHourET < NewYorkCloseHour);
   bool isInSession       = inLondonSession || inNewYorkSession;

   // Update global flags
   g_allowNewTrades       = isInSession;
   g_allowTradeManagement = true;  // Usually allow trade management even if session is closed

   return isInSession;
}

//==================================================================
// MODULE 5: STRATEGY LOGIC - PLACEHOLDER
// Purpose: Insert your strategy detection/validation logic here.
//          For instance, candlestick patterns, momentum signals,
//          custom indicators, etc.
//==================================================================

// Example placeholder function signature:
bool CheckEntrySignal(/* arguments as needed */)
{
   // TODO: Implement your custom conditions
   return false;
}

//==================================================================
// MODULE 6: ADDITIONAL STRATEGY VALIDATION - PLACEHOLDER
// Purpose: If your strategy needs a second step or advanced checks,
//          place them here. Otherwise, leave it empty or remove it.
//==================================================================

bool ValidateAdditionalConditions(/* arguments as needed */)
{
   // TODO: Additional checks
   return true;
}

//==================================================================
// MODULE 7: RISK MANAGEMENT
// Purpose: Position sizing, margin checks, etc.
//==================================================================
double CalculateLotSize(double stopLossPrice, double entryPrice, double riskPercent)
{
   // 1) Determine the account balance and base risk amount
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount     = accountBalance * (riskPercent / 100.0);

   // 2) Calculate distance from entry to SL in points
   double stopDistancePoints = MathAbs(entryPrice - stopLossPrice) / _Point;
   if(stopDistancePoints < 1.0)  // prevent nonsensical math
      stopDistancePoints = 10.0; // fallback, e.g., 10 points

   // 3) Get tick value in account currency
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickValue <= 0)
   {
      if(ShowDebugPrints)
         Print("⚠️ [CalculateLotSize] Tick value = 0; using min lot fallback.");
      return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   }

   // 4) Calculate potential loss per 1.0 lot
   double potentialLossPerLot = stopDistancePoints * tickValue;
   if(potentialLossPerLot <= 0)
   {
      if(ShowDebugPrints)
         Print("⚠️ [CalculateLotSize] Potential loss per lot = 0; fallback to min lot.");
      return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   }

   // 5) Initial lot size based on risk
   double lots = riskAmount / potentialLossPerLot;

   // 6) Broker constraints
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   // Round down to nearest lot step
   lots = MathFloor(lots / lotStep) * lotStep;
   // Enforce boundaries
   lots = MathMax(minLot, MathMin(lots, maxLot));

   // 7) Margin check
   double marginRequiredBuy  = 0.0;
   double marginRequiredSell = 0.0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY,  _Symbol, lots, entryPrice, marginRequiredBuy) ||
      !OrderCalcMargin(ORDER_TYPE_SELL, _Symbol, lots, entryPrice, marginRequiredSell))
   {
      if(ShowDebugPrints)
         Print("⚠️ [CalculateLotSize] OrderCalcMargin failed; fallback to min lot.");
      return minLot;
   }

   // Use the higher margin requirement for safety
   double marginRequired = MathMax(marginRequiredBuy, marginRequiredSell);
   double freeMargin     = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double safeMargin     = freeMargin * 0.8; // only 80% usage

   // If margin is too high, reduce lots
   if(marginRequired > safeMargin)
   {
      double reduceFactor = safeMargin / marginRequired;
      lots = lots * reduceFactor;
      // Round to lot step again
      lots = MathFloor(lots / lotStep) * lotStep;
      lots = MathMax(minLot, lots);
   }

   return lots;
}

//==================================================================
// MODULE 8: ORDER MANAGEMENT
// Purpose: Placing trades, setting SL/TP, pivot calculations, etc.
//==================================================================

// 8.1: Daily Pivot Points (helper function)
bool GetDailyPivotPoints(double &pivot, double &r1, double &r2, double &s1, double &s2)
{
   MqlRates dailyRates[];
   ArrayResize(dailyRates, 2);
   ArraySetAsSeries(dailyRates, true);

   // Copy 2 bars: index 0 = current daily (not closed), index 1 = last closed daily
   if(CopyRates(_Symbol, PERIOD_D1, 0, 2, dailyRates) < 2)
   {
      Print("❌ [GetDailyPivotPoints] Unable to copy daily bars, error =", GetLastError());
      return false;
   }

   double prevDayHigh  = dailyRates[1].high;
   double prevDayLow   = dailyRates[1].low;
   double prevDayClose = dailyRates[1].close;

   pivot = (prevDayHigh + prevDayLow + prevDayClose) / 3.0;
   r1    = 2.0 * pivot - prevDayLow;
   s1    = 2.0 * pivot - prevDayHigh;
   r2    = pivot + (r1 - s1);
   s2    = pivot - (r1 - s1);

   return true;
}

// 8.2: Example for setting pivot-based SL/TP
bool ApplyDailyPivotSLTP(bool isBullish, double &entryPrice, double &slPrice, double &tpPrice)
{
   double pivot=0, r1=0, r2=0, s1=0, s2=0;
   if(!GetDailyPivotPoints(pivot, r1, r2, s1, s2))
   {
      if(ShowDebugPrints) Print("❌ [ApplyDailyPivotSLTP] Using fallback because pivot retrieval failed.");
      return false;
   }

   // Very simplistic approach
   double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(isBullish)
   {
      slPrice = MathMin(s1, entryPrice - (SLMultiplier * 50 * pointSize));
      tpPrice = MathMax(r1, entryPrice + (TPMultiplier * 50 * pointSize));
   }
   else
   {
      slPrice = MathMax(r1, entryPrice + (SLMultiplier * 50 * pointSize));
      tpPrice = MathMin(s1, entryPrice - (TPMultiplier * 50 * pointSize));
   }

   return true;
}

// 8.3: Placing the trade
bool PlaceTrade(bool isBullish, double entryPrice, double slPrice, double tpPrice, double lots)
{
   trade.SetExpertMagicNumber(g_magicNumber);

   // Normalize price
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   entryPrice    = NormalizeDouble(entryPrice, digits);
   slPrice       = NormalizeDouble(slPrice, digits);
   tpPrice       = NormalizeDouble(tpPrice, digits);

   // Additional checks if needed...
   bool result = isBullish
               ? trade.Buy(lots, _Symbol, 0, slPrice, tpPrice, "Long Entry")
               : trade.Sell(lots, _Symbol, 0, slPrice, tpPrice, "Short Entry");

   if(!result && ShowDebugPrints)
      Print("❌ [PlaceTrade] Order failed, error = ", GetLastError());
   else if(result && ShowDebugPrints)
      Print("✅ [PlaceTrade] Placed ", (isBullish ? "Buy" : "Sell"), 
            " | Lots=", lots, " | SL=", slPrice, " | TP=", tpPrice);

   return result;
}

//==================================================================
// MODULE 9: STRATEGY EXECUTION - PLACEHOLDER
// Purpose: The high-level "go" function that calls your signals/
//          validations (Modules 5 & 6), calculates SL/TP, etc.
//==================================================================
void ExecuteStrategy()
{
   // Example outline:
   // 1. Check if your conditions from Modules 5 & 6 are met
   // 2. Decide direction (Bullish or Bearish)
   // 3. Calculate SL/TP using e.g. pivot logic or ATR
   // 4. Calculate lot size
   // 5. Place the trade
   // ---------------------------------------------------------
   // Pseudocode:
   /*
   if(!CheckEntrySignal())
      return;

   if(!ValidateAdditionalConditions())
      return;

   bool isBullish = true; // or false, depending on your logic
   double currentPrice = isBullish ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double slPrice = 0, tpPrice = 0;
   if(!ApplyDailyPivotSLTP(isBullish, currentPrice, slPrice, tpPrice))
      return;

   double lots = CalculateLotSize(slPrice, currentPrice, RiskPercentage);
   if(lots <= 0)
      return;

   // Attempt trade
   PlaceTrade(isBullish, currentPrice, slPrice, tpPrice, lots);
   */
}

//==================================================================
// MODULE 10: EA LIFECYCLE
// Purpose: Expert Advisor initialization and runtime management
//==================================================================

// 10.1: OnInit
int OnInit()
{
   // Create the ATR handle
   g_handleATR = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
   if(g_handleATR == INVALID_HANDLE)
   {
      if(ShowDebugPrints)
         Print("❌ [OnInit] Failed to create ATR handle, error=", GetLastError());
      return INIT_FAILED;
   }

   // Set a timer for periodic checks
   if(!EventSetTimer(TIMER_INTERVAL))
   {
      if(ShowDebugPrints)
         Print("❌ [OnInit] Failed to set timer");
      return INIT_FAILED;
   }

   if(ShowDebugPrints)
   {
      Print("ℹ️ [OnInit] EA template started. Session restrictions = ",
            (RestrictTradingHours ? "ON" : "OFF"), 
            "; Timer interval = ", TIMER_INTERVAL, "s");
   }
   return INIT_SUCCEEDED;
}

// 10.2: OnDeinit
void OnDeinit(const int reason)
{
   // Release ATR handle
   if(g_handleATR != INVALID_HANDLE)
      IndicatorRelease(g_handleATR);

   EventKillTimer();

   if(ShowDebugPrints)
      Print("ℹ️ [OnDeinit] EA stopped. Reason=", reason);
}

// 10.3: OnTick
void OnTick()
{
   g_tickCount++;

   ulong tickStartTime = GetMicrosecondCount();

   // Check if we can trade this session
   IsTradeAllowedInSession();

   // If allowed, run your strategy
   if(g_allowNewTrades)
   {
      // Example call:
      ExecuteStrategy();
   }

   // Performance tracking
   ulong tickEndTime = GetMicrosecondCount();
   double tickTime   = (tickEndTime - tickStartTime) / 1000.0;

   g_totalTickTime  += tickTime;
   g_avgTickTime     = g_totalTickTime / (double)g_tickCount;
   g_maxTickTime     = MathMax(g_maxTickTime, tickTime);
}

// 10.4: OnTimer
void OnTimer()
{
   // You can run heavier computations or housekeeping tasks here
   // if you don't want them in OnTick.
   //
   // For instance, only check certain signals every X seconds/minutes.
   //
   // (Leaving empty for now.)
}