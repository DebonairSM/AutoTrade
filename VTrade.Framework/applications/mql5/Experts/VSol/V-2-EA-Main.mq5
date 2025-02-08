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

//--- Global Variables
CV2EABreakoutsStrategy g_strategy;
datetime g_lastBarTime = 0;

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
    // Check for new bar with error handling
    datetime currentBarTime = 0;
    if(!SeriesInfoInteger(_Symbol, Period(), SERIES_LASTBAR_DATE, currentBarTime))
    {
        Print("❌ Error getting current bar time");
        return;
    }
    
    if(currentBarTime == g_lastBarTime)
        return;
        
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