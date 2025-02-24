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
#include "VSol.Breakout.mqh"        // Add Breakout strategy
#include "VSol.Statistics.mqh"      // Add Statistics class

//--- Version and Configuration
#define EA_VERSION "1.0.3"
#define EA_VERSION_DATE "2024-03-19"
#define EA_NAME "VSol.Main"

//--- Backtesting Configuration
#define OPTIMIZATION_MODE true         // Set to true when running optimization
#define MAX_SPREAD 20                 // Maximum allowed spread in points
#define MIN_TICKS_HISTORY 5000        // Minimum required ticks for accurate testing

//--- Key Level Detection Settings
#define KEY_LEVEL_REFRESH_TIMEFRAME    PERIOD_H4  // Timeframe for refreshing key levels
#define REFRESH_ON_NEW_DAY            true        // Force refresh at start of new day
#define REFRESH_ON_BREAKOUT           true        // Refresh after confirmed breakout
#define SHOW_DEBUG_PRINTS             true        // Show debug information
#define ENFORCE_MARKET_HOURS          true        // Enforce market hours restrictions

//--- Optimization Parameters
input group "Backtest Configuration"
input datetime TestStartDate = D'2024.01.01';  // Backtest start date
input datetime TestEndDate = D'2024.03.19';    // Backtest end date
input bool     UseSpreadFilter = true;         // Filter trades based on spread
input int      MaxSpreadPoints = 20;           // Maximum allowed spread in points
input bool     UseRealVolume = false;          // Use real volume data if available

//--- Strategy Parameters
input group "Strategy Parameters"
input int     LookbackPeriod = 100;    // Historical bars to analyze
input double  MinStrength = 0.55;      // Level strength threshold (0.1-1.0)
input int     MinTouches = 2;          // Minimum level touches required

//--- Performance Metrics
input group "Performance Settings"
input double  MinWinRate = 55.0;       // Minimum required win rate %
input double  MinProfitFactor = 1.5;   // Minimum required profit factor
input int     MinTrades = 30;          // Minimum number of trades for validation
input double  MaxDrawdown = 20.0;      // Maximum allowed drawdown %
input bool    SaveOptimizationResults = true;  // Save detailed optimization results

//--- Money Management
input group "Money Management"
input double  InitialBalance = 10000;  // Initial balance for testing
input double  MaxRiskPerDay = 5.0;     // Maximum daily risk %
input int     MaxOpenTrades = 3;       // Maximum simultaneous open trades
input bool    CompoundProfits = true;  // Compound profits during testing
input double  MaxLossPerMonth = 10.0;  // Maximum monthly loss %

//--- Market Specific Constants
// Forex
#define FOREX_TOUCH_ZONE              2.5         // Touch zone size in pips
#define FOREX_MIN_BOUNCE              1.0         // Minimum bounce size in pips

// US500
#define INDEX_TOUCH_ZONE              5.0         // Touch zone size in points
#define INDEX_MIN_BOUNCE              2.0         // Minimum bounce size in points

// Crypto
#define CRYPTO_TOUCH_ZONE             500.0       // Touch zone size in USD
#define CRYPTO_MIN_BOUNCE             250.0       // Minimum bounce size in USD

//--- Volume Analysis Parameters
input group "Volume Configuration"
input double  VolumeFactor = 1.5;      // Required volume multiplier (1.5 = 150% of average)
input int     VolumeMA = 20;           // Periods for volume moving average
input bool    UseRelativeVolume = true; // Use relative volume comparison
input double  MinVolumeThreshold = 1000; // Minimum volume threshold

//--- Breakout Parameters
input group "Breakout Parameters"
input int    RangeBars        = 20;    // Number of bars for range
input double LotSize          = 0.1;    // Trade lot size
input int    Slippage         = 3;      // Maximum slippage
input double StopLossPips     = 20;     // Stop Loss in pips
input double TakeProfitPips   = 40;     // Take Profit in pips
input bool   RequireRetest    = true;   // Wait for retest before entry
input bool   ShowH1Levels     = true;   // Show H1 levels on chart

//--- Risk Management
input group "Risk Management"
input double RiskPercent = 2.0;        // Risk per trade (% of balance)
input bool   UseFixedLots = false;     // Use fixed lot size instead of risk %
input bool   UseTrailingStop = true;   // Enable trailing stop
input double TrailingStart = 20;       // Pips in profit before trailing
input double TrailingStep = 5;         // Trailing step in pips

//--- Time Filters
input group "Trading Hours"
input bool   UseTimeFilter = true;     // Enable time filter
input string TradingHoursStart = "08:00";  // Trading session start (broker time)
input string TradingHoursEnd = "16:00";    // Trading session end (broker time)
input bool   MondayFilter = true;      // Filter out Monday
input bool   FridayFilter = true;      // Filter out Friday

//--- Global Variables
CVSolStrategy g_strategy;
CVSolMarketConfig g_marketConfig;
CVSolBreakout g_breakout;  // Add breakout strategy instance
datetime g_lastBarTime = 0;
datetime g_lastRefreshTime = 0;
datetime g_lastDayChecked = 0;
ENUM_TIMEFRAMES g_lastTimeframe = PERIOD_CURRENT;
ENUM_MARKET_TYPE g_marketType = MARKET_TYPE_UNKNOWN;

//--- Static variables for time tracking
static datetime s_lastDebugTime = 0;
static datetime s_lastProcessTime = 0;

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
    
    // Validate backtest dates
    if(OPTIMIZATION_MODE)
    {
        datetime currentTime = TimeCurrent();
        
        // Ensure dates are valid
        if(TestStartDate >= TestEndDate)
        {
            Print("❌ Invalid backtest dates: Start date must be before end date");
            return INIT_FAILED;
        }
        
        if(TestEndDate > currentTime)
        {
            Print("❌ End date cannot be in the future");
            return INIT_FAILED;
        }
        
        // Calculate testing periods
        datetime optimizationStart = TestStartDate;
        datetime optimizationEnd = TestEndDate;
        datetime outOfSampleStart = optimizationEnd;
        datetime outOfSampleEnd = currentTime;
        
        // Log testing configuration
        Print("\n=== Backtest Configuration ===");
        Print("Optimization Period: ", TimeToString(optimizationStart), " to ", TimeToString(optimizationEnd));
        Print("Out-of-Sample Period: ", TimeToString(outOfSampleStart), " to ", TimeToString(outOfSampleEnd));
        
        // Store period information for statistics tracking
        CVSolStatistics::ConfigureTestPeriods(
            optimizationStart,
            optimizationEnd,
            outOfSampleStart,
            outOfSampleEnd
        );
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
            CVSolForexData::InitForex(SHOW_DEBUG_PRINTS);
            CVSolForexData::ConfigureForex(FOREX_TOUCH_ZONE, FOREX_MIN_BOUNCE);
            break;
            
        case MARKET_TYPE_INDEX_US500:
            CVSolIndicesData::InitIndices(SHOW_DEBUG_PRINTS);
            break;
            
        case MARKET_TYPE_CRYPTO:
            {  // Added scope
                // For crypto, we use direct price values (in USD)
                double cryptoTouchZone = CRYPTO_TOUCH_ZONE;
                double cryptoMinBounce = CRYPTO_MIN_BOUNCE;
                
                // Adjust based on price scale if needed
                double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                if(currentPrice > 10000)  // For high-value coins like BTC
                {
                    cryptoTouchZone = MathMax(cryptoTouchZone, currentPrice * 0.005);  // At least 0.5% of price
                    cryptoMinBounce = MathMax(cryptoMinBounce, currentPrice * 0.0025);  // At least 0.25% of price
                }
                
                if(SHOW_DEBUG_PRINTS)
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
                
                CVSolForexData::InitForex(SHOW_DEBUG_PRINTS);
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
            touchZone = CVSolForexData::PipsToPrice(FOREX_TOUCH_ZONE);
            minBounce = CVSolForexData::PipsToPrice(FOREX_MIN_BOUNCE);
            break;
        case MARKET_TYPE_INDEX_US500:
            touchZone = INDEX_TOUCH_ZONE;
            minBounce = INDEX_MIN_BOUNCE;
            break;
        case MARKET_TYPE_CRYPTO:
            touchZone = CRYPTO_TOUCH_ZONE;
            minBounce = CRYPTO_MIN_BOUNCE;
            break;
    }
    
    // Initialize market config with market-specific parameters
    g_marketConfig.Configure(
        _Symbol,
        g_marketType,
        touchZone,
        minBounce,
        MinStrength,
        MinTouches,
        LookbackPeriod);
    
    // Initialize strategy with all parameters
    if(!g_strategy.Init(
        LookbackPeriod, 
        MinStrength, 
        touchZone, 
        MinTouches, 
        SHOW_DEBUG_PRINTS,
        UseRealVolume))
    {
        Print("❌ Failed to initialize strategy");
        return INIT_FAILED;
    }
    
    // Initialize breakout strategy with all parameters
    if(!g_breakout.Init(
        RangeBars,
        LotSize,
        Slippage,
        StopLossPips,
        TakeProfitPips,
        RequireRetest))
    {
        Print("❌ Failed to initialize breakout strategy");
        return INIT_FAILED;
    }
    
    // Configure volume analysis
    g_breakout.ConfigureVolumeAnalysis(VolumeFactor, VolumeMA);
    
    // Configure risk management
    g_breakout.ConfigureRiskManagement(
        RiskPercent,
        UseFixedLots,
        UseTrailingStop,
        TrailingStart,
        TrailingStep
    );
    
    // Configure time filters
    CVSolMarketHours::ConfigureTimeFilters(
        UseTimeFilter,
        TradingHoursStart,
        TradingHoursEnd,
        MondayFilter,
        FridayFilter
    );
    
    // Configure performance requirements
    CVSolStatistics::ConfigurePerformanceRequirements(
        MinWinRate,
        MinProfitFactor,
        MinTrades,
        MaxDrawdown
    );
    
    // Configure money management
    CVSolRisk::ConfigureMoneyManagement(
        InitialBalance,
        MaxRiskPerDay,
        MaxOpenTrades,
        CompoundProfits,
        MaxLossPerMonth
    );
    
    // Draw initial levels if enabled
    if(ShowH1Levels)
    {
        g_breakout.DrawLevels();
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
    ObjectsDeleteAll(0, "H1_");  // Delete all H1-related objects
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    datetime currentBarTime = iTime(_Symbol, Period(), 0);
    datetime currentTime = TimeCurrent();
    bool isNewBar = (currentBarTime != g_lastBarTime);
    bool shouldPrintDebug = SHOW_DEBUG_PRINTS && isNewBar;
    
    // Check if market is closed or trading is restricted
    if(ENFORCE_MARKET_HOURS && !CVSolMarketHours::IsMarketOpen(g_marketType, true))
    {
        if(shouldPrintDebug)
            Print("Market is closed or restricted for ", _Symbol, ", skipping processing");
        return;
    }
    
    // Determine if we should refresh key levels
    bool shouldRefresh = false;
    
    // Check for new bar on refresh timeframe
    datetime currentRefreshBar = iTime(_Symbol, KEY_LEVEL_REFRESH_TIMEFRAME, 0);
    if(currentRefreshBar > g_lastRefreshTime)
    {
        shouldRefresh = true;
        if(SHOW_DEBUG_PRINTS)
            Print("Refreshing key levels due to new ", EnumToString(KEY_LEVEL_REFRESH_TIMEFRAME), " bar");
    }
    
    // Check for new day if enabled
    if(REFRESH_ON_NEW_DAY)
    {
        MqlDateTime currentMqlTime;
        TimeToStruct(currentTime, currentMqlTime);
        datetime currentDayStart = StringToTime(StringFormat("%04d.%02d.%02d 00:00", 
            currentMqlTime.year, currentMqlTime.mon, currentMqlTime.day));
            
        if(currentDayStart > g_lastDayChecked)
        {
            shouldRefresh = true;
            g_lastDayChecked = currentDayStart;
            if(SHOW_DEBUG_PRINTS)
                Print("Refreshing key levels for new trading day");
        }
    }
    
    // Check for breakout if enabled
    if(REFRESH_ON_BREAKOUT && isNewBar)
    {
        // Get the latest key level
        SKeyLevel strongestLevel;
        if(g_strategy.FindKeyLevels(strongestLevel))
        {
            double currentClose = iClose(_Symbol, Period(), 0);
            double previousClose = iClose(_Symbol, Period(), 1);
            
            // Simple breakout detection - can be enhanced based on your specific criteria
            if((previousClose <= strongestLevel.price && currentClose > strongestLevel.price) ||
               (previousClose >= strongestLevel.price && currentClose < strongestLevel.price))
            {
                shouldRefresh = true;
                if(SHOW_DEBUG_PRINTS)
                    Print("Refreshing key levels after potential breakout");
            }
        }
    }
    
    // Update state and process strategy if needed
    g_lastBarTime = currentBarTime;
    g_lastTimeframe = Period();
    
    if(shouldRefresh)
    {
        g_lastRefreshTime = currentRefreshBar;
        g_strategy.ProcessStrategy();
        ChartRedraw();
        
        // Log key levels after refresh if debug is enabled
        if(SHOW_DEBUG_PRINTS)
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
                    
                Print("Updated key level: ",
                      "Price=", DoubleToString(strongestLevel.price, _Digits),
                      ", Strength=", DoubleToString(strongestLevel.strength, 2),
                      ", Touches=", strongestLevel.touchCount,
                      strongestLevel.isResistance ? " (Resistance)" : " (Support)",
                      volumeInfo,
                      "\n", touchInfo
                );
            }
        }
    }
    
    // Your breakout and retest trading logic here
    if(isNewBar)
    {
        // Update breakout levels
        g_breakout.UpdateLevels();
        
        // Update visualization if enabled
        if(ShowH1Levels)
        {
            g_breakout.DrawLevels();
        }
        
        // Check for breakout opportunities
        bool isLong = false;
        if(g_breakout.CheckBreakout(isLong))
        {
            // Execute trade if breakout is confirmed
            if(g_breakout.ExecuteBreakoutTrade(isLong))
            {
                Print("Breakout trade executed: ", isLong ? "BUY" : "SELL");
            }
        }
        
        // Check and manage existing positions
        g_breakout.CheckPositionClose();
    }
}