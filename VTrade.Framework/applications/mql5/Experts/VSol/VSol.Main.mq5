//+------------------------------------------------------------------+
//|                                               VSol.Main.mq5        |
//|                         Key Level Detection Implementation         |
//+------------------------------------------------------------------+
#property copyright "VSol Trading Systems"
#property link      "https://vsol-systems.com"
#property version   "2.01"
#property strict

// Include core implementation files
#include "VSol.Strategy.mqh"
#include "VSol.Market.mqh"
#include "VSol.Utils.mqh"

// Version tracking
#define EA_VERSION "1.0.3"
#define EA_VERSION_DATE "2024-03-19"
#define EA_NAME "VSol.Main"

//--- Input Parameters
input group "General Settings"
input int     LookbackPeriod = 100;    // Lookback period for analysis
input double  MinStrength = 0.55;      // Minimum strength for key levels
input int     MinTouches = 2;          // Minimum touches required
input bool    ShowDebugPrints = true;  // Show debug prints

input group "Forex Settings"
input double  ForexTouchZone = 0.0025;     // Touch zone size in pips
input double  ForexMinBounce = 0.0010;     // Minimum bounce size in pips

input group "US500 Settings"
input double  IndexTouchZone = 5.0;        // Touch zone size in points
input double  IndexMinBounce = 2.0;        // Minimum bounce size in points

//--- Global Variables
CVSolStrategy g_strategy;
CVSolMarketConfig g_marketConfig;  // Add market configuration
datetime g_lastBarTime = 0;
ENUM_TIMEFRAMES g_lastTimeframe = PERIOD_CURRENT;
ENUM_MARKET_TYPE g_marketType = MARKET_TYPE_UNKNOWN;  // Store market type globally

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
    
    // Detect market type
    g_marketType = CVSolMarketBase::GetMarketType(_Symbol);
    string marketTypeStr = "";
    switch(g_marketType)
    {
        case MARKET_TYPE_FOREX:     marketTypeStr = "Forex"; break;
        case MARKET_TYPE_INDEX_US500: marketTypeStr = "US500/SPX"; break;
        default: marketTypeStr = "Unknown"; break;
    }
    Print("Market Type: ", marketTypeStr);
    
    // Validate market type
    if(g_marketType == MARKET_TYPE_UNKNOWN)
    {
        Print("❌ Unsupported market type for symbol ", _Symbol);
        return INIT_FAILED;
    }
    
    // Wait for enough bars to be loaded
    int bars = Bars(_Symbol, Period());
    if(bars < LookbackPeriod + 10)  // Add buffer for swing detection
    {
        Print("❌ Not enough historical data loaded. Need at least ", LookbackPeriod + 10, " bars, got ", bars);
        return INIT_FAILED;
    }
    
    // Select market-specific parameters
    double touchZone = (g_marketType == MARKET_TYPE_FOREX) ? ForexTouchZone : IndexTouchZone;
    double minBounce = (g_marketType == MARKET_TYPE_FOREX) ? ForexMinBounce : IndexMinBounce;
    
    // Configure market settings
    g_marketConfig.Configure(
        _Symbol,
        g_marketType,
        touchZone,
        minBounce,
        MinStrength,
        MinTouches,
        LookbackPeriod
    );
    
    // Print market-specific settings
    if(ShowDebugPrints)
    {
        string units = g_marketConfig.GetUnits();
        Print(StringFormat(
            "Using %s settings:\n" +
            "Touch Zone: %.5f %s\n" +
            "Min Bounce: %.5f %s",
            marketTypeStr,
            g_marketConfig.GetTouchZone(), units,
            g_marketConfig.GetBounceMinSize(), units
        ));
    }
    
    // Initialize strategy with market-specific parameters
    if(!g_strategy.Init(LookbackPeriod, MinStrength, touchZone, MinTouches, ShowDebugPrints))
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
    
    // Find key levels
    SKeyLevel strongestLevel;
    if(g_strategy.FindKeyLevels(strongestLevel))
    {
        if(ShowDebugPrints)
        {
            string volumeInfo = strongestLevel.volumeConfirmed ? 
                StringFormat(", Volume Ratio=%.2f", strongestLevel.volumeRatio) : 
                ", No Volume Confirmation";
                
            string touchInfo = StringFormat(
                "First Touch=%s, Last Touch=%s", 
                TimeToString(strongestLevel.firstTouch),
                TimeToString(strongestLevel.lastTouch)
            );
                
            Print("Found key level: ",
                  "Price=", DoubleToString(strongestLevel.price, _Digits),
                  ", Strength=", DoubleToString(strongestLevel.strength, 2),
                  ", Touches=", strongestLevel.touchCount,
                  strongestLevel.isResistance ? " (Resistance)" : " (Support)",
                  volumeInfo,
                  "\n", touchInfo
            );
        }
    }
    
    ChartRedraw();
}