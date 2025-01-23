//+------------------------------------------------------------------+
//|                                                V-EA-Breakouts.mq5 |
//|                      Skeleton for Breakout-Retest (Modular)      |
//+------------------------------------------------------------------+
#property copyright "Your Company"
#property link      "Your Link"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//==================================================================
// MODULE 1: CONFIGURATION AND INPUTS
//==================================================================

// Strategy type selection
enum ENUM_STRATEGY_TYPE
{
   STRAT_BREAKOUT_RETEST = 0, 
   STRAT_OTHER           = 1
};

// Core strategy inputs
input ENUM_STRATEGY_TYPE StrategyType = STRAT_BREAKOUT_RETEST;
input bool   UseVolumeFilter        = true;    // Enable volume confirmation for breakouts 
input bool   UseMinATRDistance      = true;    // Use ATR for minimum breakout distance 
input bool   UseRetest             = true;   // Wait for price to retest breakout level 
input bool   ShowDebugPrints       = true;    // Show detailed debug information 
input bool   UseCandlestickConfirmation = false; // Use candlestick patterns for retest confirmation 

// Breakout parameters
input int    BreakoutLookback       = 15;      // Number of bars to look back for breakout [start=10 step=5 stop=50]
input int    ATRPeriod              = 13;      // Period for ATR calculation [start=5 step=1 stop=30]
input double VolumeFactor           = 2.0;     // Required volume multiple vs average [start=1.0 step=0.1 stop=2.0]
input double ATRMultiplier          = 0.1;     // ATR multiplier for breakout distance [start=0.1 step=0.1 stop=1.0]
input double RetestATRMultiplier    = 0.4;     // ATR multiplier for retest zone [start=0.1 step=0.1 stop=0.5]
input int    MaxRetestBars          = 5;       // Maximum bars to wait for retest [start=3 step=1 stop=20]
input int    MaxRetestMinutes       = 180;     // Maximum minutes to wait for retest [start=60 step=60 stop=480]

// Risk management
input double SLMultiplier           = 2.5;     // Stop loss multiplier vs ATR [start=1.0 step=0.5 stop=6.0]
input double TPMultiplier           = 6;     // Take profit multiplier vs ATR [start=1.0 step=0.5 stop=6.0]
input double RiskPercentage         = 5.0;     // Account risk per trade in percent [start=1.0 step=1.0 stop=5.0]

// Session control
input bool   RestrictTradingHours   = true;   // Enable trading hour restrictions 
input int    LondonOpenHour         = 2;       // London session open hour (broker time) [start=0 step=1 stop=5]
input int    LondonCloseHour        = 10;      // London session close hour (broker time) [start=6 step=1 stop=14]
input int    NewYorkOpenHour        = 7;       // New York session open hour (broker time) [start=7 step=1 stop=10]
input int    NewYorkCloseHour       = 16;      // New York session close hour (broker time) [start=13 step=1 stop=18]
input int    BrokerToLocalOffsetHours = 7;     // Hours to add to local time for broker time [start=0 step=1 stop=12]

// Key level detection parameters
input int    KeyLevelLookback       = 260;      // Bars to analyze for key levels [start=50 step=10 stop=300]
input int    MinTouchCount          = 5;        // Minimum touches for key level validation [start=2 step=1 stop=6]
input double TouchZoneSize          = 0.0002;   // Size of zone around key level in price units [start=0.0001 step=0.0001 stop=0.001]
input double KeyLevelMinDistance    = 0.0019;   // Minimum distance between key levels [start=0.0002 step=0.0001 stop=0.002]

// Strength calculation weights (must sum to 1.0)
input double TouchScoreWeight       = 0.4;      // Weight for number of touches in strength calc [start=0.3 step=0.1 stop=0.7]
input double RecencyWeight            = 0.2;      // Weight for recency of touches in strength calc [start=0.2 step=0.1 stop=0.5]
input double DurationWeight           = 0.4;      // Weight for level duration in strength calc [start=0.1 step=0.1 stop=0.4]

// Level validation
input int    MinLevelDurationHours    = 48;       // Minimum hours a level must exist [start=12 step=12 stop=96]
input double MinStrengthThreshold       = 0.7;      // Minimum strength score for valid level [start=0.4 step=0.1 stop=0.8]

// Example input for retest check threshold (in pips) & timeframe for candlestick pattern
input double RetestPipsThreshold        = 15;       // Distance in pips to consider price in retest zone [start=5 step=5 stop=30]
input ENUM_TIMEFRAMES RetestTimeframe = PERIOD_M15; // Timeframe for candlestick pattern analysis

//==================================================================
// MODULE 2: GLOBAL STATE MANAGEMENT
//==================================================================
datetime      g_lastBarTime      = 0;
bool          g_hasPositionOpen  = false;
int           g_magicNumber      = 12345;

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
SBreakoutState g_breakoutState = {0,0.0,false,false,0,0,0};

// Structure to store key level information
struct SKeyLevel
{
   double price;           // The price level
   int    touchCount;      // Number of times price touched this level
   bool   isResistance;    // Whether this is resistance (true) or support (false)
   datetime firstTouch;    // Time of first touch
   datetime lastTouch;     // Time of last touch
   double  strength;       // Relative strength of the level (based on touches and recency)
};

// Global variables for key level tracking
SKeyLevel g_keyLevels[];  // Array to store detected key levels
int g_lastKeyLevelUpdate = 0;  // Bar index of last key level update

// Add global variable for tracking last debug message time
datetime g_lastSessionDebugTime = 0;

// Add these with the other global variables at the top
datetime g_lastLockoutDebugTime = 0;
double g_lastReportedDistance = 0.0;

//==================================================================
// MODULE 3: STRATEGY CONSTANTS
//==================================================================
const double VOLUME_THRESH   = 1.1;  
const double BO_ATR_MULT     = 0.3;  
const double RT_ATR_MULT     = 0.2;  

//==================================================================
// MODULE 4: SESSION CONTROL
//==================================================================

// MODULE 4.1: Check if trading is allowed in current session
bool IsTradeAllowedInSession()
{
   // If trading hours are not restricted, always allow trading
   if(!RestrictTradingHours)
      return true;
      
   // Get current broker time
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   
   int currentHour = dt.hour;
   
   // Check if we're in London session
   bool inLondonSession = (currentHour >= LondonOpenHour && currentHour < LondonCloseHour);
   
   // Check if we're in New York session
   bool inNewYorkSession = (currentHour >= NewYorkOpenHour && currentHour < NewYorkCloseHour);
   
   // Trading is allowed if we're in either session
   bool isAllowed = inLondonSession || inNewYorkSession;
   
   // Only show debug message once per hour
   if(ShowDebugPrints && !isAllowed && (now - g_lastSessionDebugTime >= 3600))
   {
      Print("❌ [Session Control] Trading not allowed at hour ", currentHour,
            " | London: ", LondonOpenHour, "-", LondonCloseHour,
            " | NY: ", NewYorkOpenHour, "-", NewYorkCloseHour);
      g_lastSessionDebugTime = now;
   }
   
   return isAllowed;
}

//==================================================================
// MODULE 5: BREAKOUT VALIDATION AND DETECTION
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
double CalculateLevelStrength(const int touchCount, const datetime firstTouch, const datetime lastTouch)
{
   double touchScore = (double)touchCount / MinTouchCount;
   
   // Recency score: more recent touches get higher weight
   datetime now = TimeCurrent();
   double hoursElapsed = (double)(now - lastTouch) / 3600.0;
   double recencyScore = MathExp(-hoursElapsed / (KeyLevelLookback * 24.0)); // Exponential decay
   
   // Duration score: longer-lasting levels get higher weight
   double hoursDuration = (double)(lastTouch - firstTouch) / 3600.0;
   double durationScore = MathMin(hoursDuration / (KeyLevelLookback * 24.0), 1.0);
   
   return (touchScore * TouchScoreWeight + recencyScore * RecencyWeight + durationScore * DurationWeight);
}

// MODULE 5.3: Key level detection for breakout analysis
bool FindKeyLevels(SKeyLevel &outStrongestLevel)
{
   // Validate weights sum to 1.0
   if(MathAbs(TouchScoreWeight + RecencyWeight + DurationWeight - 1.0) > 0.001)
   {
      if(ShowDebugPrints)
         Print("❌ [M5.3.a Key Level Detection] ERROR: Strength weights must sum to 1.0. Current sum: ",
               TouchScoreWeight + RecencyWeight + DurationWeight);
      return false;
   }

   // Copy arrays
   double highPrices[], lowPrices[], closePrices[];
   datetime times[];
   ArraySetAsSeries(highPrices, true);
   ArraySetAsSeries(lowPrices, true);
   ArraySetAsSeries(closePrices, true);
   ArraySetAsSeries(times, true);

   // Edge case: KeyLevelLookback might be < 3
   if(KeyLevelLookback < 3)
   {
      if(ShowDebugPrints)
         Print("❌ [M5.3.a Key Level Detection] KeyLevelLookback too small (", KeyLevelLookback,
               "). No key levels will be found.");
      return false;
   }

   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, KeyLevelLookback, highPrices) <= 0 ||
      CopyLow(_Symbol, PERIOD_CURRENT, 0, KeyLevelLookback, lowPrices) <= 0 ||
      CopyClose(_Symbol, PERIOD_CURRENT, 0, KeyLevelLookback, closePrices) <= 0 ||
      CopyTime(_Symbol, PERIOD_CURRENT, 0, KeyLevelLookback, times) <= 0)
   {
      if(ShowDebugPrints)
         Print("❌ [M5.3.b Key Level Detection] Failed to copy price data. Error=", GetLastError());
      return false;
   }

   SKeyLevel tempLevels[];
   int levelCount = 0;

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
            
            if(touches >= MinTouchCount && durationHours >= MinLevelDurationHours)
            {
               double strength = CalculateLevelStrength(touches, firstTouch, lastTouch);
               
               if(strength >= MinStrengthThreshold)
               {
                  ArrayResize(tempLevels, levelCount + 1);
                  tempLevels[levelCount].price = level;
                  tempLevels[levelCount].touchCount = touches;
                  tempLevels[levelCount].isResistance = true;
                  tempLevels[levelCount].firstTouch = firstTouch;
                  tempLevels[levelCount].lastTouch = lastTouch;
                  tempLevels[levelCount].strength = strength;
                  levelCount++;
               }
            }
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
            
            if(touches >= MinTouchCount && durationHours >= MinLevelDurationHours)
            {
               double strength = CalculateLevelStrength(touches, firstTouch, lastTouch);
               
               if(strength >= MinStrengthThreshold)
               {
                  ArrayResize(tempLevels, levelCount + 1);
                  tempLevels[levelCount].price = level;
                  tempLevels[levelCount].touchCount = touches;
                  tempLevels[levelCount].isResistance = false;
                  tempLevels[levelCount].firstTouch = firstTouch;
                  tempLevels[levelCount].lastTouch = lastTouch;
                  tempLevels[levelCount].strength = strength;
                  levelCount++;
               }
            }
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
      
      if(ShowDebugPrints)
      {
         //rbandeira
         //Print("[M5.3 Key Level Detection] Found ", levelCount, " key levels. Strongest level: ",
         //      "Price=", outStrongestLevel.price,
         //      ", Type=", (outStrongestLevel.isResistance ? "Resistance" : "Support"),
         //      ", Touches=", outStrongestLevel.touchCount,
         //      ", Strength=", outStrongestLevel.strength,
         //      ", Duration=", (double)(outStrongestLevel.lastTouch - outStrongestLevel.firstTouch) / 3600.0, " hours");
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

   long sumVol = 0;
   for(int i = 1; i <= lookback; i++)
      sumVol += volumes[i];
      
   double avgVol = (double)sumVol / (double)lookback;
   double currVol = (double)volumes[0];

   return (currVol >= avgVol * VolumeFactor);
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
      if(ShowDebugPrints)
         Print("⚠️ [M5.5 ATR Distance Check] Warning: Invalid ATR handle. Bypassing distance check.");
      return true;
   }

   if(CopyBuffer(g_handleATR, 0, 0, 1, atrBuf) <= 0)
   {
      if(ShowDebugPrints)
         Print("⚠️ [M5.5 ATR Distance Check] Warning: ATR copy failed. Bypassing distance check.");
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
   // CRITICAL: First check if we already have a position - if so, skip breakout detection entirely
   if(PositionsTotal() > 0)
   {
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(PositionGetSymbol(i) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
         {
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
         if(ShowDebugPrints)
            Print("✅ [M5.6.a Breakout Detection] Resetting lockout. Distance from zone: ", 
                  NormalizeDouble(distanceFromLastBreak/pointSize, 1), " pips",
                  " (required ", NormalizeDouble(threshold/pointSize, 1), " pips)");
         g_inLockout = false;
         g_activeBreakoutZonePrice = 0.0;  // Clear the active zone
      }
      else
      {
         datetime now = TimeCurrent();
         // Only show debug message if:
         // 1. Distance has changed by at least 50 pips from last report, OR
         // 2. At least 1 hour has passed since last debug message
         if(ShowDebugPrints && 
            (MathAbs(distanceInPips - g_lastReportedDistance) >= 50.0 || 
             now - g_lastLockoutDebugTime >= 3600))
         {
            Print("❌ [M5.6.a Breakout Detection] Still within lockout zone. Distance: ", 
                  NormalizeDouble(distanceInPips, 1), " pips",
                  " (need ", NormalizeDouble(threshold/pointSize, 1), " pips)");
            g_lastLockoutDebugTime = now;
            g_lastReportedDistance = distanceInPips;
         }
         return false;
      }
   }

   // Find key levels first
   SKeyLevel strongestLevel;
   if(!FindKeyLevels(strongestLevel))
      return false;

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
      CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, bars_to_copy, volumes) <= 0)
   {
      if(ShowDebugPrints)
         Print("❌ [M5.6.a Breakout Detection] Failed to copy price or volume data. Err=", GetLastError());
      return false;
   }

   // Use last closed candle to confirm the breakout
   double lastClose = closePrices[1];
   double pipPoint  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   bool volumeOK     = DoesVolumeMeetRequirement(volumes, BreakoutLookback);
   bool bullishBreak = (lastClose > (strongestLevel.price + pipPoint));
   bool bearishBreak = (lastClose < (strongestLevel.price - pipPoint));

   if(ShowDebugPrints)
   {
      //rbandeira
      //Print("[M5.6.a Breakout Detection] LastClose=", lastClose,
      //      " | KeyLevel=", strongestLevel.price,
      //      " | VolumeOK=", volumeOK,
      //      " | BullishBreak=", bullishBreak,
      //      " | BearishBreak=", bearishBreak);
   }

   // Bullish breakout
   if(bullishBreak && volumeOK && IsATRDistanceMet(lastClose, strongestLevel.price))
   {
      outBreakoutLevel = strongestLevel.price;
      outBullish       = true;

      // If retest is toggled on, set global breakoutState, then return false
      if(UseRetest)
      {
         g_breakoutState.breakoutTime   = TimeCurrent();
         g_breakoutState.breakoutLevel  = strongestLevel.price;
         g_breakoutState.isBullish      = true;
         g_breakoutState.awaitingRetest = true;
         g_breakoutState.barsWaiting    = 0;
         g_breakoutState.retestStartTime = TimeCurrent();
         g_breakoutState.retestStartBar = iBarShift(_Symbol, _Period, TimeCurrent(), false);
         if(ShowDebugPrints)
         {
            static datetime lastBreakoutMsg = 0;
            datetime now = TimeCurrent();
            // Only show message once per minute
            if(now - lastBreakoutMsg >= 60)
            {
               Print("✅ [M5.6.b Breakout Detection] Bullish breakout found; awaiting retest.");
               lastBreakoutMsg = now;
            }
         }
         return false;  
      }

      // Return true only if no retest required => safe to place trade
      return true;
   }

   // Bearish breakout
   if(bearishBreak && volumeOK && IsATRDistanceMet(strongestLevel.price, lastClose))
   {
      outBreakoutLevel = strongestLevel.price;
      outBullish       = false;

      if(UseRetest)
      {
         g_breakoutState.breakoutTime   = TimeCurrent();
         g_breakoutState.breakoutLevel  = strongestLevel.price;
         g_breakoutState.isBullish      = false;
         g_breakoutState.awaitingRetest = true;
         g_breakoutState.barsWaiting    = 0;
         g_breakoutState.retestStartTime = TimeCurrent();
         g_breakoutState.retestStartBar = iBarShift(_Symbol, _Period, TimeCurrent(), false);
         if(ShowDebugPrints)
         {
            static datetime lastBreakoutMsg = 0;
            datetime now = TimeCurrent();
            // Only show message once per minute
            if(now - lastBreakoutMsg >= 60)
            {
               Print("✅ [M5.6.c Breakout Detection] Bearish breakout found; awaiting retest.");
               lastBreakoutMsg = now;
            }
         }
         return false;  
      }

      return true;
   }

   // No breakout
   return false;
}

//==================================================================
// MODULE 6: RETEST VALIDATION
//==================================================================

// MODULE 6.1: Candlestick pattern check for retest validation
bool CheckEngulfingPattern(const bool bullish)
{
   // We'll copy two candles from the specified retest timeframe
   MqlRates rates[2];
   ArraySetAsSeries(rates, true);

   if(CopyRates(_Symbol, RetestTimeframe, 0, 2, rates) < 2)
   {
      if(ShowDebugPrints)
         Print("❌ [M6.1.a Pattern Check] Failed fetching candlestick data for retest timeframe. Err=", GetLastError());
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

// MODULE 6.2.1: Check if price is in retest zone
bool IsPriceInRetestZone()
{
   if(!g_breakoutState.awaitingRetest)
      return false;
      
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);  // Use bid for general price reference
   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   
   if(CopyBuffer(g_handleATR, 0, 0, 1, atrBuf) <= 0)
   {
      if(ShowDebugPrints)
         Print("⚠️ [IsPriceInRetestZone] Failed to get ATR value. Using default zone size.");
      return false;
   }
   
   double zoneSize = atrBuf[0] * RetestATRMultiplier;
   double breakoutLevel = g_breakoutState.breakoutLevel;
   
   // For bullish breakout, price should come down to test the breakout level from above
   if(g_breakoutState.isBullish)
   {
      bool inZone = (currentPrice >= breakoutLevel - zoneSize && 
                     currentPrice <= breakoutLevel + zoneSize);
                     
      if(ShowDebugPrints && inZone)
         Print("✅ [IsPriceInRetestZone] Price in bullish retest zone. Price=", currentPrice,
               " Zone=", breakoutLevel-zoneSize, " to ", breakoutLevel+zoneSize);
               
      return inZone;
   }
   // For bearish breakout, price should come up to test the breakout level from below
   else
   {
      bool inZone = (currentPrice >= breakoutLevel - zoneSize && 
                     currentPrice <= breakoutLevel + zoneSize);
                     
      if(ShowDebugPrints && inZone)
         Print("✅ [IsPriceInRetestZone] Price in bearish retest zone. Price=", currentPrice,
               " Zone=", breakoutLevel-zoneSize, " to ", breakoutLevel+zoneSize);
               
      return inZone;
   }
}

// MODULE 6.2: Retest validation and tracking
bool ValidateRetestConditions()
{
   // If user does not want retest, skip it entirely
   if(!UseRetest)
      return true;

   // If there's no breakout awaiting a retest, nothing to do
   if(!g_breakoutState.awaitingRetest)
   {
      if(ShowDebugPrints)
         Print("✅ [M6.2.a Retest Validation] No breakout awaiting retest");
      return true;
   }

   // CRITICAL: Check if we already have an open position
   if(PositionsTotal() > 0)
   {
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(PositionGetSymbol(i) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
         {
            if(ShowDebugPrints)
               Print("❌ [M6.2.a Retest Validation] Position already exists for this symbol and magic number");
            g_breakoutState.awaitingRetest = false;  // Reset retest state
            return false;
         }
      }
   }

   // 1) Compute how many minutes have passed since we started awaiting the retest
   double elapsedSeconds = (TimeCurrent() - g_breakoutState.retestStartTime);
   double elapsedMinutes = elapsedSeconds / 60.0;

   // 2) Determine how many bars have elapsed
   int currentBar      = iBarShift(_Symbol, _Period, TimeCurrent(), false);
   int retestStartBar  = g_breakoutState.retestStartBar;
   int barsElapsed     = retestStartBar - currentBar;

   // Check if the bar count or time limit has been exceeded
   if(elapsedMinutes >= MaxRetestMinutes || barsElapsed >= MaxRetestBars)
   {
      PrintFormat("❌ [M6.2.b Retest Validation] Retest timed out after %.2f minutes and %d bars. Canceling retest.",
                  elapsedMinutes, barsElapsed);
      g_breakoutState.awaitingRetest = false;
      return false;
   }

   // 3) Check if the price is "in zone"
   bool inRetestZone = IsPriceInRetestZone();
   if(inRetestZone)
   {
      PrintFormat(
         "✅ [M6.2.c Retest Validation] Price in retest zone | Direction: %s",
         g_breakoutState.isBullish ? "Bullish" : "Bearish"
      );
      return true;
   }

   // 4) Retest so far not timed out and not confirmed
   return false;
}

//==================================================================
// MODULE 7: RISK MANAGEMENT
//==================================================================

// MODULE 7.1: Position sizing calculation
double CalculateLotSize(double stopLossPoints)
{
   if(stopLossPoints <= 0.0)
   {
      if(ShowDebugPrints)
         Print("⚠️ [M7.1.a Position Sizing] Invalid stop loss distance. Using minimum lot size.");
      return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   }

   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(accountEquity <= 0.0)
   {
      if(ShowDebugPrints)
         Print("⚠️ [M7.1.b Position Sizing] Invalid account equity. Using minimum lot size.");
      return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   }

   // Basic risk calculation
   double riskAmount = accountEquity * (RiskPercentage / 100.0);
   double tickSize   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   if(tickSize <= 0.0 || tickValue <= 0.0)
   {
      if(ShowDebugPrints)
         Print("⚠️ [M7.1.c Position Sizing] Invalid tick size / value. Using minimum lot size.");
      return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   }

   double ticksCount = stopLossPoints / tickSize;
   double lotSize    = riskAmount / (ticksCount * tickValue);

   // Broker constraints
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(lotSize < minLot) lotSize = minLot;
   if(lotSize > maxLot) lotSize = maxLot;

   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   if(lotSize < minLot) lotSize = minLot;

   lotSize = NormalizeDouble(lotSize, 2);
   if(ShowDebugPrints)
      Print("✅ [M7.1.d Position Sizing] Calculated lot size: ", lotSize);
   return lotSize;
}

//==================================================================
// MODULE 8: ORDER MANAGEMENT
//==================================================================

// MODULE 8.1: Trade execution and order management
bool PlaceTrade(bool isBuy, double entryPrice, double slPrice, double tpPrice, double lots)
{
   trade.SetExpertMagicNumber(g_magicNumber);

   double point                = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits               = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double minStopDistPoints    = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double fallbackStopDistance = 5 * minStopDistPoints; // or some multiplier

   // Normalize
   entryPrice = NormalizeDouble(entryPrice, digits);
   slPrice    = NormalizeDouble(slPrice, digits);
   tpPrice    = NormalizeDouble(tpPrice, digits);

   // For a buy, SL must be below entry and above zero
   if(isBuy)
   {
      // 1) If SL >= entryPrice, clamp or skip
      if(slPrice >= entryPrice)
      {
         if(ShowDebugPrints)
            Print("⚠️ [M8.1.a Order Management] SL is not below entry. Clamping or skipping.");
         slPrice = entryPrice - fallbackStopDistance; // clamp approach
      }

      // 2) If SL < some tiny positive threshold, clamp or skip
      if(slPrice <= point)
      {
         // Attempt to clamp once more using fallbackStopDistance
         slPrice = entryPrice - fallbackStopDistance;
         if(slPrice <= point)
         {
            // If still invalid, skip trade
            if(ShowDebugPrints)
               Print("❌ [M8.1.a Order Management] SL is invalid (negative or zero) after clamp. Skipping trade.");
            return false;
         }
      }
   }
   else // Sell
   {
      // 1) If SL <= entryPrice, clamp or skip
      if(slPrice <= entryPrice)
      {
         if(ShowDebugPrints)
            Print("⚠️ [M8.1.a Order Management] SL is not above entry for a Sell. Clamping or skipping.");
         slPrice = entryPrice + fallbackStopDistance; // clamp approach
      }

      // 2) If SL < point, skip
      if(slPrice <= point)
      {
         if(ShowDebugPrints)
            Print("❌ [M8.1.a Order Management] SL is invalid (negative or zero) for a Sell. Skipping trade.");
         return false;
      }
   }

   // Re-normalize after any clamps
   slPrice = NormalizeDouble(slPrice, digits);
   tpPrice = NormalizeDouble(tpPrice, digits);

   // Final logging
   if(ShowDebugPrints)
      Print("✅ [M8.1.a Order Management] PlaceTrade - ", (isBuy ? "Buy" : "Sell"),
            " | lots=", lots,
            " | entry=", entryPrice,
            " | SL=", slPrice,
            " | TP=", tpPrice);

   bool result = isBuy 
               ? trade.Buy(lots, _Symbol, 0, slPrice, tpPrice, "Breakout-Buy")
               : trade.Sell(lots, _Symbol, 0, slPrice, tpPrice, "Breakout-Sell");

   if(!result)
   {
      if(ShowDebugPrints)
         Print("❌ [M8.1.a Order Management] ❌ Order failed. Error=", GetLastError());
      return false;
   }

   // Update multi-entry filter state after successful trade
   g_lastTradeTime = TimeCurrent();
   g_lastTradeBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);  // Record the opening time of the current bar
   g_lastTradeBar = Bars(_Symbol, PERIOD_CURRENT) - 1;  // Current bar index
   g_activeBreakoutZonePrice = entryPrice;
   g_activeBreakoutDirection = isBuy;
   g_inLockout = true;

   if(ShowDebugPrints)
      Print("✅ [M8.1.b Order Management] Multi-entry filter state updated: Bar=", g_lastTradeBar,
            " BarTime=", TimeToString(g_lastTradeBarTime, TIME_DATE|TIME_MINUTES),
            " Level=", g_activeBreakoutZonePrice,
            " Direction=", (isBuy ? "Buy" : "Sell"));

   if(ShowDebugPrints)
      Print("✅ [M8.1.a Order Management] ✅ Order placed at price=", trade.ResultPrice());
   return true;
}

//==================================================================
// MODULE 9: STRATEGY EXECUTION
//==================================================================

// MODULE 9.1: Calculate daily pivot points
void CalculateDailyPivots(string symbol, 
                          double &pivotPoint, 
                          double &r1, double &r2, 
                          double &s1, double &s2)
{
   MqlRates dailyData[];
   // We'll look at the previous daily bar (index=1).
   if(CopyRates(symbol, PERIOD_D1, 1, 2, dailyData) < 2)
   {
      if(ShowDebugPrints)
         Print("⚠️ [PivotCalculation] Can't fetch daily bar data. Using fallback values.");
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

// MODULE 9.2: Set pivot-based SL/TP
void SetPivotSLTP(bool isBuy, double currentPrice, double &slPrice, double &tpPrice)
{
   double pivot, r1, r2, s1, s2;
   CalculateDailyPivots(_Symbol, pivot, r1, r2, s1, s2);
   
   // If we fail to get pivot data or pivot == 0, skip or fallback
   if(pivot <= 0.0)
   {
      if(ShowDebugPrints)
         Print("⚠️ [SetPivotSLTP] Invalid pivot data. Setting default fallback SL/TP.");
      
      // Use ATR-based fallback if available
      double fallbackDist = 30.0 * SymbolInfoDouble(_Symbol, SYMBOL_POINT); // Default fallback
      
      if(g_handleATR != INVALID_HANDLE)
      {
         double atrBuf[];
         ArraySetAsSeries(atrBuf, true);
         if(CopyBuffer(g_handleATR, 0, 0, 1, atrBuf) > 0)
         {
            fallbackDist = atrBuf[0] * ATRMultiplier;
         }
      }
      
      if(isBuy)
      {
         slPrice = currentPrice - fallbackDist;
         tpPrice = currentPrice + fallbackDist;
      }
      else
      {
         slPrice = currentPrice + fallbackDist;
         tpPrice = currentPrice - fallbackDist;
      }
      return;
   }

   // For a bullish breakout
   if(isBuy)
   {
      // Example: place SL at min(pivot, s1) and TP at r1
      slPrice = MathMin(pivot, s1);
      tpPrice = r1;  // or r2 if you want a larger target
      // If pivot < s1, you might pick pivot anyway, or adapt logic
   }
   else
   {
      // For a bearish breakout
      // Example: place SL at max(pivot, r1) and TP at s1
      slPrice = MathMax(pivot, r1);
      tpPrice = s1;  // or s2
   }
   
   // Defensive check: if we ended up with negative or near-zero SL/TP, clamp or log
   if(slPrice <= 0.0)
   {
      if(ShowDebugPrints)
         Print("⚠️ [SetPivotSLTP] SL is invalid or <= 0.0. Clamping to currentPrice.");
      slPrice = currentPrice;
   }
   if(tpPrice <= 0.0)
   {
      if(ShowDebugPrints)
         Print("⚠️ [SetPivotSLTP] TP is invalid or <= 0.0. Clamping to currentPrice.");
      tpPrice = currentPrice;
   }
}

// MODULE 9.3: Execute breakout-retest strategy
void ExecuteBreakoutRetestStrategy(bool isBullish, double breakoutLevel)
{
   // CRITICAL: Check for existing positions and enforce cooldown
   if(PositionsTotal() > 0)
   {
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(PositionGetSymbol(i) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
         {
            if(ShowDebugPrints)
               Print("❌ [M9.3 Strategy Execution] Position already exists for this symbol and magic number");
            return;
         }
      }
   }

   // Enforce minimum time between trades (5 minutes cooldown)
   datetime currentTime = TimeCurrent();
   if(currentTime - g_lastTradeTime < 300)  // 300 seconds = 5 minutes
   {
      if(ShowDebugPrints)
         Print("❌ [M9.3 Strategy Execution] Trade cooldown period still active. Waiting...");
      return;
   }

   // 1) Current price
   double currentPrice = isBullish 
                       ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // 2) Calculate pivot-based SL / TP
   double slPrice, tpPrice;
   SetPivotSLTP(isBullish, currentPrice, slPrice, tpPrice);

   // 3) Calculate lot size the same as before (or however you prefer)
   //    e.g., your existing "CalculateLotSize" logic
   double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pointSize <= 0.0) { pointSize = 0.00001; }
   // Hard-coded example, or your existing calculation:
   double lotSize = 0.01; 

   // 4) Place the trade (reusing your 'PlaceTrade' logic)
   //    Make sure 'PlaceTrade' does any final broker-distance checks
   //    or clamping as needed.
   if(PlaceTrade(isBullish, currentPrice, slPrice, tpPrice, lotSize))
   {
      if(ShowDebugPrints)
         Print("✅ [M9.3 Strategy Execution - Pivot] Trade placed - ",
               (isBullish ? "Buy" : "Sell"), " at ", currentPrice,
               " SL=", slPrice, " TP=", tpPrice);

      // Set breakout zone lockout after successful trade
      g_activeBreakoutZonePrice = breakoutLevel;  
      g_activeBreakoutDirection = isBullish;
      g_inLockout = true;

      if(ShowDebugPrints)
         Print("✅ [M9.3 Strategy Execution] Breakout zone lockout set: Level=", breakoutLevel,
               " Direction=", (isBullish ? "Bullish" : "Bearish"));
   }
   else
   {
      if(ShowDebugPrints)
         Print("❌ [M9.3 Strategy Execution] Trade placement failed.");
   }
}

//==================================================================
// MODULE 10: EA LIFECYCLE
//==================================================================

// MODULE 10.1: EA initialization
int OnInit()
{
   // Initialize ATR indicator handle
   g_handleATR = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
   if(g_handleATR == INVALID_HANDLE)
   {
      if(ShowDebugPrints)
         Print("❌ [M10.1.a Initialization] Failed to create ATR indicator handle");
      return INIT_FAILED;
   }

   if(ShowDebugPrints)
      Print("ℹ️ [M10.1.a Initialization] EA started. Session trading restrictions are ", (RestrictTradingHours ? "enabled" : "disabled"), ".");
   return(INIT_SUCCEEDED);
}

// MODULE 10.2: EA deinitialization
void OnDeinit(const int reason)
{
   // Clean up indicator handle
   if(g_handleATR != INVALID_HANDLE)
      IndicatorRelease(g_handleATR);

   if(ShowDebugPrints)
      Print("ℹ️ [M10.2.a Deinitialization] EA Deinit. Reason=", reason);
}

// MODULE 10.3: Main EA tick
void OnTick()
{
   // Check if trading is allowed in current session
   if(!IsTradeAllowedInSession())
      return;

   // 1) If retest is in progress, see if it is confirmed
   if(g_breakoutState.awaitingRetest)
   {
      bool retestConfirmed = ValidateRetestConditions();
      if(retestConfirmed)
      {
         // Retest confirmed; place trade based on stored breakout state
         ExecuteBreakoutRetestStrategy(g_breakoutState.isBullish,
                                       g_breakoutState.breakoutLevel);
      }
   }
   else
   {
      // 2) Look for a new breakout
      double breakoutLevel = 0.0;
      bool   isBullish     = false;

      bool breakoutConfirmed = DetectBreakoutAndInitRetest(breakoutLevel, isBullish);

      // If breakoutConfirmed == true, that means retest is not required, so go ahead with trade
      if(breakoutConfirmed)
         ExecuteBreakoutRetestStrategy(isBullish, breakoutLevel);
      // If breakoutConfirmed == false, either no breakout or retest is now pending
   }
}
//+------------------------------------------------------------------+
