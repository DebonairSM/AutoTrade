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
#include "VSol.MarketHours.mqh"

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
input bool    EnforceMarketHours = true;  // Enforce market hours restrictions

input group "Forex Settings"
input double  ForexTouchZone = 2.5;     // Touch zone size in pips
input double  ForexMinBounce = 1.0;     // Minimum bounce size in pips

input group "US500 Settings"
input double  IndexTouchZone = 5.0;        // Touch zone size in points
input double  IndexMinBounce = 2.0;        // Minimum bounce size in points

input group "Crypto Settings"
input double  CryptoTouchZone = 500.0;      // Touch zone size in USD (e.g. $500 for BTC)
input double  CryptoMinBounce = 250.0;      // Minimum bounce size in USD (e.g. $250 for BTC)

//--- Global Variables
CVSolStrategy g_strategy;
CVSolMarketConfig g_marketConfig;  // Add market configuration
datetime g_lastBarTime = 0;
ENUM_TIMEFRAMES g_lastTimeframe = PERIOD_CURRENT;
ENUM_MARKET_TYPE g_marketType = MARKET_TYPE_UNKNOWN;  // Store market type globally

//--- Static variables for time tracking
static datetime s_lastDebugTime = 0;    // Static variable to track last debug print
static datetime s_lastProcessTime = 0;   // Static variable to track last processing time

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
        case MARKET_TYPE_CRYPTO:    marketTypeStr = "Crypto"; break;
        default: marketTypeStr = "Unknown"; break;
    }
    Print("Market Type: ", marketTypeStr);
    
    // Log time conversion details on initialization
    CVSolMarketHours::LogTimeConversion();
    
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
            CVSolForexData::ConfigureForex(ForexTouchZone, ForexMinBounce);
            break;
            
        case MARKET_TYPE_INDEX_US500:
            CVSolIndicesData::InitIndices(ShowDebugPrints);
            break;
            
        case MARKET_TYPE_CRYPTO:
            {  // Added scope
                // For crypto, we use direct price values (in USD)
                double cryptoTouchZone = CryptoTouchZone;
                double cryptoMinBounce = CryptoMinBounce;
                
                // Adjust based on price scale if needed
                double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                if(currentPrice > 10000)  // For high-value coins like BTC
                {
                    cryptoTouchZone = MathMax(cryptoTouchZone, currentPrice * 0.005);  // At least 0.5% of price
                    cryptoMinBounce = MathMax(cryptoMinBounce, currentPrice * 0.0025);  // At least 0.25% of price
                }
                
                if(ShowDebugPrints)
                {
                    Print(StringFormat(
                        "Configuring crypto settings for %s:\n" +
                        "Current Price: $%.2f\n" +
                        "Touch Zone: $%.2f (%.2f%%)\n" +
                        "Min Bounce: $%.2f (%.2f%%)",
                        _Symbol,
                        currentPrice,
                        cryptoTouchZone,
                        (cryptoTouchZone / currentPrice) * 100,
                        cryptoMinBounce,
                        (cryptoMinBounce / currentPrice) * 100
                    ));
                }
                
                CVSolForexData::InitForex(ShowDebugPrints);
                // Convert to points since we're using direct price values
                double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                CVSolForexData::ConfigureForex(cryptoTouchZone / point, cryptoMinBounce / point);
            }
            break;
            
        default:
            Print("❌ Unsupported market type for market data initialization");
            return INIT_FAILED;
    }
    
    // Select market-specific parameters and configure market settings
    double touchZone = 0.0;
    double minBounce = 0.0;
    
    switch(g_marketType)
    {
        case MARKET_TYPE_FOREX:
            touchZone = CVSolForexData::PipsToPrice(ForexTouchZone);
            minBounce = CVSolForexData::PipsToPrice(ForexMinBounce);
            break;
        case MARKET_TYPE_INDEX_US500:
            touchZone = IndexTouchZone;
            minBounce = IndexMinBounce;
            break;
        case MARKET_TYPE_CRYPTO:
            touchZone = CryptoTouchZone;
            minBounce = CryptoMinBounce;
            break;
    }
    
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
        else if(g_marketType == MARKET_TYPE_CRYPTO)
        {
            Print(StringFormat(
                "Using %s settings:\n" +
                "Touch Zone: $%.2f\n" +
                "Min Bounce: $%.2f",
                marketTypeStr,
                touchZone,
                minBounce
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
    
    // Store initial state with proper server time
    g_lastBarTime = iTime(_Symbol, Period(), 0);
    g_lastTimeframe = Period();
    
    // Initialize the last process time to current server time
    s_lastProcessTime = TimeCurrent();
    
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
    datetime currentBarTime = iTime(_Symbol, Period(), 0);
    bool isNewBar = (currentBarTime != g_lastBarTime);
    bool shouldPrintDebug = ShowDebugPrints && isNewBar;  // Only print debug on new bars
    
    // Get detailed market status
    ENUM_SYMBOL_TRADE_MODE tradeMode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
    bool isTradeAllowed = tradeMode == SYMBOL_TRADE_MODE_FULL;
    bool isSessionOpen = (g_marketType == MARKET_TYPE_CRYPTO || g_marketType == MARKET_TYPE_FOREX) ? true : 
                        (bool)SymbolInfoInteger(_Symbol, SYMBOL_SESSION_DEALS) > 0;
    
    // Print market status only on new bars if debug is enabled
    if(shouldPrintDebug)
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
    if(EnforceMarketHours && !CVSolMarketHours::IsMarketOpen(g_marketType, isTradeAllowed))
    {
        if(shouldPrintDebug)  // Only print on new bars
            Print("Market is closed or restricted for ", _Symbol, ", skipping processing");
        return;
    }
    
    // Update state before processing
    g_lastBarTime = currentBarTime;
    g_lastTimeframe = Period();
    s_lastProcessTime = TimeCurrent();

    // Process the strategy (this is where key levels are computed and lines drawn)
    g_strategy.ProcessStrategy();
    ChartRedraw();

    // Find and log key levels (only on new bars)
    if(shouldPrintDebug)
    {
        SKeyLevel strongestLevel;
        if(g_strategy.FindKeyLevels(strongestLevel))
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
            
            Print("Processing trading logic for ", _Symbol);
        }
        else
        {
            Print("No key levels found for ", _Symbol);
        }
    }
    
    // ... Trading logic here ...
}