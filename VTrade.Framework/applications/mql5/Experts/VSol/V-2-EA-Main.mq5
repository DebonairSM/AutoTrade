//+------------------------------------------------------------------+
//|                                               TemplateEA.mq5     |
//|                         Example EA Template (Modular)            |
//+------------------------------------------------------------------+
#property copyright "Your Company"
#property link      "Your Link"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>
#include "V-2-EA-Breakouts.mqh"
CTrade trade;

//==================================================================
// MODULE 1: CONFIGURATION AND INITIALIZATION
// Purpose: Core EA settings, input parameters, and placeholders
//==================================================================

// Strategy type selection
enum ENUM_STRATEGY_TYPE
{
   STRAT_NONE = 0,        // No Strategy
   STRAT_BREAKOUTS = 1,   // Breakout Strategy
   STRAT_OTHER = 2        // Other Strategies
};

// Core strategy inputs (general placeholders)
input ENUM_STRATEGY_TYPE StrategyType = STRAT_BREAKOUTS;

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

// Strategy objects
CV2EABreakouts* g_breakoutStrategy = NULL;  // Strategy instance

//==================================================================
// MODULE 3: SESSION CONTROL
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
// MODULE 4: STRATEGY EXECUTION
// Purpose: The high-level "go" function that executes the selected
//          strategy based on type.
//==================================================================
void ExecuteStrategy()
{
   // Early exit if trading not allowed
   if(!g_allowNewTrades)
      return;
      
   // Strategy-specific execution
   switch(StrategyType)
   {
      case STRAT_BREAKOUTS:
         if(g_breakoutStrategy != NULL && g_breakoutStrategy.IsTradeAllowed())
         {
            g_breakoutStrategy.ProcessTick();
         }
         break;
         
      case STRAT_OTHER:
         // Future strategy implementations
         break;
         
      case STRAT_NONE:
      default:
         if(ShowDebugPrints)
            Print("ℹ️ [ExecuteStrategy] No active strategy selected");
         break;
   }
}

//==================================================================
// MODULE 5: EA LIFECYCLE
// Purpose: Expert Advisor initialization and runtime management
//==================================================================

// 5.1: OnInit
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

   // Initialize selected strategy
   switch(StrategyType)
   {
      case STRAT_BREAKOUTS:
         // Initialize breakout strategy
         g_breakoutStrategy = new CV2EABreakouts();
         if(g_breakoutStrategy == NULL)
         {
            if(ShowDebugPrints)
               Print("❌ [OnInit] Failed to create breakout strategy instance");
            return INIT_FAILED;
         }
         
         // Initialize strategy with parameters
         if(!g_breakoutStrategy.Init(g_magicNumber, ATRPeriod, SLMultiplier, 
                                   TPMultiplier, RiskPercentage, ShowDebugPrints))
         {
            if(ShowDebugPrints)
               Print("❌ [OnInit] Failed to initialize breakout strategy");
            return INIT_FAILED;
         }
         
         // Set session control parameters
         g_breakoutStrategy.SetSessionControl(RestrictTradingHours,
                                           LondonOpenHour,
                                           LondonCloseHour,
                                           NewYorkOpenHour,
                                           NewYorkCloseHour,
                                           BrokerToLocalOffsetHours);
         break;
         
      case STRAT_OTHER:
         // Future strategy initializations
         break;
         
      case STRAT_NONE:
      default:
         if(ShowDebugPrints)
            Print("ℹ️ [OnInit] No strategy selected for initialization");
         break;
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
      Print("ℹ️ [OnInit] EA started with strategy: ", EnumToString(StrategyType),
            " Session restrictions: ", (RestrictTradingHours ? "ON" : "OFF"),
            " Timer interval: ", TIMER_INTERVAL, "s");
   }
   return INIT_SUCCEEDED;
}

// 5.2: OnDeinit
void OnDeinit(const int reason)
{
   // Release ATR handle
   if(g_handleATR != INVALID_HANDLE)
      IndicatorRelease(g_handleATR);

   // Clean up based on strategy type
   switch(StrategyType)
   {
      case STRAT_BREAKOUTS:
         if(g_breakoutStrategy != NULL)
         {
            delete g_breakoutStrategy;
            g_breakoutStrategy = NULL;
         }
         break;
         
      case STRAT_OTHER:
         // Future strategy cleanup
         break;
   }

   EventKillTimer();

   if(ShowDebugPrints)
      Print("ℹ️ [OnDeinit] EA stopped. Strategy: ", EnumToString(StrategyType),
            " Reason: ", reason);
}

// 5.3: OnTick
void OnTick()
{
   g_tickCount++;
   ulong tickStartTime = GetMicrosecondCount();

   // Check if we can trade this session
   IsTradeAllowedInSession();

   // Execute selected strategy
   ExecuteStrategy();

   // Performance tracking
   ulong tickEndTime = GetMicrosecondCount();
   double tickTime   = (tickEndTime - tickStartTime) / 1000.0;

   g_totalTickTime  += tickTime;
   g_avgTickTime     = g_totalTickTime / (double)g_tickCount;
   g_maxTickTime     = MathMax(g_maxTickTime, tickTime);
}

// 5.4: OnTimer
void OnTimer()
{
   // Future enhancement: Add timer-based strategy updates if needed
   // For now, we'll keep it empty as the breakout strategy operates on ticks
}