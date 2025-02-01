//+------------------------------------------------------------------+
//|                                                   V-2-EA-Main.mq5 |
//|                                                     Rommel Company |
//|                                                     Your Link |
//+------------------------------------------------------------------+
#property copyright "Rommel Company"
#property link      "Your Link"
#property version   "1.00"

#include "V-2-EA-Breakouts.mqh"
#include "V-2-EA-MarketData.mqh"
#include "V-2-EA-Utils.mqh"

// Input parameters
input int InpLookbackPeriod = 0;      // Lookback period (0 = auto based on timeframe)
input double InpMinStrength = 0.55;    // Minimum strength for key levels (0.45-0.98)
input double InpTouchZone = 0;         // Touch zone size (0 = auto based on timeframe)
input int InpMinTouches = 2;           // Minimum touches required
input bool InpShowDebug = false;       // Show debug output

// Global variables
VSol::CV2EABreakouts* g_strategy = NULL;  // Strategy instance
VSol::CV2EAUtils g_utils;                 // Utils instance
VSol::CV2EAMarketData g_marketData;       // Market data instance
datetime g_lastBarTime = 0; // Track last processed bar time
ENUM_TIMEFRAMES g_lastTimeframe = PERIOD_CURRENT; // Track last timeframe

//+------------------------------------------------------------------+
//| Expert initialization function                                      |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize utils and market data
    VSol::CV2EAUtils::Init(InpShowDebug);
    VSol::CV2EAMarketData::Init(InpShowDebug);
    
    // Create strategy instance
    if(g_strategy != NULL)
    {
        delete g_strategy;
        g_strategy = NULL;
    }
    
    g_strategy = new VSol::CV2EABreakouts();
    
    // Initialize strategy
    if(!g_strategy.Init(InpLookbackPeriod, InpMinStrength, InpTouchZone, 
                        InpMinTouches, InpShowDebug))
    {
        VSol::CV2EAUtils::LogError("Failed to initialize strategy");
        return INIT_FAILED;
    }
    
    // Store initial timeframe
    g_lastTimeframe = Period();
    
    // Print timeframe info
    int periodMinutes = PeriodSeconds(g_lastTimeframe) / 60;
    
    VSol::CV2EAUtils::LogInfo(StringFormat(
        "Initializing EA on %s timeframe (%d minutes)",
        EnumToString(g_lastTimeframe),
        periodMinutes
    ));
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up all components in reverse order of initialization
    g_strategy.Cleanup();  // Clean up Breakouts strategy
    VSol::CV2EAMarketData::Cleanup();  // Clean up MarketData
    VSol::CV2EAUtils::Cleanup();  // Clean up Utils
    
    // Log deinitialization
    VSol::CV2EAUtils::LogInfo(StringFormat("EA Deinitialized (reason: %d)", reason));
    
    // Force chart redraw to ensure all objects are removed
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
    if(g_strategy == NULL) return;
    
    // Check if timeframe has changed
    ENUM_TIMEFRAMES currentTimeframe = Period();
    if(currentTimeframe != g_lastTimeframe)
    {
        VSol::CV2EAUtils::LogInfo(StringFormat("Timeframe changed from %s to %s - Reinitializing EA...",
            EnumToString(g_lastTimeframe),
            EnumToString(currentTimeframe)));
            
        // Clear existing chart objects
        g_strategy.ClearChartObjects();
        
        // Reinitialize with new timeframe settings
        if(!g_strategy.Init(InpLookbackPeriod, InpMinStrength, InpTouchZone, 
                            InpMinTouches, InpShowDebug))
        {
            VSol::CV2EAUtils::LogError("Failed to reinitialize after timeframe change");
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