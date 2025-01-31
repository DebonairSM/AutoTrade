//+------------------------------------------------------------------+
//|                                               V-2-EA-Main.mq5     |
//|                         Key Level Detection Implementation        |
//+------------------------------------------------------------------+
#property copyright "Your Company"
#property link      "Your Link"
#property version   "1.0"
#property strict

#include "V-2-EA-Breakouts.mqh"

//--- Level Detection Parameters
input int    MinTouches        = 2;     // Minimum touches required
input bool   ShowDebugPrints   = true; // Show debug messages

//--- Global Variables
CV2EABreakouts g_strategy;  // Strategy instance

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    // Print timeframe info
    ENUM_TIMEFRAMES tf = Period();
    int periodMinutes = PeriodSeconds(tf) / 60;
    
    Print(StringFormat(
        "Initializing EA on %s timeframe (%d minutes)",
        EnumToString(tf),
        periodMinutes
    ));
    
    // Initialize key level detection with auto-calculated settings
    if(!g_strategy.Init(0, 0.55, 0, MinTouches, ShowDebugPrints))
    {
        Print("❌ Failed to initialize key level detection");
        return INIT_FAILED;
    }
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Cleanup is handled by CV2EABreakouts destructor
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Process the strategy on each tick
    g_strategy.ProcessStrategy();
}