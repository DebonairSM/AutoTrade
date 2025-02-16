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
#include "VSol.Market.Forex.mqh"    // Add Forex market data
#include "VSol.Market.Indices.mqh"  // Add Indices market data

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
input double  ForexTouchZone = 2.5;     // Touch zone size in pips
input double  ForexMinBounce = 1.0;     // Minimum bounce size in pips

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
    
    // Add detailed debug info for market type detection
    ENUM_SYMBOL_CALC_MODE calc_mode = (ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_CALC_MODE);
    Print("Symbol: ", _Symbol);
    Print("Calculation Mode: ", EnumToString(calc_mode));
    
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
    
    // Initialize market data classes with debug flag based on market type
    switch(g_marketType)
    {
        case MARKET_TYPE_FOREX:
            CVSolForexData::InitForex(ShowDebugPrints);
            CVSolForexData::ConfigureForex(ForexTouchZone, ForexMinBounce);  // Configure with pip values
            break;
            
        case MARKET_TYPE_INDEX_US500:
            CVSolIndicesData::InitIndices(ShowDebugPrints);
            break;
            
        default:
            Print("❌ Unsupported market type for market data initialization");
            return INIT_FAILED;
    }
    
    // Select market-specific parameters and configure market settings
    double touchZone = (g_marketType == MARKET_TYPE_FOREX) ? 
                      CVSolForexData::PipsToPrice(ForexTouchZone) : IndexTouchZone;
    double minBounce = (g_marketType == MARKET_TYPE_FOREX) ? 
                      CVSolForexData::PipsToPrice(ForexMinBounce) : IndexMinBounce;
    
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
        if(g_marketType == MARKET_TYPE_FOREX)
        {
            Print(StringFormat(
                "Using %s settings:\n" +
                "Touch Zone: %.2f %s (%.5f price)\n" +
                "Min Bounce: %.2f %s (%.5f price)",
                marketTypeStr,
                ForexTouchZone, units, touchZone,
                ForexMinBounce, units, minBounce
            ));
        }
        else
        {
            Print(StringFormat(
                "Using %s settings:\n" +
                "Touch Zone: %.2f %s\n" +
                "Min Bounce: %.2f %s",
                marketTypeStr,
                touchZone, units,
                minBounce, units
            ));
        }
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
    // Get detailed market status
    ENUM_SYMBOL_TRADE_MODE tradeMode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
    bool isTradeAllowed = tradeMode == SYMBOL_TRADE_MODE_FULL;
    bool isSessionOpen = (bool)SymbolInfoInteger(_Symbol, SYMBOL_SESSION_DEALS) > 0;
    
    if(ShowDebugPrints)
    {
        string tradeModeStr = "";
        switch(tradeMode)
        {
            case SYMBOL_TRADE_MODE_DISABLED: tradeModeStr = "Trading disabled"; break;
            case SYMBOL_TRADE_MODE_LONGONLY: tradeModeStr = "Long only"; break;
            case SYMBOL_TRADE_MODE_SHORTONLY: tradeModeStr = "Short only"; break;
            case SYMBOL_TRADE_MODE_CLOSEONLY: tradeModeStr = "Close only"; break;
            case SYMBOL_TRADE_MODE_FULL: tradeModeStr = "Full trading"; break;
            default: tradeModeStr = "Unknown"; break;
        }
        
        Print("Market status for ", _Symbol, ":");
        Print("Trade Mode: ", tradeModeStr);
        Print("Trade Allowed: ", (isTradeAllowed ? "Yes" : "No"));
        Print("Session Open: ", (isSessionOpen ? "Yes" : "No"));
    }
    
    // Check if market is closed or trading is restricted
    if(tradeMode != SYMBOL_TRADE_MODE_FULL || !isTradeAllowed || !isSessionOpen)
    {
        if(ShowDebugPrints)
            Print("Market is closed or restricted for ", _Symbol, ", skipping processing");
        return;
    }
    
    // Check for new bar or timeframe change
    datetime currentBarTime = iTime(_Symbol, Period(), 0);
    if(currentBarTime == g_lastBarTime && Period() == g_lastTimeframe)
    {
        if(ShowDebugPrints)
            Print("No new bar for ", _Symbol, ", last bar time: ", TimeToString(g_lastBarTime));
        return;
    }
        
    if(ShowDebugPrints)
        Print("Processing new bar at ", TimeToString(currentBarTime), " for ", _Symbol);
        
    // Update state
    g_lastBarTime = currentBarTime;
    g_lastTimeframe = Period();
    
    // Process strategy
    if(ShowDebugPrints)
        Print("Starting strategy processing for ", _Symbol);
        
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
    else if(ShowDebugPrints)
    {
        Print("No key levels found for ", _Symbol);
    }
    
    ChartRedraw();
}