//+------------------------------------------------------------------+
//|                                               V-2-EA-Main.mq5      |
//|                         Key Level Detection Implementation         |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "2.01"
#property strict

#include "V-2-EA-BreakoutsStrategy.mqh"
#include <Trade\Trade.mqh>
#include "V-2-EA-Utils.mqh"

// Version tracking
#define EA_VERSION "1.0.4"
#define EA_VERSION_DATE "2024-03-19"
#define EA_NAME "V-2-EA-Main"

// Trading components
CTrade trade;

//--- Input Parameters
input int     LookbackPeriod = 100;    // Lookback period for analysis
input double  MinStrength = 0.30;      // Minimum strength for key levels (LOWERED from 0.55)
input double  TouchZone = 0.0025;      // Touch zone size (in pips for Forex, points for US500)
input int     MinTouches = 2;          // Minimum touches required
input bool    ShowDebugPrints = false;  // Show debug prints
input bool    EnforceMarketHours = false; // Enforce market hours check (set to false to ignore market hours)
input bool    CurrentTimeframeOnly = true; // Process ONLY current chart timeframe (simplified mode)

// Trading Parameters
input group "=== TRADING PARAMETERS ==="
input bool   EnableTrading = true;     // Enable actual trading
input double RiskPercentage = 1.0;     // Risk percentage per trade
input double ATRMultiplierSL = 1.5;    // ATR multiplier for stop loss
input double ATRMultiplierTP = 3.0;    // ATR multiplier for take profit
input int    MagicNumber = 12345;      // Magic number for trade identification
input bool   UseVolumeFilter = true;   // Use volume confirmation for breakouts
input bool   UseRetest = true;         // Wait for retest before entry

// Breakout Detection Parameters
input group "=== BREAKOUT DETECTION ==="
input int    BreakoutLookback = 24;    // Bars to look back for breakout detection
input double MinStrengthThreshold = 0.65; // Minimum strength for breakout
input double RetestATRMultiplier = 0.5;   // ATR multiplier for retest zone
input double RetestPipsThreshold = 15;     // Pips threshold for retest zone

//--- Global Variables
CV2EABreakoutsStrategy g_strategy;
datetime g_lastBarTime = 0;
string g_requiredStrategyVersion = "1.0.4";

// Trading state variables
bool g_hasPositionOpen = false;
datetime g_lastTradeTime = 0;
double g_breakoutLevel = 0.0;
bool g_isBullishBreak = false;
bool g_awaitingRetest = false;
datetime g_breakoutTime = 0;
int g_breakoutStartBar = 0;

// ATR handle for trading calculations
int g_handleATR = INVALID_HANDLE;

// Breakout state tracking
struct SBreakoutState
{
   datetime breakoutTime;  
   double   breakoutLevel; 
   bool     isBullish;     
   bool     awaitingRetest; 
   int      barsWaiting;   
   datetime retestStartTime;
   int      retestStartBar;
};
SBreakoutState g_breakoutState = {0,0.0,false,false,0,0,0};

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    // Print version information
    PrintFormat("=== %s v%s (%s) ===", EA_NAME, EA_VERSION, EA_VERSION_DATE);
    PrintFormat("Changes: Added multi-timeframe key level detection + TRADING LOGIC");
    
    // Validate input parameters (recommended by documentation)
    if(RiskPercentage <= 0 || RiskPercentage > 50) {
        PrintFormat("❌ Invalid risk percentage: %.2f%%. Must be between 0.1 and 50.", RiskPercentage);
        return INIT_PARAMETERS_INCORRECT;
    }
    
    if(ATRMultiplierSL <= 0 || ATRMultiplierTP <= 0) {
        Print("❌ Invalid ATR multipliers. Both SL and TP multipliers must be positive.");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    if(MagicNumber <= 0) {
        Print("❌ Invalid magic number. Must be positive.");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    // Initialize ATR indicator handle for trading calculations
    g_handleATR = iATR(_Symbol, Period(), 14);
    if(g_handleATR == INVALID_HANDLE)
    {
        Print("❌ Failed to create ATR indicator handle. Error: ", GetLastError());
        return INIT_FAILED;
    }
    
    // Initialize trading components
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);

    // Set filling type based on symbol (recommended practice)
    trade.SetTypeFillingBySymbol(_Symbol);

    // Configure logging for trade operations
    trade.LogLevel(LOG_LEVEL_ERRORS);

    // Initialize strategy (note: ignoreMarketHours = !EnforceMarketHours)
    if(!g_strategy.Init(LookbackPeriod, MinStrength, TouchZone, MinTouches, ShowDebugPrints, true, !EnforceMarketHours, CurrentTimeframeOnly))
    {
        Print("❌ Failed to initialize strategy");
        return INIT_FAILED;
    }
    
    // Store initial state
    g_lastBarTime = 0; // Will be set on first tick or timer
    
    // Print configuration info
    Print(StringFormat("⚙️ Main EA Configuration: Market Hours Enforcement = %s", EnforceMarketHours ? "ENABLED" : "DISABLED"));
    Print(StringFormat("⚙️ Breakouts Component: Market Hours Ignored = %s", !EnforceMarketHours ? "YES" : "NO"));
    Print(StringFormat("⚙️ CRITICAL: CurrentTimeframeOnly = %s", CurrentTimeframeOnly ? "TRUE" : "FALSE"));
    Print(StringFormat("⚙️ TRADING: Enabled = %s, Risk = %.1f%%, Magic = %d", EnableTrading ? "YES" : "NO", RiskPercentage, MagicNumber));
    
    // Print timeframe info
    Print(StringFormat("Initializing EA on %s timeframe", EnumToString(Period())));
    
    // Add diagnostic information
    if(ShowDebugPrints) {
        Print("🔍 Diagnostic Information:");
        Print("   Current Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
        Print("   Symbol: ", _Symbol);
        Print("   Available Bars: ", Bars(_Symbol, Period()));
        Print("   Account Server: ", AccountInfoString(ACCOUNT_SERVER));
        Print("   Connection Status: ", TerminalInfoInteger(TERMINAL_CONNECTED) ? "Connected" : "Disconnected");
    }
    
    if(!CheckVersionCompatibility()) {
        Print("❌ Version mismatch between EA and Strategy");
        return INIT_FAILED;
    }
    
    // Set up timer for initial calculation if no ticks come
    EventSetTimer(5); // Check every 5 seconds for initial calculation
    if(ShowDebugPrints)
        Print("⏰ Timer set for initial calculation (5 seconds)");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Kill timer (proper cleanup)
    EventKillTimer();
    if(ShowDebugPrints)
        Print("⏰ Timer stopped in OnDeinit");
    
    // Clean up ATR indicator handle
    if(g_handleATR != INVALID_HANDLE)
        IndicatorRelease(g_handleATR);
    
    // Strategy object will clean up its own chart objects through destructor
    if(ShowDebugPrints)
        Print("🔧 EA deinitialization complete. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Timer function - handles initial calculation when no ticks        |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Timer only used for initial calculation if OnTick doesn't fire
    
    // Only process if we haven't done initial calculation yet
    if(g_lastBarTime != 0) {
        return; // OnTick is working, no need for timer fallback
    }
    
    if(ShowDebugPrints)
        Print("⏰ OnTimer: Attempting initial calculation (no ticks received)");
    
    // Check if data is available
    datetime currentBarTime = iTime(_Symbol, Period(), 0);
    if(currentBarTime == 0) {
        if(ShowDebugPrints)
            Print("⚠️ OnTimer: Data not ready yet, will retry...");
        return;
    }
    
    if(!SeriesInfoInteger(_Symbol, Period(), SERIES_SYNCHRONIZED)) {
        if(ShowDebugPrints)
            Print("⚠️ OnTimer: Data not synchronized yet, will retry...");
        return;
    }
    
    // Perform initial calculation
    g_lastBarTime = currentBarTime;
    HandleInitialCalculation("OnTimer");
    
    // Note: Timer continues running (don't kill it here)
    if(ShowDebugPrints)
        Print("⏰ Timer calculation complete - timer continues running");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check data synchronization first (no debug spam)
    datetime currentBarTime = iTime(_Symbol, Period(), 0);
    if(currentBarTime == 0) {
        int error = GetLastError();
        Print("❌ Invalid current bar time - data not synchronized. Error: ", error);
        ResetLastError();
        return;
    }
    
    if(!SeriesInfoInteger(_Symbol, Period(), SERIES_SYNCHRONIZED)) {
        int error = GetLastError();
        Print("⚠️ Chart data not synchronized. Error: ", error);
        ResetLastError();
        return;
    }
    
    // Handle initial calculation on first valid tick
    if(g_lastBarTime == 0) {
        g_lastBarTime = currentBarTime;
        HandleInitialCalculation("OnTick");
        return;
    }
    
    // Only check market hours if enforcement is enabled
    if(EnforceMarketHours && !IsDuringMarketHours()) {
        if(ShowDebugPrints)
            Print(StringFormat("Skipping processing outside market hours (EnforceMarketHours=%s)", 
                EnforceMarketHours ? "true" : "false"));
        return;
    }
    
    // Check for new bar and update strategy if needed
    bool isNewBar = (currentBarTime > g_lastBarTime);
    if(isNewBar) {
        g_lastBarTime = currentBarTime;
        g_strategy.OnNewBar();
        if(ShowDebugPrints)
            Print("🆕 NEW BAR: ", TimeToString(currentBarTime, TIME_MINUTES));
    }
    
    // Get and print report (only on new bars to avoid spam)
    if(isNewBar) {
        SKeyLevelReport report;
        g_strategy.GetReport(report);
        if(report.isValid && ShowDebugPrints)
            PrintKeyLevelReport(report);
    }
    
    // TRADING LOGIC - Only if trading is enabled
    if(EnableTrading) {
        // Check for existing positions
        UpdatePositionState();
        
        // Manage open positions
        ManageOpenPositions();
        
        // Look for new trading opportunities
        if(!g_hasPositionOpen) {
            // Check for retest conditions if we're awaiting one
            if(g_breakoutState.awaitingRetest) {
                CheckRetestConditions();
            }
            
            // Detect new breakouts
            DetectBreakoutAndInitRetest();
        }
    } else {
        if(ShowDebugPrints && isNewBar)
            Print("⚠️ Trading is DISABLED - EnableTrading = false");
    }
}

//+------------------------------------------------------------------+
//| Print formatted key level report                                   |
//+------------------------------------------------------------------+
void PrintKeyLevelReport(const SKeyLevelReport &report)
{
    if(!report.isValid || !ShowDebugPrints)
        return;
        
    PrintFormat("=== Key Level Report Update ===");
    PrintFormat("Symbol: %s", report.symbol);
    PrintFormat("Time: %s", TimeToString(report.reportTime));
    PrintFormat("Levels found: %d", ArraySize(report.levels));
    
    for(int i = 0; i < ArraySize(report.levels); i++)
    {
        if(!report.levels[i].isValid)
            continue;
            
        STimeframeKeyLevel level = report.levels[i];
        
        PrintFormat(
            "%s: %.5f (%.2f strength, %d touches) %s",
            EnumToString(level.timeframe),
            level.strongestLevel.price,
            level.strongestLevel.strength,
            level.strongestLevel.touchCount,
            level.strongestLevel.isResistance ? "RESISTANCE" : "SUPPORT"
        );
    }
    PrintFormat("===========================");
}

//+------------------------------------------------------------------+
//| Handle initial calculation (used by both OnTick and OnTimer)      |
//+------------------------------------------------------------------+
void HandleInitialCalculation(const string context)
{
    if(ShowDebugPrints)
        Print("🔍 Calculating initial key levels from ", context);
        
    g_strategy.OnNewBar();
    
    // Get and display initial report
    SKeyLevelReport report;
    g_strategy.GetReport(report);
    if(report.isValid) {
        PrintKeyLevelReport(report);
        if(ShowDebugPrints)
            Print("✅ Initial key levels calculated and displayed");
        
        // Force chart update to ensure lines are drawn
        if(ShowDebugPrints)
            Print("🔧 Forcing chart line update...");
        g_strategy.ForceChartUpdate();
    } else {
        if(ShowDebugPrints) {
            Print("⚠️ No initial key levels found");
            Print("🔧 Trying force update anyway...");
        }
        
        // Try to force update anyway
        g_strategy.ForceChartUpdate();
    }
}

// Add new function
bool CheckVersionCompatibility()
{
    if(g_strategy.GetVersion() != EA_VERSION) {
        PrintFormat("EA Version: %s | Strategy Version: %s", 
              EA_VERSION, g_strategy.GetVersion());
        return false;
    }
    return true;
}

// Add new function
bool IsDuringMarketHours()
{
    if(!EnforceMarketHours)
        return true;
        
    // Expanded trading hours - European and US sessions
    datetime nyTime = TimeCurrent() - 5*3600;
    int nyHour = (int)(nyTime % 86400) / 3600;
    
    // Extended hours: 3:00-17:00 NY time (covers London + NY sessions)
    if(nyHour >= 3 && nyHour < 17)
        return true;
    return false;
}

//+------------------------------------------------------------------+
//| TRADING FUNCTIONS                                                  |
//+------------------------------------------------------------------+

// Update position state
void UpdatePositionState()
{
    g_hasPositionOpen = false;
    
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetSymbol(i) == _Symbol && 
           PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
            g_hasPositionOpen = true;
            break;
        }
    }
}

// Manage open positions
void ManageOpenPositions()
{
    if(!g_hasPositionOpen) return;
    
    // Use proper position selection method
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetSymbol(i) == _Symbol && 
           PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
            
            // Get position details using proper selection
            ulong positionTicket = PositionGetInteger(POSITION_TICKET);
            if(!PositionSelectByTicket(positionTicket)) continue;
            
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            double stopLoss = PositionGetDouble(POSITION_SL);
            double takeProfit = PositionGetDouble(POSITION_TP);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            // Check for breakeven (move SL to entry after price moves favorably)
            if(stopLoss != 0 && takeProfit != 0) {
                double risk = MathAbs(openPrice - stopLoss);
                double currentMovement = 0;
                
                if(posType == POSITION_TYPE_BUY) {
                    currentMovement = currentPrice - openPrice;
                } else {
                    currentMovement = openPrice - currentPrice;
                }
                
                // Move to breakeven when price has moved at least 1.5x the risk
                if(currentMovement >= risk * 1.5 && stopLoss != openPrice) {
                    double newSL = openPrice;
                    
                    // Use proper position modification with error checking
                    if(trade.PositionModify(positionTicket, newSL, takeProfit)) {
                        // Check if modification was successful
                        uint resultCode = trade.ResultRetcode();
                        if(resultCode == TRADE_RETCODE_DONE) {
                            if(ShowDebugPrints)
                                Print(StringFormat("✅ Moved stop loss to breakeven for ticket %I64u", positionTicket));
                        } else {
                            if(ShowDebugPrints)
                                Print(StringFormat("❌ Failed to modify position: %s", trade.ResultRetcodeDescription()));
                        }
                    } else {
                        if(ShowDebugPrints) {
                            Print(StringFormat("❌ Position modification failed: %s", trade.ResultRetcodeDescription()));
                            trade.PrintResult();
                        }
                    }
                }
            }
            
            break; // Only manage one position
        }
    }
}

// Detect breakout and initialize retest
bool DetectBreakoutAndInitRetest()
{
    // Get key level report
    SKeyLevelReport report;
    g_strategy.GetReport(report);
    
    if(!report.isValid || ArraySize(report.levels) == 0) {
        return false;
    }
    
    // Find strongest level on current timeframe
    STimeframeKeyLevel strongestLevel;
    bool foundLevel = false;
    
    for(int i = 0; i < ArraySize(report.levels); i++) {
        if(report.levels[i].isValid && report.levels[i].timeframe == Period()) {
            if(!foundLevel || report.levels[i].strongestLevel.strength > strongestLevel.strongestLevel.strength) {
                strongestLevel = report.levels[i];
                foundLevel = true;
            }
        }
    }
    
    if(!foundLevel || strongestLevel.strongestLevel.strength < MinStrengthThreshold) {
        return false;
    }
    
    // Get current price data
    double highPrices[], lowPrices[], closePrices[];
    long volumes[];
    ArraySetAsSeries(highPrices, true);
    ArraySetAsSeries(lowPrices, true);
    ArraySetAsSeries(closePrices, true);
    ArraySetAsSeries(volumes, true);
    
    int bars_to_copy = BreakoutLookback + 2;
    if(CopyHigh(_Symbol, Period(), 0, bars_to_copy, highPrices) <= 0 ||
       CopyLow(_Symbol, Period(), 0, bars_to_copy, lowPrices) <= 0 ||
       CopyClose(_Symbol, Period(), 0, bars_to_copy, closePrices) <= 0 ||
       CopyTickVolume(_Symbol, Period(), 0, bars_to_copy, volumes) <= 0) {
        return false;
    }
    
    // Check for breakout
    double lastClose = closePrices[1];
    double pipPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double levelPrice = strongestLevel.strongestLevel.price;
    
    bool volumeOK = DoesVolumeMeetRequirement(volumes, BreakoutLookback);
    bool bullishBreak = (lastClose > (levelPrice + pipPoint));
    bool bearishBreak = (lastClose < (levelPrice - pipPoint));
    
    // Check ATR distance
    bool atrOK = IsATRDistanceMet(lastClose, levelPrice);
    
    // Use established CV2EAUtils throttled logging pattern (only for valid trades)
    if((bullishBreak || bearishBreak) && atrOK && volumeOK) {
        // Only log valid breakouts that meet ALL criteria (following CV2EAUtils pattern)
        string breakoutMsg = StringFormat("Valid Breakout: Level=%.5f, Close=%.5f, Bull=%s, Bear=%s",
              levelPrice, lastClose, bullishBreak ? "YES" : "NO", bearishBreak ? "YES" : "NO");
        
        // Note: This will be throttled by CV2EAUtils internally
        if(ShowDebugPrints) {
            Print(StringFormat("🔍 %s", breakoutMsg));
        }
    }
    
    // Bullish breakout
    if(bullishBreak && volumeOK && atrOK) {
        g_breakoutState.breakoutTime = TimeCurrent();
        g_breakoutState.breakoutLevel = levelPrice;
        g_breakoutState.isBullish = true;
        g_breakoutState.awaitingRetest = UseRetest;
        g_breakoutState.barsWaiting = 0;
        g_breakoutState.retestStartTime = TimeCurrent();
        g_breakoutState.retestStartBar = iBarShift(_Symbol, Period(), TimeCurrent(), false);
        
        if(ShowDebugPrints)
            Print(StringFormat("🚀 Bullish breakout detected at %.5f, awaiting retest: %s", 
                  levelPrice, UseRetest ? "YES" : "NO"));
        
        if(!UseRetest) {
            ExecuteBreakoutTrade(true, levelPrice);
        }
        return true;
    }
    
    // Bearish breakout
    if(bearishBreak && volumeOK && atrOK) {
        g_breakoutState.breakoutTime = TimeCurrent();
        g_breakoutState.breakoutLevel = levelPrice;
        g_breakoutState.isBullish = false;
        g_breakoutState.awaitingRetest = UseRetest;
        g_breakoutState.barsWaiting = 0;
        g_breakoutState.retestStartTime = TimeCurrent();
        g_breakoutState.retestStartBar = iBarShift(_Symbol, Period(), TimeCurrent(), false);
        
        if(ShowDebugPrints)
            Print(StringFormat("🚀 Bearish breakout detected at %.5f, awaiting retest: %s", 
                  levelPrice, UseRetest ? "YES" : "NO"));
        
        if(!UseRetest) {
            ExecuteBreakoutTrade(false, levelPrice);
        }
        return true;
    }
    
    return false;
}

// Check retest conditions
void CheckRetestConditions()
{
    if(!g_breakoutState.awaitingRetest) return;
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double retestZone = g_breakoutState.breakoutLevel;
    double zoneSize = RetestPipsThreshold * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    bool priceInZone = (currentPrice >= retestZone - zoneSize && 
                       currentPrice <= retestZone + zoneSize);
    
    if(priceInZone && ValidateRetestConditions()) {
        if(ShowDebugPrints)
            Print(StringFormat("✅ Retest confirmed at %.5f", currentPrice));
        
        ExecuteBreakoutTrade(g_breakoutState.isBullish, g_breakoutState.breakoutLevel);
        g_breakoutState.awaitingRetest = false;
    }
}

// Validate retest conditions
bool ValidateRetestConditions()
{
    // Check if we haven't waited too long
    datetime currentTime = TimeCurrent();
    int barsWaited = iBarShift(_Symbol, Period(), currentTime, false) - g_breakoutState.retestStartBar;
    
    if(barsWaited > 8) { // Max 8 bars wait
        if(ShowDebugPrints)
            Print("❌ Retest timeout - too many bars waited");
        g_breakoutState.awaitingRetest = false;
        return false;
    }
    
    // Check if price is moving in the right direction
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double breakoutLevel = g_breakoutState.breakoutLevel;
    
    if(g_breakoutState.isBullish) {
        // For bullish breakout, price should be above level
        return (currentPrice > breakoutLevel);
    } else {
        // For bearish breakout, price should be below level
        return (currentPrice < breakoutLevel);
    }
}

// Execute breakout trade
bool ExecuteBreakoutTrade(bool isBullish, double breakoutLevel)
{
    // Check if we already have a position
    if(g_hasPositionOpen) {
        if(ShowDebugPrints)
            Print("❌ Position already exists - skipping trade");
        return false;
    }
    
    // Enforce minimum time between trades (5 minutes cooldown)
    datetime currentTime = TimeCurrent();
    if(currentTime - g_lastTradeTime < 300) {
        if(ShowDebugPrints)
            Print("❌ Trade cooldown period still active");
        return false;
    }
    
    // Get current price with error checking
    double currentPrice = isBullish 
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    if(currentPrice <= 0) {
        if(ShowDebugPrints)
            Print("❌ Invalid price received from broker");
        return false;
    }
    
    // Calculate SL/TP using ATR
    double atrValue = GetATRValue();
    double slPrice = 0, tpPrice = 0;
    
    if(isBullish) {
        slPrice = currentPrice - (atrValue * ATRMultiplierSL);
        tpPrice = currentPrice + (atrValue * ATRMultiplierTP);
    } else {
        slPrice = currentPrice + (atrValue * ATRMultiplierSL);
        tpPrice = currentPrice - (atrValue * ATRMultiplierTP);
    }
    
    // Calculate position size
    double lotSize = CalculateLotSize(slPrice, currentPrice, RiskPercentage);
    if(lotSize <= 0) {
        if(ShowDebugPrints)
            Print("❌ Invalid lot size calculated");
        return false;
    }
    
    // Place the trade using proper CTrade method
    ENUM_ORDER_TYPE orderType = isBullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    
    // Use PositionOpen method as documented
    bool tradeResult = trade.PositionOpen(_Symbol, orderType, lotSize, currentPrice, slPrice, tpPrice, "V-2-EA Breakout");
    
    // Check result according to documentation
    if(tradeResult) {
        // Verify the trade was actually executed by checking ResultRetcode
        uint resultCode = trade.ResultRetcode();
        if(resultCode == TRADE_RETCODE_DONE || resultCode == TRADE_RETCODE_PLACED || resultCode == TRADE_RETCODE_DONE_PARTIAL) {
            g_lastTradeTime = currentTime;
            g_hasPositionOpen = true;
            
            if(ShowDebugPrints) {
                Print(StringFormat("✅ TRADE EXECUTED SUCCESSFULLY:\n" +
                       "Direction: %s at %.5f\n" +
                       "SL: %.5f TP: %.5f\n" +
                       "Lot Size: %.2f (Risk: %.2f%%)\n" +
                       "Breakout Level: %.5f\n" +
                       "Deal Ticket: %I64u\n" +
                       "Result Code: %s",
                       (isBullish ? "Buy" : "Sell"), trade.ResultPrice(), slPrice, tpPrice,
                       lotSize, RiskPercentage, breakoutLevel,
                       trade.ResultDeal(), trade.ResultRetcodeDescription()));
            }
            return true;
        } else {
            if(ShowDebugPrints) {
                Print(StringFormat("❌ Trade execution failed with code: %s", trade.ResultRetcodeDescription()));
                trade.PrintResult(); // Print detailed result for debugging
            }
            return false;
        }
    } else {
        if(ShowDebugPrints) {
            Print(StringFormat("❌ Trade placement failed: %s", trade.ResultRetcodeDescription()));
            trade.PrintResult(); // Print detailed result for debugging
        }
        return false;
    }
}

// Get ATR value
double GetATRValue()
{
    double atrBuf[];
    ArraySetAsSeries(atrBuf, true);
    
    if(CopyBuffer(g_handleATR, 0, 0, 1, atrBuf) > 0) {
        return atrBuf[0];
    }
    
    // Fallback to fixed value if ATR fails
    return 0.0010; // 10 pips default
}

// Calculate lot size based on risk
double CalculateLotSize(double stopLoss, double entryPrice, double riskPercent)
{
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (riskPercent / 100.0);
    
    double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double stopDistance = MathAbs(entryPrice - stopLoss);
    double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    if(stopDistance <= 0 || pointValue <= 0) {
        return 0;
    }
    
    double lotSize = riskAmount / (stopDistance / pointSize * pointValue);
    
    // Normalize to valid lot size
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    lotSize = NormalizeDouble(lotSize / lotStep, 0) * lotStep;
    
    return lotSize;
}

// Check volume requirement
bool DoesVolumeMeetRequirement(const long &volumes[], int lookback)
{
    if(!UseVolumeFilter) return true;
    
    if(ArraySize(volumes) < lookback) return false;
    
    // Calculate average volume
    long totalVolume = 0;
    for(int i = 0; i < lookback; i++) {
        totalVolume += volumes[i];
    }
    double avgVolume = (double)totalVolume / lookback;
    
    // Check if current volume is above average
    return (volumes[0] > avgVolume * 1.5);
}

// Check ATR distance requirement
bool IsATRDistanceMet(double price1, double price2)
{
    double atrValue = GetATRValue();
    double distance = MathAbs(price1 - price2);
    
    return (distance >= atrValue * RetestATRMultiplier);
}