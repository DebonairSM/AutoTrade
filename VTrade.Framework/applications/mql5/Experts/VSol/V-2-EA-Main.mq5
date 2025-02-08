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
input double  MinStrength = 0.55;      // Minimum strength for key levels
input double  TouchZone = 0.0025;      // Touch zone size (in pips for Forex, points for US500)
input int     MinTouches = 2;          // Minimum touches required
input bool    ShowDebugPrints = true;  // Show debug prints
input bool    EnforceMarketHours = true; // Enforce market hours check

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
    
    // Initialize strategy
    if(!g_strategy.Init(LookbackPeriod, MinStrength, TouchZone, MinTouches, ShowDebugPrints))
    {
        Print("❌ Failed to initialize strategy");
        return INIT_FAILED;
    }
    
    // Store initial state
    g_lastBarTime = iTime(_Symbol, Period(), 0);
    
    // Print timeframe info
    Print(StringFormat(
        "Initializing EA on %s timeframe",
        EnumToString(Period())
    ));
    
    if(!CheckVersionCompatibility()) {
        Print("❌ Version mismatch between EA and Strategy");
        return INIT_FAILED;
    }
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Strategy object will clean up its own chart objects through destructor
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Replace existing new bar check with:
    datetime currentBarTime = iTime(_Symbol, Period(), 0);
    if(currentBarTime == 0) {
        Print("❌ Invalid current bar time - data not synchronized");
        return;
    }
    
    if(!SeriesInfoInteger(_Symbol, Period(), SERIES_SYNCHRONIZED)) {
        Print("⚠️ Chart data not synchronized");
        return;
    }
    
    if(currentBarTime <= g_lastBarTime) 
        return;
        
    if(!IsDuringMarketHours()) {
        if(ShowDebugPrints)
            Print("Skipping processing outside market hours");
        return;
    }
    
    // Update state and process
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