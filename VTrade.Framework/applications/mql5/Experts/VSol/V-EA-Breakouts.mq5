//+------------------------------------------------------------------+
//|                                                V-EA-Breakouts.mq5 |
//|                      Skeleton for Breakout-Retest (Modular)      |
//+------------------------------------------------------------------+
#property copyright "Your Company"
#property link      "Your Link"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>
#include "V-2-EA-Utils.mqh"  // Add centralized logging utilities
CTrade trade;


//==================================================================
// MODULE 1: CONFIGURATION AND INITIALIZATION
// Purpose: Core EA settings, input parameters, and strategy configuration
// Components:
// - Strategy type and core behavior settings
// - Breakout detection and validation parameters
// - Risk management and position sizing
// - Session control and trading hours
// - Key level detection and strength calculation
//==================================================================

// Strategy type selection
enum ENUM_STRATEGY_TYPE
{
   STRAT_BREAKOUT_RETEST = 0, 
   STRAT_OTHER           = 1
};

// Core strategy inputs
input ENUM_STRATEGY_TYPE StrategyType = STRAT_BREAKOUT_RETEST;

// Enhanced Position Management
input group "=== POSITION MANAGEMENT ==="
input bool   UseMultiTimeframeConfirmation = true;   // Enable multi-timeframe confirmation
input bool   UseStrengthBasedSizing = true;          // Adjust position size based on level strength
input double MaxStrengthMultiplier = 1.5;            // Maximum multiplier for strong levels

// [P1 OPTIMIZATION] - Core Breakout Detection for H1
// Goal: Find optimal parameters for identifying valid H1 breakouts
// Success Metrics: 
// - Higher win rate (>60%)
// - Minimal false breakouts (<20%)
// - Clear level identification (check debug logs)
input int    BreakoutLookback       = 24;      // BreakoutLookback: P1 opt 12-48/4, H1 bars
input double MinStrengthThreshold   = 0.65;    // MinStrengthThreshold: P1 opt 0.55-0.85/0.05
input double RetestATRMultiplier    = 0.5;     // RetestATRMultiplier: P1 opt 0.3-1.0/0.1

// Core filters - Keep enabled in P1
input bool   UseVolumeFilter        = true;     // UseVolumeFilter: Required for breakout
input bool   UseMinATRDistance      = true;     // UseMinATRDistance: Required for validation
input bool   UseRetest             = true;      // UseRetest: Required for entry confirmation
input bool   ShowDebugPrints       = true;      // ShowDebugPrints: Enable logging

// [DISABLED FOR P1] - Risk Management
input double SLMultiplier           = 1.5;     // SLMultiplier: P2 optimization
input double TPMultiplier           = 6.0;     // TPMultiplier: P2 optimization
input double RiskPercentage         = 1.0;     // RiskPercentage: Fixed 1% in P1

// [DISABLED FOR P1] - Advanced Settings
input bool   UseCandlestickConfirmation = false; // UseCandlestickConfirmation: Disabled in P1
input int    MaxRetestBars          = 8;       // MaxRetestBars: P3 optimization
input int    MaxRetestMinutes       = 480;     // MaxRetestMinutes: Fixed 8h for H1

// Session control - Fixed in P1
input bool   RestrictTradingHours   = true;    // RestrictTradingHours: Session control
input int    LondonOpenHour         = 3;       // LondonOpenHour: London start (ET)
input int    LondonCloseHour        = 11;      // LondonCloseHour: London end (ET)
input int    NewYorkOpenHour        = 9;       // NewYorkOpenHour: NY start (ET)
input int    NewYorkCloseHour       = 16;      // NewYorkCloseHour: NY end (ET)
input int    BrokerToLocalOffsetHours = 7;     // BrokerToLocalOffsetHours: ET offset

// Technical Parameters - Fixed in P1
input int    ATRPeriod              = 14;      // ATRPeriod: Fixed 14
input double ATRMultiplier          = 0.2;     // ATRMultiplier: Fixed 0.2
input int    KeyLevelLookback       = 480;     // KeyLevelLookback: Fixed 480 (20 days)
input int    MinTouchCount          = 2;       // MinTouchCount: Fixed 2
input double TouchZoneSize          = 0.0004;  // TouchZoneSize: Fixed 0.0004
input double KeyLevelMinDistance    = 0.0025;  // KeyLevelMinDistance: Fixed 0.0025

// Level validation weights - Fixed in P1
input double TouchScoreWeight       = 0.5;     // TouchScoreWeight: Fixed 0.5
input double RecencyWeight          = 0.3;     // RecencyWeight: Fixed 0.3
input double DurationWeight         = 0.2;     // DurationWeight: Fixed 0.2

// Level validation - Fixed in P1
input int    MinLevelDurationHours  = 12;      // MinLevelDurationHours: Fixed 12h

// Retest parameters - Fixed in P1
input double RetestPipsThreshold    = 15;      // RetestPipsThreshold: Fixed 15p
input ENUM_TIMEFRAMES RetestTimeframe = PERIOD_M15; // RetestTimeframe: Fixed M15

// Volatility thresholds - Fixed in P1
input double ATRVolatilityThreshold = 0.0010;  // ATRVolatilityThreshold: Fixed 0.001
input int    HighVolatilityStartHour = 7;      // HighVolatilityStartHour: Fixed 7
input int    HighVolatilityEndHour   = 16;     // HighVolatilityEndHour: Fixed 16

// Volume filter parameters
input ENUM_APPLIED_VOLUME VolumeType   = VOLUME_TICK; // VolumeType: Use tick volume

//==================================================================
// MODULE 2: GLOBAL STATE MANAGEMENT
// Purpose: Maintains EA state variables and runtime tracking
// Components:
// - Trade state tracking (positions, breakouts)
// - Technical indicator handles
// - Multi-entry filter state
// - Breakout zone tracking
// - Session and volatility state
//==================================================================

// Core state variables
datetime      g_lastBarTime      = 0;    // Track last bar time
int           g_lastBarIndex     = -1;   // Track last bar index
bool          g_hasPositionOpen  = false;
int           g_magicNumber      = 12345;

// Session control state
bool          g_allowNewTrades     = true;  // Controls new trade entry permission
bool          g_allowTradeManagement = true; // Controls position management permission
datetime      g_lastSessionStateChange = 0;  // Track last session state change

// Timer settings
static int    TIMER_INTERVAL     = 15;   // 15 second timer interval

// Breakout state tracking
double        g_breakoutLevel    = 0.0;
bool          g_isBullishBreak   = false;

// Add global ATR handle
int           g_handleATR        = INVALID_HANDLE;

// Multi-entry filter state
datetime      g_lastTradeTime    = 0;     // Time of last trade placement
datetime      g_lastTradeBarTime = 0;     // Opening time of the bar where last trade occurred
int           g_lastTradeBar     = 0;     // Bar index of last trade

// Breakout zone lockout state
double        g_activeBreakoutZonePrice = 0.0;  // Price level of the active breakout zone
bool          g_activeBreakoutDirection = false; // Direction of active breakout (true=bullish)
bool          g_inLockout = false;              // Whether we have an active breakout zone lockout

// Debug and logging time tracking
datetime      g_lastSessionDebugTime = 0;    // Last session debug message time
datetime      g_lastLockoutDebugTime = 0;    // Last lockout debug message time
datetime      g_lastKeyLevelLogTime = 0;     // Track last key level log time
double        g_lastReportedDistance = 0.0;   // Last reported distance

// Performance monitoring
datetime      g_lastCalculationTime = 0;    // Last time we performed heavy calculations
datetime      g_lastDebugTime = 0;          // Last time we printed debug info
ulong         g_tickCount = 0;              // Total number of ticks processed
ulong         g_calculationCount = 0;       // Number of times we performed heavy calculations
ulong         g_lastTickTime = 0;            // For measuring tick processing time
double        g_maxTickTime = 0;            // Maximum time spent processing a tick
double        g_avgTickTime = 0;            // Average time spent processing a tick
double        g_totalTickTime = 0;          // Total time spent processing ticks

struct SBreakoutState
{
   datetime breakoutTime;  
   double   breakoutLevel; 
   bool     isBullish;     
   bool     awaitingRetest; 
   int      barsWaiting;   
   datetime retestStartTime; // store exact time of breakout or retest init
   int      retestStartBar;  // store bar index at breakout or retest init
};
SBreakoutState g_breakoutState = {0,0.0,false,false,0,0};

// Define structs at the top of the file, after the input parameters
struct STouch
{
   datetime time;       // When the touch occurred
   double   price;     // Exact price of the touch
   double   strength;  // How close to the exact level (0.0-1.0)
   bool     isValid;   // Whether this is a valid touch or just a spike
};

struct SKeyLevel
{
   double    price;           // The price level
   int       touchCount;      // Number of times price touched this level
   bool      isResistance;    // Whether this is resistance (true) or support (false)
   datetime  firstTouch;      // Time of first touch
   datetime  lastTouch;       // Time of last touch
   double    strength;        // Relative strength of the level
   STouch    touches[];      // Dynamic array of touches
};

// Global variables for key level tracking
SKeyLevel g_keyLevels[];  // Array to store detected key levels
int g_lastKeyLevelUpdate = 0;  // Bar index of last key level update

// [OPTIMIZATION LOGGING]
string g_lastBreakoutStats = "";    // Stores stats about last breakout
int g_totalBreakouts = 0;          // Total breakouts detected
int g_validBreakouts = 0;          // Breakouts that met all criteria
int g_falseBreakouts = 0;          // Failed breakouts
int g_retestSuccess = 0;           // Successful retests
double g_avgStrength = 0;          // Average level strength

//==================================================================
// MODULE 4: SESSION CONTROL
// Purpose: Trading session validation and time-based filters
// Components:
// - Session time validation
// - Trading hour restrictions
// - Market activity monitoring
//==================================================================

// MODULE 4.1: Check if trading is allowed in current session
bool IsTradeAllowedInSession()
{
   // If trading hours are not restricted, allow everything
   if(!RestrictTradingHours)
   {
      g_allowNewTrades = true;
      g_allowTradeManagement = true;
      return true;
   }
      
   // Get current broker time and convert to Eastern time
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   
   // Convert broker time to Eastern time by subtracting the offset
   int currentHourET = (dt.hour - BrokerToLocalOffsetHours + 24) % 24;
   
   // Check if we're in London session (using Eastern time)
   bool inLondonSession = (currentHourET >= LondonOpenHour && currentHourET < LondonCloseHour);
   
   // Check if we're in New York session (using Eastern time)
   bool inNewYorkSession = (currentHourET >= NewYorkOpenHour && currentHourET < NewYorkCloseHour);
   
   // Trading is allowed if we're in either session
   bool isInSession = inLondonSession || inNewYorkSession;
   
   // Update global permission flags
   bool previousTradeState = g_allowNewTrades;
   g_allowNewTrades = isInSession;  // Only allow new trades during session
   g_allowTradeManagement = true;   // Always allow trade management
   
   // Only log when the session state actually changes
   if(ShowDebugPrints && previousTradeState != g_allowNewTrades)
   {
      CV2EAUtils::LogInfo(StringFormat("Trading %s at Eastern hour %d", 
            (isInSession ? "enabled" : "disabled"), currentHourET));
      g_lastSessionStateChange = now;
   }
   
   return isInSession;  // Return session state for backward compatibility
}

//==================================================================
// MODULE 5: BREAKOUT VALIDATION AND DETECTION
// Purpose: Core breakout strategy implementation
// Components:
// - Key level proximity checking
// - Level strength calculation
// - Breakout pattern detection
// - Volume and ATR validation
//==================================================================

// MODULE 5.1: Key level proximity check for breakout levels
bool IsNearExistingLevel(const double price, const SKeyLevel &levels[], const int count)
{
   for(int i = 0; i < count; i++)
   {
      if(MathAbs(price - levels[i].price) < KeyLevelMinDistance)
         return true;
   }
   return false;
}

// MODULE 5.2: Key level strength calculation for breakout levels
double CalculateLevelStrength(const SKeyLevel &level)
{
   // Touch score with higher cap and weighted by touch quality
   double totalTouchStrength = 0;
   for(int i = 0; i < ArraySize(level.touches); i++)
      totalTouchStrength += level.touches[i].strength;
   
   double touchScore = MathMin(totalTouchStrength / MinTouchCount, 3.0);  // Increased cap to 3x
   
   // Recency score with adjusted decay
   datetime now = TimeCurrent();
   double hoursElapsed = (double)(now - level.lastTouch) / 3600.0;
   double recencyScore = MathExp(-hoursElapsed / (KeyLevelLookback * 12.0)); // Slower decay
   
   // Duration score with enhanced scaling
   double hoursDuration = (double)(level.lastTouch - level.firstTouch) / 3600.0;
   double normalizedDuration = hoursDuration / (double)MinLevelDurationHours;  // Fix conversion
   double durationScore = MathMin(1.0 + MathLog(normalizedDuration) / 1.5, 1.5);
   
   // Calculate weighted sum
   double strength = (touchScore * TouchScoreWeight + 
                     recencyScore * RecencyWeight + 
                     durationScore * DurationWeight);
   
   return strength;
}

// Add after the SKeyLevel struct definition
string GetKeyLevelLogFilename()
{
   string symbol = _Symbol;
   string timeframe = EnumToString(Period());
   
   // Create unique timestamp for this run
   static string runTimestamp = "";
   if(runTimestamp == "")
   {
      datetime currentTime = TimeCurrent();
      ulong microseconds = GetMicrosecondCount();
      MqlDateTime dt;
      TimeToStruct(currentTime, dt);
      runTimestamp = StringFormat("%04d%02d%02d_%02d%02d%02d_%06d", 
         dt.year, dt.mon, dt.day,
         dt.hour, dt.min, dt.sec,
         (int)(microseconds % 1000000));
      
      // *** FILENAME VERIFICATION ***
      Print("🔍 KEY LEVEL CSV TIMESTAMP CREATED: ", runTimestamp);
   }
   
   return "KeyLevels_" + symbol + "_" + timeframe + "_" + runTimestamp + ".csv";
}

void LogKeyLevel(const SKeyLevel &level, bool isAccepted, string rejectionReason="")
{
   if(!ShowDebugPrints) return;
   
   static datetime lastLogTime = 0;
   datetime now = TimeCurrent();
   
   // Only log every hour for accepted levels
   if(isAccepted && now - lastLogTime < 3600) return;
   
   // Only log rejections that are close to being accepted (strength > 0.58)
   if(!isAccepted && level.strength <= 0.58) return;
   
   // Update last log time for accepted levels
   if(isAccepted)
      lastLogTime = now;
   
   // Log to CSV file for detailed analysis (keep this for strategy optimization)
   // Pattern from: MQL5 Programming Reference
   // Reference: Write Data to CSV File section
   static bool headerWritten = false;
   string filename = GetKeyLevelLogFilename();
   
   if(!headerWritten)
   {
      int handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_COMMON);
      if(handle != INVALID_HANDLE)
      {
         Print("✅ NEW KEY LEVEL CSV CREATED: ", filename);
         FileWrite(handle, 
            "Timestamp",
            "Price",
            "Type",
            "TouchCount",
            "FirstTouch",
            "LastTouch",
            "DurationHours",
            "TouchScore",
            "RecencyScore",
            "DurationScore",
            "FinalStrength",
            "IsAccepted",
            "RejectionReason"
         );
         FileClose(handle);
         headerWritten = true;
      }
   }
   
   // Only print to journal if level is accepted
   if(isAccepted)
   {
      CV2EAUtils::LogSuccess(StringFormat("Key Level %s: %s @ %.5f | Strength: %.4f",
            (isAccepted ? "Accepted" : "Rejected"),
            level.isResistance ? "Resistance" : "Support",
            level.price,
            level.strength));
   }
   
   // Always write to CSV for complete analysis using official pattern
   int handle = FileOpen(filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);
   if(handle != INVALID_HANDLE)
   {
      FileSeek(handle, 0, SEEK_END);
      FileWrite(handle,
         TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES),
         DoubleToString(level.price, _Digits),
         level.isResistance ? "Resistance" : "Support",
         level.touchCount,
         TimeToString(level.firstTouch, TIME_DATE|TIME_MINUTES),
         TimeToString(level.lastTouch, TIME_DATE|TIME_MINUTES),
         (level.lastTouch - level.firstTouch) / 3600.0,
         level.touchScore,
         level.recencyScore,
         level.durationScore,
         level.strength,
         isAccepted ? "1" : "0",
         rejectionReason
      );
      FileClose(handle);
   }
}

// MODULE 5.3: Key level detection for breakout analysis
bool FindKeyLevels(SKeyLevel &outStrongestLevel)
{
   // Validate weights sum to 1.0
   if(MathAbs(TouchScoreWeight + RecencyWeight + DurationWeight - 1.0) > 0.001)
   {
      CV2EAUtils::LogError("Strength weights must sum to 1.0");
      return false;
   }

   // Copy arrays
   double highPrices[];
   double lowPrices[];
   double closePrices[];
   datetime times[];
   
   ArraySetAsSeries(highPrices, true);
   ArraySetAsSeries(lowPrices, true);
   ArraySetAsSeries(closePrices, true);
   ArraySetAsSeries(times, true);

   if(KeyLevelLookback < 3)
   {
      CV2EAUtils::LogError("KeyLevelLookback too small");
      return false;
   }

   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, KeyLevelLookback, highPrices) <= 0 ||
      CopyLow(_Symbol, PERIOD_CURRENT, 0, KeyLevelLookback, lowPrices) <= 0 ||
      CopyClose(_Symbol, PERIOD_CURRENT, 0, KeyLevelLookback, closePrices) <= 0 ||
      CopyTime(_Symbol, PERIOD_CURRENT, 0, KeyLevelLookback, times) <= 0)
   {
      CV2EAUtils::LogError("Failed to copy price data");
      return false;
   }

   SKeyLevel tempLevels[];
   int levelCount = 0;
   static datetime lastKeyLevelLog = 0;
   static double lastStrongestLevel = 0;
   static double lastStrongestStrength = 0;

   for(int i = 1; i < KeyLevelLookback - 1; i++)
   {
      // Check swing highs
      if(highPrices[i] > highPrices[i-1] && highPrices[i] > highPrices[i+1])
      {
         double level = highPrices[i];
         if(!IsNearExistingLevel(level, tempLevels, levelCount))
         {
            // Count touches within zone
            int touches = 0;
            datetime firstTouch = times[i];
            datetime lastTouch = times[i];
            
            for(int j = 0; j < KeyLevelLookback; j++)
            {
               if(MathAbs(highPrices[j] - level) <= TouchZoneSize ||
                  MathAbs(lowPrices[j] - level) <= TouchZoneSize)
               {
                  touches++;
                  if(times[j] < firstTouch) firstTouch = times[j];
                  if(times[j] > lastTouch) lastTouch = times[j];
               }
            }
            
            // Check minimum duration requirement
            double durationHours = (double)(lastTouch - firstTouch) / 3600.0;
            
            // Create temporary level for logging
            SKeyLevel tempLevel;
            tempLevel.price = level;
            tempLevel.touchCount = touches;
            tempLevel.isResistance = true;
            tempLevel.firstTouch = firstTouch;
            tempLevel.lastTouch = lastTouch;
            
            // Log rejection if minimum touches not met
            if(touches < MinTouchCount)
            {
               LogKeyLevel(tempLevel, false, 
                  StringFormat("Insufficient touches (%d < %d required)", 
                  touches, MinTouchCount));
               continue;
            }
            
            // Log rejection if duration too short
            if(durationHours < MinLevelDurationHours)
            {
               LogKeyLevel(tempLevel, false,
                  StringFormat("Duration too short (%.1f < %d hours required)",
                  durationHours, MinLevelDurationHours));
               continue;
            }
            
            double strength = CalculateLevelStrength(tempLevel);
            tempLevel.strength = strength;
            
            // Log rejection if strength too low
            if(strength < MinStrengthThreshold)
            {
               LogKeyLevel(tempLevel, false,
                  StringFormat("Strength too low (%.4f < %.2f required)",
                  strength, MinStrengthThreshold));
               continue;
            }
            
            // Level accepted - log and add to array
            LogKeyLevel(tempLevel, true);
            
            ArrayResize(tempLevels, levelCount + 1);
            tempLevels[levelCount] = tempLevel;
            levelCount++;
         }
      }
      
      // Swing low
      if(lowPrices[i] < lowPrices[i-1] && lowPrices[i] < lowPrices[i+1])
      {
         double level = lowPrices[i];
         if(!IsNearExistingLevel(level, tempLevels, levelCount))
         {
            // Count touches within zone
            int touches = 0;
            datetime firstTouch = times[i];
            datetime lastTouch = times[i];
            
            for(int j = 0; j < KeyLevelLookback; j++)
            {
               if(MathAbs(highPrices[j] - level) <= TouchZoneSize ||
                  MathAbs(lowPrices[j] - level) <= TouchZoneSize)
               {
                  touches++;
                  if(times[j] < firstTouch) firstTouch = times[j];
                  if(times[j] > lastTouch) lastTouch = times[j];
               }
            }
            
            // Check minimum duration requirement
            double durationHours = (double)(lastTouch - firstTouch) / 3600.0;
            
            // Create temporary level for logging
            SKeyLevel tempLevel;
            tempLevel.price = level;
            tempLevel.touchCount = touches;
            tempLevel.isResistance = false;
            tempLevel.firstTouch = firstTouch;
            tempLevel.lastTouch = lastTouch;
            
            // Log rejection if minimum touches not met
            if(touches < MinTouchCount)
            {
               LogKeyLevel(tempLevel, false, 
                  StringFormat("Insufficient touches (%d < %d required)", 
                  touches, MinTouchCount));
               continue;
            }
            
            // Log rejection if duration too short
            if(durationHours < MinLevelDurationHours)
            {
               LogKeyLevel(tempLevel, false,
                  StringFormat("Duration too short (%.1f < %d hours required)",
                  durationHours, MinLevelDurationHours));
               continue;
            }
            
            double strength = CalculateLevelStrength(tempLevel);
            tempLevel.strength = strength;
            
            // Log rejection if strength too low
            if(strength < MinStrengthThreshold)
            {
               LogKeyLevel(tempLevel, false,
                  StringFormat("Strength too low (%.4f < %.2f required)",
                  strength, MinStrengthThreshold));
               continue;
            }
            
            // Level accepted - log and add to array
            LogKeyLevel(tempLevel, true);
            
            ArrayResize(tempLevels, levelCount + 1);
            tempLevels[levelCount] = tempLevel;
            levelCount++;
         }
      }
   }
   
   // Update global key levels array
   ArrayResize(g_keyLevels, levelCount);
   for(int i = 0; i < levelCount; i++)
      g_keyLevels[i] = tempLevels[i];
   
   // Find strongest level
   if(levelCount > 0)
   {
      int strongestIdx = 0;
      double maxStrength = tempLevels[0].strength;
      
      for(int i = 1; i < levelCount; i++)
      {
         if(tempLevels[i].strength > maxStrength)
         {
            maxStrength = tempLevels[i].strength;
            strongestIdx = i;
         }
      }
      
      outStrongestLevel = tempLevels[strongestIdx];
      
      // Only log if:
      // 1. It's been at least 1 hour since last log, OR
      // 2. The strongest level has changed significantly (different price or strength change > 0.01)
      datetime now = TimeCurrent();
      bool significantChange = (MathAbs(outStrongestLevel.price - lastStrongestLevel) > 0.0001) ||
                             (MathAbs(outStrongestLevel.strength - lastStrongestStrength) > 0.01);
      
      if(ShowDebugPrints && (now - lastKeyLevelLog >= 3600 || significantChange))
      {
         CV2EAUtils::LogInfo(StringFormat("Strongest level found at %.5f Type: %s Strength: %.4f Touches: %d", 
               DoubleToString(outStrongestLevel.price, _Digits),
               (outStrongestLevel.isResistance ? "Resistance" : "Support"),
               outStrongestLevel.strength,
               outStrongestLevel.touchCount));
               
         lastKeyLevelLog = now;
         lastStrongestLevel = outStrongestLevel.price;
         lastStrongestStrength = outStrongestLevel.strength;
      }
      
      return true;
   }
   
   return false;
}

// MODULE 5.4: Volume filter check for breakout validation
bool DoesVolumeMeetRequirement(const long &volumes[], const int lookback)
{
   if(!UseVolumeFilter) 
      return true;

   // Use the market data class's volume check instead
   return CV2EAMarketData::DoesVolumeMeetRequirement(_Symbol, lookback);
}

// MODULE 5.5: ATR distance check for breakout validation
bool IsATRDistanceMet(const double currentClose, const double breakoutLevel)
{
   // If user does not want ATR distance check, skip
   if(!UseMinATRDistance)
      return true;

   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   
   // Use global ATR handle instead of creating new one
   if(g_handleATR == INVALID_HANDLE)
   {
      CV2EAUtils::LogWarning("Invalid ATR handle. Bypassing distance check.");
      return true;
   }

   if(CopyBuffer(g_handleATR, 0, 0, 1, atrBuf) <= 0)
   {
      CV2EAUtils::LogWarning("ATR copy failed. Bypassing distance check.");
      return true;
   }
   double currentATR    = atrBuf[0];
   double minBreakoutDist= currentATR * ATRMultiplier;

   // For bullish breakout: (currentClose - highestHigh)
   // For bearish breakout: (lowestLow - currentClose)
   double distance = MathAbs(currentClose - breakoutLevel);
   return (distance >= minBreakoutDist);
}

// MODULE 5.6: Main breakout detection and state initialization
bool DetectBreakoutAndInitRetest(double &outBreakoutLevel, bool &outBullish)
{
   static datetime lastDebugTime = 0;
   datetime now = TimeCurrent();
   bool shouldLog = (now - lastDebugTime >= 3600); // Log once per hour

   // CRITICAL: First check if we already have a position - if so, skip breakout detection entirely
   if(PositionsTotal() > 0)
   {
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(PositionGetSymbol(i) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
         {
            if(ShowDebugPrints && shouldLog)
               CV2EAUtils::LogError("Position already exists for this symbol and magic number");
            return false;  // Skip breakout detection if we have a position
         }
      }
   }

   // If we're in a lockout, check if price has truly formed a new breakout
   if(g_inLockout)
   {
      int currentBar = Bars(_Symbol, PERIOD_CURRENT) - 1;
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);  // Using bid for general price reference
      double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      // Calculate ATR-based threshold for minimum distance
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      double handle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
      double threshold = 50 * pointSize;  // Default to 50 pips if ATR fails
      
      if(CopyBuffer(handle, 0, 0, 1, atrBuf) > 0)
      {
         threshold = MathMax(atrBuf[0] * 2, 50 * pointSize);  // Use max of 2x ATR or 50 pips
      }
      
      // Check distance from last breakout zone
      double distanceFromLastBreak = MathAbs(currentPrice - g_activeBreakoutZonePrice);
      double distanceInPips = distanceFromLastBreak/pointSize;
      
      // Reset lockout if we're on a new bar AND have moved far enough from the zone
      if(currentBar > g_lastTradeBar && distanceFromLastBreak >= threshold)
      {
         if(ShowDebugPrints && shouldLog)
            CV2EAUtils::LogSuccess(StringFormat("Resetting lockout. Distance from zone: %.1f pips (required %.1f pips)", 
                  NormalizeDouble(distanceFromLastBreak/pointSize, 1), NormalizeDouble(threshold/pointSize, 1)));
         g_inLockout = false;
         g_activeBreakoutZonePrice = 0.0;  // Clear the active zone
      }
      else
      {
         if(ShowDebugPrints && shouldLog)
         {
            CV2EAUtils::LogWarning(StringFormat("Still within lockout zone. Distance: %.1f pips (need %.1f pips)", 
                  NormalizeDouble(distanceInPips, 1), NormalizeDouble(threshold/pointSize, 1)));
         }
         return false;
      }
   }

   // Find key levels first
   SKeyLevel strongestLevel;
   if(!FindKeyLevels(strongestLevel))
   {
      if(ShowDebugPrints && shouldLog)
      {
         CV2EAUtils::LogInfo("No valid key levels found");
         lastDebugTime = now;
      }
      return false;
   }

   // Update optimization metrics for level strength
   g_avgStrength = (g_avgStrength * g_totalBreakouts + strongestLevel.strength) / (g_totalBreakouts + 1);
   g_totalBreakouts++;

   // Prepare data arrays
   double highPrices[];
   double lowPrices[];
   double closePrices[];
   long   volumes[];

   ArraySetAsSeries(highPrices,true);
   ArraySetAsSeries(lowPrices,true);
   ArraySetAsSeries(closePrices,true);
   ArraySetAsSeries(volumes,true);

   int bars_to_copy = BreakoutLookback + 2; 
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, bars_to_copy, highPrices) <= 0 ||
      CopyLow(_Symbol, PERIOD_CURRENT, 0, bars_to_copy, lowPrices) <= 0 ||
      CopyClose(_Symbol, PERIOD_CURRENT, 0, bars_to_copy, closePrices) <= 0 ||
      ((VolumeType == VOLUME_REAL && CopyRealVolume(_Symbol, PERIOD_CURRENT, 0, bars_to_copy, volumes) <= 0) ||
       (VolumeType == VOLUME_TICK && CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, bars_to_copy, volumes) <= 0)))
   {
      CV2EAUtils::LogError("Failed to copy price or volume data. Err=" + GetLastError());
      return false;
   }

   // Use last closed candle to confirm the breakout
   double lastClose = closePrices[1];
   double pipPoint  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   bool volumeOK     = DoesVolumeMeetRequirement(volumes, BreakoutLookback);
   bool bullishBreak = (lastClose > (strongestLevel.price + pipPoint));
   bool bearishBreak = (lastClose < (strongestLevel.price - pipPoint));

   // Enhanced logging for optimization
   if(ShowDebugPrints)
   {
      string breakoutStats = StringFormat(
         "BREAKOUT_STATS\t%s\t%.5f\t%s\t%.4f\t%s\t%s\t%d\t%d\t%.2f",
         TimeToString(now),
         strongestLevel.price,
         (bullishBreak ? "BULL" : (bearishBreak ? "BEAR" : "NONE")),
         strongestLevel.strength,
         (volumeOK ? "1" : "0"),
         (IsATRDistanceMet(lastClose, strongestLevel.price) ? "1" : "0"),
         strongestLevel.touchCount,
         g_totalBreakouts,
         g_avgStrength
      );
      
      // Store last stats and log to file
      g_lastBreakoutStats = breakoutStats;
      
      // Create unique optimization log filename using centralized function
      static string optimizationLogFile = "";
      if(optimizationLogFile == "")
      {
         optimizationLogFile = GetOptimizationLogFilename();
         Print("🔍 OPTIMIZATION LOG FILENAME: ", optimizationLogFile);
      }
      
      // Pattern from: MQL5 Programming Reference
      // Reference: Write Data to CSV File section
      static bool optimizationLogInitialized = false;
      
      if(!optimizationLogInitialized)
      {
         // First time: create new file with header
         int handle = FileOpen(optimizationLogFile, FILE_WRITE|FILE_TXT|FILE_COMMON);
         if(handle != INVALID_HANDLE)
         {
            Print("✅ NEW OPTIMIZATION LOG CREATED: ", optimizationLogFile);
            FileWriteString(handle, "# V-2-EA Optimization Log - " + TimeToString(TimeCurrent()) + "\n");
            FileWriteString(handle, "# Timestamp\tPrice\tDirection\tStrength\tVolumeOK\tATROK\tTouchCount\tTotalBreakouts\tAvgStrength\n");
            FileWriteString(handle, breakoutStats + "\n");
            FileClose(handle);
            optimizationLogInitialized = true;
         }
      }
      else
      {
         // Subsequent times: append to existing file using standard pattern
         int handle = FileOpen(optimizationLogFile, FILE_READ|FILE_WRITE|FILE_TXT|FILE_COMMON);
         if(handle != INVALID_HANDLE)
         {
            FileSeek(handle, 0, SEEK_END);
            FileWriteString(handle, breakoutStats + "\n");
            FileClose(handle);
         }
      }
   }

   // Bullish breakout
   if(bullishBreak && volumeOK && IsATRDistanceMet(lastClose, strongestLevel.price))
   {
      g_validBreakouts++;
      outBreakoutLevel = strongestLevel.price;
      outBullish = true;

      if(UseRetest)
      {
         g_breakoutState.breakoutTime = TimeCurrent();
         g_breakoutState.breakoutLevel = strongestLevel.price;
         g_breakoutState.isBullish = true;
         g_breakoutState.awaitingRetest = true;
         g_breakoutState.barsWaiting = 0;
         g_breakoutState.retestStartTime = TimeCurrent();
         g_breakoutState.retestStartBar = iBarShift(_Symbol, _Period, TimeCurrent(), false);
         return false;
      }
      return true;
   }

   // Bearish breakout
   if(bearishBreak && volumeOK && IsATRDistanceMet(strongestLevel.price, lastClose))
   {
      g_validBreakouts++;
      outBreakoutLevel = strongestLevel.price;
      outBullish = false;

      if(UseRetest)
      {
         g_breakoutState.breakoutTime = TimeCurrent();
         g_breakoutState.breakoutLevel = strongestLevel.price;
         g_breakoutState.isBullish = false;
         g_breakoutState.awaitingRetest = true;
         g_breakoutState.barsWaiting = 0;
         g_breakoutState.retestStartTime = TimeCurrent();
         g_breakoutState.retestStartBar = iBarShift(_Symbol, _Period, TimeCurrent(), false);
         return false;
      }
      return true;
   }

   // If we detected a breakout but filters failed, count as false breakout
   if(bullishBreak || bearishBreak)
   {
      g_falseBreakouts++;
   }

   return false;
}

//==================================================================
// MODULE 6: RETEST VALIDATION
// Purpose: Validates price retest of breakout levels
// Components:
// - Candlestick pattern analysis
// - Retest zone validation
// - Time-based retest constraints
// - Retest confirmation logic
//==================================================================

// MODULE 6.1: Candlestick Pattern Analysis
// Purpose: Validates candlestick patterns for retest confirmation
// Components:
// - Engulfing pattern detection
// - Pattern direction validation
// - Candle body comparison
bool CheckEngulfingPattern(const bool bullish)
{
   // We'll copy two candles from the specified retest timeframe
   MqlRates rates[2];
   ArraySetAsSeries(rates, true);

   if(CopyRates(_Symbol, RetestTimeframe, 0, 2, rates) < 2)
   {
      CV2EAUtils::LogError("Failed fetching candlestick data for retest timeframe. Err=" + GetLastError());
      return false;
   }

   // Candle indices: rates[0] is the current not-yet-closed candle, rates[1] is the fully closed candle before it.
   // For an engulfing pattern, we need 2 fully closed candles. So normally we'd look at rates[1] and rates[2].
   // But for simplicity, let's assume the last two fully closed candles are rates[1] and rates[2].
   // We'll shift references accordingly if needed.

   // Minimal approach: treat rates[1] as the last closed candle and rates[2] as the one before that.
   // Adjust our copy logic to grab 3 bars so we can see them:
   MqlRates lastTwo[3];
   ArraySetAsSeries(lastTwo, true);
   if(CopyRates(_Symbol, RetestTimeframe, 0, 3, lastTwo) < 3)
      return false;

   // Renaming for clarity
   double open1  = lastTwo[2].open;  // older candle
   double close1 = lastTwo[2].close;
   double open2  = lastTwo[1].open;  // most recent fully closed candle
   double close2 = lastTwo[1].close;

   if(bullish)
   {
      // Check if first candle is bearish and second candle is bullish
      bool candle1Bearish = (close1 < open1);
      bool candle2Bullish = (close2 > open2);

      // Check if Candle2 fully engulfs Candle1 body
      // i.e., Candle2's body covers Candle1's open-to-close range
      bool bodyEngulf = (close2 > open1 && open2 < close1);

      if(candle1Bearish && candle2Bullish && bodyEngulf)
         return true;
   }
   else
   {
      // Bearish engulfing
      bool candle1Bullish = (close1 > open1);
      bool candle2Bearish = (close2 < open2);

      bool bodyEngulf = (close2 < open1 && open2 > close1);

      if(candle1Bullish && candle2Bearish && bodyEngulf)
         return true;
   }

   return false;
}

// MODULE 6.2.1: Retest Zone Price Check
// Purpose: Validates if current price is within retest zone
// Components:
// - ATR-based zone calculation
// - Fixed pip threshold fallback
// - Zone boundary validation
bool IsPriceInRetestZone()
{
   if(!g_breakoutState.awaitingRetest)
      return false;
      
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);  // Use bid for general price reference
   double breakoutLevel = g_breakoutState.breakoutLevel;
   double zoneSize = 0.0;
   
   // Get ATR-based zone size
   if(g_handleATR != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(g_handleATR, 0, 0, 1, atrBuf) > 0)
      {
         zoneSize = atrBuf[0] * RetestATRMultiplier;
      }
   }
   
   // If ATR is not available or too small, use RetestPipsThreshold
   double pipsZoneSize = RetestPipsThreshold * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(zoneSize < pipsZoneSize)
   {
      zoneSize = pipsZoneSize;
      CV2EAUtils::LogInfo("Using pips-based zone size: " + RetestPipsThreshold + " pips");
   }
   
   // Calculate if price is in zone
   bool inZone = (currentPrice >= breakoutLevel - zoneSize && 
                  currentPrice <= breakoutLevel + zoneSize);
                  
   if(ShowDebugPrints && inZone)
   {
      CV2EAUtils::LogSuccess(StringFormat("Price in %s retest zone. Price=%.5f Zone=%.5f to %.5f (%.1f pips)",
            (g_breakoutState.isBullish ? "bullish" : "bearish"),
            currentPrice,
            breakoutLevel-zoneSize,
            breakoutLevel+zoneSize,
            NormalizeDouble(zoneSize/SymbolInfoDouble(_Symbol, SYMBOL_POINT), 1)));
   }
   
   return inZone;
}

// MODULE 6.3: Position State Management
// Purpose: Centralized position tracking and state management
// Components:
// - Position existence check
// - Magic number validation
// - Global state maintenance
bool HasOpenPosition()
{
   if(PositionsTotal() > 0)
   {
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(PositionGetSymbol(i) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
         {
            g_hasPositionOpen = true;  // Update global state
            return true;
         }
      }
   }
   g_hasPositionOpen = false;  // Update global state
   return false;
}

// MODULE 6.4: Retest Validation
// Purpose: Comprehensive retest condition validation
// Components:
// - Time-based validation
// - Bar count validation
// - Position conflict check
// - Zone price validation
bool ValidateRetestConditions()
{
   // If user does not want retest, skip it entirely
   if(!UseRetest)
      return true;

   // If there's no breakout awaiting a retest, nothing to do
   if(!g_breakoutState.awaitingRetest)
   {
      CV2EAUtils::LogInfo("No breakout awaiting retest");
      return true;
   }

   // Check for existing position
   if(HasOpenPosition())
   {
      CV2EAUtils::LogError("Position already exists");
      g_breakoutState.awaitingRetest = false;  // Reset retest state
      return false;
   }

   // Rest of the existing validation logic...
   double elapsedSeconds = (TimeCurrent() - g_breakoutState.retestStartTime);
   double elapsedMinutes = elapsedSeconds / 60.0;
   
   int currentBar = iBarShift(_Symbol, _Period, TimeCurrent(), false);
   int barsElapsed = g_breakoutState.retestStartBar - currentBar;
   
   if(elapsedMinutes >= MaxRetestMinutes || barsElapsed >= MaxRetestBars)
   {
      CV2EAUtils::LogError(StringFormat("Retest timed out after %.2f minutes and %d bars",
                    elapsedMinutes, barsElapsed));
      g_breakoutState.awaitingRetest = false;
      return false;
   }
   
   return IsPriceInRetestZone();
}

//==================================================================
// MODULE 7: RISK MANAGEMENT
// Purpose: Position sizing and risk control
// Components:
// - Dynamic lot size calculation
// - Account risk percentage handling
// - Broker-specific adjustments
//==================================================================

// MODULE 7.1: Position Sizing
// Purpose: Risk-based position size calculation
// Components:
// - Account balance analysis
// - Risk percentage application
// - Broker constraint handling
// - Lot size normalization
double CalculateLotSize(double stopLossPrice, double entryPrice, double riskPercent)
{
   // 1. Determine the account balance and risk in currency terms
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (riskPercent / 100.0);

   // 2. Calculate stop loss distance in points
   double stopDistancePoints = MathAbs(entryPrice - stopLossPrice) / _Point;
   
   // 3. Get tick value in account currency
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickValue == 0)
   {
      CV2EAUtils::LogWarning("Zero tick value, using minimum lot as fallback");
      return 0.01; // Return minimum lot as fallback
   }

   // 4. Calculate potential loss per lot
   double potentialLossPerLot = stopDistancePoints * tickValue;
   if(potentialLossPerLot == 0)
   {
      CV2EAUtils::LogWarning("Zero loss per lot calculation, using minimum lot as fallback");
      return 0.01;
   }

   // 5. Calculate initial lots based on risk amount
   double lots = riskAmount / potentialLossPerLot;

   // 6. Adjust for broker's constraints
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   // Round down to nearest valid lot step
   lots = MathFloor(lots / lotStep) * lotStep;

   // Enforce boundaries
   lots = MathMax(minLot, MathMin(maxLot, lots));

   // 7. Calculate margin requirements for both BUY and SELL
   double marginBuy = 0.0, marginSell = 0.0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lots, entryPrice, marginBuy) ||
      !OrderCalcMargin(ORDER_TYPE_SELL, _Symbol, lots, entryPrice, marginSell))
   {
      CV2EAUtils::LogWarning("Failed to calculate margin, using minimum lot as fallback");
      return minLot;
   }

   // Use the higher margin requirement
   double margin = MathMax(marginBuy, marginSell);

   // Get available margin and apply a safety factor
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double safetyMargin = freeMargin * 0.8; // Only use 80% of free margin
   
   // If margin requirement exceeds safe margin, reduce lot size
   if(margin > safetyMargin)
   {
      // Calculate maximum lots based on available margin with safety factor
      double maxLotsMargin = lots * (safetyMargin / margin);
      // Round down to nearest lot step
      maxLotsMargin = MathFloor(maxLotsMargin / lotStep) * lotStep;
      // Ensure minimum lot size
      lots = MathMax(minLot, maxLotsMargin);
      
      CV2EAUtils::LogWarning(StringFormat("Reduced lot size due to margin requirements. Original: %f New: %f Margin Required: %f Free Margin: %f Safe Margin: %f", 
               lots, maxLotsMargin, margin, freeMargin, safetyMargin));
   }

   // Final check - recalculate margin for new lot size
   if(!OrderCalcMargin(ORDER_TYPE_SELL, _Symbol, lots, entryPrice, margin))
   {
      CV2EAUtils::LogWarning("Final margin check failed, using minimum lot as fallback");
      return minLot;
   }

   // If still not enough margin, return minimum lot
   if(margin > freeMargin)
   {
      CV2EAUtils::LogWarning("Still insufficient margin, using minimum lot as fallback");
      return minLot;
   }

   CV2EAUtils::LogSuccess(StringFormat("Risk=%f%%, Balance=%f, Stop Distance=%f points, Calculated Lots=%f, Margin Required=%f, Free Margin=%f, Safe Margin: %f", 
            riskPercent, accountBalance, stopDistancePoints, lots, margin, freeMargin, safetyMargin));

   return lots;
}

//==================================================================
// MODULE 8: ORDER MANAGEMENT
// Purpose: Trade execution and order handling
// Components:
// - Trade placement with SL/TP
// - Pivot-based SL/TP calculation
// - Order validation and safety checks
// - Multi-entry filter logic
//==================================================================

// MODULE 8.1: Trade Execution
// Purpose: Order placement and validation
// Components:
// - Price normalization
// - SL/TP validation
// - Order type handling
// - Trade placement confirmation
bool PlaceTrade(bool isBullish, double entryPrice, double slPrice, double tpPrice, double lots)
{
   trade.SetExpertMagicNumber(g_magicNumber);

   double point                = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits               = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double minStopDistPoints    = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double fallbackStopDistance = 5 * minStopDistPoints; // or some multiplier

   // Normalize prices
   entryPrice = NormalizeDouble(entryPrice, digits);
   slPrice    = NormalizeDouble(slPrice, digits);
   tpPrice    = NormalizeDouble(tpPrice, digits);

   // For a buy, SL must be below entry and above zero
   if(isBullish)
   {
      // 1) If SL >= entryPrice, try to get a new pivot-based SL
      if(slPrice >= entryPrice)
      {
         double pivot, r1, r2, s1, s2;
         if(GetDailyPivotPoints(pivot, r1, r2, s1, s2))
         {
            // Try to use S1 as SL for a buy
            slPrice = MathMin(s1, entryPrice - fallbackStopDistance);
         }
         else
         {
            CV2EAUtils::LogWarning("SL invalid and pivot calculation failed, using fallback distance");
            slPrice = entryPrice - fallbackStopDistance;
         }
      }

      // 2) If SL still invalid, use fallback
      if(slPrice <= point || slPrice >= entryPrice)
      {
         CV2EAUtils::LogWarning("Invalid SL for Buy, using fallback distance");
         slPrice = entryPrice - fallbackStopDistance;
      }
   }
   else // Sell
   {
      // 1) If SL <= entryPrice, try to get a new pivot-based SL
      if(slPrice <= entryPrice)
      {
         double pivot, r1, r2, s1, s2;
         if(GetDailyPivotPoints(pivot, r1, r2, s1, s2))
         {
            // Try to use R1 as SL for a sell
            slPrice = MathMax(r1, entryPrice + fallbackStopDistance);
         }
         else
         {
            CV2EAUtils::LogWarning("SL invalid and pivot calculation failed, using fallback distance");
            slPrice = entryPrice + fallbackStopDistance;
         }
      }

      // 2) If SL still invalid, use fallback
      if(slPrice <= point || slPrice <= entryPrice)
      {
         CV2EAUtils::LogWarning("Invalid SL for Sell, using fallback distance");
         slPrice = entryPrice + fallbackStopDistance;
      }
   }

   // Re-normalize after any adjustments
   slPrice = NormalizeDouble(slPrice, digits);
   tpPrice = NormalizeDouble(tpPrice, digits);

   // Final logging
   CV2EAUtils::LogSuccess(StringFormat("Placing %s | lots=%f | entry=%f | SL=%f | TP=%f",
            (isBullish ? "Buy" : "Sell"), lots, entryPrice, slPrice, tpPrice));

   bool result = isBullish 
               ? trade.Buy(lots, _Symbol, 0, slPrice, tpPrice, "Breakout-Buy")
               : trade.Sell(lots, _Symbol, 0, slPrice, tpPrice, "Breakout-Sell");

   if(!result)
   {
      CV2EAUtils::LogError("Order failed. Error=" + GetLastError());
      return false;
   }

   // Update multi-entry filter state after successful trade
   g_lastTradeTime = TimeCurrent();
   g_lastTradeBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);  // Record the opening time of the current bar
   g_lastTradeBar = Bars(_Symbol, PERIOD_CURRENT) - 1;  // Current bar index
   g_activeBreakoutZonePrice = entryPrice;
   g_activeBreakoutDirection = isBullish;
   g_inLockout = true;

   CV2EAUtils::LogSuccess(StringFormat("Multi-entry filter state updated: Bar=%d BarTime=%s Level=%f Direction=%s", 
            g_lastTradeBar, TimeToString(g_lastTradeBarTime, TIME_DATE|TIME_MINUTES), 
            g_activeBreakoutZonePrice, (isBullish ? "Buy" : "Sell")));

   CV2EAUtils::LogSuccess("Order placed at price=" + trade.ResultPrice());
   return true;
}


// -------------------------------------------------------------------
// DAILY PIVOT LOGIC
// -------------------------------------------------------------------
/*
   These two helper functions retrieve the last closed daily bar
   to compute pivot points, then apply them as SL/TP in your
   order-management logic (M8.1.a, etc.).
*/

// MODULE 8.2: Daily Pivot Points
// Purpose: Calculate daily pivot levels
// Components:
// - Previous day OHLC processing
// - Pivot point calculation
// - Support/Resistance level derivation
bool GetDailyPivotPoints(double &pivot, double &r1, double &r2, double &s1, double &s2)
{
   // Make sure we have enough data
   MqlRates dailyRates[];
   ArraySetAsSeries(dailyRates, true);

   // We copy 2 bars from the daily timeframe: [0] is current day, [1] is the last closed day
   if(CopyRates(_Symbol, PERIOD_D1, 0, 2, dailyRates) < 2)
   {
      CV2EAUtils::LogError("Unable to copy daily bars. Error=" + GetLastError());
      return false;
   }

   // The bar at index [1] is the most recently closed daily bar
   double prevDayHigh  = dailyRates[1].high;
   double prevDayLow   = dailyRates[1].low;
   double prevDayClose = dailyRates[1].close;

   // Standard pivot point formulas:
   pivot = (prevDayHigh + prevDayLow + prevDayClose) / 3.0;
   r1    = 2.0 * pivot - prevDayLow;
   s1    = 2.0 * pivot - prevDayHigh;
   r2    = pivot + (r1 - s1);
   s2    = pivot - (r1 - s1);

   return true;
}

// 2) Main function to apply pivot points for SL/TP
bool ApplyDailyPivotSLTP(bool isBullish, double &priceEntry, double &priceSL, double &priceTP)
{
   double pivot=0, r1=0, r2=0, s1=0, s2=0;
   if(!GetDailyPivotPoints(pivot, r1, r2, s1, s2))
   {
      CV2EAUtils::LogWarning("Unable to compute daily pivots. Using defaults.");
      return false;
   }

   // Decide which pivot levels to use
   bool useWiderLevels = IsHighVolatilityOrBusySession(); // from Step 2

   if(isBullish)
   {
      if(useWiderLevels)
      {
         // Wider stops in high-volatility sessions
         priceSL = MathMin(s1, s2); // Could use s2 if you prefer the very wide level
         priceTP = r2;             // Target r2 for bigger reward
      }
      else
      {
         // Normal or quieter session
         priceSL = s1;            
         priceTP = r1;            
      }
   }
   else // Bearish
   {
      if(useWiderLevels)
      {
         priceSL = MathMax(r1, r2);
         priceTP = s2;
      }
      else
      {
         priceSL = r1;
         priceTP = s1;
      }
   }

   // Safety checks
   double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(isBullish)
   {
      if(priceSL >= priceEntry)
         priceSL = priceEntry - (50 * pointSize);
      if(priceTP <= priceEntry)
         priceTP = priceEntry + (100 * pointSize);
   }
   else
   {
      if(priceSL <= priceEntry)
         priceSL = priceEntry + (50 * pointSize);
      if(priceTP >= priceEntry)
         priceTP = priceEntry - (100 * pointSize);
   }

   return true;
}

//==================================================================
// MODULE 9: STRATEGY EXECUTION
// Purpose: Main strategy logic and trade execution flow
// Components:
// - Daily pivot calculation
// - Breakout-retest execution
// - Position management
// - Strategy state transitions
//==================================================================

// MODULE 9.1: Pivot Level Calculation
// Purpose: Daily pivot point computation
// Components:
// - Historical data retrieval
// - Classic pivot formula application
// - Support/Resistance calculation
void CalculateDailyPivots(string symbol, double &pivotPoint, double &r1, double &r2, double &s1, double &s2)
{
   MqlRates dailyData[];
   // We'll look at the previous daily bar (index=1).
   if(CopyRates(symbol, PERIOD_D1, 1, 2, dailyData) < 2)
   {
      CV2EAUtils::LogWarning("Can't fetch daily bar data. Using fallback values.");
      pivotPoint = 0.0;
      r1 = r2 = s1 = s2 = 0.0;
      return;
   }

   double highVal  = dailyData[1].high;
   double lowVal   = dailyData[1].low;
   double closeVal = dailyData[1].close;

   // Classic pivot formula
   pivotPoint = (highVal + lowVal + closeVal) / 3.0;
   r1 = 2.0 * pivotPoint - lowVal;         // Resistance 1
   s1 = 2.0 * pivotPoint - highVal;        // Support 1
   r2 = pivotPoint + (r1 - s1);            // Resistance 2
   s2 = pivotPoint - (r1 - s1);            // Support 2
}

// MODULE 9.2: Stop Loss and Take Profit Management
// Purpose: Dynamic SL/TP level calculation
// Components:
// - ATR-based distance calculation
// - Pivot point integration
// - Minimum distance enforcement
// - Broker requirement compliance
void SetPivotSLTP(bool isBuy, double currentPrice, double &slPrice, double &tpPrice)
{
   // Initialize with safe defaults
   slPrice = 0.0;
   tpPrice = 0.0;
   
   // Get ATR value first as we need it for both methods
   double atrValue = 0.0;
   if(g_handleATR != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(g_handleATR, 0, 0, 1, atrBuf) > 0)
      {
         atrValue = atrBuf[0];
      }
   }

   // If we can't get ATR, use a fallback based on point size
   if(atrValue <= 0.0)
   {
      atrValue = 50 * SymbolInfoDouble(_Symbol, SYMBOL_POINT); // Default to 50 points
      CV2EAUtils::LogWarning("Using fallback ATR value of " + atrValue);
   }

   // Calculate ATR-based distances
   double atrStopDistance = atrValue * SLMultiplier;
   double atrTpDistance = atrValue * TPMultiplier;

   // Get pivot points
   double pivot, r1, r2, s1, s2;
   bool havePivots = false;
   
   CalculateDailyPivots(_Symbol, pivot, r1, r2, s1, s2);
   havePivots = (pivot > 0.0);

   // Set SL/TP based on direction
   if(isBuy)
   {
      if(havePivots)
      {
         // Use the tighter of pivot-based or ATR-based SL
         slPrice = MathMax(MathMin(s1, currentPrice - atrStopDistance), 
                          currentPrice - (2 * atrStopDistance)); // Maximum 2x ATR stop
         
         // Use the further of pivot-based or ATR-based TP
         tpPrice = MathMax(r2, currentPrice + atrTpDistance);
      }
      else
      {
         // Pure ATR-based levels
         slPrice = currentPrice - atrStopDistance;
         tpPrice = currentPrice + atrTpDistance;
      }
   }
   else
   {
      if(havePivots)
      {
         // Use the tighter of pivot-based or ATR-based SL
         slPrice = MathMin(MathMax(r1, currentPrice + atrStopDistance),
                          currentPrice + (2 * atrStopDistance)); // Maximum 2x ATR stop
         
         // Use the further of pivot-based or ATR-based TP
         tpPrice = MathMin(s2, currentPrice - atrTpDistance);
      }
      else
      {
         // Pure ATR-based levels
         slPrice = currentPrice + atrStopDistance;
         tpPrice = currentPrice - atrTpDistance;
      }
   }
   
   // Ensure minimum broker distance requirements
   double minDistance = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * 
                       SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(isBuy)
   {
      if(currentPrice - slPrice < minDistance)
         slPrice = currentPrice - minDistance;
      if(tpPrice - currentPrice < minDistance)
         tpPrice = currentPrice + minDistance;
   }
   else
   {
      if(slPrice - currentPrice < minDistance)
         slPrice = currentPrice + minDistance;
      if(currentPrice - tpPrice < minDistance)
         tpPrice = currentPrice - minDistance;
   }

   // Final validation
   if(slPrice <= 0.0 || tpPrice <= 0.0)
   {
      CV2EAUtils::LogError("Invalid SL/TP calculation. SL=" + slPrice + " TP=" + tpPrice);
      return;
   }

   CV2EAUtils::LogSuccess(StringFormat("Levels set - Method: %s SL=%f pips TP=%f pips Risk:Reward=%f",
            (havePivots ? "Pivot+ATR" : "Pure ATR"),
            NormalizeDouble(MathAbs(currentPrice - slPrice)/SymbolInfoDouble(_Symbol, SYMBOL_POINT), 1),
            NormalizeDouble(MathAbs(currentPrice - tpPrice)/SymbolInfoDouble(_Symbol, SYMBOL_POINT), 1),
            NormalizeDouble(MathAbs(currentPrice - tpPrice)/MathAbs(currentPrice - slPrice), 2)));
}

//==================================================================
// MODULE 9.1: ENHANCED POSITION MANAGEMENT
// Purpose: Comprehensive position management with advanced features
// Components:
// - Trailing stops with key level awareness
// - Breakeven moves based on key levels
// - Partial profit taking at key levels
// - Dynamic stop loss adjustment
//==================================================================

// Global position management state
struct SPositionState
{
    bool hasPosition;
    bool isBuy;
    double entryPrice;
    double currentSL;
    double currentTP;
    double lotSize;
    datetime entryTime;
    double highestPrice;    // For buy positions
    double lowestPrice;     // For sell positions
    bool breakevenActivated;
    bool partialTaken;
    double keyLevelEntryPrice; // The key level that triggered entry
    ulong positionTicket;
    
    void Reset()
    {
        hasPosition = false;
        isBuy = false;
        entryPrice = 0;
        currentSL = 0;
        currentTP = 0;
        lotSize = 0;
        entryTime = 0;
        highestPrice = 0;
        lowestPrice = DBL_MAX;
        breakevenActivated = false;
        partialTaken = false;
        keyLevelEntryPrice = 0;
        positionTicket = 0;
    }
} g_positionState;

// Position management parameters
input double TrailingStopPips = 30.0;      // Trailing stop distance in pips
input double BreakevenTriggerPips = 20.0;  // Profit threshold to move to breakeven
input double PartialTakeProfitRatio = 0.5; // Take 50% profit at first key level
input bool UseKeyLevelTrailing = true;     // Use key levels for trailing stops
input bool UseBreakevenMove = true;        // Enable breakeven functionality
input bool UsePartialTakeProfit = true;    // Enable partial profit taking

// MODULE 9.1.1: Update Position State
void UpdatePositionState()
{
    g_positionState.hasPosition = false;
    
    if(PositionsTotal() > 0)
    {
        for(int i = 0; i < PositionsTotal(); i++)
        {
            if(PositionGetSymbol(i) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
            {
                g_positionState.hasPosition = true;
                g_positionState.isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
                g_positionState.entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                g_positionState.currentSL = PositionGetDouble(POSITION_SL);
                g_positionState.currentTP = PositionGetDouble(POSITION_TP);
                g_positionState.lotSize = PositionGetDouble(POSITION_VOLUME);
                g_positionState.entryTime = (datetime)PositionGetInteger(POSITION_TIME);
                g_positionState.positionTicket = PositionGetInteger(POSITION_TICKET);
                
                // Update price extremes for trailing
                double currentPrice = g_positionState.isBuy ? 
                    SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                    SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                
                if(g_positionState.isBuy)
                {
                    g_positionState.highestPrice = MathMax(g_positionState.highestPrice, currentPrice);
                }
                else
                {
                    g_positionState.lowestPrice = MathMin(g_positionState.lowestPrice, currentPrice);
                }
                
                g_hasPositionOpen = true;
                return;
            }
        }
    }
    
    // No position found - reset state
    if(g_positionState.hasPosition)
    {
        CV2EAUtils::LogSuccess("Position closed - resetting state");
        g_positionState.Reset();
    }
    g_hasPositionOpen = false;
}

// MODULE 9.1.2: Key Level Based Trailing
double CalculateKeyLevelTrailingStop(bool isBuy, double currentPrice)
{
    if(!UseKeyLevelTrailing) return 0;
    
    // Get current key levels from breakout strategy
    SKeyLevel supportLevel, resistanceLevel;
    bool foundSupport = false, foundResistance = false;
    
    // Find nearest key levels
    double nearestSupport = 0, nearestResistance = DBL_MAX;
    
    for(int i = 0; i < breakoutStrategy.TEST_GetKeyLevelCount(); i++)
    {
        SKeyLevel level;
        if(breakoutStrategy.TEST_GetKeyLevel(i, level))
        {
            if(level.isResistance && level.price > currentPrice)
            {
                if(level.price < nearestResistance)
                {
                    nearestResistance = level.price;
                    resistanceLevel = level;
                    foundResistance = true;
                }
            }
            else if(!level.isResistance && level.price < currentPrice)
            {
                if(level.price > nearestSupport)
                {
                    nearestSupport = level.price;
                    supportLevel = level;
                    foundSupport = true;
                }
            }
        }
    }
    
    double keyLevelSL = 0;
    double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if(SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 3 || SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 5)
        pipSize *= 10;
    
    if(isBuy && foundSupport)
    {
        // For buy positions, use support level minus buffer as trailing stop
        keyLevelSL = supportLevel.price - (10 * pipSize); // 10 pip buffer below support
        
        if(ShowDebugPrints)
        {
            CV2EAUtils::LogInfo(StringFormat("Key level trailing - Buy position: Support %.5f, SL %.5f", 
                supportLevel.price, keyLevelSL));
        }
    }
    else if(!isBuy && foundResistance)
    {
        // For sell positions, use resistance level plus buffer as trailing stop
        keyLevelSL = resistanceLevel.price + (10 * pipSize); // 10 pip buffer above resistance
        
        if(ShowDebugPrints)
        {
            CV2EAUtils::LogInfo(StringFormat("Key level trailing - Sell position: Resistance %.5f, SL %.5f", 
                resistanceLevel.price, keyLevelSL));
        }
    }
    
         return keyLevelSL;
}

// MODULE 9.1.2b: Key Level Based Profit Targets
double CalculateKeyLevelProfitTarget(bool isBuy, double currentPrice, double entryPrice)
{
    if(!UseKeyLevelTrailing) return 0;
    
    double bestTarget = 0;
    double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if(SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 3 || SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 5)
        pipSize *= 10;
    
    // Find the next key level in profit direction
    for(int i = 0; i < breakoutStrategy.TEST_GetKeyLevelCount(); i++)
    {
        SKeyLevel level;
        if(breakoutStrategy.TEST_GetKeyLevel(i, level))
        {
            if(isBuy && level.isResistance && level.price > currentPrice)
            {
                // For buy positions, look for resistance levels above current price
                double distance = level.price - entryPrice;
                if(distance > 20 * pipSize) // At least 20 pips profit potential
                {
                    if(bestTarget == 0 || level.price < bestTarget)
                    {
                        bestTarget = level.price - (5 * pipSize); // Target 5 pips before resistance
                    }
                }
            }
            else if(!isBuy && !level.isResistance && level.price < currentPrice)
            {
                // For sell positions, look for support levels below current price
                double distance = entryPrice - level.price;
                if(distance > 20 * pipSize) // At least 20 pips profit potential
                {
                    if(bestTarget == 0 || level.price > bestTarget)
                    {
                        bestTarget = level.price + (5 * pipSize); // Target 5 pips above support
                    }
                }
            }
        }
    }
    
    if(bestTarget > 0 && ShowDebugPrints)
    {
        CV2EAUtils::LogInfo(StringFormat("Key level profit target: %.5f (%.1f pips from entry)",
            bestTarget, MathAbs(bestTarget - entryPrice) / pipSize));
    }
    
    return bestTarget;
}

// MODULE 9.1.3: Comprehensive Position Management
void ManageOpenPositions()
{
    UpdatePositionState();
    
    if(!g_positionState.hasPosition)
        return;
    
    double currentPrice = g_positionState.isBuy ? 
        SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
        SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if(SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 3 || SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 5)
        pipSize *= 10;
    
    bool needsUpdate = false;
    double newSL = g_positionState.currentSL;
    double newTP = g_positionState.currentTP;
    
    // Calculate current profit in pips
    double profitPips = 0;
    if(g_positionState.isBuy)
    {
        profitPips = (currentPrice - g_positionState.entryPrice) / pipSize;
    }
    else
    {
        profitPips = (g_positionState.entryPrice - currentPrice) / pipSize;
    }
    
    // 1. BREAKEVEN MOVE
    if(UseBreakevenMove && !g_positionState.breakevenActivated && profitPips >= BreakevenTriggerPips)
    {
        double breakevenPrice = g_positionState.entryPrice + (g_positionState.isBuy ? 5 : -5) * pipSize; // 5 pip profit lock
        
        if(g_positionState.isBuy && breakevenPrice > g_positionState.currentSL)
        {
            newSL = breakevenPrice;
            needsUpdate = true;
            g_positionState.breakevenActivated = true;
            CV2EAUtils::LogSuccess(StringFormat("Moving to breakeven + 5 pips at %.5f (profit: %.1f pips)", 
                breakevenPrice, profitPips));
        }
        else if(!g_positionState.isBuy && breakevenPrice < g_positionState.currentSL)
        {
            newSL = breakevenPrice;
            needsUpdate = true;
            g_positionState.breakevenActivated = true;
            CV2EAUtils::LogSuccess(StringFormat("Moving to breakeven + 5 pips at %.5f (profit: %.1f pips)", 
                breakevenPrice, profitPips));
        }
    }
    
    // 2. PARTIAL PROFIT TAKING
    if(UsePartialTakeProfit && !g_positionState.partialTaken && profitPips >= TrailingStopPips)
    {
        double partialLots = NormalizeDouble(g_positionState.lotSize * PartialTakeProfitRatio, 2);
        
        if(partialLots >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        {
            if(PositionClosePartial(g_positionState.positionTicket, partialLots))
            {
                g_positionState.partialTaken = true;
                CV2EAUtils::LogSuccess(StringFormat("Partial profit taken: %.2f lots at %.1f pips profit", 
                    partialLots, profitPips));
            }
        }
    }
    
    // 3. KEY LEVEL TRAILING STOP
    double keyLevelSL = CalculateKeyLevelTrailingStop(g_positionState.isBuy, currentPrice);
    
    // 4. TRADITIONAL TRAILING STOP
    double traditionalTrailingSL = 0;
    if(g_positionState.isBuy)
    {
        traditionalTrailingSL = g_positionState.highestPrice - (TrailingStopPips * pipSize);
        if(traditionalTrailingSL > g_positionState.currentSL)
        {
            newSL = MathMax(newSL, traditionalTrailingSL);
            needsUpdate = true;
        }
    }
    else
    {
        traditionalTrailingSL = g_positionState.lowestPrice + (TrailingStopPips * pipSize);
        if(traditionalTrailingSL < g_positionState.currentSL || g_positionState.currentSL == 0)
        {
            newSL = traditionalTrailingSL;
            if(g_positionState.currentSL == 0 || newSL < g_positionState.currentSL)
                needsUpdate = true;
        }
    }
    
    // 5. APPLY KEY LEVEL TRAILING IF BETTER
    if(keyLevelSL > 0)
    {
        if(g_positionState.isBuy && keyLevelSL > newSL)
        {
            newSL = keyLevelSL;
            needsUpdate = true;
            CV2EAUtils::LogInfo("Using key level trailing stop");
        }
        else if(!g_positionState.isBuy && (keyLevelSL < newSL || newSL == 0))
        {
            newSL = keyLevelSL;
            needsUpdate = true;
            CV2EAUtils::LogInfo("Using key level trailing stop");
        }
    }
    
         // 6. DYNAMIC TAKE PROFIT ADJUSTMENT
     double keyLevelTP = CalculateKeyLevelProfitTarget(g_positionState.isBuy, currentPrice, g_positionState.entryPrice);
     if(keyLevelTP > 0)
     {
         // Only update TP if the key level target is better than current TP
         bool shouldUpdateTP = false;
         if(g_positionState.isBuy && (g_positionState.currentTP == 0 || keyLevelTP < g_positionState.currentTP))
         {
             newTP = keyLevelTP;
             shouldUpdateTP = true;
         }
         else if(!g_positionState.isBuy && (g_positionState.currentTP == 0 || keyLevelTP > g_positionState.currentTP))
         {
             newTP = keyLevelTP;
             shouldUpdateTP = true;
         }
         
         if(shouldUpdateTP)
         {
             needsUpdate = true;
             CV2EAUtils::LogInfo("Adjusting TP to key level target");
         }
     }
     
     // 7. UPDATE POSITION IF NEEDED
     if(needsUpdate && (newSL != g_positionState.currentSL || newTP != g_positionState.currentTP))
     {
         if(trade.PositionModify(g_positionState.positionTicket, newSL, newTP))
         {
             string updateMsg = "";
             if(newSL != g_positionState.currentSL)
                 updateMsg += StringFormat("SL: %.5f → %.5f ", g_positionState.currentSL, newSL);
             if(newTP != g_positionState.currentTP)
                 updateMsg += StringFormat("TP: %.5f → %.5f ", g_positionState.currentTP, newTP);
             
             CV2EAUtils::LogSuccess(StringFormat("Position updated - %s(Profit: %.1f pips)", 
                 updateMsg, profitPips));
         }
         else
         {
             CV2EAUtils::LogError(StringFormat("Failed to update position. Error: %d", GetLastError()));
         }
     }
}

// MODULE 9.2: Enhanced Entry Logic with Multi-Timeframe Confirmation
bool ValidateMultiTimeframeEntry(bool isBullish, double breakoutLevel)
{
    // Get confirmation from higher timeframe
    ENUM_TIMEFRAMES higherTF = PERIOD_CURRENT;
    
    // Determine higher timeframe
    switch(Period())
    {
        case PERIOD_M5:  higherTF = PERIOD_M15; break;
        case PERIOD_M15: higherTF = PERIOD_M30; break;
        case PERIOD_M30: higherTF = PERIOD_H1;  break;
        case PERIOD_H1:  higherTF = PERIOD_H4;  break;
        case PERIOD_H4:  higherTF = PERIOD_D1;  break;
        case PERIOD_D1:  higherTF = PERIOD_W1;  break;
        default: return true; // Skip multi-timeframe for higher TFs
    }
    
    // Process higher timeframe to get key levels
    if(!breakoutStrategy.ProcessTimeframe(higherTF))
    {
        CV2EAUtils::LogWarning("Failed to process higher timeframe for confirmation");
        return true; // Don't block trade if we can't get higher TF data
    }
    
    // Check if higher timeframe supports the breakout direction
    SKeyLevel higherTFLevel;
    if(breakoutStrategy.GetStrongestLevel(higherTFLevel))
    {
        double distance = MathAbs(higherTFLevel.price - breakoutLevel);
        double touchZone = breakoutStrategy.TEST_GetTouchZone();
        
        // Check alignment
        bool aligned = false;
        if(isBullish && !higherTFLevel.isResistance && distance <= touchZone * 2)
        {
            aligned = true; // Bullish breakout with higher TF support nearby
        }
        else if(!isBullish && higherTFLevel.isResistance && distance <= touchZone * 2)
        {
            aligned = true; // Bearish breakout with higher TF resistance nearby
        }
        
        if(ShowDebugPrints)
        {
            CV2EAUtils::LogInfo(StringFormat("Multi-TF check: %s breakout %s with %s TF",
                isBullish ? "Bullish" : "Bearish",
                aligned ? "ALIGNED" : "NOT ALIGNED",
                EnumToString(higherTF)));
        }
        
        return aligned;
    }
    
    return true; // Default to allowing trade if no higher TF levels found
}

// MODULE 9.3: Strategy Core Execution
// Purpose: Main strategy implementation and trade execution
// Components:
// - Position conflict prevention
// - Cooldown enforcement
// - Risk management application
// - Trade placement coordination
void ExecuteBreakoutRetestStrategy(bool isBullish, double breakoutLevel)
{
   // CRITICAL: First check if new trades are allowed
   if(!g_allowNewTrades)
   {
      CV2EAUtils::LogError("New trades not allowed during current session");
      return;
   }

   // Check for existing positions and enforce cooldown
   UpdatePositionState(); // Update our position tracking
   if(g_positionState.hasPosition)
   {
      CV2EAUtils::LogError("Position already exists for this symbol and magic number");
      return;
   }

   // Enforce minimum time between trades (5 minutes cooldown)
   datetime currentTime = TimeCurrent();
   if(currentTime - g_lastTradeTime < 300)  // 300 seconds = 5 minutes
   {
      CV2EAUtils::LogWarning("Trade cooldown period still active. Waiting...");
      return;
   }

   // 1) Multi-timeframe confirmation
   if(UseMultiTimeframeConfirmation && !ValidateMultiTimeframeEntry(isBullish, breakoutLevel))
   {
      CV2EAUtils::LogWarning("Multi-timeframe confirmation failed - skipping entry");
      return;
   }

   // 2) Current price
   double currentPrice = isBullish 
                       ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // 3) Enhanced risk-based position sizing
   SKeyLevel entryLevel;
   double originalRisk = RiskPercentage;
   if(UseStrengthBasedSizing && breakoutStrategy.GetStrongestLevel(entryLevel))
   {
      // Adjust position size based on key level strength
      double strengthMultiplier = MathMin(entryLevel.strength * MaxStrengthMultiplier, MaxStrengthMultiplier);
      RiskPercentage = RiskPercentage * strengthMultiplier;
      
      if(ShowDebugPrints)
      {
         CV2EAUtils::LogInfo(StringFormat("Risk adjusted for level strength: %.2f%% → %.2f%% (strength: %.3f)",
            originalRisk, RiskPercentage, entryLevel.strength));
      }
   }

   // 4) Calculate SL/TP using pivot points
   double slPrice = 0, tpPrice = 0;
   if(!ApplyDailyPivotSLTP(isBullish, currentPrice, slPrice, tpPrice))
   {
      CV2EAUtils::LogError("Failed to calculate pivot-based SL/TP");
      return;
   }

   // 5) Calculate position size based on adjusted risk
   double lotSize = CalculateLotSize(slPrice, currentPrice, RiskPercentage);
   if(lotSize <= 0)
   {
      CV2EAUtils::LogError("Invalid lot size calculated");
      return;
   }

   // 6) Place the trade with enhanced tracking
   if(PlaceTrade(isBullish, currentPrice, slPrice, tpPrice, lotSize))
   {
      // Initialize position state tracking
      g_positionState.keyLevelEntryPrice = breakoutLevel;
      g_positionState.highestPrice = currentPrice;
      g_positionState.lowestPrice = currentPrice;
      
      CV2EAUtils::LogSuccess(StringFormat("ENHANCED TRADE PLACED:\n" +
               "Direction: %s at %.5f\n" +
               "SL: %.5f TP: %.5f\n" +
               "Lot Size: %.2f (Risk: %.2f%%)\n" +
               "Key Level: %.5f (Strength: %.3f)",
               (isBullish ? "Buy" : "Sell"), currentPrice, slPrice, tpPrice,
               lotSize, RiskPercentage, breakoutLevel, 
               entryLevel.strength > 0 ? entryLevel.strength : 0.0));

      // Set breakout zone lockout after successful trade
      g_activeBreakoutZonePrice = breakoutLevel;  
      g_activeBreakoutDirection = isBullish;
      g_inLockout = true;

      CV2EAUtils::LogSuccess(StringFormat("Breakout zone lockout set: Level=%.5f Direction=%s",
               breakoutLevel, (isBullish ? "Bullish" : "Bearish")));
   }
   else
   {
      CV2EAUtils::LogError("Trade placement failed.");
   }
}

//==================================================================
// MODULE 10: EA LIFECYCLE
// Purpose: Expert Advisor initialization and runtime management
// Components:
// - EA initialization and cleanup
// - Main trading loop (OnTick)
// - Resource management
// - Debug logging
//==================================================================

// MODULE 10.1: EA initialization
int OnInit()
{
   // Initialize ATR indicator handle
   g_handleATR = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
   if(g_handleATR == INVALID_HANDLE)
   {
      CV2EAUtils::LogError("Failed to create ATR indicator handle");
      return INIT_FAILED;
   }

   // Initialize market data class
   CV2EAMarketData::Init(ShowDebugPrints);
   
   // Configure volume analysis with default multiplier (2.0)
   CV2EAMarketData::ConfigureVolumeAnalysis(2.0, VolumeType);

   // Setup timer
   if(!EventSetTimer(TIMER_INTERVAL))
   {
      CV2EAUtils::LogError("Failed to set timer");
      return INIT_FAILED;
   }

   // Initialize position state
   g_positionState.Reset();
   
   CV2EAUtils::LogSuccess(StringFormat("EA started. Session trading restrictions are %s. Timer interval: %d seconds", 
            (RestrictTradingHours ? "enabled" : "disabled"), TIMER_INTERVAL));
   return(INIT_SUCCEEDED);
}

// MODULE 10.2: EA deinitialization
void OnDeinit(const int reason)
{
   // Clean up indicator handle
   if(g_handleATR != INVALID_HANDLE)
      IndicatorRelease(g_handleATR);
      
   // Remove timer
   EventKillTimer();

   CV2EAUtils::LogInfo(StringFormat("EA Deinit. Reason: %d", reason));
}

// MODULE 10.3: Main EA tick
void OnTick()
{
   // Performance monitoring
   g_tickCount += 1;
   ulong tickStartTime = GetMicrosecondCount();
   
   datetime now = TimeCurrent();
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool isNewBar = (currentBarTime != g_lastBarTime);
   
   // Update bar tracking if new bar
   if(isNewBar)
   {
      g_lastBarTime = currentBarTime;
   }
   
   // Check session permissions
   IsTradeAllowedInSession();  // This updates g_allowNewTrades and g_allowTradeManagement
   
   // Always check and manage open positions regardless of session
   if(g_allowTradeManagement)
   {
      ManageOpenPositions();
   }
   
   // Only look for new trade opportunities if allowed
   if(g_allowNewTrades)
   {
      // Check for retest conditions if we're awaiting one
      if(g_breakoutState.awaitingRetest)
      {
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double retestZone = g_breakoutState.breakoutLevel;
         double zoneSize = RetestPipsThreshold * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         
         bool priceInZone = (currentPrice >= retestZone - zoneSize && 
                            currentPrice <= retestZone + zoneSize);
                            
         if(priceInZone && ValidateRetestConditions())
         {
            ExecuteBreakoutRetestStrategy(g_breakoutState.isBullish,
                                        g_breakoutState.breakoutLevel);
         }
      }
   }
   
   // Performance stats calculation
   ulong tickEndTime = GetMicrosecondCount();
   double tickTime = (tickEndTime - tickStartTime) / 1000.0;
   
   g_totalTickTime += tickTime;
   g_avgTickTime = g_totalTickTime / (double)g_tickCount;
   g_maxTickTime = MathMax(g_maxTickTime, tickTime);
}

bool IsHighVolatilityOrBusySession()
{
   // Get current time using MQL5's datetime structure
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hourNow = dt.hour;

   // Check time-of-day window
   bool isBusyTime = (hourNow >= HighVolatilityStartHour && hourNow < HighVolatilityEndHour);

   // Check ATR for volatility
   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   
   // Use the global ATR handle we already have
   if(g_handleATR != INVALID_HANDLE)
   {
      if(CopyBuffer(g_handleATR, 0, 0, 1, atrBuf) > 0)
      {
         bool isHighATR = (atrBuf[0] >= ATRVolatilityThreshold);
         
         // Return true if either time is busy or volatility is high
         return (isBusyTime || isHighATR);
      }
   }
   
   // If we can't get ATR, just use time-based decision
   return isBusyTime;
}

// Add new touch validation function
bool IsValidTouch(const double &prices[], const datetime &times[], const int touchIndex, const int lookback=3)
{
   if(touchIndex < 0 || touchIndex >= ArraySize(prices) || touchIndex >= ArraySize(times))
      return false;
      
   // Check if we have enough bars before the touch point
   if(touchIndex < lookback - 1)
      return false;
      
   // Check if price stayed near the level for at least a few bars
   double avgPrice = 0;
   for(int i = 0; i < lookback; i++)
   {
      if(touchIndex - i < 0 || touchIndex - i >= ArraySize(prices))
         return false;
      avgPrice += prices[touchIndex - i];
   }
   avgPrice /= lookback;
   
   // Calculate price volatility around the touch
   double variance = 0;
   for(int i = 0; i < lookback; i++)
   {
      if(touchIndex - i < 0 || touchIndex - i >= ArraySize(prices))
         return false;
      variance += MathPow(prices[touchIndex - i] - avgPrice, 2);
   }
   variance /= lookback;
   
   // Reject if volatility is too high (spike)
   double stdDev = MathSqrt(variance);
   if(stdDev > TouchZoneSize * 2)
      return false;
      
   return true;
}

// Enhanced touch counting function
void CountTouchesEnhanced(const double &highPrices[], const double &lowPrices[], 
                         const datetime &times[], const double level,
                         SKeyLevel &outLevel)
{
   int highSize = ArraySize(highPrices);
   int lowSize = ArraySize(lowPrices);
   int timeSize = ArraySize(times);
   
   if(highSize == 0 || lowSize == 0 || timeSize == 0)
      return;
      
   ArrayResize(outLevel.touches, 0);
   int touchCount = 0;
   datetime firstTouch = 0;
   datetime lastTouch = 0;
   
   int maxBars = MathMin(KeyLevelLookback, MathMin(highSize, MathMin(lowSize, timeSize)));
   
   for(int j = 0; j < maxBars; j++)
   {
      // Calculate distance to level
      double highDist = MathAbs(highPrices[j] - level);
      double lowDist = MathAbs(lowPrices[j] - level);
      double minDist = MathMin(highDist, lowDist);
      
      if(minDist <= TouchZoneSize)
      {
         // Determine which price to use
         double price = (highDist < lowDist) ? highPrices[j] : lowPrices[j];
         
         // Create temporary arrays for validation
         double priceArray[];
         ArrayResize(priceArray, highSize);
         
         // Copy the appropriate price array based on which distance is smaller
         if(highDist < lowDist)
         {
            ArrayCopy(priceArray, highPrices);
         }
         else
         {
            ArrayCopy(priceArray, lowPrices);
         }
         
         // Validate this touch
         if(IsValidTouch(priceArray, times, j))
         {
            // Calculate touch strength based on proximity
            double touchStrength = 1.0 - (minDist / TouchZoneSize);
            
            // Add to touches array
            int size = ArraySize(outLevel.touches);
            ArrayResize(outLevel.touches, size + 1);
            outLevel.touches[size].time = times[j];
            outLevel.touches[size].price = price;
            outLevel.touches[size].strength = touchStrength;
            outLevel.touches[size].isValid = true;
            
            touchCount++;
            
            if(firstTouch == 0 || times[j] < firstTouch) firstTouch = times[j];
            if(times[j] > lastTouch) lastTouch = times[j];
         }
      }
   }
   
   outLevel.touchCount = touchCount;
   outLevel.firstTouch = firstTouch;
   outLevel.lastTouch = lastTouch;
}

// Add OnTimer event handler
void OnTimer()
{
   // Performance monitoring for timer events
   ulong timerStartTime = GetMicrosecondCount();
   static ulong g_timerCount = 0;
   g_timerCount++;
   
   datetime now = TimeCurrent();
   static datetime lastCalculationTime = 0;
   
   // Get current bar info
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   static datetime lastProcessedBarTime = 0;
   bool isNewBar = (currentBarTime != lastProcessedBarTime);
   
   // Only perform periodic calculations every minute
   if(now - lastCalculationTime < 60)
      return;
      
   lastCalculationTime = now;
   
   // Check if trading is allowed
   if(!IsTradeAllowedInSession())
      return;
   
   // Perform periodic heavy calculations here
   if(g_breakoutState.awaitingRetest)
   {
      g_calculationCount++;
      bool retestConfirmed = ValidateRetestConditions();
      if(retestConfirmed)
      {
         CV2EAUtils::LogSuccess("Trade Signal: Retest confirmed at " + TimeToString(now, TIME_MINUTES));
         ExecuteBreakoutRetestStrategy(g_breakoutState.isBullish,
                                     g_breakoutState.breakoutLevel);
      }
   }
   else if(isNewBar) // Look for new breakouts on new bars
   {
      g_calculationCount++;
      double breakoutLevel = 0.0;
      bool isBullish = false;
      
      bool breakoutConfirmed = DetectBreakoutAndInitRetest(breakoutLevel, isBullish);
      if(breakoutConfirmed)
      {
         CV2EAUtils::LogSuccess("Trade Signal: Breakout detected at " + TimeToString(now, TIME_MINUTES) +
                  " | Level: " + DoubleToString(breakoutLevel, _Digits) +
                  " | Direction: " + (isBullish ? "Buy" : "Sell"));
      }
      
      // Update last processed bar
      lastProcessedBarTime = currentBarTime;
   }
   
   // Log timer performance
   ulong timerEndTime = GetMicrosecondCount();
   double timerProcessingTime = (timerEndTime - timerStartTime) / 1000.0;
   
   // Enhanced position status reporting every 30 minutes for active positions
   static datetime lastPositionStatusTime = 0;
   if(g_positionState.hasPosition && now - lastPositionStatusTime >= 1800) // 30 minutes
   {
      UpdatePositionState(); // Refresh position data
      double currentPrice = g_positionState.isBuy ? 
          SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
          SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 3 || SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 5)
          pipSize *= 10;
          
      double profitPips = g_positionState.isBuy ? 
          (currentPrice - g_positionState.entryPrice) / pipSize :
          (g_positionState.entryPrice - currentPrice) / pipSize;
          
      CV2EAUtils::LogInfo(StringFormat("📊 POSITION STATUS [%s]\n" +
          "Direction: %s | Entry: %.5f | Current: %.5f\n" +
          "Profit: %.1f pips | SL: %.5f | TP: %.5f\n" +
          "Breakeven: %s | Partial Taken: %s\n" +
          "Key Level Entry: %.5f | Duration: %s",
          TimeToString(now, TIME_DATE|TIME_MINUTES),
          g_positionState.isBuy ? "BUY" : "SELL",
          g_positionState.entryPrice, currentPrice,
          profitPips, g_positionState.currentSL, g_positionState.currentTP,
          g_positionState.breakevenActivated ? "YES" : "NO",
          g_positionState.partialTaken ? "YES" : "NO",
          g_positionState.keyLevelEntryPrice,
          TimeToString(now - g_positionState.entryTime, TIME_MINUTES)));
      lastPositionStatusTime = now;
   }
   
   // Log consolidated stats every 6 hours and only if there's been activity
   static datetime lastStatsTime = 0;
   if(ShowDebugPrints && now - lastStatsTime >= 21600 && // 6 hours
      (g_calculationCount > 0 || g_tickCount > 1000)) // Only if there's been activity
   {
      UpdatePositionState(); // Make sure we have current position data
      CV2EAUtils::LogInfo(StringFormat("📈 EA STATUS REPORT [%s]", TimeToString(now, TIME_DATE|TIME_MINUTES)));
      CV2EAUtils::LogInfo(StringFormat("  Performance:\n    Ticks/Calculations: %d / %d\n    Calc/Tick Ratio: %f%%\n    Avg/Max Tick Time: %f / %f ms\n    Timer Events: %d\n    Last Process Time: %f ms\n  Trading:\n    Session Active: %s\n    Awaiting Retest: %s\n    Open Positions: %d\n    Position Management: %s",
            g_tickCount, g_calculationCount, g_calculationCount * 100.0 / (double)g_tickCount,
            g_avgTickTime, g_maxTickTime, g_timerCount, timerProcessingTime,
            (IsTradeAllowedInSession() ? "Yes" : "No"),
            (g_breakoutState.awaitingRetest ? "Yes" : "No"),
            PositionsTotal(),
            g_positionState.hasPosition ? "ACTIVE" : "IDLE"));
      lastStatsTime = now;
   }
}

//+------------------------------------------------------------------+

string GetOptimizationLogFilename() 
{
   string symbol = _Symbol;
   string timeframe = EnumToString(Period());
   
   // Create unique timestamp for this run
   static string runTimestamp = "";
   if(runTimestamp == "")
   {
      datetime currentTime = TimeCurrent();
      ulong microseconds = GetMicrosecondCount();
      MqlDateTime dt;
      TimeToStruct(currentTime, dt);
      runTimestamp = StringFormat("%04d%02d%02d_%02d%02d%02d_%06d", 
         dt.year, dt.mon, dt.day,
         dt.hour, dt.min, dt.sec,
         (int)(microseconds % 1000000));
      
      // *** FILENAME VERIFICATION ***
      Print("🔍 OPTIMIZATION LOG TIMESTAMP CREATED: ", runTimestamp);
   }
   
   string filename = "OptimizationLog_" + symbol + "_" + timeframe + "_" + runTimestamp + ".txt";
   return filename;
}
