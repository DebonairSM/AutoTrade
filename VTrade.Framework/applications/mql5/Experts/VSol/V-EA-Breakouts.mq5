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
input bool   UseRetest             = false;   // If true, enforce a retest before confirming breakout
input bool   ShowDebugPrints       = true;    // If true, print debug logs

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
// [Optional] Breakout Logic Support Functions
//==================================================================

// Check volume filter requirement
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

// Check ATR-based distance requirement
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
      Print("Warning: ATR copy failed. Bypassing distance check.");
      return true;
   }
   double currentATR    = atrBuf[0];
   double minBreakoutDist= currentATR * ATRMultiplier;

   // For bullish breakout: (currentClose - highestHigh)
   // For bearish breakout: (lowestLow - currentClose)
   double distance = MathAbs(currentClose - breakoutLevel);
   return (distance >= minBreakoutDist);
}

// Optional stub for retest check
bool CheckRetestIfNeeded()
{
   // If user does not want retest logic, return true (i.e., skip retest completely)
   if(!UseRetest)
      return true;

   // Otherwise, put your actual retest checks here
   // For demonstration, it still returns false (no successful retest).
   return false;
}

//==================================================================
// Key Level Detection Functions
//==================================================================

// Check if a price point is near an existing key level
bool IsNearExistingLevel(const double price, const SKeyLevel &levels[], const int count)
{
   for(int i = 0; i < count; i++)
   {
      if(MathAbs(price - levels[i].price) < KeyLevelMinDistance)
         return true;
   }
   return false;
}

// Calculate level strength based on touches and recency
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

// Find and update key price levels
bool FindKeyLevels(SKeyLevel &outStrongestLevel)
{
   // Validate weights sum to 1.0
   if(MathAbs(TouchScoreWeight + RecencyWeight + DurationWeight - 1.0) > 0.001)
   {
      Print("ERROR: Strength weights must sum to 1.0. Current sum: ",
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
   // If so, consider skipping or adjusting the logic to avoid out-of-bounds.
   if(KeyLevelLookback < 3)
   {
      Print(__FUNCTION__, ": KeyLevelLookback too small (", KeyLevelLookback,
            "). No key levels will be found.");
      return false;
   }

   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, KeyLevelLookback, highPrices) <= 0 ||
      CopyLow(_Symbol, PERIOD_CURRENT, 0, KeyLevelLookback, lowPrices) <= 0 ||
      CopyClose(_Symbol, PERIOD_CURRENT, 0, KeyLevelLookback, closePrices) <= 0 ||
      CopyTime(_Symbol, PERIOD_CURRENT, 0, KeyLevelLookback, times) <= 0)
   {
      Print(__FUNCTION__, ": Failed to copy price data. Error=", GetLastError());
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
         Print("Found ", levelCount, " key levels. Strongest level: ",
               "Price=", outStrongestLevel.price,
               ", Type=", (outStrongestLevel.isResistance ? "Resistance" : "Support"),
               ", Touches=", outStrongestLevel.touchCount,
               ", Strength=", outStrongestLevel.strength,
               ", Duration=", (double)(outStrongestLevel.lastTouch - outStrongestLevel.firstTouch) / 3600.0, " hours");
      }
      
      return true;
   }
   
   return false;
}

//==================================================================
// MODULE 5: BREAKOUT DETECTION
//==================================================================
double s_testSLdistance = 0.001;  
double s_testTPdistance = 0.001;  

bool DetectBreakoutRetest(double &outBreakoutLevel, bool &outBullish)
{
   // Find key levels first
   SKeyLevel strongestLevel;
   if(!FindKeyLevels(strongestLevel))
   {
      if(ShowDebugPrints)
         Print("No strong key levels found. Skipping breakout detection.");
      return false;
   }

   // Prepare data arrays
   double highPrices[];
   double lowPrices[];
   double closePrices[];
   long   volumes[];

   ArraySetAsSeries(highPrices, true);
   ArraySetAsSeries(lowPrices, true);
   ArraySetAsSeries(closePrices, true);
   ArraySetAsSeries(volumes, true);

   int bars_to_copy = (int)BreakoutLookback + 1;

   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, bars_to_copy, highPrices) <= 0 ||
      CopyLow(_Symbol, PERIOD_CURRENT, 0, bars_to_copy, lowPrices) <= 0 ||
      CopyClose(_Symbol, PERIOD_CURRENT, 0, bars_to_copy, closePrices) <= 0 ||
      CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, bars_to_copy, volumes) <= 0)
   {
      Print(__FUNCTION__,": Failed to copy price or volume data. Err=", GetLastError());
      return false;
   }

   double currentClose = closePrices[0];
   double pipPoint     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // Check volume requirements
   bool volumeOK = DoesVolumeMeetRequirement(volumes, (int)BreakoutLookback);

   // Evaluate breakout based on key level
   bool bullishBreak = (currentClose > (strongestLevel.price + pipPoint));
   bool bearishBreak = (currentClose < (strongestLevel.price - pipPoint));

   // Debug logs
   if(ShowDebugPrints)
   {
      Print("=== DetectBreakoutRetest Debug ===");
      Print("Close=", currentClose, " | Key Level=", strongestLevel.price, 
            " | Type=", (strongestLevel.isResistance ? "Resistance" : "Support"),
            " | Strength=", strongestLevel.strength);
      Print("UseVolumeFilter=", UseVolumeFilter, ", VolumeOK=", volumeOK);
      Print("UseMinATRDistance=", UseMinATRDistance, ", ATRMult=", ATRMultiplier);
      Print("UseRetest=", UseRetest, ", RetestATRMult=", RetestATRMultiplier);
      Print("BullishBreak=", bullishBreak, " | BearishBreak=", bearishBreak);
   }

   // Bullish breakout
   if(bullishBreak && volumeOK && IsATRDistanceMet(currentClose, strongestLevel.price))
   {
      outBreakoutLevel = strongestLevel.price;
      outBullish       = true;

      // Combine skip logic with the retest result
      bool retestPassed = CheckRetestIfNeeded();
      if(retestPassed)
         return true;
      return false;
   }

   // Bearish breakout
   if(bearishBreak && volumeOK && IsATRDistanceMet(strongestLevel.price, currentClose))
   {
      outBreakoutLevel = strongestLevel.price;
      outBullish       = false;

      bool retestPassed = CheckRetestIfNeeded();
      if(retestPassed)
         return true;
      return false;
   }

   // Not a breakout
   return false;
}

//==================================================================
// MODULE 6: RISK MANAGEMENT
//==================================================================
double CalculateLotSize(double stopLossDistancePoints)
{
   if(stopLossDistancePoints <= 0.0)
   {
      Print("Invalid stop loss distance. Using minimum lot size.");
      return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   }

   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(accountEquity <= 0.0)
   {
      Print("Invalid account equity. Using minimum lot size.");
      return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   }

   // Basic risk calculation
   double riskAmount = accountEquity * (RiskPercentage / 100.0);
   double tickSize   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   if(tickSize <= 0.0 || tickValue <= 0.0)
   {
      Print("Invalid tick size / value. Using minimum lot size.");
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
      Print("Calculated lot size: ", lotSize);
   return lotSize;
}

//==================================================================
// MODULE 7: ORDER MANAGEMENT
//==================================================================
bool PlaceTrade(bool isBuy, double entryPrice, double slPrice, double tpPrice, double lots)
{
   trade.SetExpertMagicNumber(g_magicNumber);
   double point       = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits      = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double minStopDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;

   entryPrice = NormalizeDouble(entryPrice, digits);
   slPrice    = NormalizeDouble(slPrice,    digits);
   tpPrice    = NormalizeDouble(tpPrice,    digits);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(isBuy)
   {
      double slDistance = entryPrice - slPrice;
      double tpDistance = tpPrice - entryPrice;
      if(slDistance < minStopDist)
      {
         slPrice = entryPrice - minStopDist;
         Print("Warning: SL adjusted for minimum stop distance");
      }
      if(tpDistance < minStopDist)
      {
         tpPrice = entryPrice + minStopDist;
         Print("Warning: TP adjusted for minimum stop distance");
      }
   }
   else
   {
      double slDistance = slPrice - entryPrice;
      double tpDistance = entryPrice - tpPrice;
      if(slDistance < minStopDist)
      {
         slPrice = entryPrice + minStopDist;
         Print("Warning: SL adjusted for minimum stop distance");
      }
      if(tpDistance < minStopDist)
      {
         tpPrice = entryPrice - minStopDist;
         Print("Warning: TP adjusted for minimum stop distance");
      }
   }

   slPrice = NormalizeDouble(slPrice, digits);
   tpPrice = NormalizeDouble(tpPrice, digits);

#ifdef _DEBUG
   Print("PlaceTrade - ", (isBuy?"Buy":"Sell"),
         " | lots=", lots,
         " | entry=", entryPrice,
         " | SL=", slPrice,
         " | TP=", tpPrice);
#endif

   bool result = isBuy 
               ? trade.Buy(lots, _Symbol, 0, slPrice, tpPrice, "Breakout-Buy")
               : trade.Sell(lots, _Symbol, 0, slPrice, tpPrice, "Breakout-Sell");

   if(!result)
   {
      Print(__FUNCTION__,"(): ❌ Order failed. Error=", GetLastError());
      return false;
   }
   Print(__FUNCTION__,"(): ✅ Order placed at price=", trade.ResultPrice());
   return true;
}

//==================================================================
// MODULE 8: STRATEGY EXECUTION
//==================================================================
void ExecuteBreakoutRetestStrategy()
{
   double foundBreakoutLevel = 0.0;
   bool   isBullish          = false;

   // 1) Check for a valid breakout
   bool foundBreakout = DetectBreakoutRetest(foundBreakoutLevel, isBullish);
   if(!foundBreakout)
   {
      if(ShowDebugPrints) Print("No breakout. Skipping entry logic.");
      return;
   }

   // 2) Compute SL / TP from ATR
   double theATR = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
   if(theATR <= 0.0)
   {
      Print("No valid ATR. Using default distances.");
      theATR = 0.001; 
   }
   double slDistance = SLMultiplier * theATR;
   double tpDistance = TPMultiplier * theATR;

   // 3) Grab current price depending on direction
   double currentPrice = isBullish
                       ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // 4) SL and TP
   double slPrice = isBullish ? (currentPrice - slDistance) : (currentPrice + slDistance);
   double tpPrice = isBullish ? (currentPrice + tpDistance) : (currentPrice - tpDistance);

   // 5) Calculate lots based on SL distance
   double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pointSize <= 0.0)
   {
      Print("Invalid point size. Using fallback.");
      pointSize = 0.00001; 
   }
   double slDistancePoints = MathAbs(currentPrice - slPrice) / pointSize;
   double lotSize = CalculateLotSize(slDistancePoints);
   if(lotSize <= 0.0)
   {
      Print("Failed lot size. No trade taken.");
      return;
   }

   // 6) Place trade
   if(PlaceTrade(isBullish, currentPrice, slPrice, tpPrice, lotSize))
      Print("Trade placed - Type=", (isBullish ? "Buy" : "Sell"));
   else
      Print("Trade failed to place.");
}

//==================================================================
// MODULE 9: EA LIFECYCLE
//==================================================================
int OnInit()
{
#ifdef _DEBUG
   Print("OnInit: EA started in DEBUG mode. Sessions bypassed.");
#endif
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Print("== V-EA-Breakouts: Deinit. Reason=", reason);
}

void OnTick()
{
#ifdef _DEBUG
   Print("OnTick: Tick at ", TimeToString(TimeCurrent()));
#endif

   // Example usage in a live environment:
   // You might call your full strategy from OnTick or OnTimer, etc.
   // For demonstration, we detect breakouts every tick:
   double breakoutLevel = 0.0;
   bool   isBullish     = false;
   bool   foundBreakout = DetectBreakoutRetest(breakoutLevel, isBullish);

   if(foundBreakout)
   {
#ifdef _DEBUG
      Print("OnTick: Found a breakout at level=", breakoutLevel, 
            " direction=", (isBullish?"Bullish":"Bearish"));
#endif
      // For debugging, place small test trade
      double slPrice, tpPrice;
      int    digits   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      double pipPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

      if(isBullish)
      {
         slPrice = breakoutLevel - s_testSLdistance;
         tpPrice = breakoutLevel + s_testTPdistance;
         slPrice = NormalizeDouble(slPrice, digits);
         tpPrice = NormalizeDouble(tpPrice, digits);
         trade.Buy(0.01, _Symbol, 0, slPrice, tpPrice);
      }
      else
      {
         slPrice = breakoutLevel + s_testSLdistance;
         tpPrice = breakoutLevel - s_testTPdistance;
         slPrice = NormalizeDouble(slPrice, digits);
         tpPrice = NormalizeDouble(tpPrice, digits);
         trade.Sell(0.01, _Symbol, 0, slPrice, tpPrice);
      }
   }
   else
   {
#ifdef _DEBUG
      Print("OnTick: No breakout this tick.");
#endif
   }
}
//+------------------------------------------------------------------+