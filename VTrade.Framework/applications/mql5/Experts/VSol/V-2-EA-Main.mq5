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
input int    LookbackPeriod    = 144;   // Lookback period (12h in M5)
input double MinStrength       = 0.55;  // Min strength threshold
input double TouchZone         = 0.0005; // Touch zone size
input int    MinTouches        = 2;     // Minimum touches required
input bool   ShowDebugPrints   = true;  // Show debug output

//--- Global Variables
CV2EABreakouts g_strategy;  // Strategy instance

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize key level detection
    if(!g_strategy.Init(LookbackPeriod, MinStrength, TouchZone, 
                        MinTouches, ShowDebugPrints))
    {
        Print("❌ Failed to initialize key level detection");
        return INIT_FAILED;
    }
    
    Print("✅ Strategy initialized successfully");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Nothing to clean up
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Process the strategy on each tick
    g_strategy.ProcessStrategy();
}