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
datetime g_lastBarTime = 0; // Track last processed bar time
ENUM_TIMEFRAMES g_lastTimeframe = PERIOD_CURRENT; // Track last timeframe

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    // Store initial timeframe
    g_lastTimeframe = Period();
    
    // Print timeframe info
    int periodMinutes = PeriodSeconds(g_lastTimeframe) / 60;
    
    Print(StringFormat(
        "Initializing EA on %s timeframe (%d minutes)",
        EnumToString(g_lastTimeframe),
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
    // Check if timeframe has changed
    ENUM_TIMEFRAMES currentTimeframe = Period();
    if(currentTimeframe != g_lastTimeframe)
    {
        Print(StringFormat("Timeframe changed from %s to %s - Reinitializing EA...",
            EnumToString(g_lastTimeframe),
            EnumToString(currentTimeframe)));
            
        // Clear existing chart objects
        g_strategy.ClearChartObjects();
        
        // Reinitialize with new timeframe settings
        if(!g_strategy.Init(0, 0.55, 0, MinTouches, ShowDebugPrints))
        {
            Print("❌ Failed to reinitialize after timeframe change");
            return;
        }
        
        g_lastTimeframe = currentTimeframe;
        g_lastBarTime = 0; // Force immediate processing
    }
    
    // Get the current bar's open time
    datetime currentBarTime = iTime(_Symbol, Period(), 0);
    
    // Only process if this is a new bar
    if(currentBarTime != g_lastBarTime)
    {
        // Process the strategy on bar close
        g_strategy.ProcessStrategy();
        
        // Update last processed bar time
        g_lastBarTime = currentBarTime;
    }
}