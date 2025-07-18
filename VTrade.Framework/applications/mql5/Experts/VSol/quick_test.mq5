//+------------------------------------------------------------------+
//|                                                    quick_test.mq5 |
//|                                           Quick Compilation Test   |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property version   "1.00"

// Test essential includes only
#include "V-2-EA-MarketData.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("MarketData include test successful!");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Minimal functionality
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("Quick test EA deinitializing");
} 