//+------------------------------------------------------------------+
//|                                               V-2-EA-Main.mq5      |
//|                         Key Level Detection Implementation         |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "2.01"
#property strict

#include "V-2-EA-BreakoutsStrategy.mqh"

// Version tracking
#define EA_VERSION "1.0.4"
#define EA_VERSION_DATE "2024-03-19"
#define EA_NAME "V-2-EA-Main"

//--- Input Parameters
input int     LookbackPeriod = 100;    // Lookback period for analysis
input double  MinStrength = 0.30;      // Minimum strength for key levels (LOWERED from 0.55)
input double  TouchZone = 0.0025;      // Touch zone size (in pips for Forex, points for US500)
input int     MinTouches = 2;          // Minimum touches required
input bool    ShowDebugPrints = true;  // Show debug prints
input bool    EnforceMarketHours = false; // Enforce market hours check (set to false to ignore market hours)
input bool    CurrentTimeframeOnly = true; // Process ONLY current chart timeframe (simplified mode)

//--- Global Variables
CV2EABreakoutsStrategy g_strategy;
datetime g_lastBarTime = 0;
string g_requiredStrategyVersion = "1.0.4";

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    // Print version information
    PrintFormat("=== %s v%s (%s) ===", EA_NAME, EA_VERSION, EA_VERSION_DATE);
    PrintFormat("Changes: Added multi-timeframe key level detection");
    
    // Initialize strategy (note: ignoreMarketHours = !EnforceMarketHours)
    if(!g_strategy.Init(LookbackPeriod, MinStrength, TouchZone, MinTouches, ShowDebugPrints, true, !EnforceMarketHours, CurrentTimeframeOnly))
    {
        Print("❌ Failed to initialize strategy");
        return INIT_FAILED;
    }
    
    // Store initial state
    g_lastBarTime = iTime(_Symbol, Period(), 0);
    
    // Print configuration info
    Print(StringFormat("⚙️ Main EA Configuration: Market Hours Enforcement = %s", EnforceMarketHours ? "ENABLED" : "DISABLED"));
    Print(StringFormat("⚙️ Breakouts Component: Market Hours Ignored = %s", !EnforceMarketHours ? "YES" : "NO"));
    Print(StringFormat("⚙️ CRITICAL: CurrentTimeframeOnly = %s", CurrentTimeframeOnly ? "TRUE" : "FALSE"));
    
    // Print timeframe info
    Print(StringFormat(
        "Initializing EA on %s timeframe",
        EnumToString(Period())
    ));
    
    // Add diagnostic information
    Print("🔍 Diagnostic Information:");
    Print("   Current Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
    Print("   Symbol: ", _Symbol);
    Print("   Available Bars: ", Bars(_Symbol, Period()));
    Print("   Last Bar Time: ", TimeToString(iTime(_Symbol, Period(), 0), TIME_DATE|TIME_SECONDS));
    Print("   Account Server: ", AccountInfoString(ACCOUNT_SERVER));
    Print("   Connection Status: ", TerminalInfoInteger(TERMINAL_CONNECTED) ? "Connected" : "Disconnected");
    
    if(!CheckVersionCompatibility()) {
        Print("❌ Version mismatch between EA and Strategy");
        return INIT_FAILED;
    }
    
    // Set up timer for initial calculation if no ticks come
    EventSetTimer(5); // Check every 5 seconds for initial calculation
    Print("⏰ Timer set for initial calculation (5 seconds)");
    
    // IMMEDIATE TEST: Try to calculate levels right in OnInit to see if it works
    Print("🧪 IMMEDIATE TEST: Attempting level calculation in OnInit...");
    datetime testBarTime = iTime(_Symbol, Period(), 0);
    if(testBarTime > 0) {
        Print(StringFormat("🧪 Test bar time: %s", TimeToString(testBarTime, TIME_DATE|TIME_SECONDS)));
        g_lastBarTime = testBarTime; // Set this so OnTimer knows we tried
        g_strategy.OnNewBar();
        
        SKeyLevelReport testReport;
        g_strategy.GetReport(testReport);
        if(testReport.isValid) {
            Print("🧪 SUCCESS: Levels found in OnInit!");
            PrintKeyLevelReport(testReport);
            Print("🧪 Forcing chart update from OnInit...");
            g_strategy.ForceChartUpdate();
        } else {
            Print("🧪 FAILED: No levels found in OnInit");
            Print("🔧 Skipping diagnostics to prevent recursive loop");
        }
    } else {
        Print("🧪 FAILED: Invalid bar time in OnInit");
    }
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Kill timer
    EventKillTimer();
    
    // Strategy object will clean up its own chart objects through destructor
}

//+------------------------------------------------------------------+
//| Timer function - handles initial calculation when no ticks        |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Add immediate debug to see if timer fires at all
    Print("⏰ OnTimer FIRED! Current time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
    
    // Only process if we haven't done initial calculation yet
    if(g_lastBarTime != 0) {
        Print("⏰ OnTimer: Already calculated, stopping timer");
        EventKillTimer(); // Stop timer once we've done initial calculation
        return;
    }
    
    Print("⏰ OnTimer: Attempting initial calculation (no ticks received)");
    
    // Check if data is available
    datetime currentBarTime = iTime(_Symbol, Period(), 0);
    if(currentBarTime == 0) {
        Print("⚠️ OnTimer: Data not ready yet, will retry...");
        return;
    }
    
    if(!SeriesInfoInteger(_Symbol, Period(), SERIES_SYNCHRONIZED)) {
        Print("⚠️ OnTimer: Data not synchronized yet, will retry...");
        return;
    }
    
    // Perform initial calculation
    Print("🔍 OnTimer: Calculating initial key levels...");
    g_lastBarTime = currentBarTime;
    g_strategy.OnNewBar();
    
    // Get and display initial report
    SKeyLevelReport report;
    g_strategy.GetReport(report);
    if(report.isValid) {
        PrintKeyLevelReport(report);
        Print("✅ OnTimer: Initial key levels calculated and displayed");
        
        // Force chart update to ensure lines are drawn
        Print("🔧 Forcing chart line update...");
        g_strategy.ForceChartUpdate();
    } else {
        Print("⚠️ OnTimer: No initial key levels found");
        Print("🔧 Skipping diagnostics to prevent loop - trying force update...");
        
        // Try to force update anyway in case levels exist but report is invalid
        g_strategy.ForceChartUpdate();
    }
    
    // Stop timer since we're done
    EventKillTimer();
    Print("⏰ Timer stopped - initial calculation complete");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Add debug message to confirm OnTick is being called (always show this)
    Print("📊 OnTick() FIRED! Current time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
    
    // Check data synchronization first
    datetime currentBarTime = iTime(_Symbol, Period(), 0);
    if(currentBarTime == 0) {
        Print("❌ Invalid current bar time - data not synchronized. Error: ", GetLastError());
        return;
    }
    
    if(!SeriesInfoInteger(_Symbol, Period(), SERIES_SYNCHRONIZED)) {
        Print("⚠️ Chart data not synchronized. Error: ", GetLastError());
        return;
    }
    
    if(ShowDebugPrints) {
        Print("✅ Data checks passed. CurrentBarTime: ", TimeToString(currentBarTime, TIME_SECONDS));
    }
    
    // Handle initial calculation on first valid tick
    if(g_lastBarTime == 0) {
        Print("🔍 Calculating initial key levels on first tick...");
        g_lastBarTime = currentBarTime;
        g_strategy.OnNewBar();
        
        // Get and display initial report
        SKeyLevelReport report;
        g_strategy.GetReport(report);
        if(report.isValid) {
            PrintKeyLevelReport(report);
            Print("✅ Initial key levels calculated and displayed");
            
            // Force chart update to ensure lines are drawn
            Print("🔧 Forcing chart line update from OnTick...");
            g_strategy.ForceChartUpdate();
        } else {
            Print("⚠️ No initial key levels found in OnTick");
            Print("🔧 Skipping diagnostics - trying force update only...");
            
            // Try to force update anyway
            g_strategy.ForceChartUpdate();
        }
        return;
    }
    
    // Regular new bar detection
    if(currentBarTime <= g_lastBarTime) 
        return;
        
    if(!IsDuringMarketHours()) {
        if(ShowDebugPrints)
            Print(StringFormat("Skipping processing outside market hours (EnforceMarketHours=%s)", 
                EnforceMarketHours ? "true" : "false"));
        return;
    }
    
    // Update state and process new bar
    g_lastBarTime = currentBarTime;
    g_strategy.OnNewBar();
    
    // Get and print report
    SKeyLevelReport report;
    g_strategy.GetReport(report);
    if(report.isValid)
        PrintKeyLevelReport(report);
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
        
    // US/EU session overlap check
    datetime nyTime = TimeCurrent() - 5*3600;
    int nyHour = (int)(nyTime % 86400) / 3600;
    
    // Monday-Friday 13:30-16:00 NY time (FX liquid hours)
    if(nyHour >= 13 && nyHour < 16)
        return true;
    return false;
}