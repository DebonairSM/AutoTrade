//+------------------------------------------------------------------+
//|                                               V-2-EA-Main.mq5     |
//|                         Key Level Detection Implementation        |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "2.01"
#property strict

#include "V-2-EA-Breakouts.mqh"

// Version tracking
#define EA_VERSION "1.0.3"
#define EA_VERSION_DATE "2024-03-19"
#define EA_NAME "V-2-EA-Main"

//--- Input Parameters
input int     LookbackPeriod = 100;    // Lookback period for analysis
input double  MinStrength = 0.55;      // Minimum strength for key levels
input double  TouchZone = 0.0025;      // Touch zone size (in pips for Forex, points for US500)
input int     MinTouches = 2;          // Minimum touches required
input bool    ShowDebugPrints = true;  // Show debug prints

//--- Global Variables
CV2EABreakouts g_strategy;
datetime g_lastBarTime = 0;
ENUM_TIMEFRAMES g_lastTimeframe = PERIOD_CURRENT;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    // Print version information
    PrintFormat("=== %s v%s (%s) ===", EA_NAME, EA_VERSION, EA_VERSION_DATE);
    PrintFormat("Changes: Added version tracking and improved timeframe handling");
    
    // Clear any existing chart objects first
    ObjectsDeleteAll(0, "KL_");  // Delete all objects starting with "KL_"
    
    // Wait for enough bars to be loaded
    int bars = Bars(_Symbol, Period());
    if(bars < LookbackPeriod + 10)  // Add buffer for swing detection
    {
        Print("❌ Not enough historical data loaded. Need at least ", LookbackPeriod + 10, " bars, got ", bars);
        return INIT_FAILED;
    }
    
    // Initialize strategy
    if(!g_strategy.Init(LookbackPeriod, MinStrength, TouchZone, MinTouches, ShowDebugPrints))
    {
        Print("❌ Failed to initialize strategy");
        return INIT_FAILED;
    }
    
    // Store initial state
    g_lastBarTime = iTime(_Symbol, Period(), 0);
    g_lastTimeframe = Period();
    
    // Print timeframe info
    int periodMinutes = PeriodSeconds(g_lastTimeframe) / 60;
    Print(StringFormat(
        "Initializing EA on %s timeframe (%d minutes)",
        EnumToString(g_lastTimeframe),
        periodMinutes
    ));
    
    // Force initial strategy processing to draw lines immediately
    g_strategy.ProcessStrategy();
    ChartRedraw(0);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ObjectsDeleteAll(0, "KL_");  // Delete all objects starting with "KL_"
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check for new bar or timeframe change
    datetime currentBarTime = iTime(_Symbol, Period(), 0);
    if(currentBarTime == g_lastBarTime && Period() == g_lastTimeframe)
        return;
        
    // Update state
    g_lastBarTime = currentBarTime;
    g_lastTimeframe = Period();
    
    // Process strategy
    g_strategy.ProcessStrategy();
}