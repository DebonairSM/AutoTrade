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
input bool   UseVolumeFilter       = true;    // If true, require volume filter
input bool   UseMinATRDistance     = true;    // If true, require minimum ATR breakout distance
input bool   UseRetest             = true;   // If true, enforce a retest before confirming breakout
input bool   ShowDebugPrints       = true;    // If true, print debug logs
input bool   UseCandlestickConfirmation = false; // Set to true if you want to use the engulfing pattern check

// Breakout parameters
input int    BreakoutLookback      = 15;      // Bars to look back for highest/lowest
input int    ATRPeriod             = 10;      // Default ATR period for breakout
input double VolumeFactor          = 1.2;     // e.g., 1.2 means current volume >= 120% of average
input double ATRMultiplier         = 0.3;     // Distance multiple for breakout
input double RetestATRMultiplier   = 0.2;     // Distance multiple for retest
input int    MaxRetestBars         = 10;      // Max bars to wait for retest
input int    MaxRetestMinutes      = 240;     // Max minutes to wait for retest

// Risk management
input double SLMultiplier          = 5.0;     // Stop loss ATR multiplier
input double TPMultiplier          = 5.0;     // Take profit ATR multiplier
input double RiskPercentage        = 5.0;     // Risk per trade (%)

// Session control
input bool   RestrictTradingHours  = true;    // Whether to restrict to sessions
input int    LondonOpenHour        = 3;       // London session open (broker time)
input int    LondonCloseHour       = 11;      // London session close (broker time)
input int    NewYorkOpenHour       = 8;       // NY session open (broker time)
input int    NewYorkCloseHour      = 17;      // NY session close (broker time)
input int    BrokerToLocalOffsetHours = 7;    // Offset hours from broker to local time

// Key level detection parameters
input int    KeyLevelLookback     = 100;     // Bars to look back for key levels [50,300,50]
input int    MinTouchCount        = 3;       // Minimum touches to qualify as key level [2,6,1]
input double TouchZoneSize        = 0.0002;  // Size of zone to consider as "touch" (in price) [0.0001,0.001,0.0001]
input double KeyLevelMinDistance  = 0.0005;  // Minimum distance between key levels [0.0002,0.002,0.0002]

// Strength calculation weights (must sum to 1.0)
input double TouchScoreWeight     = 0.5;     // Weight for number of touches [0.3,0.7,0.1]
input double RecencyWeight        = 0.3;     // Weight for recency of touches [0.2,0.4,0.1]
input double DurationWeight       = 0.2;     // Weight for duration of level validity [0.1,0.3,0.1]

// Level validation
input int    MinLevelDurationHours = 24;     // Minimum hours between first and last touch [12,96,12]
input double MinStrengthThreshold  = 0.6;    // Minimum strength to consider level valid [0.4,0.8,0.1]

// Example input for retest check threshold (in pips) & timeframe for candlestick pattern
input double RetestPipsThreshold = 10;           // Distance from breakout level to consider as a "retest"
input ENUM_TIMEFRAMES RetestTimeframe = PERIOD_M15; // Timeframe to check retest candlestick pattern

//==================================================================
// MODULE 2: GLOBAL STATE MANAGEMENT
//==================================================================
datetime      g_lastBarTime      = 0;
bool          g_hasPositionOpen  = false;
int           g_magicNumber      = 12345;

// Breakout state tracking
double        g_breakoutLevel    = 0.0;
bool          g_isBullishBreak   = false;

struct SBreakoutState
{
   datetime breakoutTime;  
   double   breakoutLevel; 
   bool     isBullish;     
   bool     awaitingRetest; 
   int      barsWaiting;   
};
SBreakoutState g_breakoutState = {0,0.0,false,false,0};

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

//==================================================================
// MODULE 3: STRATEGY CONSTANTS
//==================================================================
const double VOLUME_THRESH   = 1.1;  
const double BO_ATR_MULT     = 0.3;  
const double RT_ATR_MULT     = 0.2;  

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
      Print("[M5.3.a Key Level Detection] ERROR: Strength weights must sum to 1.0. Current sum: ",
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
      Print("[M5.3.a Key Level Detection] KeyLevelLookback too small (", KeyLevelLookback,
            "). No key levels will be found.");
      return false;
   }

   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, KeyLevelLookback, highPrices) <= 0 ||
      CopyLow(_Symbol, PERIOD_CURRENT, 0, KeyLevelLookback, lowPrices) <= 0 ||
      CopyClose(_Symbol, PERIOD_CURRENT, 0, KeyLevelLookback, closePrices) <= 0 ||
      CopyTime(_Symbol, PERIOD_CURRENT, 0, KeyLevelLookback, times) <= 0)
   {
      Print("[M5.3.b Key Level Detection] Failed to copy price data. Error=", GetLastError());
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
   double handle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
   if(CopyBuffer(handle, 0, 0, 1, atrBuf) <= 0)
   {
      Print("[M5.5 ATR Distance Check] Warning: ATR copy failed. Bypassing distance check.");
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
      Print("[M5.6.a Breakout Detection] Failed to copy price or volume data. Err=", GetLastError());
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
      Print("[M5.6.a Breakout Detection] LastClose=", lastClose,
            " | KeyLevel=", strongestLevel.price,
            " | VolumeOK=", volumeOK,
            " | BullishBreak=", bullishBreak,
            " | BearishBreak=", bearishBreak);
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
         if(ShowDebugPrints)
            Print("[M5.6.b Breakout Detection] Bullish breakout found; awaiting retest.");
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
         if(ShowDebugPrints)
            Print("[M5.6.c Breakout Detection] Bearish breakout found; awaiting retest.");
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

// MODULE 6.3: Candlestick pattern check for retest validation
bool CheckEngulfingPattern(const bool bullish)
{
   // We'll copy two candles from the specified retest timeframe
   MqlRates rates[2];
   ArraySetAsSeries(rates, true);

   if(CopyRates(_Symbol, RetestTimeframe, 0, 2, rates) < 2)
   {
      Print("[M6.3.a Pattern Check] Failed fetching candlestick data for retest timeframe. Err=", GetLastError());
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

// MODULE 6.2: Retest validation and tracking
bool ValidateRetestConditions()
{
   // If user does not want retest, skip it entirely
   if(!UseRetest)
      return true;

   // If there's no breakout awaiting a retest, nothing to do
   if(!g_breakoutState.awaitingRetest)
   {
      Print("[M6.2.a Retest Validation] No breakout awaiting retest");
      return true;
   }

   // Check for time-based or bar-count timeout
   double minutesSinceBreakout = (double)(TimeCurrent() - g_breakoutState.breakoutTime) / 60.0;
   if(minutesSinceBreakout > MaxRetestMinutes || g_breakoutState.barsWaiting > MaxRetestBars)
   {
      Print("[M6.2.b Retest Validation] Retest timed out after ", minutesSinceBreakout, " minutes and ", 
            g_breakoutState.barsWaiting, " bars. Canceling retest.");
      g_breakoutState.awaitingRetest = false;
      return false;
   }

   // On each new bar, we can increment g_breakoutState.barsWaiting
   g_breakoutState.barsWaiting++;

   // Distance threshold in points
   double pointSize      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double retestDistance = RetestPipsThreshold * pointSize;

   // For a bullish breakout, let's watch the bid price retest the breakout level
   // For a bearish breakout, watch the ask price retest the breakout level
   double currentPrice = g_breakoutState.isBullish
                      ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Check if current price is within the retest zone
   double diff         = MathAbs(currentPrice - g_breakoutState.breakoutLevel);
   bool   inRetestZone = (diff <= retestDistance);

   if(ShowDebugPrints)
      Print("[M6.2.c Retest Validation] Checking retest | Direction: ", (g_breakoutState.isBullish ? "Bullish" : "Bearish"),
            " | Distance from level: ", NormalizeDouble(diff/pointSize, 1), " pips",
            " | Required: ", NormalizeDouble(retestDistance/pointSize, 1), " pips",
            " | In zone: ", (inRetestZone ? "Yes" : "No"));

   if(inRetestZone)
   {
      // Only check the engulfing pattern if user wants it
      if(UseCandlestickConfirmation)
      {
         bool isPatternValid = CheckEngulfingPattern(g_breakoutState.isBullish);
         if(isPatternValid)
         {
            g_breakoutState.awaitingRetest = false;
            if(ShowDebugPrints)
               Print("[M6.2.d Retest Validation] ✅ Retest confirmed via candlestick pattern.");
            return true;
         }
         else if(ShowDebugPrints)
            Print("[M6.2.e Retest Validation] In retest zone, but no valid candlestick pattern yet.");
      }
      else
      {
         // If optional candlestick confirmation is disabled, confirm retest immediately
         g_breakoutState.awaitingRetest = false;
         if(ShowDebugPrints)
            Print("[M6.2.d Retest Validation] Retest confirmed with no candlestick check (disabled).");
         return true;
      }
   }

   // Not yet confirmed
   return false;
}

//==================================================================
// MODULE 7: RISK MANAGEMENT
//==================================================================

// MODULE 7.1: Position sizing calculation
double CalculateLotSize(double stopLossDistancePoints)
{
   if(stopLossDistancePoints <= 0.0)
   {
      Print("[M7.1.a Position Sizing] Invalid stop loss distance. Using minimum lot size.");
      return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   }

   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(accountEquity <= 0.0)
   {
      Print("[M7.1.b Position Sizing] Invalid account equity. Using minimum lot size.");
      return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   }

   // Basic risk calculation
   double riskAmount = accountEquity * (RiskPercentage / 100.0);
   double tickSize   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   if(tickSize <= 0.0 || tickValue <= 0.0)
   {
      Print("[M7.1.c Position Sizing] Invalid tick size / value. Using minimum lot size.");
      return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   }

   double ticksCount = stopLossDistancePoints / tickSize;
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
      Print("[M7.1.d Position Sizing] Calculated lot size: ", lotSize);
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
         Print("[M8.1.a Order Management] SL is not below entry. Clamping or skipping.");
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
            Print("[M8.1.a Order Management] SL is invalid (negative or zero) after clamp. Skipping trade.");
            return false;
         }
      }
   }
   else // Sell
   {
      // 1) If SL <= entryPrice, clamp or skip
      if(slPrice <= entryPrice)
      {
         Print("[M8.1.a Order Management] SL is not above entry for a Sell. Clamping or skipping.");
         slPrice = entryPrice + fallbackStopDistance; // clamp approach
      }

      // 2) If SL < point, skip
      if(slPrice <= point)
      {
         Print("[M8.1.a Order Management] SL is invalid (negative or zero) for a Sell. Skipping trade.");
         return false;
      }
   }

   // Re-normalize after any clamps
   slPrice = NormalizeDouble(slPrice, digits);
   tpPrice = NormalizeDouble(tpPrice, digits);

   // Final logging
   Print("[M8.1.a Order Management] PlaceTrade - ", (isBuy ? "Buy" : "Sell"),
         " | lots=", lots,
         " | entry=", entryPrice,
         " | SL=", slPrice,
         " | TP=", tpPrice);

   bool result = isBuy 
               ? trade.Buy(lots, _Symbol, 0, slPrice, tpPrice, "Breakout-Buy")
               : trade.Sell(lots, _Symbol, 0, slPrice, tpPrice, "Breakout-Sell");

   if(!result)
   {
      Print("[M8.1.a Order Management] ❌ Order failed. Error=", GetLastError());
      return false;
   }

   Print("[M8.1.a Order Management] ✅ Order placed at price=", trade.ResultPrice());
   return true;
}

//==================================================================
// MODULE 9: STRATEGY EXECUTION
//==================================================================

//------------------------------------------------------------------//
// 1) Calculate daily pivot points
//------------------------------------------------------------------//
void CalculateDailyPivots(string symbol, 
                          double &pivotPoint, 
                          double &r1, double &r2, 
                          double &s1, double &s2)
{
   MqlRates dailyData[];
   // We'll look at the previous daily bar (index=1).
   if(CopyRates(symbol, PERIOD_D1, 1, 2, dailyData) < 2)
   {
      Print("[PivotCalculation] Can't fetch daily bar data. Using fallback values.");
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

//------------------------------------------------------------------//
// 2) Set pivot-based SL/TP
//------------------------------------------------------------------//
void SetPivotSLTP(bool isBuy, double currentPrice, double &slPrice, double &tpPrice)
{
   double pivot, r1, r2, s1, s2;
   CalculateDailyPivots(_Symbol, pivot, r1, r2, s1, s2);
   
   // If we fail to get pivot data or pivot == 0, skip or fallback
   if(pivot <= 0.0)
   {
      Print("[SetPivotSLTP] Invalid pivot data. Setting default fallback SL/TP.");
      // Fallback: 30 pips away each, for instance
      double fallbackDist = 30.0 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
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
      Print("[SetPivotSLTP] SL is invalid or <= 0.0. Clamping to currentPrice.");
      slPrice = currentPrice;
   }
   if(tpPrice <= 0.0)
   {
      Print("[SetPivotSLTP] TP is invalid or <= 0.0. Clamping to currentPrice.");
      tpPrice = currentPrice;
   }
}

//------------------------------------------------------------------//
// 3) Revised ExecuteBreakoutRetestStrategy using pivot SL/TP
//------------------------------------------------------------------//
void ExecuteBreakoutRetestStrategy(bool isBullish, double breakoutLevel)
{
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
      Print("[M9.1 Strategy Execution - Pivot] Trade placed - ",
            (isBullish ? "Buy" : "Sell"), " at ", currentPrice,
            " SL=", slPrice, " TP=", tpPrice);
   else
      Print("[M9.1 Strategy Execution - Pivot] Trade placement failed.");
}

//==================================================================
// MODULE 10: EA LIFECYCLE
//==================================================================

// MODULE 10.1: EA initialization
int OnInit()
{
   Print("[M10.1.a Initialization] EA started in DEBUG mode. Sessions bypassed.");
   return(INIT_SUCCEEDED);
}

// MODULE 10.2: EA deinitialization
void OnDeinit(const int reason)
{
   Print("[M10.2.a Deinitialization] EA Deinit. Reason=", reason);
}

// MODULE 10.3: Main EA tick
void OnTick()
{
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
