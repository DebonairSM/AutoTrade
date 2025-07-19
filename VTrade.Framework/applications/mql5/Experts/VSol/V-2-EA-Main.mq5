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
#include <Trade\DealInfo.mqh>
#include "V-2-EA-Utils.mqh"
#include "V-2-EA-PerformanceLogger.mqh"

// Version tracking
#define EA_VERSION "1.0.4"
#define EA_VERSION_DATE "2024-03-19"
#define EA_NAME "V-2-EA-Main"

// Trading components
CTrade trade;

//--- Input Parameters
input int     LookbackPeriod = 100;    // Lookback period for analysis
input double  MinStrength = 0.20;      // Minimum strength for key levels (TUNED: Lowered to 0.20)
input double  TouchZone = 0.0025;      // Touch zone size (in pips for Forex, points for US500)
input int     MinTouches = 1;          // Minimum touches required (TUNED: Lowered from 2)
input bool    ShowDebugPrints = true;   // Show debug prints (ENABLED for filter tuning)
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
input double MinStrengthThreshold = 0.40; // Minimum strength for breakout (TUNED: Lowered from 0.65)
input double RetestATRMultiplier = 0.5;   // ATR multiplier for retest zone
input double RetestPipsThreshold = 15;     // Pips threshold for retest zone

//--- Global Variables
CV2EABreakoutsStrategy g_strategy;
CV2EAPerformanceLogger* g_performanceLogger = NULL;
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

// Deferred deal processing (to avoid MQL5 API race conditions)
ulong g_pendingDealTicket = 0;
bool g_processingRequired = false;

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
    
    // Initialize performance logger
    // Pattern from: Professional backtesting analysis framework
    // Reference: MQL5 Expert Advisor initialization patterns
    SOptimizationParameters params;
    params.lookbackPeriod = LookbackPeriod;
    params.minStrength = MinStrength;
    params.touchZone = TouchZone;
    params.minTouches = MinTouches;
    params.riskPercentage = RiskPercentage;
    params.atrMultiplierSL = ATRMultiplierSL;
    params.atrMultiplierTP = ATRMultiplierTP;
    params.useVolumeFilter = UseVolumeFilter;
    params.useRetest = UseRetest;
    params.breakoutLookback = BreakoutLookback;
    params.minStrengthThreshold = MinStrengthThreshold;
    params.retestATRMultiplier = RetestATRMultiplier;
    params.retestPipsThreshold = RetestPipsThreshold;
    params.optimizationStart = TimeCurrent();
    params.optimizationEnd = 0; // Will be set on deinit
    params.symbol = _Symbol;
    params.timeframe = Period();
    
    g_performanceLogger = new CV2EAPerformanceLogger();
    if(!g_performanceLogger.Initialize(_Symbol, Period(), params))
    {
        Print("❌ Failed to initialize performance logger");
        delete g_performanceLogger;
        g_performanceLogger = NULL;
        return INIT_FAILED;
    }
    
    // Store initial state
    g_lastBarTime = 0; // Will be set on first tick or timer
    
    // Print configuration info
    Print(StringFormat("⚙️ Main EA Configuration: Market Hours Enforcement = %s", EnforceMarketHours ? "ENABLED" : "DISABLED"));
    Print(StringFormat("⚙️ Breakouts Component: Market Hours Ignored = %s", !EnforceMarketHours ? "YES" : "NO"));
    Print(StringFormat("⚙️ CRITICAL: CurrentTimeframeOnly = %s", CurrentTimeframeOnly ? "TRUE" : "FALSE"));
    Print(StringFormat("⚙️ TRADING: Enabled = %s, Risk = %.1f%%, Magic = %d", EnableTrading ? "YES" : "NO", RiskPercentage, MagicNumber));
    Print("📊 PERFORMANCE LOGGING: Enabled with comprehensive tracking");
    
    // Print tuning parameters for debugging
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║                    🔧 TUNING PARAMETERS                        ║");
    Print("╠═══════════════════════════════════════════════════════════════╣");
    Print(StringFormat("║ 📊 MinStrength: %.2f (How strong levels must be)          ║", MinStrength));
    Print(StringFormat("║ 🎯 MinStrengthThreshold: %.2f (Breakout strength req.)    ║", MinStrengthThreshold));
    Print(StringFormat("║ 👆 MinTouches: %d (Touches needed to form level)         ║", MinTouches));
    Print("║ 🔊 Volume Min: 1000 units + 1.3x spike required          ║");
    Print("║ 📈 ATR Min: 0.0015 + stable/expanding required           ║");
    Print("║ 🎯 Entry: 2 pips + 40% candle body required              ║");
    Print("║ 💡 If 0 trades: These parameters are too strict              ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    
    // Print timeframe info
    Print(StringFormat("Initializing EA on %s timeframe", EnumToString(Period())));
    
    // *** FILE CREATION EXPLANATION ***
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║                    📁 FILE CREATION NOTICE                     ║");
    Print("╠═══════════════════════════════════════════════════════════════╣");
    Print("║ ✅ OUR CUSTOM FILES: Will have UNIQUE timestamps              ║");
    Print("║    📁 Location: MetaTrader 5\\MQL5\\Files\\                     ║");
    Print("║    📝 Examples:                                                ║");
    Print("║       • V2EA_Performance_EURUSD_PERIOD_H1_20250119_143022.log ║");
    Print("║       • V2EA_Trades_EURUSD_PERIOD_H1_20250119_143022.csv      ║");
    Print("║       • KeyLevels_EURUSD_PERIOD_H1_20250119_143022.csv        ║");
    Print("║                                                                ║");
    Print("║ ⚠️  MT5 SYSTEM LOGS: Always use date format (DIFFERENT!)       ║");
    Print("║    📁 Location: AppData\\Roaming\\MetaQuotes\\Tester\\...\\logs\\ ║");
    Print("║    📝 Example: 20250119.log (THIS IS NOT OUR FILE!)           ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    
    // *** GUARANTEED FILE CREATION TEST ***
    Print("🔧 TESTING FILE CREATION CAPABILITY...");
    if(!TestFileCreation()) {
        Print("❌ File creation test failed - check MT5 file permissions");
        return INIT_FAILED;
    }
    
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
    
    // Clean up performance logger and generate final reports
    // Pattern from: MQL5 Expert Advisor cleanup patterns
    // Reference: Professional backtesting cleanup procedures
    if(g_performanceLogger != NULL)
    {
        if(ShowDebugPrints)
            Print("📊 Generating final performance report...");
        
        g_performanceLogger.PrintPerformanceSummary();
        g_performanceLogger.LogOptimizationResult();
        
        delete g_performanceLogger;
        g_performanceLogger = NULL;
        
        if(ShowDebugPrints)
            Print("✅ Performance logger cleaned up successfully");
    }
    
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
//| Process deferred deal (avoids MQL5 API race conditions)         |
//+------------------------------------------------------------------+
void ProcessDeferredDeal(ulong dealTicket)
{
    Print("🔄 PROCESSING DEFERRED DEAL #", dealTicket);
    
    // *** SAFE HISTORY ACCESS: Deal should be committed to history by now ***
    // First, ensure we have recent history loaded
    if(!HistorySelect(TimeCurrent() - 3600, TimeCurrent())) // Last hour
    {
        Print("❌ Failed to load recent history for deal processing");
        return;
    }
    
    // Now safely select and access the deal
    if(!HistoryDealSelect(dealTicket))
    {
        Print("❌ Failed to select deal #", dealTicket, " from history");
        return;
    }
    
    Print("   ✅ Deal successfully selected from committed history");
    
    // Extract deal data safely
    double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
    double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);  
    double swap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
    ulong dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
    double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
    datetime closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
    ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
    ulong positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
    string comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
    
    Print("   📊 COMMITTED DEAL DATA - Magic: ", dealMagic, " | P: ", profit, " | C: ", commission, " | S: ", swap);
    
    // Validate magic number
    if(dealMagic != MagicNumber) 
    {
        Print("   ⏭️ SKIPPED - Magic mismatch (Expected: ", MagicNumber, ", Got: ", dealMagic, ")");
        return;
    }
    
    // Data should be clean now, but add basic validation as safety net
    const double REASONABLE_LIMIT = 100000.0; // $100K limit
    bool dataValid = true;
    
    if(MathAbs(profit) > REASONABLE_LIMIT || !MathIsValidNumber(profit))
    {
        Print("⚠️ Still seeing corrupted profit: ", profit, " - This indicates a deeper MT5 issue");
        profit = 0.0;
        dataValid = false;
    }
    
    if(MathAbs(commission) > REASONABLE_LIMIT || !MathIsValidNumber(commission))
    {
        Print("⚠️ Still seeing corrupted commission: ", commission, " - This indicates a deeper MT5 issue");
        commission = 0.0;
        dataValid = false;
    }
    
    if(MathAbs(swap) > REASONABLE_LIMIT || !MathIsValidNumber(swap))
    {
        Print("⚠️ Still seeing corrupted swap: ", swap, " - This indicates a deeper MT5 issue");
        swap = 0.0;
        dataValid = false;
    }
    
    if(!dataValid)
    {
        Print("⚠️ Deal data required sanitization even after deferred processing");
    }
    else
    {
        Print("   ✅ All deal data validated successfully");
    }
    
    // Process position closing deals only
    if((dealType == DEAL_TYPE_SELL || dealType == DEAL_TYPE_BUY) && positionId > 0)
    {
        // Determine exit reason
        string exitReason = "UNKNOWN";
        if(StringFind(comment, "tp") >= 0 || StringFind(comment, "take profit") >= 0)
            exitReason = "TP";
        else if(StringFind(comment, "sl") >= 0 || StringFind(comment, "stop loss") >= 0)
            exitReason = "SL";
        else if(StringFind(comment, "so") >= 0 || StringFind(comment, "stop out") >= 0)
            exitReason = "STOPOUT";
        else
            exitReason = "MANUAL";
        
        Print("   📝 EXIT REASON: ", exitReason);
        
        // Log to performance logger
        if(g_performanceLogger != NULL)
        {
            g_performanceLogger.LogTradeClose(
                closeTime,
                closePrice,
                profit,
                commission,
                swap,
                exitReason
            );
            
            Print("   ✅ TRADE LOGGED SUCCESSFULLY: P/L=", DoubleToString(profit, 2), 
                  " | Exit=", exitReason, " | Commission=", DoubleToString(commission, 2), 
                  " | Swap=", DoubleToString(swap, 2));
        }
        
        // Update position state
        g_hasPositionOpen = false;
        Print("   🔄 Position state updated: hasPositionOpen = false");
    }
    else
    {
        Print("   ⏭️ SKIPPED - Not a position closing deal (Type: ", EnumToString(dealType), ", Position: ", positionId, ")");
    }
    
    Print("✅ DEFERRED DEAL PROCESSING COMPLETED for deal #", dealTicket);
}

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
    
    // *** PROCESS DEFERRED DEALS FIRST (Race condition fix) ***
    if(g_processingRequired && g_pendingDealTicket > 0)
    {
        ProcessDeferredDeal(g_pendingDealTicket);
        g_processingRequired = false;
        g_pendingDealTicket = 0;
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
            
        // Update performance tracking on new bars
        // Pattern from: Professional performance tracking systems
        // Reference: Daily performance analysis for backtesting
        if(g_performanceLogger != NULL)
        {
            // Update balance tracking
            double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
            g_performanceLogger.UpdateBalance(currentBalance);
            
            // Check if it's a new day for daily reporting
            static int lastDay = 0;
            MqlDateTime dt;
            TimeToStruct(TimeCurrent(), dt);
            
            if(dt.day != lastDay && lastDay != 0)
            {
                g_performanceLogger.LogDailyUpdate();
                lastDay = dt.day;
            }
            else if(lastDay == 0)
            {
                lastDay = dt.day; // Initialize on first run
            }
        }
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
                if(ShowDebugPrints && isNewBar)
                    Print("🔄 Checking retest conditions...");
                CheckRetestConditions();
            }
            
            // Detect new breakouts
            if(ShowDebugPrints && isNewBar)
                Print("🔍 Looking for new breakouts...");
            DetectBreakoutAndInitRetest();
        } else {
            if(ShowDebugPrints && isNewBar)
                Print("⏭️ Skipping breakout detection - position already open");
        }
    } else {
        if(ShowDebugPrints && isNewBar)
            Print("⚠️ Trading is DISABLED - EnableTrading = false");
    }
}

//+------------------------------------------------------------------+
//| Trade transaction event handler                                    |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result)
{
    Print("🔍 OnTradeTransaction CALLED - Type: ", EnumToString(trans.type), " | Deal: ", trans.deal);
    
    // Only process deals (actual trades)
    if(trans.type != TRADE_TRANSACTION_DEAL_ADD) 
    {
        Print("   ⏭️ SKIPPED - Not a deal add transaction");
        return;
    }
    
    Print("   ✅ DEAL ADD TRANSACTION - Processing deal #", trans.deal);
    
    // *** CRITICAL FIX: Use DEFERRED PROCESSING instead of immediate history access ***
    // The deal may not be fully committed to history yet, causing race conditions
    // We'll defer the actual processing to allow MT5 to complete the deal commit
    
    if(g_performanceLogger != NULL)
    {
        Print("   📝 SCHEDULING DEFERRED DEAL PROCESSING for deal #", trans.deal);
        // Store the deal ticket for processing in the next OnTick() cycle
        // This allows MT5 to fully commit the deal to history first
        g_pendingDealTicket = trans.deal;
        g_processingRequired = true;
    }
    
    Print("🔚 OnTradeTransaction COMPLETED for deal #", trans.deal, " - Processing deferred");
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
            
            // Update trade performance tracking
            // Pattern from: Professional trade tracking systems
            // Reference: MFE/MAE analysis for trade optimization
            if(g_performanceLogger != NULL)
            {
                double mfe = 0, mae = 0;
                
                if(posType == POSITION_TYPE_BUY)
                {
                    mfe = MathMax(0, currentPrice - openPrice);
                    mae = MathMax(0, openPrice - currentPrice);
                }
                else
                {
                    mfe = MathMax(0, openPrice - currentPrice);
                    mae = MathMax(0, currentPrice - openPrice);
                }
                
                g_performanceLogger.LogTradeUpdate(currentPrice, mfe, mae);
            }
            
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
    
    if(!report.isValid) {
        if(ShowDebugPrints)
            Print("❌ STRATEGY REPORT INVALID - Strategy may not be initialized properly");
        return false;
    }
    
    if(ArraySize(report.levels) == 0) {
        if(ShowDebugPrints)
            Print("❌ NO LEVELS IN REPORT - Strategy found no key levels with MinStrength ", MinStrength);
        return false;
    }
    
    if(ShowDebugPrints)
        Print("📊 STRATEGY REPORT: Found ", ArraySize(report.levels), " timeframe(s) with levels");
    
    // Find strongest level on current timeframe
    STimeframeKeyLevel strongestLevel;
    bool foundLevel = false;
    
    if(ShowDebugPrints)
        Print("🔍 SEARCHING FOR LEVELS ON TIMEFRAME: ", EnumToString(Period()));
    
    for(int i = 0; i < ArraySize(report.levels); i++) {
        if(ShowDebugPrints)
            Print("   Level ", i, ": TF=", EnumToString(report.levels[i].timeframe), 
                  " Valid=", report.levels[i].isValid ? "YES" : "NO",
                  " Strength=", DoubleToString(report.levels[i].strongestLevel.strength, 3));
        
        if(report.levels[i].isValid && report.levels[i].timeframe == Period()) {
            if(!foundLevel || report.levels[i].strongestLevel.strength > strongestLevel.strongestLevel.strength) {
                strongestLevel = report.levels[i];
                foundLevel = true;
                if(ShowDebugPrints)
                    Print("   ✅ NEW STRONGEST: ", DoubleToString(strongestLevel.strongestLevel.strength, 3), 
                          " at ", DoubleToString(strongestLevel.strongestLevel.price, 5));
            }
        }
    }
    
    if(!foundLevel) {
        if(ShowDebugPrints)
            Print("❌ NO KEY LEVELS FOUND - Check MinStrength (", MinStrength, ") vs available levels");
        return false;
    }
    
    if(strongestLevel.strongestLevel.strength < MinStrengthThreshold) {
        if(ShowDebugPrints)
            Print("❌ STRONGEST LEVEL TOO WEAK - Strength: ", DoubleToString(strongestLevel.strongestLevel.strength, 3), 
                  " vs Required: ", DoubleToString(MinStrengthThreshold, 3));
        return false;
    }
    
    if(ShowDebugPrints)
        Print("✅ VALID KEY LEVEL FOUND - Strength: ", DoubleToString(strongestLevel.strongestLevel.strength, 3), 
              " at ", DoubleToString(strongestLevel.strongestLevel.price, 5));
    
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
    
    // **COMPREHENSIVE FILTER DEBUGGING**
    if(ShowDebugPrints && (bullishBreak || bearishBreak))
    {
        Print("🔍 BREAKOUT DETECTED - FILTER ANALYSIS:");
        Print("   📊 Level: ", DoubleToString(levelPrice, 5), " | Close: ", DoubleToString(lastClose, 5));
        Print("   📈 Direction: ", (bullishBreak ? "BULLISH" : "BEARISH"));
        Print("   📊 Level Strength: ", DoubleToString(strongestLevel.strongestLevel.strength, 3));
        Print("   🔊 Volume Filter: ", (volumeOK ? "✅ PASSED" : "❌ BLOCKED"));
        Print("   📈 ATR Filter: ", (atrOK ? "✅ PASSED" : "❌ BLOCKED"));
        Print("   🎯 Overall Result: ", (volumeOK && atrOK ? "✅ ALL FILTERS PASSED" : "❌ BLOCKED BY FILTERS"));
        
        if(volumeOK && atrOK) {
            Print("   🚀 PROCEEDING TO ENTRY CONFIRMATION...");
        } else {
            Print("   🚫 TRADE BLOCKED - Check filter details above");
        }
    }
    
    // Log filter results to performance logger
    // Pattern from: Professional trading system analysis
    // Reference: Filter effectiveness tracking for optimization
    if(g_performanceLogger != NULL && (bullishBreak || bearishBreak))
    {
        g_performanceLogger.LogVolumeFilterResult(volumeOK);
        g_performanceLogger.LogATRFilterResult(atrOK);
        
        // Log failed breakout attempts (breakout signal but filters failed)
        if(!volumeOK || !atrOK)
        {
            g_performanceLogger.LogBreakoutAttempt(levelPrice, false);
        }
    }
    
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
        
        // Log successful retest
        // Pattern from: Professional retest analysis
        // Reference: Retest effectiveness tracking for strategy optimization
        if(g_performanceLogger != NULL)
        {
            g_performanceLogger.LogRetestAttempt(retestZone, true);
        }
        
        ExecuteBreakoutTrade(g_breakoutState.isBullish, g_breakoutState.breakoutLevel);
        g_breakoutState.awaitingRetest = false;
    }
    else if(priceInZone)
    {
        // Price is in zone but retest validation failed - log failed retest
        if(g_performanceLogger != NULL)
        {
            g_performanceLogger.LogRetestAttempt(retestZone, false);
        }
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
    
    // **ENTRY CONFIRMATION FILTER** - Prevent immediate reversals and weak signals
    if(!HasEntryConfirmation(isBullish, breakoutLevel)) {
        if(ShowDebugPrints)
            Print("❌ ENTRY CONFIRMATION FAILED - No sustained momentum detected");
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
            
            // Log trade opening to performance logger
            // Pattern from: Professional trade tracking systems
            // Reference: MetaTrader 5 trade execution documentation
            if(g_performanceLogger != NULL)
            {
                // Get volume data for logging
                long volumes[];
                ArraySetAsSeries(volumes, true);
                if(CopyTickVolume(_Symbol, Period(), 0, 1, volumes) > 0)
                {
                    g_performanceLogger.LogTradeOpen(
                        currentTime, 
                        trade.ResultPrice(), 
                        lotSize,
                        isBullish ? "BUY" : "SELL",
                        slPrice, 
                        tpPrice,
                        breakoutLevel, 
                        g_breakoutState.awaitingRetest, 
                        atrValue, 
                        volumes[0]
                    );
                }
                else
                {
                    // Fallback without volume data
                    g_performanceLogger.LogTradeOpen(
                        currentTime, 
                        trade.ResultPrice(), 
                        lotSize,
                        isBullish ? "BUY" : "SELL",
                        slPrice, 
                        tpPrice,
                        breakoutLevel, 
                        g_breakoutState.awaitingRetest, 
                        atrValue, 
                        0
                    );
                }
                
                // Log breakout attempt
                g_performanceLogger.LogBreakoutAttempt(breakoutLevel, true);
                
                // Log filter results
                g_performanceLogger.LogVolumeFilterResult(true); // Trade was executed, so filters passed
                g_performanceLogger.LogATRFilterResult(true);
            }
            
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

// Check volume requirement with enhanced filters
bool DoesVolumeMeetRequirement(const long &volumes[], int lookback)
{
    if(!UseVolumeFilter) return true;
    
    if(ArraySize(volumes) < lookback) return false;
    
    // Get current volume (breakout bar)
    long currentVolume = volumes[0];
    
    // **MINIMUM ABSOLUTE VOLUME THRESHOLD**
    // Based on analysis: winning trades had 6,558+ volume, losing trades had 7
    // TUNED: Set to 1,000 (above current ~2,350 would still pass)
    long minAbsoluteVolume = 1000;  // Minimum 1,000 volume units
    
    if(currentVolume < minAbsoluteVolume)
    {
        if(ShowDebugPrints)
            Print("🚫 VOLUME FILTER BLOCKED: Current volume ", currentVolume, " < minimum ", minAbsoluteVolume);
        return false;
    }
    
    // Calculate average volume over lookback period
    long totalVolume = 0;
    for(int i = 1; i < lookback + 1; i++) { // Skip current bar, use historical average
        if(i < ArraySize(volumes))
            totalVolume += volumes[i];
    }
    double avgVolume = (double)totalVolume / MathMin(lookback, ArraySize(volumes) - 1);
    
    // **VOLUME SPIKE REQUIREMENT**
    // TUNED: Reduced to 1.3x (just need above-average volume)
    // Still blocks half-average volume like current ~0.5x
    double volumeSpike = 1.3;
    bool spikeOK = (currentVolume > avgVolume * volumeSpike);
    
    if(!spikeOK)
    {
        if(ShowDebugPrints)
            Print("🚫 VOLUME SPIKE BLOCKED: Current ", currentVolume, " vs Average ", (int)avgVolume, 
                  " (", DoubleToString(currentVolume/avgVolume, 1), "x < ", volumeSpike, "x required)");
        return false;
    }
    
    // **VOLUME TREND ANALYSIS**
    // Check if volume is building up over last few bars
    bool trendOK = true;
    if(ArraySize(volumes) > 3)
    {
        long recent3Avg = (volumes[0] + volumes[1] + volumes[2]) / 3;
        long older3Avg = (volumes[3] + volumes[4] + volumes[5]) / 3;
        // TUNED: Reduced volume trend requirement from 20% to 15%
        trendOK = (recent3Avg > older3Avg * 1.15); // Recent volume 15% higher than older
        
        if(!trendOK && ShowDebugPrints)
            Print("⚠️ VOLUME TREND WARNING: Recent average ", recent3Avg, " vs Older ", older3Avg);
    }
    
    if(ShowDebugPrints)
        Print("✅ VOLUME FILTER PASSED: ", currentVolume, " (", DoubleToString(currentVolume/avgVolume, 1), 
              "x avg), Trend: ", (trendOK ? "Good" : "Weak"));
    
    return true; // Pass all volume tests
}

// Check ATR distance requirement with enhanced volatility filtering
bool IsATRDistanceMet(double price1, double price2)
{
    double atrValue = GetATRValue();
    double distance = MathAbs(price1 - price2);
    
    // **MINIMUM ATR VOLATILITY THRESHOLD**
    // Based on analysis: winning trades had ATR 0.0018+, losing trades had 0.0014
    // TUNED: Reduced from 0.0016 to 0.0015 to allow more trades through
    double minATR = 0.0015;  // Minimum volatility threshold
    
    if(atrValue < minATR)
    {
        if(ShowDebugPrints)
            Print("🚫 ATR VOLATILITY BLOCKED: Current ATR ", DoubleToString(atrValue, 4), 
                  " < minimum ", DoubleToString(minATR, 4));
        return false;
    }
    
    // **ATR DISTANCE REQUIREMENT** 
    bool distanceOK = (distance >= atrValue * RetestATRMultiplier);
    
    if(!distanceOK && ShowDebugPrints)
        Print("🚫 ATR DISTANCE BLOCKED: Distance ", DoubleToString(distance, 4), 
              " < required ", DoubleToString(atrValue * RetestATRMultiplier, 4));
    
    // **ATR TREND ANALYSIS**
    // Check if volatility is expanding (good for breakouts)
    bool atrTrendOK = IsATRExpanding();
    
    if(ShowDebugPrints)
        Print("✅ ATR FILTER: Value=", DoubleToString(atrValue, 4), 
              ", Distance=", DoubleToString(distance, 4), 
              ", Trend=", (atrTrendOK ? "Expanding" : "Contracting"));
    
    return distanceOK && atrTrendOK;
}

// Check if ATR is expanding (volatility increasing - good for breakouts)
bool IsATRExpanding()
{
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    
    if(CopyBuffer(g_handleATR, 0, 0, 5, atrBuffer) < 5)
        return true; // Default to true if we can't get ATR data
    
    // Compare recent ATR vs older ATR
    double recentATR = (atrBuffer[0] + atrBuffer[1]) / 2.0;  // Last 2 bars
    double olderATR = (atrBuffer[2] + atrBuffer[3]) / 2.0;   // Previous 2 bars
    
    // TUNED: Allow flat or slightly expanding ATR (just need to not be severely contracting)
    bool expanding = (recentATR >= olderATR * 0.95); // Allow 5% contraction or better
    
    if(ShowDebugPrints)
        Print("ATR Trend: Recent=", DoubleToString(recentATR, 4), 
              " vs Older=", DoubleToString(olderATR, 4), 
              " (", (expanding ? "Stable/Expanding ✅" : "Severely Contracting ❌"), ")");
    
    return expanding;
}

// Entry confirmation to prevent immediate reversals
bool HasEntryConfirmation(bool isBullishBreakout, double breakoutLevel)
{
    // Get recent price data for momentum analysis
    double closes[];
    ArraySetAsSeries(closes, true);
    
    if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 5, closes) < 5)
        return true; // Default to true if we can't get data
    
    double currentPrice = closes[0];
    double previousPrice = closes[1];
    double twoBarsAgo = closes[2];
    
    // **MOMENTUM CONFIRMATION**
    // Require sustained movement in breakout direction
    bool momentumOK = false;
    
    if(isBullishBreakout)
    {
        // For bullish breakout: ensure we're not immediately reversing down
        momentumOK = (currentPrice > previousPrice) && 
                     (previousPrice >= twoBarsAgo * 0.9999); // Allow tiny pullback
        
        // Additional check: ensure we're meaningfully above breakout level
        // TUNED: Reduced from 3.0 to 2.0 pips to allow more entries
        double pipsAbove = (currentPrice - breakoutLevel) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        momentumOK = momentumOK && (pipsAbove >= 2.0); // At least 2 pips above
    }
    else
    {
        // For bearish breakout: ensure we're not immediately reversing up
        momentumOK = (currentPrice < previousPrice) && 
                     (previousPrice <= twoBarsAgo * 1.0001); // Allow tiny pullback
        
        // Additional check: ensure we're meaningfully below breakout level  
        // TUNED: Reduced from 3.0 to 2.0 pips to allow more entries
        double pipsBelow = (breakoutLevel - currentPrice) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        momentumOK = momentumOK && (pipsBelow >= 2.0); // At least 2 pips below
    }
    
    // **CANDLE PATTERN CONFIRMATION**
    // Check if recent candles support the breakout direction
    bool candleOK = false;
    
    if(isBullishBreakout)
    {
        // Look for bullish candle patterns
        double bodySize = MathAbs(closes[0] - iOpen(_Symbol, PERIOD_CURRENT, 0));
        double candleRange = iHigh(_Symbol, PERIOD_CURRENT, 0) - iLow(_Symbol, PERIOD_CURRENT, 0);
        
        // TUNED: Reduced body requirement from 50% to 40% of range
        candleOK = (closes[0] > iOpen(_Symbol, PERIOD_CURRENT, 0)) && // Bullish candle
                   (bodySize > candleRange * 0.4); // Strong body (>40% of range)
    }
    else
    {
        // Look for bearish candle patterns
        double bodySize = MathAbs(closes[0] - iOpen(_Symbol, PERIOD_CURRENT, 0));
        double candleRange = iHigh(_Symbol, PERIOD_CURRENT, 0) - iLow(_Symbol, PERIOD_CURRENT, 0);
        
        // TUNED: Reduced body requirement from 50% to 40% of range
        candleOK = (closes[0] < iOpen(_Symbol, PERIOD_CURRENT, 0)) && // Bearish candle
                   (bodySize > candleRange * 0.4); // Strong body (>40% of range)
    }
    
    bool confirmed = momentumOK && candleOK;
    
    if(ShowDebugPrints)
    {
        Print("🔍 ENTRY CONFIRMATION: ", (isBullishBreakout ? "BULLISH" : "BEARISH"), 
              " - Momentum: ", (momentumOK ? "✅" : "❌"), 
              ", Candle: ", (candleOK ? "✅" : "❌"), 
              ", Result: ", (confirmed ? "CONFIRMED ✅" : "REJECTED ❌"));
    }
    
    return confirmed;
}

//+------------------------------------------------------------------+
//| Test guaranteed file creation with unique names                   |
//+------------------------------------------------------------------+
bool TestFileCreation()
{
    // Create super unique timestamp using multiple methods
    datetime currentTime = TimeCurrent();
    ulong microseconds = GetMicrosecondCount();
    MqlDateTime dt;
    TimeToStruct(currentTime, dt);
    
    // Ultra-unique timestamp: YYYYMMDD_HHMMSS_microseconds_random
    string ultraTimestamp = StringFormat("%04d%02d%02d_%02d%02d%02d_%06d_%04d", 
        dt.year, dt.mon, dt.day,
        dt.hour, dt.min, dt.sec,
        (int)(microseconds % 1000000),
        MathRand() % 10000); // Add random component for absolute uniqueness
    
    string testFileName = "V2EA_INIT_TEST_" + _Symbol + "_" + EnumToString(Period()) + "_" + ultraTimestamp + ".txt";
    
    Print("🔍 ATTEMPTING TO CREATE TEST FILE: ", testFileName);
    Print("📁 FILE LOCATION: ", TerminalInfoString(TERMINAL_DATA_PATH), "\\MQL5\\Files\\");
    
    // Create test file
    int fileHandle = FileOpen(testFileName, FILE_WRITE|FILE_TXT|FILE_COMMON);
    if(fileHandle == INVALID_HANDLE)
    {
        int error = GetLastError();
        Print("❌ FAILED TO CREATE TEST FILE! Error: ", error);
        Print("🔧 Troubleshooting:");
        Print("   1. Check if MetaTrader has file access permissions");
        Print("   2. Ensure MQL5\\Files\\ directory exists");
        Print("   3. Check if antivirus is blocking file creation");
        return false;
    }
    
    // Write test data to file
    string testContent = StringFormat(
        "✅ V-2-EA FILE CREATION TEST SUCCESS!\n" +
        "=================================\n" +
        "Creation Time: %s\n" +
        "Symbol: %s\n" +
        "Timeframe: %s\n" +
        "Account: %s\n" +
        "Server: %s\n" +
        "Terminal Build: %d\n" +
        "Ultra Timestamp: %s\n" +
        "=================================\n" +
        "This file proves our EA can create unique files!\n" +
        "Every time you restart, you'll get a NEW file.\n",
        TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
        _Symbol,
        EnumToString(Period()),
        IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)),
        AccountInfoString(ACCOUNT_SERVER),
        TerminalInfoInteger(TERMINAL_BUILD),
        ultraTimestamp
    );
    
    FileWriteString(fileHandle, testContent);
    FileClose(fileHandle);
    
    // Verify file was created successfully
    fileHandle = FileOpen(testFileName, FILE_READ|FILE_TXT|FILE_COMMON);
    if(fileHandle == INVALID_HANDLE)
    {
        Print("❌ FILE CREATED BUT CANNOT BE READ BACK!");
        return false;
    }
    
    string readBack = FileReadString(fileHandle);
    FileClose(fileHandle);
    
    if(StringFind(readBack, "V-2-EA FILE CREATION TEST SUCCESS") < 0)
    {
        Print("❌ FILE CREATED BUT CONTENT IS CORRUPTED!");
        return false;
    }
    
    Print("✅ ✅ ✅ FILE CREATION TEST SUCCESSFUL! ✅ ✅ ✅");
    Print("📄 Created file: ", testFileName);
    Print("📁 Full path: ", TerminalInfoString(TERMINAL_DATA_PATH), "\\MQL5\\Files\\", testFileName);
    Print("💡 SOLUTION: Look for files with THIS timestamp pattern: ", ultraTimestamp);
    Print("🎯 EVERY EA RESTART = NEW UNIQUE FILES!");
    
    return true;
}