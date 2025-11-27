//+------------------------------------------------------------------+
//| GrandeTradingSystem.mq5                                          |
//| Copyright 2024, Grande Tech                                      |
//| Advanced Trading System - Regime Detection + Key Levels         |
//+------------------------------------------------------------------+
// Pattern from: MetaTrader 5 MQL5 Documentation
// Reference: Expert Advisor OnInit/OnTick/OnDeinit event handling patterns
//
// MULTI-CURRENCY PAIR COMPATIBILITY:
// This EA is designed to work with all major FX pairs:
//   - EUR/USD, GBP/USD, USD/CHF, USD/CAD (4-5 digit pairs)
//   - USD/JPY, EUR/JPY, GBP/JPY, AUD/JPY (2-3 digit JPY pairs)
//   - AUD/USD, NZD/USD (commodity currency pairs)
//
// Key features for universal compatibility:
//   1. GetPipSize() handles different digit formats automatically
//   2. ATR-based calculations adapt to each pair's volatility
//   3. Symbol properties queried dynamically (volume steps, stop levels)
//   4. PointValueUSD() calculates correct pip values for any pair
//   5. Touch zones use ATR instead of fixed pips (InpTouchZone = 0)
//
// IMPORTANT: Always backtest on specific pair before live trading
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.01"
#property description "Advanced trading system combining market regime detection with key level analysis"
#property description "Universal multi-currency pair support for all major FX pairs"

#include "Include/GrandeMarketRegimeDetector.mqh"
#include "Include/GrandeKeyLevelDetector.mqh"
#include "Include/GrandeCandleAnalyzer.mqh"
#include "Include/GrandeFibonacciCalculator.mqh"
#include "Include/GrandeConfluenceDetector.mqh"
#include "Include/GrandeLimitOrderManager.mqh"
#include "mcp/analyze_sentiment_server/GrandeNewsSentimentIntegration.mqh"
#include "Include/GrandeMT5CalendarReader.mqh"
#include "Include/GrandeIntelligentReporter.mqh"
#include "Include/GrandeDatabaseManager.mqh"
#include "..\VSol\AdvancedTrendFollower.mqh"
#include "..\VSol\GrandeRiskManager.mqh"
#include <Trade\Trade.mqh>

// Infrastructure components
#include "Include/GrandeStateManager.mqh"
#include "Include/GrandeConfigManager.mqh"
#include "Include/GrandeComponentRegistry.mqh"
#include "Include/GrandeHealthMonitor.mqh"
#include "Include/GrandeEventBus.mqh"

// Profit-critical modules
#include "Include/GrandeProfitCalculator.mqh"
#include "Include/GrandePerformanceTracker.mqh"
#include "Include/GrandeSignalQualityAnalyzer.mqh"
#include "Include/GrandePositionOptimizer.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== Market Regime Settings ==="
input double InpADXTrendThreshold = 25.0;        // ADX Threshold for Trending
input double InpADXBreakoutMin = 18.0;           // ADX Minimum for Breakout Setup
input int    InpATRPeriod = 21;                  // ATR Period (optimized for H4)
input int    InpATRAvgPeriod = 90;               // ATR Average Period
input double InpHighVolMultiplier = 2.0;         // High Volatility Multiplier

input group "=== Key Level Detection Settings ==="
input int    InpLookbackPeriod = 200;            // Lookback Period for Key Levels (reduced for H4)
input double InpMinStrength = 0.40;              // Minimum Level Strength
input double InpTouchZone = 0.0;                 // Touch Zone (0 = auto ATR-based, or manual value)
input int    InpMinTouches = 1;                  // Minimum Touches Required

input group "=== Trading Settings ==="
input bool   InpEnableTrading = true;           // Enable Live Trading
input int    InpMagicNumber = 123456;            // Magic Number for Trades
input int    InpSlippage = 30;                   // Slippage in Points
input string InpOrderTag = "[GRANDE]";           // Order comment tag for identification

input group "=== Risk Management Settings ==="
input double InpRiskPctTrend = 2.0;              // Risk % for Trend Trades (reduced for H4)
input double InpRiskPctRange = 0.8;              // Risk % for Range Trades (reduced for H4)
input double InpRiskPctBreakout = 3.5;           // Risk % for Breakout Trades (reduced for H4)
input double InpMaxRiskPerTrade = 5.0;           // Maximum Risk % per Trade
input double InpMaxDrawdownPct = 30.0;           // Maximum Account Drawdown %
input double InpEquityPeakReset = 5.0;           // Reset Peak after X% Recovery
input int    InpMaxPositions = 7;                // Maximum Concurrent Positions

input group "=== Emergency Margin Protection ==="
input bool   InpEnableMarginProtection = true;   // Enable Emergency Margin Protection
input double InpMinMarginLevelToTrade = 150.0;   // Minimum Margin Level to Open New Trades (%)
input double InpMarginWarningLevel = 150.0;      // Margin Level Warning Threshold (%)
input double InpMarginCriticalLevel = 120.0;     // Margin Level Critical Threshold (%)
input double InpMarginEmergencyLevel = 110.0;    // Margin Level Emergency Threshold (%)
input int    InpMarginCheckIntervalSeconds = 5;  // Margin Check Interval (seconds)
input bool   InpCloseWorstPositionsFirst = true; // Close worst-performing positions first
input int    InpMaxPositionsToClose = 2;         // Max positions to close per emergency cycle

input group "=== Stop Loss & Take Profit ==="
input double InpSLATRMultiplier = 1.8;           // Stop Loss ATR Multiplier (wider for H4)
input double InpTPRewardRatio = 3.0;             // Take Profit Reward Ratio (R:R)
input double InpBreakevenATR = 1.5;              // Move to Breakeven after X ATR (delayed for H4)
input double InpPartialCloseATR = 2.0;           // Partial Close after X ATR (delayed for H4)
input double InpBreakevenBuffer = 0.5;           // Breakeven Buffer (pips)

input group "=== Position Management ==="
input bool   InpEnableTrailingStop = true;       // Enable Trailing Stops
input double InpTrailingATRMultiplier = 0.8;     // Trailing Stop ATR Multiplier (wider for H4)
input bool   InpEnablePartialCloses = true;      // Enable Partial Profit Taking
input double InpPartialClosePercent = 33.0;      // % of Position to Close
input bool   InpEnableBreakeven = true;          // Enable Breakeven Stops
input ENUM_TIMEFRAMES InpManagementTimeframe = PERIOD_H1; // Only manage on this TF when gated
input bool   InpManageOnlyOnTimeframe = true;    // Gate management to InpManagementTimeframe
input double InpMinModifyPips = 7.0;             // Min pips change to modify SL/TP
input double InpMinModifyATRFraction = 0.07;     // Fraction of ATR for material change
input int    InpMinModifyCooldownSec = 180;      // Cooldown between SL/TP modifies
input double InpMinStopDistanceMultiplier = 1.5; // Multiplier for minimum stop distance
input bool   InpValidateStopLevels = true;       // Enable comprehensive stop level validation

input group "=== Intelligent Position Scaling ==="
input bool   InpEnableIntelligentScaling = true; // Enable intelligent position scaling
input int    InpScalingRangePeriods = 20;        // 15-min periods for range calculation
input double InpScalingRangeBuffer = 0.25;       // Buffer as fraction of range (0.25 = 25%)
input int    InpMaxScalingPositions = 3;         // Maximum positions for scaling
input double InpMinRangeSizePips = 20.0;         // Minimum range size to enable scaling
input bool   InpLogScalingDecisions = true;      // Log scaling decisions for analysis

input group "=== Cool-Off Period Settings ==="
input bool   InpEnableCooloffPeriod = true;      // Enable cool-off period after position closes
input int    InpTPCooloffMinutes = 30;           // Minutes to wait after TP hit (0=disabled)
input int    InpSLCooloffMinutes = 15;           // Minutes to wait after SL hit (0=disabled)
input bool   InpAllowDirectionChangeOverride = true;  // Allow re-entry if direction changes
input bool   InpLogCooloffDecisions = true;      // Log cool-off blocking decisions

input group "=== Cool-Off Advanced Settings ==="
input bool   InpEnableDynamicCooloff = true;     // Enable ATR-based dynamic cool-off adjustment
input double InpATRHighVolMultiplier = 1.5;      // Multiplier for high volatility (>1.5x avg ATR)
input double InpATRLowVolMultiplier = 0.7;       // Multiplier for low volatility (<0.7x avg ATR)
input bool   InpEnableRegimeAwareCooloff = true; // Enable regime-based cool-off adjustment
input double InpTrendingCooloffMultiplier = 0.7; // Multiplier for strong trends (shorter wait)
input double InpRangingCooloffMultiplier = 1.3;  // Multiplier for ranging markets (longer wait)
input bool   InpEnableCooloffStatistics = true;  // Track cool-off effectiveness statistics
input int    InpStatisticsReportMinutes = 60;    // Minutes between statistics reports

input group "=== Limit Order Settings ==="
input bool   InpUseLimitOrders = true;           // Use limit orders instead of market orders
input int    InpMaxLimitDistancePips = 30;       // Max distance for limit order placement (pips)
input int    InpLimitOrderExpirationHours = 4;   // Limit order expiration time (hours)
input bool   InpCancelStaleOrders = true;        // Cancel orders if price moves too far away
input double InpStaleOrderDistancePips = 50.0;   // Distance to consider order "stale" (pips)
input int    InpLimitOrderDuplicateTolerancePoints = 3; // Tolerance for duplicate order detection (points)

input group "=== Technical Validation Settings ==="
input bool   InpEnableTechnicalValidation = true;  // Require technical confirmation before entry
input double InpMaxWickToBodyRatio = 2.0;          // Max acceptable wick-to-body ratio
input int    InpMinConfluenceScore = 2;            // Minimum confluence factors required
input bool   InpRequireFibConfluence = true;       // Require Fibonacci level nearby
input bool   InpRequireKeyLevelConfluence = true;  // Require key level nearby
input bool   InpRejectExcessiveWicks = true;       // Reject entries with excessive wicks
input bool   InpRejectDojiCandles = true;          // Reject doji candles (indecision)

input group "=== Fibonacci Settings ==="
input int    InpFibLookbackBars = 100;            // Bars to search for swing high/low
input double InpFibProximityPips = 10.0;          // Pips to consider "at" Fibonacci level
input int    InpFibMinSwingBars = 5;              // Minimum bars between swing points
input bool   InpPreferGoldenRatio = true;         // Prefer 61.8% level for entries

input group "=== Confluence Settings ==="
input double InpConfluenceProximityPips = 10.0;   // Pips to group factors into zones
input int    InpMaxConfluenceZones = 3;           // Max confluence zones to analyze
input bool   InpLogConfluenceAnalysis = true;     // Log confluence zone analysis

input group "=== Signal Settings ==="
input int    InpEMA50Period = 76;                // 76 EMA Period (optimal for H4)
input int    InpEMA200Period = 200;              // 200 EMA Period
input int    InpEMA20Period = 20;                // 20 EMA Period
input int    InpRSIPeriod = 14;                  // RSI Period
input int    InpStochPeriod = 14;                // Stochastic Period
input int    InpStochK = 3;                      // Stochastic %K
input int    InpStochD = 3;                      // Stochastic %D

input group "=== Database Settings ==="
input bool   InpEnableDatabase = true;          // Enable Database Logging
input string InpDatabasePath = "Data/GrandeTradingData.db"; // Database File Path
input bool   InpDatabaseDebug = false;           // Enable Database Debug Prints
input int    InpDataCollectionInterval = 60;     // Data Collection Interval (seconds)
input int    InpFinBERTAnalysisInterval = 300;   // FinBERT Analysis Interval (seconds)

input group "=== Advanced Trend Follower ==="
input bool   InpEnableTrendFollower = true;      // Enable Trend Follower Confirmation
input bool   InpRequireEmaAlignment = false;     // Require Additional EMA Alignment (50/200)
input int    InpTFEmaFastPeriod = 50;            // TF Fast EMA Period
input int    InpTFEmaSlowPeriod = 200;           // TF Slow EMA Period  
input int    InpTFEmaPullbackPeriod = 20;        // TF Pullback EMA Period
input int    InpTFMacdFastPeriod = 12;           // TF MACD Fast Period
input int    InpTFMacdSlowPeriod = 26;           // TF MACD Slow Period
input int    InpTFMacdSignalPeriod = 9;          // TF MACD Signal Period
input int    InpTFRsiPeriod = 14;                // TF RSI Period
input double InpTFRsiThreshold = 50.0;           // TF RSI Threshold

// RSI Risk Management Settings
input bool   InpEnableMTFRSI = true;              // Gate entries by H4/D1 RSI
input double InpH4RSIOverbought = 75.0;           // H4 RSI overbought
input double InpH4RSIOversold  = 25.0;            // H4 RSI oversold
input bool   InpUseD1RSI = true;                  // Also gate by D1 extremes
input double InpD1RSIOverbought = 80.0;
input double InpD1RSIOversold  = 20.0;

input bool   InpDisableRiskManagerTemp = false;   // EMERGENCY: Disable risk manager (error recovery)
input bool   InpEnableRSIExits = true;            // Enable RSI-based exits
input double InpRSIExitOB = 70.0;                 // Chart TF RSI overbought (long exit trigger)
input double InpRSIExitOS = 30.0;                 // Chart TF RSI oversold (short exit trigger)
input double InpRSIPartialClose = 0.50;           // Fraction to close on RSI extreme
input int    InpRSIExitMinProfitPips = 10;        // Require min unrealized profit
input int    InpTFAdxPeriod = 14;                // TF ADX Period
input double InpTFAdxThreshold = 25.0;           // TF ADX Minimum Threshold
input bool   InpShowTrendFollowerPanel = true;   // Show TF Diagnostic Panel

// RSI Exit Enhancements
input int    InpRSIExitCooldownSec = 900;         // Cooldown between RSI partial closes (seconds)
input double InpMinRemainingVolume = 0.02;        // Min remaining volume after partial close
input bool   InpExitRequireATROK = false;         // Require ATR not collapsing for RSI exit
input double InpExitMinATRRat = 0.80;             // Min ATR ratio vs 10-bar avg (0.8 = 80%)
input bool   InpExitStructureGuard = false;       // Require >=1R in favor before RSI exit

input group "=== Display Settings ==="
input bool   InpShowRegimeBackground = true;     // Show Regime Background Colors
input bool   InpShowRegimeInfo = true;           // Show Regime Info Panel
input bool   InpShowKeyLevels = true;            // Show Key Level Lines
input bool   InpShowSystemStatus = true;         // Show System Status Panel
input bool   InpShowRegimeTrendArrows = true;    // Show Regime Trend Arrows
input bool   InpShowADXStrengthMeter = true;     // Show ADX Strength Meter
input bool   InpShowRegimeAlerts = true;         // Show Regime Change Alerts
input bool   InpLogDetailedInfo = true;          // Log Detailed Trade Information
input bool   InpLogVerbose = false;             // Verbose Logging (reduced noise - only important changes)
input bool   InpLogDebugInfo = false;            // Log Debug Information (Risk Manager)
input bool   InpLogAllErrors = true;             // Log ALL Errors and Retries (CRITICAL)
input bool   InpLogImportantOnly = true;         // Log only important events (signals, trades, errors)

input group "=== Update Settings ==="
input int    InpRegimeUpdateSeconds = 5;         // Regime Update Interval (seconds)
input int    InpKeyLevelUpdateSeconds = 300;     // Key Level Update Interval (seconds)
input int    InpRiskUpdateSeconds   = 2;         // Risk Update Interval (seconds)

input group "=== Calendar AI Settings ==="
input bool   InpEnableCalendarAI        = true;  // Enable Calendar AI analysis
input int    InpCalendarUpdateMinutes   = 15;    // Calendar AI update interval (minutes)
input int    InpCalendarLookaheadHours  = 24;    // Lookahead window for calendar events (hours)
input double InpCalendarMinConfidence   = 0.60;  // Log highlight threshold for confidence
input bool   InpCalendarOnlyOnTimeframe = false; // Run calendar only on a specific timeframe
input ENUM_TIMEFRAMES InpCalendarRunTimeframe = PERIOD_H1; // Timeframe to run calendar

// DISABLED: News Service (commented out - only using free economic calendar data)
// input group "=== News Sentiment Settings ==="
// input bool   InpEnableNewsSentiment    = false; // Enable News Sentiment Analysis (DISABLED - requires paid APIs)
// input int    InpNewsUpdateMinutes      = 30;    // News analysis update interval (minutes)
// input double InpNewsMinConfidence      = 0.70;  // Minimum confidence for news signals

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CGrandeMarketRegimeDetector*  g_regimeDetector;
CGrandeKeyLevelDetector*      g_keyLevelDetector;
CGrandeCandleAnalyzer*        g_candleAnalyzer;
CGrandeFibonacciCalculator*   g_fibCalculator;
CGrandeConfluenceDetector*    g_confluenceDetector;
CGrandeLimitOrderManager*     g_limitOrderManager;
CAdvancedTrendFollower*       g_trendFollower;
CGrandeRiskManager*           g_riskManager;
CGrandeIntelligentReporter*   g_reporter;
CGrandeDatabaseManager*       g_databaseManager;
// CMultiTimeframeAnalyzer*      g_mtfAnalyzer;  // Temporarily disabled
CNewsSentimentIntegration     g_newsSentiment;
CGrandeMT5NewsReader          g_calendarReader;
CTrade                        g_trade;
RegimeConfig                  g_regimeConfig;
RiskConfig                    g_riskConfig;

// Infrastructure components
CGrandeStateManager*          g_stateManager;
CGrandeConfigManager*         g_configManager;
CGrandeComponentRegistry*     g_componentRegistry;
CGrandeHealthMonitor*         g_healthMonitor;
CGrandeEventBus*              g_eventBus;
long                          g_chartID;

// Profit-critical modules
CGrandeProfitCalculator*      g_profitCalculator;
CGrandePerformanceTracker*    g_performanceTracker;
CGrandeSignalQualityAnalyzer* g_signalQualityAnalyzer;
CGrandePositionOptimizer*     g_positionOptimizer;

// Signal analysis throttling variables
int                           g_signalAnalysisThrottleSeconds = 10; // Reduced from 30 to 10 seconds for faster analysis

// Intelligent Position Scaling variables
// Note: All state variables (timestamps, RSI cache, range, cool-off) are now managed by GrandeStateManager
int                           g_rangeHandle15M = INVALID_HANDLE;

// Cooldown storage per ticket for partial closes
struct SRsiExitState {
    datetime lastPartialTime;
};
// We will store cooldowns in chart objects to avoid dynamic arrays/maps complexity
// Key format: "RSIExitCooldown_" + IntegerToString(ticket)

// Chart object names
const string REGIME_BACKGROUND_NAME = "GrandeRegimeBackground";
const string REGIME_INFO_PANEL_NAME = "GrandeRegimeInfoPanel";
const string SYSTEM_STATUS_PANEL_NAME = "GrandeSystemStatusPanel";
const string REGIME_TREND_ARROW_NAME = "GrandeRegimeTrendArrow";
const string ADX_STRENGTH_METER_NAME = "GrandeADXStrengthMeter";
const string REGIME_ALERT_NAME = "GrandeRegimeAlert";

//+------------------------------------------------------------------+
//| Forward declarations                                              |
//+------------------------------------------------------------------+
void ShowStartupSnapshot();
bool FindNearestKeyLevels(const double currentPrice, SKeyLevel &outSupport, SKeyLevel &outResistance);
string BuildGoldenNugget(const RegimeSnapshot &rs, const SKeyLevel &support, const SKeyLevel &resistance);
// New helpers forward declarations
bool HasOpenPositionForSymbolAndMagic(const string symbol, const int magic);
double NormalizeVolumeToStep(const string symbol, double volume);
void NormalizeStops(const bool isBuy, const double entryPrice, double &sl, double &tp);
bool IsPendingPriceValid(const bool isBuyStop, const double levelPrice);
bool HasSimilarPendingOrderForBreakout(const bool isBuyStop, const double levelPrice, const int tolerancePoints);
bool HasSimilarPendingLimitOrder(const bool isBuyLimit, const double levelPrice, const int tolerancePoints);
void CollectMarketDataForDatabase();
void CollectEnhancedMarketDataForFinBERT();
string CreateComprehensiveMarketContext();
double GetVolumeAverage(int periods);
double GetATRValue();
double GetATRAverage(int periods);
double GetEMAValue(int period);
string GetKeyLevelsJson();
string GetEconomicCalendarJson();
void SaveMarketContextToFile(string jsonData);
// Event Bus helper functions
void PublishOrderEvent(EVENT_TYPE eventType, ulong ticket, string details);
void PublishPositionEvent(EVENT_TYPE eventType, ulong ticket, string details);
void PublishRiskEvent(EVENT_TYPE eventType, string details, double value);
// Core function forward declarations
bool ValidateInputParameters();
void ConfigureTradeFillingMode();
void SetupChartDisplay();
void PerformInitialAnalysis();
void CleanupChartObjects();

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Only show debug initialization info if specifically requested
    if(InpLogDebugInfo)
    {
        Print("=== Grande Tech Advanced Trading System ===");
        Print("Initializing for symbol: ", _Symbol);
    }
    
    // Validate input parameters
    if(!ValidateInputParameters())
    {
        Print("ERROR: Invalid input parameters detected. Please check settings.");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    // Get chart ID
    g_chartID = ChartID();
    
    // Initialize trade object
    g_trade.SetExpertMagicNumber(InpMagicNumber);
    g_trade.SetDeviationInPoints(InpSlippage);
    // Configure supported filling mode for this symbol
    ConfigureTradeFillingMode();
    
    // Initialize database manager
    if(InpEnableDatabase)
    {
        Print("[Grande] Attempting to initialize Database Manager...");
        g_databaseManager = new CGrandeDatabaseManager();
        if(g_databaseManager == NULL)
        {
            Print("ERROR: Failed to create Database Manager");
            return INIT_FAILED;
        }
        
        if(!g_databaseManager.Initialize(InpDatabasePath, InpDatabaseDebug))
        {
            Print("ERROR: Failed to initialize Database Manager");
            delete g_databaseManager;
            g_databaseManager = NULL;
            // Don't fail initialization, just disable database
            Print("[Grande] WARNING: Database disabled due to initialization failure");
        }
        else
        {
            Print("[Grande] ✅ Database Manager initialized successfully: ", InpDatabasePath);
            
            // Initialize historical data backfill if database is enabled
            if(InpEnableDatabase)
            {
                datetime cutoff = TimeCurrent() - (30 * 86400); // 30 days
                if(!g_databaseManager.HasHistoricalData(_Symbol, cutoff))
                {
                    Print("[Grande] Backfilling 30 days of historical data...");
                    if(g_databaseManager.BackfillRecentHistory(_Symbol, PERIOD_CURRENT, 30))
                    {
                        Print("[Grande] ✅ Backfill complete!");
                        if(InpLogDebugInfo)
                            Print(g_databaseManager.GetDataCoverageStats(_Symbol));
                    }
                    else
                    {
                        Print("[Grande] WARNING: Historical data backfill failed, continuing anyway");
                    }
                }
                else if(InpLogDebugInfo)
                {
                    Print("[Grande] Historical data up to date");
                    Print(g_databaseManager.GetDataCoverageStats(_Symbol));
                }
            }
        }
    }
    else
    {
        Print("[Grande] Database logging is DISABLED (InpEnableDatabase = false)");
    }
    
    // Initialize Infrastructure Components
    // Initialize State Manager
    g_stateManager = new CGrandeStateManager();
    if(g_stateManager == NULL)
    {
        Print("ERROR: Failed to create State Manager");
        return INIT_FAILED;
    }
    if(!g_stateManager.Initialize(_Symbol, InpLogDebugInfo))
    {
        Print("ERROR: Failed to initialize State Manager");
        delete g_stateManager;
        g_stateManager = NULL;
        return INIT_FAILED;
    }
    if(InpLogDebugInfo)
        Print("[Grande] ✅ State Manager initialized");
    
    // Initialize Config Manager
    g_configManager = new CGrandeConfigManager();
    if(g_configManager == NULL)
    {
        Print("ERROR: Failed to create Config Manager");
        delete g_stateManager;
        g_stateManager = NULL;
        return INIT_FAILED;
    }
    if(!g_configManager.Initialize(_Symbol, InpLogDebugInfo))
    {
        Print("ERROR: Failed to initialize Config Manager");
        delete g_stateManager;
        delete g_configManager;
        g_stateManager = NULL;
        g_configManager = NULL;
        return INIT_FAILED;
    }
    if(InpLogDebugInfo)
        Print("[Grande] ✅ Config Manager initialized");
    
    // Initialize Component Registry
    g_componentRegistry = new CGrandeComponentRegistry();
    if(g_componentRegistry == NULL)
    {
        Print("ERROR: Failed to create Component Registry");
        delete g_stateManager;
        delete g_configManager;
        g_stateManager = NULL;
        g_configManager = NULL;
        return INIT_FAILED;
    }
    if(!g_componentRegistry.Initialize(InpLogDebugInfo))
    {
        Print("ERROR: Failed to initialize Component Registry");
        delete g_stateManager;
        delete g_configManager;
        delete g_componentRegistry;
        g_stateManager = NULL;
        g_configManager = NULL;
        g_componentRegistry = NULL;
        return INIT_FAILED;
    }
    if(InpLogDebugInfo)
        Print("[Grande] ✅ Component Registry initialized");
    
    // Initialize Event Bus
    g_eventBus = new CGrandeEventBus();
    if(g_eventBus == NULL)
    {
        Print("ERROR: Failed to create Event Bus");
        delete g_stateManager;
        delete g_configManager;
        delete g_componentRegistry;
        g_stateManager = NULL;
        g_configManager = NULL;
        g_componentRegistry = NULL;
        return INIT_FAILED;
    }
    if(!g_eventBus.Initialize(1000, InpLogDebugInfo, InpLogVerbose))
    {
        Print("ERROR: Failed to initialize Event Bus");
        delete g_stateManager;
        delete g_configManager;
        delete g_componentRegistry;
        delete g_eventBus;
        g_stateManager = NULL;
        g_configManager = NULL;
        g_componentRegistry = NULL;
        g_eventBus = NULL;
        return INIT_FAILED;
    }
    if(InpLogDebugInfo)
        Print("[Grande] ✅ Event Bus initialized");
    
    // Initialize Health Monitor
    g_healthMonitor = new CGrandeHealthMonitor();
    if(g_healthMonitor == NULL)
    {
        Print("ERROR: Failed to create Health Monitor");
        delete g_stateManager;
        delete g_configManager;
        delete g_componentRegistry;
        delete g_eventBus;
        g_stateManager = NULL;
        g_configManager = NULL;
        g_componentRegistry = NULL;
        g_eventBus = NULL;
        return INIT_FAILED;
    }
    if(!g_healthMonitor.Initialize(g_componentRegistry, InpLogDebugInfo))
    {
        Print("ERROR: Failed to initialize Health Monitor");
        delete g_stateManager;
        delete g_configManager;
        delete g_componentRegistry;
        delete g_eventBus;
        delete g_healthMonitor;
        g_stateManager = NULL;
        g_configManager = NULL;
        g_componentRegistry = NULL;
        g_eventBus = NULL;
        g_healthMonitor = NULL;
        return INIT_FAILED;
    }
    if(InpLogDebugInfo)
        Print("[Grande] ✅ Health Monitor initialized");
    
    // Publish initialization event
    if(g_eventBus != NULL)
        g_eventBus.PublishEvent(EVENT_SYSTEM_INIT, "GrandeTradingSystem", 
                               "EA initialization started", 0.0, 0);
    
    // Configure risk management settings
    g_riskConfig.risk_percent_trend = InpRiskPctTrend;
    g_riskConfig.risk_percent_range = InpRiskPctRange;
    g_riskConfig.risk_percent_breakout = InpRiskPctBreakout;
    g_riskConfig.max_risk_per_trade = InpMaxRiskPerTrade;
    g_riskConfig.sl_atr_multiplier = InpSLATRMultiplier;
    g_riskConfig.tp_reward_ratio = InpTPRewardRatio;
    g_riskConfig.breakeven_atr = InpBreakevenATR;
    g_riskConfig.partial_close_atr = InpPartialCloseATR;
    g_riskConfig.max_drawdown_percent = InpMaxDrawdownPct;
    g_riskConfig.equity_peak_reset = InpEquityPeakReset;
    g_riskConfig.max_positions = InpMaxPositions;
    g_riskConfig.enable_trailing_stop = InpEnableTrailingStop;
    g_riskConfig.trailing_atr_multiplier = InpTrailingATRMultiplier;
    g_riskConfig.enable_partial_closes = InpEnablePartialCloses;
    g_riskConfig.partial_close_percent = InpPartialClosePercent;
    g_riskConfig.enable_breakeven = InpEnableBreakeven;
    g_riskConfig.breakeven_buffer = InpBreakevenBuffer;
    g_riskConfig.management_timeframe = InpManagementTimeframe;
    g_riskConfig.manage_only_on_timeframe = InpManageOnlyOnTimeframe;
    g_riskConfig.min_modify_pips = InpMinModifyPips;
    g_riskConfig.min_modify_atr_fraction = InpMinModifyATRFraction;
    g_riskConfig.min_modify_cooldown_sec = InpMinModifyCooldownSec;
    g_riskConfig.min_stop_distance_multiplier = InpMinStopDistanceMultiplier;
    g_riskConfig.validate_stop_levels = InpValidateStopLevels;
    
    // Configure regime detection settings
    g_regimeConfig.adx_trend_threshold = InpADXTrendThreshold;
    g_regimeConfig.adx_breakout_min = InpADXBreakoutMin;
    g_regimeConfig.adx_ranging_threshold = InpADXBreakoutMin;
    g_regimeConfig.atr_period = InpATRPeriod;
    g_regimeConfig.atr_avg_period = InpATRAvgPeriod;
    g_regimeConfig.high_vol_multiplier = InpHighVolMultiplier;
    g_regimeConfig.tf_primary = PERIOD_H1;
    g_regimeConfig.tf_secondary = PERIOD_H4;
    g_regimeConfig.tf_tertiary = PERIOD_D1;
    
    // Create and initialize regime detector
    g_regimeDetector = new CGrandeMarketRegimeDetector();
    if(g_regimeDetector == NULL)
    {
        Print("ERROR: Failed to create Market Regime Detector");
        return INIT_FAILED;
    }
    
    if(!g_regimeDetector.Initialize(_Symbol, g_regimeConfig, InpLogDebugInfo))
    {
        Print("ERROR: Failed to initialize Market Regime Detector");
        delete g_regimeDetector;
        g_regimeDetector = NULL;
        return INIT_FAILED;
    }
    
    // Create and initialize key level detector
    g_keyLevelDetector = new CGrandeKeyLevelDetector();
    if(g_keyLevelDetector == NULL)
    {
        Print("ERROR: Failed to create Key Level Detector");
        delete g_regimeDetector;
        g_regimeDetector = NULL;
        return INIT_FAILED;
    }
    
    if(!g_keyLevelDetector.Initialize(InpLookbackPeriod, InpMinStrength, InpTouchZone, 
                                      InpMinTouches, InpLogDebugInfo)) // Pass debug flag to detector
    {
        Print("ERROR: Failed to initialize Key Level Detector");
        delete g_regimeDetector;
        delete g_keyLevelDetector;
        g_regimeDetector = NULL;
        g_keyLevelDetector = NULL;
        return INIT_FAILED;
    }
    
    // Create candle analyzer
    g_candleAnalyzer = new CGrandeCandleAnalyzer(_Symbol, PERIOD_CURRENT);
    if(g_candleAnalyzer == NULL)
    {
        Print("ERROR: Failed to create Candle Analyzer");
        delete g_regimeDetector;
        delete g_keyLevelDetector;
        g_regimeDetector = NULL;
        g_keyLevelDetector = NULL;
        return INIT_FAILED;
    }
    g_candleAnalyzer.SetMinBodyPercentage(0.1);
    g_candleAnalyzer.SetWickRatioThreshold(InpMaxWickToBodyRatio);
    if(InpLogDebugInfo)
        Print("[Grande] Candle Analyzer initialized");
    
    // Create Fibonacci calculator
    g_fibCalculator = new CGrandeFibonacciCalculator(_Symbol, PERIOD_CURRENT);
    if(g_fibCalculator == NULL)
    {
        Print("ERROR: Failed to create Fibonacci Calculator");
        delete g_regimeDetector;
        delete g_keyLevelDetector;
        delete g_candleAnalyzer;
        g_regimeDetector = NULL;
        g_keyLevelDetector = NULL;
        g_candleAnalyzer = NULL;
        return INIT_FAILED;
    }
    g_fibCalculator.SetDefaultLookback(InpFibLookbackBars);
    g_fibCalculator.SetMinSwingBars(InpFibMinSwingBars);
    if(InpLogDebugInfo)
        Print("[Grande] Fibonacci Calculator initialized");
    
    // Create confluence detector
    g_confluenceDetector = new CGrandeConfluenceDetector(_Symbol, PERIOD_CURRENT);
    if(g_confluenceDetector == NULL)
    {
        Print("ERROR: Failed to create Confluence Detector");
        delete g_regimeDetector;
        delete g_keyLevelDetector;
        delete g_candleAnalyzer;
        delete g_fibCalculator;
        g_regimeDetector = NULL;
        g_keyLevelDetector = NULL;
        g_candleAnalyzer = NULL;
        g_fibCalculator = NULL;
        return INIT_FAILED;
    }
    g_confluenceDetector.SetProximityPips(InpConfluenceProximityPips);
    g_confluenceDetector.SetMinConfluenceScore(InpMinConfluenceScore);
    g_confluenceDetector.SetMaxZones(InpMaxConfluenceZones);
    if(InpLogDebugInfo)
        Print("[Grande] Confluence Detector initialized");
    
    // Create and initialize limit order manager
    g_limitOrderManager = new CGrandeLimitOrderManager();
    if(g_limitOrderManager == NULL)
    {
        Print("ERROR: Failed to create Limit Order Manager");
        delete g_regimeDetector;
        delete g_keyLevelDetector;
        delete g_candleAnalyzer;
        delete g_fibCalculator;
        delete g_confluenceDetector;
        g_regimeDetector = NULL;
        g_keyLevelDetector = NULL;
        g_candleAnalyzer = NULL;
        g_fibCalculator = NULL;
        g_confluenceDetector = NULL;
        return INIT_FAILED;
    }
    
    // Configure limit order manager
    LimitOrderConfig limitConfig;
    limitConfig.useLimitOrders = InpUseLimitOrders;
    limitConfig.maxLimitDistancePips = InpMaxLimitDistancePips;
    limitConfig.expirationHours = InpLimitOrderExpirationHours;
    limitConfig.cancelStaleOrders = InpCancelStaleOrders;
    limitConfig.staleOrderDistancePips = InpStaleOrderDistancePips;
    limitConfig.duplicateTolerancePoints = InpLimitOrderDuplicateTolerancePoints;
    limitConfig.logConfluenceAnalysis = InpLogConfluenceAnalysis;
    limitConfig.logDetailedInfo = InpLogDetailedInfo;
    
    if(!g_limitOrderManager.Initialize(_Symbol, InpMagicNumber, 
                                        g_confluenceDetector, 
                                        g_keyLevelDetector, 
                                        GetPointer(g_trade),
                                        limitConfig))
    {
        Print("ERROR: Failed to initialize Limit Order Manager");
        delete g_regimeDetector;
        delete g_keyLevelDetector;
        delete g_candleAnalyzer;
        delete g_fibCalculator;
        delete g_confluenceDetector;
        delete g_limitOrderManager;
        g_regimeDetector = NULL;
        g_keyLevelDetector = NULL;
        g_candleAnalyzer = NULL;
        g_fibCalculator = NULL;
        g_confluenceDetector = NULL;
        g_limitOrderManager = NULL;
        return INIT_FAILED;
    }
    if(InpLogDebugInfo)
        Print("[Grande] Limit Order Manager initialized");
    
    // Create and initialize trend follower (if enabled)
    g_trendFollower = NULL;
    if(InpEnableTrendFollower)
    {
        g_trendFollower = new CAdvancedTrendFollower();
        if(g_trendFollower == NULL)
        {
            Print("ERROR: Failed to create Advanced Trend Follower");
            delete g_regimeDetector;
            delete g_keyLevelDetector;
            g_regimeDetector = NULL;
            g_keyLevelDetector = NULL;
            return INIT_FAILED;
        }
        
        if(!g_trendFollower.Init())
        {
            Print("ERROR: Failed to initialize Advanced Trend Follower");
            delete g_regimeDetector;
            delete g_keyLevelDetector;
            delete g_trendFollower;
            g_regimeDetector = NULL;
            g_keyLevelDetector = NULL;
            g_trendFollower = NULL;
            return INIT_FAILED;
        }
        
        // Configure trend follower display
        g_trendFollower.ShowDiagnosticPanel(InpShowTrendFollowerPanel);
        
        if(InpLogDebugInfo)
            Print("[Grande] Advanced Trend Follower initialized and integrated");
    }
    
    // DISABLED: News Sentiment Integration (commented out - only using free economic calendar data)
    /*
    // Initialize News Sentiment (non-fatal if unavailable)
    if(!g_newsSentiment.Initialize())
    {
        if(InpLogDebugInfo)
            Print("[Grande] WARNING: News sentiment server unavailable; continuing without sentiment integration");
    }
    g_newsSentiment.SetAnalysisInterval(300);
    */
    if(InpLogDebugInfo)
        Print("[Grande] News Sentiment Integration: DISABLED (using free economic calendar only)");
    
    // Initialize Calendar AI (non-fatal if unavailable)
    if(InpEnableCalendarAI)
    {
        if(!g_calendarReader.Initialize(_Symbol))
        {
            if(InpLogDebugInfo)
                Print("[Grande] WARNING: Calendar reader initialization failed; calendar AI will attempt to proceed with existing files");
        }
        else if(InpLogDebugInfo)
        {
            Print("[Grande] Calendar reader initialized for ", _Symbol);
        }
        // Calendar update timestamp now managed by State Manager
        
        // One-time calendar availability warning only on configured run timeframe
        bool calendarRunsHere = (!InpCalendarOnlyOnTimeframe || Period() == InpCalendarRunTimeframe);
        if(calendarRunsHere)
        {
            if(!g_calendarReader.CheckCalendarAvailability())
            {
                Print("[Grande] ⚠️ Economic Calendar appears disabled or unavailable. Go to Tools > Options > Server and ensure 'Enable news' is checked. Then restart MT5 to allow calendar sync.");
            }
        }
        else if(InpLogDebugInfo)
        {
            Print("[CAL-AI] Skipping calendar availability check on this timeframe (configured to run on ", (int)InpCalendarRunTimeframe, ")");
        }
    }
    
    // Create and initialize risk manager
    g_riskManager = new CGrandeRiskManager();
    if(g_riskManager == NULL)
    {
        Print("ERROR: Failed to create Risk Manager");
        delete g_regimeDetector;
        delete g_keyLevelDetector;
        if(g_trendFollower != NULL) delete g_trendFollower;
        g_regimeDetector = NULL;
        g_keyLevelDetector = NULL;
        g_trendFollower = NULL;
        return INIT_FAILED;
    }
    
    if(!g_riskManager.Initialize(_Symbol, g_riskConfig, InpLogDebugInfo))
    {
        Print("ERROR: Failed to initialize Risk Manager");
        delete g_regimeDetector;
        delete g_keyLevelDetector;
        if(g_trendFollower != NULL) delete g_trendFollower;
        delete g_riskManager;
        g_regimeDetector = NULL;
        g_keyLevelDetector = NULL;
        g_trendFollower = NULL;
        g_riskManager = NULL;
        return INIT_FAILED;
    }
    
    if(InpLogDebugInfo)
        Print("[Grande] Risk Manager initialized and integrated");
    
    // Initialize profit-critical modules
    // Initialize Profit Calculator
    g_profitCalculator = new CGrandeProfitCalculator();
    if(g_profitCalculator == NULL)
    {
        Print("ERROR: Failed to create Profit Calculator");
        return INIT_FAILED;
    }
    if(!g_profitCalculator.Initialize(_Symbol))
    {
        Print("ERROR: Failed to initialize Profit Calculator");
        delete g_profitCalculator;
        g_profitCalculator = NULL;
        return INIT_FAILED;
    }
    if(InpLogDebugInfo)
        Print("[Grande] ✅ Profit Calculator initialized");
    
    // Initialize Performance Tracker
    g_performanceTracker = new CGrandePerformanceTracker();
    if(g_performanceTracker == NULL)
    {
        Print("ERROR: Failed to create Performance Tracker");
        return INIT_FAILED;
    }
    if(!g_performanceTracker.Initialize(_Symbol, g_databaseManager, g_profitCalculator))
    {
        Print("ERROR: Failed to initialize Performance Tracker");
        delete g_profitCalculator;
        delete g_performanceTracker;
        g_profitCalculator = NULL;
        g_performanceTracker = NULL;
        return INIT_FAILED;
    }
    if(InpLogDebugInfo)
        Print("[Grande] ✅ Performance Tracker initialized");
    
    // Initialize Signal Quality Analyzer
    g_signalQualityAnalyzer = new CGrandeSignalQualityAnalyzer();
    if(g_signalQualityAnalyzer == NULL)
    {
        Print("ERROR: Failed to create Signal Quality Analyzer");
        return INIT_FAILED;
    }
    if(!g_signalQualityAnalyzer.Initialize(_Symbol, g_stateManager, g_eventBus))
    {
        Print("ERROR: Failed to initialize Signal Quality Analyzer");
        delete g_profitCalculator;
        delete g_performanceTracker;
        delete g_signalQualityAnalyzer;
        g_profitCalculator = NULL;
        g_performanceTracker = NULL;
        g_signalQualityAnalyzer = NULL;
        return INIT_FAILED;
    }
    if(InpLogDebugInfo)
        Print("[Grande] ✅ Signal Quality Analyzer initialized");
    
    // Initialize Position Optimizer
    g_positionOptimizer = new CGrandePositionOptimizer();
    if(g_positionOptimizer == NULL)
    {
        Print("ERROR: Failed to create Position Optimizer");
        return INIT_FAILED;
    }
    if(!g_positionOptimizer.Initialize(_Symbol, g_riskManager, g_stateManager, g_eventBus))
    {
        Print("ERROR: Failed to initialize Position Optimizer");
        delete g_profitCalculator;
        delete g_performanceTracker;
        delete g_signalQualityAnalyzer;
        delete g_positionOptimizer;
        g_profitCalculator = NULL;
        g_performanceTracker = NULL;
        g_signalQualityAnalyzer = NULL;
        g_positionOptimizer = NULL;
        return INIT_FAILED;
    }
    // Configure position optimizer settings
    g_positionOptimizer.SetTrailingStopEnabled(InpEnableTrailingStop);
    g_positionOptimizer.SetBreakevenEnabled(InpEnableBreakeven);
    g_positionOptimizer.SetPartialClosesEnabled(InpEnablePartialCloses);
    g_positionOptimizer.SetTrailingATRMultiplier(InpTrailingATRMultiplier);
    g_positionOptimizer.SetBreakevenATR(InpBreakevenATR);
    g_positionOptimizer.SetPartialCloseATR(InpPartialCloseATR);
    g_positionOptimizer.SetPartialClosePercent(InpPartialClosePercent);
    if(InpLogDebugInfo)
        Print("[Grande] ✅ Position Optimizer initialized");
    
    // Create and initialize intelligent reporter
    g_reporter = new CGrandeIntelligentReporter();
    if(g_reporter == NULL)
    {
        Print("ERROR: Failed to create Intelligent Reporter");
        delete g_regimeDetector;
        delete g_keyLevelDetector;
        if(g_trendFollower != NULL) delete g_trendFollower;
        delete g_riskManager;
        g_regimeDetector = NULL;
        g_keyLevelDetector = NULL;
        g_trendFollower = NULL;
        g_riskManager = NULL;
        return INIT_FAILED;
    }
    
    if(!g_reporter.Initialize(_Symbol, 60)) // 60-minute reporting interval
    {
        Print("ERROR: Failed to initialize Intelligent Reporter");
        delete g_regimeDetector;
        delete g_keyLevelDetector;
        if(g_trendFollower != NULL) delete g_trendFollower;
        delete g_riskManager;
        delete g_reporter;
        g_regimeDetector = NULL;
        g_keyLevelDetector = NULL;
        g_trendFollower = NULL;
        g_riskManager = NULL;
        g_reporter = NULL;
        return INIT_FAILED;
    }
    
    Print("[Grande] 📊 Intelligent Reporter initialized - Hourly reports enabled");
    
    // Create and initialize multi-timeframe analyzer
    // Temporarily disabled for immediate RSI fix
    // TODO: Re-enable after fixing compilation errors
    
    // Generate immediate startup report after short delay to collect initial data
    EventSetTimer(5); // Set 5 second timer for initial report
    
    // Set up chart display - always setup for any visual features
    SetupChartDisplay();
    
    // Set timer for updates
    EventSetTimer(MathMin(MathMin(InpRegimeUpdateSeconds, InpKeyLevelUpdateSeconds), InpRiskUpdateSeconds));
    
    // Initialize update times
    // Timestamp variables now managed by State Manager
    
    // Initial analysis
    PerformInitialAnalysis();
    
    // Only show success message and config in debug mode
    if(InpLogDebugInfo)
    {
        Print("Grande Trading System initialized successfully");
        Print("Configuration Summary:");
        Print("  - ADX Trend Threshold: ", InpADXTrendThreshold);
        Print("  - Key Level Min Strength: ", InpMinStrength);
        Print("  - Lookback Period: ", InpLookbackPeriod);
        Print("  - Trading Enabled: ", InpEnableTrading ? "YES" : "NO");
        Print("  - Trend Follower: ", InpEnableTrendFollower ? "ENABLED" : "DISABLED");
        Print("  - Risk %: Trend=", DoubleToString(InpRiskPctTrend, 1), 
              " Range=", DoubleToString(InpRiskPctRange, 1), " Breakout=", DoubleToString(InpRiskPctBreakout, 1));
        Print("  - Display Features: Regime=", InpShowRegimeBackground ? "ON" : "OFF", 
              ", KeyLevels=", InpShowKeyLevels ? "ON" : "OFF",
              ", TrendFollower=", InpShowTrendFollowerPanel ? "ON" : "OFF");
    }
    
    // Initialize cool-off state
    if(g_stateManager != NULL)
    {
        CoolOffInfo coolOff = {false, 0, 0, 0, 0.0};
        g_stateManager.SetCoolOffInfo(coolOff);
        g_stateManager.SetLastPositionCount(0);
    }
    LoadCooloffState(); // Load any persisted state
    
    // Initialize cool-off statistics
    // Cool-off statistics now managed by State Manager
    if(g_stateManager != NULL)
    {
        CoolOffStats stats;
        stats.Reset();
        g_stateManager.SetCoolOffStats(stats);
    }
    
    // Register components in Component Registry
    // Note: Component registration requires components to implement IMarketAnalyzer interface
    // Currently components don't implement this interface, so registration is skipped
    // TODO: Refactor components to implement IMarketAnalyzer interface for full registry support
    // Profit-critical modules (ProfitCalculator, PerformanceTracker, SignalQualityAnalyzer, PositionOptimizer)
    // are initialized but not registered in Component Registry as they don't implement IMarketAnalyzer
    if(g_componentRegistry != NULL && InpLogDebugInfo)
    {
        Print("[Grande] Component Registry initialized (component registration pending interface implementation)");
        Print("[Grande] Profit-critical modules initialized: ProfitCalculator, PerformanceTracker, SignalQualityAnalyzer, PositionOptimizer");
    }
    
    // Perform initial system health check
    if(g_healthMonitor != NULL)
    {
        g_healthMonitor.CheckSystemHealth();
        if(InpLogDebugInfo)
        {
            string healthReport = g_healthMonitor.GetHealthReport();
            Print("[Grande] System Health Report:\n", healthReport);
        }
    }
    
    // Publish initialization complete event
    if(g_eventBus != NULL)
        g_eventBus.PublishEvent(EVENT_SYSTEM_INIT, "GrandeTradingSystem", 
                               "EA initialization complete", 1.0, 0);
    
    if(InpLogCooloffDecisions && InpEnableCooloffPeriod)
    {
        Print(StringFormat("[COOL-OFF] Initialized - TP: %dm, SL: %dm, Direction Override: %s",
              InpTPCooloffMinutes,
              InpSLCooloffMinutes,
              InpAllowDirectionChangeOverride ? "YES" : "NO"));
        
        if(InpEnableDynamicCooloff)
            Print("[COOL-OFF] Dynamic adjustment: ENABLED (ATR-based)");
        
        if(InpEnableRegimeAwareCooloff)
            Print("[COOL-OFF] Regime-aware adjustment: ENABLED");
        
        if(InpEnableCooloffStatistics)
            Print(StringFormat("[COOL-OFF] Statistics tracking: ENABLED (reports every %dm)", InpStatisticsReportMinutes));
    }
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Publish deinitialization event
    if(g_eventBus != NULL)
        g_eventBus.PublishEvent(EVENT_SYSTEM_DEINIT, "GrandeTradingSystem", 
                               "EA deinitialization started. Reason: " + IntegerToString(reason), 0.0, 0);
    
    if(InpLogDebugInfo)
        Print("Deinitializing Grande Trading System. Reason: ", reason);
    
    // Clean up Infrastructure Components
    if(g_healthMonitor != NULL)
    {
        delete g_healthMonitor;
        g_healthMonitor = NULL;
    }
    
    if(g_componentRegistry != NULL)
    {
        // Components will be cleaned up individually below
        // Registry cleanup is automatic when deleted
        delete g_componentRegistry;
        g_componentRegistry = NULL;
    }
    
    if(g_eventBus != NULL)
    {
        // Save event log if needed
        delete g_eventBus;
        g_eventBus = NULL;
    }
    
    if(g_configManager != NULL)
    {
        delete g_configManager;
        g_configManager = NULL;
    }
    
    if(g_stateManager != NULL)
    {
        // Save state before cleanup
        g_stateManager.SaveState();
        delete g_stateManager;
        g_stateManager = NULL;
    }
    
    // Cool-off state cleanup (persisted in GlobalVariables)
    if(reason == REASON_REMOVE)
    {
        ClearCooloffState();
    }
    
    // Clean up timer
    EventKillTimer();
    
    // Clean up database manager
    if(g_databaseManager != NULL)
    {
        if(InpLogDebugInfo)
            Print("Closing database connection...");
        
        g_databaseManager.Close();
        delete g_databaseManager;
        g_databaseManager = NULL;
    }
    
    // Clean up detectors
    if(g_regimeDetector != NULL)
    {
        delete g_regimeDetector;
        g_regimeDetector = NULL;
    }
    
    if(g_keyLevelDetector != NULL)
    {
        delete g_keyLevelDetector;
        g_keyLevelDetector = NULL;
    }
    
    if(g_candleAnalyzer != NULL)
    {
        delete g_candleAnalyzer;
        g_candleAnalyzer = NULL;
    }
    
    if(g_fibCalculator != NULL)
    {
        delete g_fibCalculator;
        g_fibCalculator = NULL;
    }
    
    if(g_confluenceDetector != NULL)
    {
        delete g_confluenceDetector;
        g_confluenceDetector = NULL;
    }
    
    if(g_limitOrderManager != NULL)
    {
        delete g_limitOrderManager;
        g_limitOrderManager = NULL;
    }
    
    if(g_trendFollower != NULL)
    {
        delete g_trendFollower;
        g_trendFollower = NULL;
    }
    
    if(g_riskManager != NULL)
    {
        delete g_riskManager;
        g_riskManager = NULL;
    }
    
    if(g_reporter != NULL)
    {
        delete g_reporter;
        g_reporter = NULL;
    }
    
    // Clean up profit-critical modules
    if(g_positionOptimizer != NULL)
    {
        delete g_positionOptimizer;
        g_positionOptimizer = NULL;
    }
    
    if(g_signalQualityAnalyzer != NULL)
    {
        delete g_signalQualityAnalyzer;
        g_signalQualityAnalyzer = NULL;
    }
    
    if(g_performanceTracker != NULL)
    {
        delete g_performanceTracker;
        g_performanceTracker = NULL;
    }
    
    if(g_profitCalculator != NULL)
    {
        delete g_profitCalculator;
        g_profitCalculator = NULL;
    }
    
    // Multi-timeframe analyzer cleanup - temporarily disabled
    
    // Clean up chart objects
    CleanupChartObjects();
    
    if(InpLogDebugInfo)
        Print("Grande Trading System deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check for position closure to activate cool-off period
    CheckForPositionClosure();
    
    // Minimize OnTick work and avoid any logging or trade/risk operations here.
    // Check if trading is allowed
    if(!MQLInfoInteger(MQL_TRADE_ALLOWED) || !InpEnableTrading)
        return;
    
    // Collect market data for database if enabled
    if(InpEnableDatabase && g_databaseManager != NULL)
    {
        CollectMarketDataForDatabase();
    }
    
    // Collect enhanced market data for FinBERT analysis if enabled
    if(InpEnableCalendarAI)
    {
        CollectEnhancedMarketDataForFinBERT();
    }
    
    // All periodic updates are handled in OnTimer to prevent per-tick thrashing
}

//+------------------------------------------------------------------+
//| Manage pending limit orders                                      |
//+------------------------------------------------------------------+
void ManagePendingOrders()
{
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double maxStaleDistance = InpStaleOrderDistancePips * GetPipSize();
    
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        
        // Check if order is ours
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
        
        ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        
        // Only manage limit orders (not stop orders)
        if(orderType != ORDER_TYPE_BUY_LIMIT && orderType != ORDER_TYPE_SELL_LIMIT)
            continue;
        
        double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
        double distance = MathAbs(currentPrice - orderPrice) / GetPipSize();
        
        bool shouldCancel = false;
        string cancelReason = "";
        
        // Check if order has moved too far from current price
        if(distance > InpStaleOrderDistancePips)
        {
            shouldCancel = true;
            cancelReason = StringFormat("Price moved %.1f pips away (max: %.1f)", distance, InpStaleOrderDistancePips);
        }
        
        // Check if order has expired (if not already handled by broker)
        datetime expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
        if(expiration > 0 && TimeCurrent() >= expiration)
        {
            shouldCancel = true;
            cancelReason = "Order expired";
        }
        
        // Cancel stale orders
        if(shouldCancel)
        {
            if(g_trade.OrderDelete(ticket))
            {
                Print(StringFormat("[ORDER-MGR] Cancelled limit order #%I64u: %s", ticket, cancelReason));
            }
            else
            {
                Print(StringFormat("[ORDER-MGR] Failed to cancel order #%I64u: %s (error: %d)", 
                     ticket, cancelReason, GetLastError()));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
    datetime currentTime = TimeCurrent();
    
    // Generate initial report 5 seconds after startup
    static bool initialReportGenerated = false;
    static datetime startupTime = TimeCurrent();
    if(!initialReportGenerated && g_reporter != NULL && (currentTime - startupTime >= 5))
    {
        Print("[Grande] 📊 Generating initial intelligence report...");
        g_reporter.GenerateHourlyReport();
        g_reporter.GenerateFinBERTDataset();
        Print("[Grande] ✅ Initial report generated - Check Experts tab and Files folder");
        initialReportGenerated = true;
    }
    
    // Check if hourly report is due
    if(g_reporter != NULL && g_reporter.IsReportDue())
    {
        g_reporter.GenerateHourlyReport();
        g_reporter.GenerateFinBERTDataset(); // Also save data for FinBERT
    }
    
    // Report cool-off statistics periodically
    ReportCooloffStatistics();
    
    // Emergency margin protection - check margin level and close positions if critical
    static datetime g_lastMarginCheck = 0;
    if(InpEnableMarginProtection && (currentTime - g_lastMarginCheck >= InpMarginCheckIntervalSeconds))
    {
        CheckEmergencyMarginProtection();
        g_lastMarginCheck = currentTime;
    }
    
    // Periodic risk manager updates (trailing stop, breakeven, etc.)
    datetime lastRiskUpdate = (g_stateManager != NULL) ? g_stateManager.GetLastRiskUpdate() : 0;
    if(g_riskManager != NULL && currentTime - lastRiskUpdate >= InpRiskUpdateSeconds)
    {
        // CRITICAL FIX: Only manage positions on the designated timeframe to prevent competition
        if(!InpManageOnlyOnTimeframe || Period() == InpManagementTimeframe)
        {
            ResetLastError();
            
            // Track consecutive risk manager errors to prevent infinite loops
            static int consecutiveRMErrors = 0;
            static ulong lastErrorTicket = 0;
            static int consecutive4203Errors = 0;
            static datetime last4203ErrorTime = 0;
            
            // Cache RSI once per management tick for reuse
            if(InpEnableRSIExits || InpEnableMTFRSI)
                CacheRsiForCycle();
            
            // Check if the problematic position still exists
            bool problemPositionExists = false;
            for(int i = 0; i < PositionsTotal(); i++)
            {
                if(PositionGetTicket(i) == 24684248)
                {
                    problemPositionExists = true;
                    break;
                }
            }
            
            // EMERGENCY: Skip risk manager if problematic position is detected
            if(problemPositionExists)
            {
                static bool warningShown = false;
                if(!warningShown)
                {
                    Print("[Grande] ⚠️ EMERGENCY: Skipping risk manager - position 24684248 causing errors");
                    Print("[Grande] ⚠️ ACTION REQUIRED: Please manually close position 24684248 in MT5");
                    warningShown = true;
                }
                // Skip risk manager completely for this position
            }
            // Only call risk manager if not disabled and not in error state
            else if(!InpDisableRiskManagerTemp)
            {
                // ERROR 4203 THROTTLING: If we've had multiple 4203 errors recently, throttle risk manager calls
                bool shouldThrottleRiskManager = false;
                if(consecutive4203Errors >= 10 && TimeCurrent() - last4203ErrorTime < 120) // 10 errors in last 2 minutes
                {
                    shouldThrottleRiskManager = true;
                    if(InpLogDetailedInfo && consecutive4203Errors % 10 == 0) // Log every 10th throttled call
                    {
                        Print(StringFormat("[Grande] ⏸️ Risk Manager throttled due to %d consecutive 4203 errors (last: %s)",
                              consecutive4203Errors, TimeToString(last4203ErrorTime, TIME_MINUTES|TIME_SECONDS)));
                    }
                }
                else
                {
                    // Check error count BEFORE doing anything
                    if(consecutiveRMErrors >= 5)
                    {
                        // EMERGENCY STOP: Risk manager has been erroring repeatedly
                        static bool emergencyStopShown = false;
                        if(!emergencyStopShown)
                        {
                            Print(StringFormat("[Grande] 🚨 EMERGENCY STOP: Risk Manager disabled after %d consecutive errors", consecutiveRMErrors));
                            Print("[Grande] 🚨 This prevents log spam and system overload");
                            Print("[Grande] 🚨 Manual intervention may be required");
                            emergencyStopShown = true;
                        }

                        // Reset error counter after 5 minutes to allow recovery attempt
                        static datetime lastErrorReset = 0;
                        if(TimeCurrent() - lastErrorReset > 300) // 5 minutes
                        {
                            consecutiveRMErrors = 0;
                            lastErrorTicket = 0;
                            lastErrorReset = TimeCurrent();
                            emergencyStopShown = false;
                            Print("[Grande] 🔄 Risk manager error counter reset after 5 minutes - attempting recovery");
                        }
                        // Skip ALL risk manager operations
                    }
                    else if(shouldThrottleRiskManager)
                    {
                        // Risk Manager is throttled due to 4203 errors - skip this cycle
                    }
                    else
                    {
                        // Safe to proceed with risk manager operations
                        ResetLastError();

                        // ALWAYS process manual positions to add SL/TP even if max positions exceeded
                        AddSLTPToManualPositions();

                        // Check for errors from AddSLTPToManualPositions
                        int postSLTPError = GetLastError();
                        if(postSLTPError != 0)
                        {
                            Print(StringFormat("[Grande] ⚠️ Error %d in AddSLTPToManualPositions: %s",
                                  postSLTPError, ErrorDescription(postSLTPError)));
                        }

                        ResetLastError();

                        // ERROR 5035 FIX: Check trade context before calling risk manager
                        if(!IsTradeAllowed())
                        {
                            if(InpLogDetailedInfo)
                                Print("[Grande] ⏸️ Trade context not available - skipping risk manager OnTick");
                        }
                        else
                        {
                            // Call risk manager OnTick
                            // Use position optimizer for position management
                            if(g_positionOptimizer != NULL)
                                g_positionOptimizer.ManageAllPositions();
                            else if(g_riskManager != NULL)
                                g_riskManager.OnTick();

                            // Check for errors from risk manager
                            int postRMError = GetLastError();
                            if(postRMError != 0)
                            {
                                if(postRMError == 5035) // Trade context busy
                                {
                                    if(InpLogDetailedInfo)
                                        Print("[Grande] ⏸️ Risk Manager OnTick: Trade context busy (error 5035)");
                                }
                                else
                                {
                                    Print(StringFormat("[Grande] ⚠️ Error %d in Risk Manager OnTick: %s",
                                          postRMError, ErrorDescription(postRMError)));
                                }
                            }
                        }
                    }
                }
            }
            else
            {
                // Risk manager temporarily disabled by user
                static bool disableWarningShown = false;
                if(!disableWarningShown)
                {
                    Print("[Grande] ⚠️ WARNING: Risk Manager is TEMPORARILY DISABLED via InpDisableRiskManagerTemp");
                    disableWarningShown = true;
                }
            }
            
            // Add RSI-based exit management (optional)
            if(InpEnableRSIExits)
                ApplyRSIExitRules();
            
            // Update momentum-specific trailing stops
            if(InpEnableTrailingStop)
            {
                for(int i = 0; i < PositionsTotal(); i++)
                {
                    ulong ticket = PositionGetTicket(i);
                    if(ticket > 0 && PositionSelectByTicket(ticket))
                    {
                        if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
                           PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                        {
                            UpdateMomentumTrailingStop(ticket);
                        }
                    }
                }
            }
            
            // Final error check - only count errors if they occurred during our operations
            int finalError = GetLastError();
            if(finalError != 0 && consecutiveRMErrors < 5)
            {
                // ERROR 5035 & 4203 FIX: Don't count trade context busy or invalid request errors as consecutive failures
                if(finalError == 5035)
                {
                    if(InpLogDetailedInfo)
                        Print("[Grande] ⏸️ Trade context busy (error 5035) - not counting as consecutive error");
                }
                else if(finalError == 4203)
                {
                    // Error 4203 is normal when positions already have SL/TP set or are being processed
                    // Don't count as consecutive error and don't increment error counter
                    if(InpLogDetailedInfo && consecutive4203Errors % 20 == 0) // Only log every 20th occurrence
                        Print("[Grande] ℹ️ Position modification skipped (error 4203) - position already processed or invalid");

                    // Reset consecutive errors since 4203 is not a real error
                    consecutiveRMErrors = 0;
                    
                    // Track 4203 errors for throttling purposes but don't let them accumulate
                    consecutive4203Errors++;
                    if(consecutive4203Errors > 100) consecutive4203Errors = 0; // Reset to 0 to prevent unnecessary throttling
                    last4203ErrorTime = TimeCurrent();
                }
                else
                {
                    consecutiveRMErrors++;
                    Print(StringFormat("[Grande] ⚠️ Risk Manager ERROR %d detected, consecutive errors: %d", finalError, consecutiveRMErrors));
                    Print(StringFormat("[Grande] ⚠️ Error Description: %s", ErrorDescription(finalError)));

                    if(consecutiveRMErrors >= 5)
                    {
                        Print("[Grande] 🚨 ERROR THRESHOLD REACHED: Risk Manager will be disabled next cycle");
                    }
                }
            }
            else if(finalError == 0 && consecutiveRMErrors > 0 && consecutiveRMErrors < 5)
            {
                // Reset on success only if we had errors before but haven't hit emergency stop
                Print(StringFormat("[Grande] ✅ Risk Manager recovered after %d errors - resetting counter", consecutiveRMErrors));
                consecutiveRMErrors = 0;
            }
            else if(finalError == 0 && consecutive4203Errors > 0)
            {
                // Reset 4203 error counter on successful operations
                consecutive4203Errors = 0;
                last4203ErrorTime = 0;
            }
            
            if(finalError == 0 && g_riskManager != NULL && !g_riskManager.IsTradingEnabled())
            {
                // Trading disabled by risk checks; simply skip further actions this cycle
            }
        }
        if(g_stateManager != NULL)
            g_stateManager.SetLastRiskUpdate(currentTime);
    }
    
    // Manage pending limit orders (cancel stale, track fills)
    if(InpUseLimitOrders && InpCancelStaleOrders && g_limitOrderManager != NULL)
    {
        g_limitOrderManager.ManageStaleOrders();
    }
    
    // Update intelligent position scaling range information
    UpdateRangeInfo();
    
    // Update regime detection
    datetime lastRegimeUpdate = (g_stateManager != NULL) ? g_stateManager.GetLastRegimeUpdate() : 0;
    if(g_regimeDetector != NULL && 
       currentTime - lastRegimeUpdate >= InpRegimeUpdateSeconds)
    {
        RegimeSnapshot currentRegime = g_regimeDetector.DetectCurrentRegime();
        
        // Get previous regime for change detection
        static MARKET_REGIME lastLoggedRegime = REGIME_RANGING;
        
        // Store in State Manager if available (SetCurrentRegime automatically updates timestamp)
        if(g_stateManager != NULL)
        {
            RegimeSnapshot previousRegime = g_stateManager.GetCurrentRegime();
            lastLoggedRegime = previousRegime.regime;
            g_stateManager.SetCurrentRegime(currentRegime);
        }
        else
        {
            // State Manager handles regime update timestamp automatically in SetCurrentRegime()
        }
        
        // Log regime changes and publish events
        if(currentRegime.regime != lastLoggedRegime)
        {
            if(InpLogDetailedInfo)
                LogRegimeChange(currentRegime);
            
            // Publish regime change event
            if(g_eventBus != NULL)
            {
                string regimeName = EnumToString(currentRegime.regime);
                g_eventBus.PublishEvent(EVENT_REGIME_CHANGED, "RegimeDetector",
                                      StringFormat("Regime changed to %s (confidence: %.2f)", regimeName, currentRegime.confidence),
                                      currentRegime.confidence, 0);
            }
            
            lastLoggedRegime = currentRegime.regime;
        }

        // Execute trading logic periodically based on current regime (no tick-level execution)
        ResetLastError();
        ExecuteTradeLogic(currentRegime);
        // Swallow non-critical errors silently to avoid log spam
    }
    
    // Update key level detection
    datetime lastKeyLevelUpdate = (g_stateManager != NULL) ? g_stateManager.GetLastKeyLevelUpdate() : 0;
    if(g_keyLevelDetector != NULL && 
       currentTime - lastKeyLevelUpdate >= InpKeyLevelUpdateSeconds)
    {
        if(g_keyLevelDetector.DetectKeyLevels())
        {
            if(InpShowKeyLevels)
                g_keyLevelDetector.UpdateChartDisplay();
                
            if(InpLogDetailedInfo)
                g_keyLevelDetector.PrintKeyLevelsReport();
            
            // Find and store nearest key levels in State Manager
            // Note: SetNearestSupport/SetNearestResistance automatically update timestamp
            if(g_stateManager != NULL)
            {
                double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                SKeyLevel support, resistance;
                if(FindNearestKeyLevels(currentPrice, support, resistance))
                {
                    g_stateManager.SetNearestSupport(support);
                    g_stateManager.SetNearestResistance(resistance);
                    
                    // Publish key level update event
                    if(g_eventBus != NULL)
                    {
                        g_eventBus.PublishEvent(EVENT_KEY_LEVEL_UPDATED, "KeyLevelDetector",
                                              StringFormat("Key levels updated - Support: %.5f, Resistance: %.5f", 
                                                          support.price, resistance.price),
                                              0.0, 0);
                    }
                }
            }
        }
        
        // Update timestamp (SetNearestSupport/SetNearestResistance already do this)
        // State Manager handles key level update timestamp automatically in SetNearestSupport/SetNearestResistance()
    }
    
    // Update trend follower
    if(g_trendFollower != NULL && InpEnableTrendFollower)
    {
        if(!g_trendFollower.Refresh())
        {
            Print("[Grande] Warning: Trend Follower refresh failed");
        }
    }
    
    // Calendar AI analysis (periodic) - Aggressive updates for FinBERT integration
    bool calendarShouldRun = InpEnableCalendarAI;
    datetime lastCalendarUpdate = (g_stateManager != NULL) ? g_stateManager.GetLastCalendarUpdate() : 0;
    int updateInterval = (lastCalendarUpdate == 0) ? 10 : (InpCalendarUpdateMinutes * 60); // First run after 10 seconds
    
    if(calendarShouldRun && currentTime - lastCalendarUpdate >= updateInterval)
    {
        if(InpLogDetailedInfo)
            Print("[CAL-AI] 🔄 Starting calendar data collection and FinBERT analysis...");
            
        bool eventsOk = g_calendarReader.GetEconomicCalendarEvents(InpCalendarLookaheadHours);
        if(!eventsOk)
        {
            if(g_calendarReader.IsCalendarAvailable())
            {
                Print("[CAL-AI] Calendar available but no qualifying events in current window — not an error.");
            }
            else
            {
                Print("[CAL-AI] Calendar fetch failed — MT5 calendar unavailable. Verify Tools > Options > Terminal: Allow News and restart terminal.");
            }
        }
        else
        {
            // Export to Common\\Files is handled within GetEconomicCalendarEvents()
            // Attempt to run/load calendar AI analysis
            bool analyzed = g_newsSentiment.RunCalendarAnalysis();
            if(!analyzed)
            {
                // Fallback: try to load any existing analysis file
                analyzed = g_newsSentiment.LoadLatestCalendarAnalysis();
            }
            
            string sig  = g_newsSentiment.GetCalendarSignal();
            double sc   = g_newsSentiment.GetCalendarScore();
            double conf = g_newsSentiment.GetCalendarConfidence();
            int evc     = g_newsSentiment.GetEventCount();
            
            if(sig != "")
            {
                Print(StringFormat("[CAL-AI] signal=%s score=%.2f conf=%.2f events=%d", sig, sc, conf, evc));
                if(conf >= InpCalendarMinConfidence)
                {
                    Print(StringFormat("[CAL-AI] ✅ High-confidence calendar %s (conf %.2f ≥ %.2f)", sig, conf, InpCalendarMinConfidence));
                }
                else
                {
                    Print(StringFormat("[CAL-AI] ℹ️ Low-confidence calendar signal (%.2f < %.2f) — informational only", conf, InpCalendarMinConfidence));
                }
                string reason = g_newsSentiment.GetCalendarReasoning();
                if(StringLen(reason) > 0)
                    Print("[CAL-AI] Reason: ", reason);
            }
            else
            {
                Print("[CAL-AI] Calendar analysis unavailable. Ensure Python dependencies are installed.");
            }
        }
        if(g_stateManager != NULL)
            g_stateManager.SetLastCalendarUpdate(currentTime);
    }
    
    // Update display elements
    datetime lastDisplayUpdate = (g_stateManager != NULL) ? g_stateManager.GetLastDisplayUpdate() : 0;
    if(currentTime - lastDisplayUpdate >= 10) // Update display every 10 seconds
    {
        UpdateDisplayElements();
        
        // Update timestamp in State Manager
        if(g_stateManager != NULL)
            g_stateManager.SetLastDisplayUpdate(currentTime);
        else
            if(g_stateManager != NULL)
                g_stateManager.SetLastDisplayUpdate(currentTime);
    }

    // Auto-hide startup panel after expiry
    const string STARTUP_PANEL_NAME = "GrandeStartupSnapshotPanel";
    if(ObjectFind(g_chartID, STARTUP_PANEL_NAME) >= 0)
    {
        string expireStr = ObjectGetString(g_chartID, STARTUP_PANEL_NAME, OBJPROP_TOOLTIP);
        if(StringLen(expireStr) > 0)
        {
            long expire = (long)StringToInteger(expireStr);
            if(TimeCurrent() >= (datetime)expire)
                ObjectDelete(g_chartID, STARTUP_PANEL_NAME);
        }
    }
}

//+------------------------------------------------------------------+
//| Setup chart display                                              |
//+------------------------------------------------------------------+
void SetupChartDisplay()
{
    // Set chart properties for better visualization
    ChartSetInteger(g_chartID, CHART_SHOW_GRID, false);
    ChartSetInteger(g_chartID, CHART_COLOR_BACKGROUND, clrBlack);
    ChartSetInteger(g_chartID, CHART_COLOR_FOREGROUND, clrWhite);
    ChartSetInteger(g_chartID, CHART_COLOR_GRID, clrDimGray);
}

//+------------------------------------------------------------------+
//| Perform initial analysis                                          |
//+------------------------------------------------------------------+
void PerformInitialAnalysis()
{
    // Get initial regime snapshot
    if(g_regimeDetector != NULL)
    {
        RegimeSnapshot initialRegime = g_regimeDetector.DetectCurrentRegime();
        
        // Store in State Manager if available (SetCurrentRegime automatically updates timestamp)
        if(g_stateManager != NULL)
        {
            g_stateManager.SetCurrentRegime(initialRegime);
        }
        
        if(InpLogDetailedInfo)
        {
            Print("[Grande] Current Market Regime: ", g_regimeDetector.RegimeToString(initialRegime.regime));
            Print("[Grande] Regime Confidence: ", DoubleToString(initialRegime.confidence, 3));
        }
        
        // Publish initial regime event
        if(g_eventBus != NULL)
        {
            string regimeName = EnumToString(initialRegime.regime);
            g_eventBus.PublishEvent(EVENT_REGIME_CHANGED, "Initialization",
                                  StringFormat("Initial regime: %s (confidence: %.2f)", regimeName, initialRegime.confidence),
                                  initialRegime.confidence, 0);
        }
    }
    
    // Detect initial key levels
    if(g_keyLevelDetector != NULL)
    {
        if(g_keyLevelDetector.DetectKeyLevels())
        {
            if(InpLogDetailedInfo)
                Print("[Grande] Found ", g_keyLevelDetector.GetKeyLevelCount(), " key levels");
            
            if(InpShowKeyLevels)
                g_keyLevelDetector.UpdateChartDisplay();
            
            // Store initial key levels in State Manager
            // Note: SetNearestSupport/SetNearestResistance automatically update timestamp
            if(g_stateManager != NULL)
            {
                double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                SKeyLevel support, resistance;
                if(FindNearestKeyLevels(currentPrice, support, resistance))
                {
                    g_stateManager.SetNearestSupport(support);
                    g_stateManager.SetNearestResistance(resistance);
                }
            }
            
            // Publish key level detection event
            if(g_eventBus != NULL && g_keyLevelDetector.GetKeyLevelCount() > 0)
            {
                g_eventBus.PublishEvent(EVENT_KEY_LEVEL_DETECTED, "Initialization",
                                      StringFormat("Detected %d key levels", g_keyLevelDetector.GetKeyLevelCount()),
                                      g_keyLevelDetector.GetKeyLevelCount(), 0);
            }
        }
        else if(InpLogDetailedInfo)
        {
            Print("[Grande] No significant key levels detected");
        }
    }
    
    // Force immediate visual update
    UpdateDisplayElements();
    
    // Ensure chart redraws
    ChartRedraw(g_chartID);

    // Show startup snapshot with actionable insights
    ShowStartupSnapshot();
    
    // Generate quick initial report with available data
    if(g_reporter != NULL)
    {
        Print("\n⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️");
        Print("📊 INTELLIGENT REPORTER - INITIAL SNAPSHOT");
        Print("⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️\n");
        Print("🔹 System initialized - Reports will be generated:");
        Print("   ▶️ Immediately: In 5 seconds (initial data collection)");
        Print("   ▶️ Hourly: Every 60 minutes automatically");
        Print("   ▶️ On-Demand: Press 'I' key anytime\n");
        Print("📁 Reports saved to: Files\\GrandeReport_", _Symbol, "_", TimeToString(TimeCurrent(), TIME_DATE), ".txt");
        Print("🤖 FinBERT data saved to: Files\\FinBERT_Data_", _Symbol, "_", TimeToString(TimeCurrent(), TIME_DATE), ".csv\n");
        Print("🔑 KEYBOARD SHORTCUTS:");
        Print("   [I] - Generate immediate intelligence report");
        Print("   [R] - Force regime update");
        Print("   [L] - Force key level update");
        Print("   [S] - Show trend follower status");
        Print("   [F] - Toggle trend follower panel");
        Print("   [E] - Enable/Disable trading");
        Print("   [X] - Close all positions\n");
        Print("⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️⚛️\n");
    }
}

//+------------------------------------------------------------------+
//| Update display elements                                          |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Update Display Elements                                          |
//+------------------------------------------------------------------+
// PURPOSE:
//   Updates all chart display elements including regime background, info panels,
//   and visual indicators based on current market regime.
//
// BEHAVIOR:
//   1. Retrieves current regime from State Manager or detector
//   2. Updates regime background color (if enabled)
//   3. Updates regime info panel (if enabled)
//   4. Updates system status panel (if enabled)
//   5. Updates trend arrows and ADX strength meter (if enabled)
//   6. Triggers chart redraw
//
// RETURNS:
//   (void) - No return value
//
// SIDE EFFECTS:
//   - Creates/updates chart objects (background, labels, panels)
//   - Triggers ChartRedraw() to update display
//   - Reads from State Manager and regime detector
//
// ERROR CONDITIONS:
//   - Returns early if regime detector is NULL
//   - Chart object creation may fail silently
//
// NOTES:
//   - Respects display flags (InpShowRegimeBackground, InpShowRegimeInfo, etc.)
//   - Called periodically from OnTimer() and after regime changes
//   - Performance: Updates all display elements in one call
//
// RELATED:
//   - See Also: UpdateRegimeBackground(), UpdateRegimeInfoPanel(), UpdateSystemStatusPanel()
//   - Called By: OnTimer(), PerformInitialAnalysis()
//+------------------------------------------------------------------+
void UpdateDisplayElements()
{
    if(g_regimeDetector == NULL) 
        return;
    
    // Get regime from State Manager if available, otherwise from detector
    RegimeSnapshot currentRegime;
    if(g_stateManager != NULL)
    {
        currentRegime = g_stateManager.GetCurrentRegime();
        // If State Manager doesn't have a valid regime yet (timestamp is 0), get from detector
        if(currentRegime.timestamp == 0)
            currentRegime = g_regimeDetector.GetLastSnapshot();
    }
    else
    {
        currentRegime = g_regimeDetector.GetLastSnapshot();
    }
    
    // Update regime background
    if(InpShowRegimeBackground)
        UpdateRegimeBackground(currentRegime.regime);
    
    // Update info panels
    if(InpShowRegimeInfo)
        UpdateRegimeInfoPanel(currentRegime);
        
    if(InpShowSystemStatus)
        UpdateSystemStatusPanel();
        
    // Update additional visual indicators
    if(InpShowRegimeTrendArrows)
        UpdateRegimeTrendArrows(currentRegime);
        
    if(InpShowADXStrengthMeter)
        UpdateADXStrengthMeter(currentRegime);
    
    ChartRedraw(g_chartID);
}

//+------------------------------------------------------------------+
//| Update regime background color                                   |
//+------------------------------------------------------------------+
// PURPOSE:
//   Updates the chart background color to reflect the current market regime.
//
// PARAMETERS:
//   regime (MARKET_REGIME) - Current market regime type
//
// RETURNS:
//   (void) - No return value
//
// SIDE EFFECTS:
//   - Deletes existing background rectangle object
//   - Creates new background rectangle covering visible chart area
//   - Sets background color based on regime type
//
// NOTES:
//   - Colors: Bull=Dark Green, Bear=Dark Red, Breakout=Dark Yellow, Range=Dark Gray, High Vol=Dark Purple
//   - Background is placed behind price bars (OBJPROP_BACK=true)
//   - Object is not selectable or visible in object list
//
// RELATED:
//   - Called By: UpdateDisplayElements()
//+------------------------------------------------------------------+
void UpdateRegimeBackground(MARKET_REGIME regime)
{
    color bgColor = clrNONE;
    
    switch(regime)
    {
        case REGIME_TREND_BULL:
            bgColor = C'0,40,0';        // Dark green
            break;
        case REGIME_TREND_BEAR:
            bgColor = C'40,0,0';        // Dark red
            break;
        case REGIME_BREAKOUT_SETUP:
            bgColor = C'40,40,0';       // Dark yellow
            break;
        case REGIME_RANGING:
            bgColor = C'20,20,20';      // Dark gray
            break;
        case REGIME_HIGH_VOLATILITY:
            bgColor = C'40,0,40';       // Dark purple
            break;
    }
    
    // Remove existing background
    ObjectDelete(g_chartID, REGIME_BACKGROUND_NAME);
    
    // Create new background rectangle
    if(bgColor != clrNONE)
    {
        datetime timeStart = iTime(_Symbol, PERIOD_CURRENT, 500);
        datetime timeEnd = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 100;
        double priceHigh = ChartGetDouble(g_chartID, CHART_PRICE_MAX);
        double priceLow = ChartGetDouble(g_chartID, CHART_PRICE_MIN);
        
        bool created = ObjectCreate(g_chartID, REGIME_BACKGROUND_NAME, OBJ_RECTANGLE, 0, 
                    timeStart, priceLow, timeEnd, priceHigh);
        
        if(created)
        {
            ObjectSetInteger(g_chartID, REGIME_BACKGROUND_NAME, OBJPROP_COLOR, bgColor);
            ObjectSetInteger(g_chartID, REGIME_BACKGROUND_NAME, OBJPROP_FILL, true);
            ObjectSetInteger(g_chartID, REGIME_BACKGROUND_NAME, OBJPROP_BACK, true);
            ObjectSetInteger(g_chartID, REGIME_BACKGROUND_NAME, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(g_chartID, REGIME_BACKGROUND_NAME, OBJPROP_HIDDEN, true);
        }
    }
}

//+------------------------------------------------------------------+
//| Update regime information panel                                  |
//+------------------------------------------------------------------+
// PURPOSE:
//   Updates the regime information text panel showing current market regime,
//   ADX values, ATR ratio, DI values, and key level count.
//
// PARAMETERS:
//   snapshot (RegimeSnapshot) - Current regime snapshot with ADX, ATR, DI values
//
// RETURNS:
//   (void) - No return value
//
// SIDE EFFECTS:
//   - Deletes existing info panel label object
//   - Creates new text label in upper-left corner
//   - Displays formatted regime information
//
// NOTES:
//   - Panel shows: Regime name, ADX (H1/H4/D1), ATR ratio, +DI/-DI, Key level count, Update time
//   - Positioned at upper-left corner (10, 30 pixels from edge)
//   - Uses Consolas font, size 9, white color
//
// RELATED:
//   - Called By: UpdateDisplayElements()
//+------------------------------------------------------------------+
void UpdateRegimeInfoPanel(const RegimeSnapshot &snapshot)
{
    // Remove existing panel
    ObjectDelete(g_chartID, REGIME_INFO_PANEL_NAME);
    
    // Create info text
    string infoText = StringFormat(
        "═══ GRANDE TRADING SYSTEM ═══\n" +
        "REGIME: %s\n" +
        "─────────────────────────\n" +
        "ADX H1: %.1f | H4: %.1f | D1: %.1f\n" +
        "ATR Ratio: %.2f\n" +
        "+DI: %.1f | -DI: %.1f\n" +
        "─────────────────────────\n" +
        "Key Levels: %d\n" +
        "Updated: %s",
        g_regimeDetector.RegimeToString(snapshot.regime),
        snapshot.adx_h1,
        snapshot.adx_h4,
        snapshot.adx_d1,
        (snapshot.atr_avg > 0) ? snapshot.atr_current / snapshot.atr_avg : 0.0,
        snapshot.plus_di,
        snapshot.minus_di,
        g_keyLevelDetector != NULL ? g_keyLevelDetector.GetKeyLevelCount() : 0,
        TimeToString(snapshot.timestamp, TIME_MINUTES)
    );
    
    // Create text label
    bool created = ObjectCreate(g_chartID, REGIME_INFO_PANEL_NAME, OBJ_LABEL, 0, 0, 0);
    
    if(created)
    {
        ObjectSetString(g_chartID, REGIME_INFO_PANEL_NAME, OBJPROP_TEXT, infoText);
        ObjectSetInteger(g_chartID, REGIME_INFO_PANEL_NAME, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(g_chartID, REGIME_INFO_PANEL_NAME, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(g_chartID, REGIME_INFO_PANEL_NAME, OBJPROP_YDISTANCE, 30);
        ObjectSetInteger(g_chartID, REGIME_INFO_PANEL_NAME, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(g_chartID, REGIME_INFO_PANEL_NAME, OBJPROP_FONTSIZE, 9);
        ObjectSetString(g_chartID, REGIME_INFO_PANEL_NAME, OBJPROP_FONT, "Consolas");
        ObjectSetInteger(g_chartID, REGIME_INFO_PANEL_NAME, OBJPROP_SELECTABLE, false);
    }
}

//+------------------------------------------------------------------+
//| Update system status panel                                       |
//+------------------------------------------------------------------+
// PURPOSE:
//   Updates the system status panel showing trading status, position information,
//   and strongest key level details.
//
// RETURNS:
//   (void) - No return value
//
// SIDE EFFECTS:
//   - Deletes existing status panel label object
//   - Creates new text label displaying system status
//   - Reads position data from risk manager
//
// NOTES:
//   - Shows: Trading status (ACTIVE/DISABLED/DEMO), Position count and profit, Strongest key level info
//   - Positioned below regime info panel
//   - Uses Consolas font, size 9, white color
//
// RELATED:
//   - Called By: UpdateDisplayElements()
//+------------------------------------------------------------------+
void UpdateSystemStatusPanel()
{
    // Remove existing panel
    ObjectDelete(g_chartID, SYSTEM_STATUS_PANEL_NAME);
    
    // Get strongest key level info
    string strongestLevelInfo = "None";
    if(g_keyLevelDetector != NULL)
    {
        SKeyLevel strongestLevel;
        if(g_keyLevelDetector.GetStrongestLevel(strongestLevel))
        {
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double distance = MathAbs(strongestLevel.price - currentPrice);
            strongestLevelInfo = StringFormat("%.5f (%s, %.2f, %d pips)",
                strongestLevel.price,
                strongestLevel.isResistance ? "R" : "S",
                strongestLevel.strength,
                (int)(distance / _Point));
        }
    }
    
    // Get trading status
    string tradingStatus = InpEnableTrading ? 
                          (g_riskManager != NULL && g_riskManager.IsTradingEnabled() ? "🟢 ACTIVE" : "🔴 DISABLED") : 
                          "⚪ DEMO";
    
    // Get current positions info
    string positionsInfo = "None";
    if(g_riskManager != NULL)
    {
        int positionCount = g_riskManager.GetPositionCount();
        double totalProfit = g_riskManager.GetTotalProfit();
        if(positionCount > 0)
        {
            positionsInfo = StringFormat("%d pos, %.2f USD", positionCount, totalProfit);
        }
    }
    else
    {
        // Fallback to old method
        int totalPositions = PositionsTotal();
        if(totalPositions > 0)
        {
            double totalProfit = 0;
            for(int i = 0; i < totalPositions; i++)
            {
                if(PositionSelectByTicket(PositionGetTicket(i)))
                {
                    if(PositionGetString(POSITION_SYMBOL) == _Symbol)
                        // Use profit calculator for consistent profit calculation
                        if(g_profitCalculator != NULL)
                            totalProfit += g_profitCalculator.CalculatePositionProfitCurrency(PositionGetTicket(i));
                        else
                            totalProfit += PositionGetDouble(POSITION_PROFIT);
                }
            }
            positionsInfo = StringFormat("%d pos, %.2f USD", totalPositions, totalProfit);
        }
    }
    
    // Get trend follower status
    string trendFollowerInfo = "Disabled";
    if(InpEnableTrendFollower)
    {
        if(g_trendFollower != NULL)
        {
            string trendMode = "⚪ NEUTRAL";  // Default to NEUTRAL instead of None
            if(g_trendFollower.IsBullish()) trendMode = "🟢 BULL";
            else if(g_trendFollower.IsBearish()) trendMode = "🔴 BEAR";
            
            double tfStrength = g_trendFollower.TrendStrength();
            trendFollowerInfo = StringFormat("%s (ADX:%.1f)", trendMode, tfStrength);
        }
        else
        {
            trendFollowerInfo = "🔴 FAILED";  // Show failed status when enabled but NULL
        }
    }
    
    // Calendar AI status (using AI results)
    string calendarInfo = "Disabled";
    string calendarEventsInfo = "-";
    if(InpEnableCalendarAI)
    {
        string calSig = g_newsSentiment.GetCalendarSignal();
        double calConf = g_newsSentiment.GetCalendarConfidence();
        int calEv = g_newsSentiment.GetEventCount();
        calendarInfo = StringFormat("%s (conf %.2f)", (StringLen(calSig) > 0 ? calSig : "N/A"), calConf);
        calendarEventsInfo = IntegerToString(calEv);
    }
    
    // Get drawdown info
    string drawdownInfo = "0.00%";
    if(g_riskManager != NULL)
    {
        double drawdown = g_riskManager.GetCurrentDrawdown();
        drawdownInfo = StringFormat("%.2f%%", drawdown);
    }
    
    // Create status text
    string statusText = StringFormat(
        "═══ GRANDE TRADING SYSTEM ═══\n" +
        "Symbol: %s | %s\n" +
        "Timeframe: %s | Spread: %.1f pips\n" +
        "─────────────────────────────\n" +
        "Trading Status: %s\n" +
        "Positions: %s\n" +
        "Drawdown: %s\n" +
        "─────────────────────────────\n" +
        "Trend Follower: %s\n" +
        "Calendar AI: %s\n" +
        "Events: %s\n" +
        "─────────────────────────────\n" +
        "Strongest Level:\n" +
        "%s\n" +
        "─────────────────────────────\n" +
        "Updates: Regime=%d, Levels=%d\n" +
        "─────────────────────────────\n" +
        "Grande Tech | www.grandetech.com.br",
        _Symbol,
        EnumToString(Period()),
        EnumToString(Period()),
        (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) / 10.0,
        tradingStatus,
        positionsInfo,
        drawdownInfo,
        trendFollowerInfo,
        calendarInfo,
        calendarEventsInfo,
        strongestLevelInfo,
        InpRegimeUpdateSeconds,
        InpKeyLevelUpdateSeconds
    );
    
    // Create text label
    ObjectCreate(g_chartID, SYSTEM_STATUS_PANEL_NAME, OBJ_LABEL, 0, 0, 0);
    ObjectSetString(g_chartID, SYSTEM_STATUS_PANEL_NAME, OBJPROP_TEXT, statusText);
    ObjectSetInteger(g_chartID, SYSTEM_STATUS_PANEL_NAME, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(g_chartID, SYSTEM_STATUS_PANEL_NAME, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(g_chartID, SYSTEM_STATUS_PANEL_NAME, OBJPROP_YDISTANCE, 30);
    ObjectSetInteger(g_chartID, SYSTEM_STATUS_PANEL_NAME, OBJPROP_COLOR, clrLightBlue);
    ObjectSetInteger(g_chartID, SYSTEM_STATUS_PANEL_NAME, OBJPROP_FONTSIZE, 8);
    ObjectSetString(g_chartID, SYSTEM_STATUS_PANEL_NAME, OBJPROP_FONT, "Consolas");
    ObjectSetInteger(g_chartID, SYSTEM_STATUS_PANEL_NAME, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Log regime change                                                |
//+------------------------------------------------------------------+
void LogRegimeChange(const RegimeSnapshot &snapshot)
{
    // Always show brief regime change (actionable information)
    Print("📊 REGIME: ", g_regimeDetector.RegimeToString(snapshot.regime), 
          " (Confidence: ", DoubleToString(snapshot.confidence, 2), ")");
    
    // Show detailed information only if requested
    if(InpLogDetailedInfo)
    {
        Print("Time: ", TimeToString(snapshot.timestamp, TIME_DATE|TIME_MINUTES));
        Print("ADX Values - H1:", DoubleToString(snapshot.adx_h1, 1), 
              " H4:", DoubleToString(snapshot.adx_h4, 1), 
              " D1:", DoubleToString(snapshot.adx_d1, 1));
    }
    
    // Show visual alert for regime change
    ShowRegimeChangeAlert(snapshot);
    
    // Check if regime aligns with key levels
    if(g_keyLevelDetector != NULL)
    {
        int levelCount = g_keyLevelDetector.GetKeyLevelCount();
        if(levelCount > 0)
        {
            SKeyLevel strongestLevel;
            if(g_keyLevelDetector.GetStrongestLevel(strongestLevel))
            {
                double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                double pipSize = GetPipSize();
                bool nearStrongLevel = MathAbs(currentPrice - strongestLevel.price) <= (20.0 * pipSize); // Within 20 pips (universal)
                
                if(nearStrongLevel)
                {
                    Print("⚠️ CONFLUENCE ALERT: Price near strongest ", 
                          strongestLevel.isResistance ? "resistance" : "support", 
                          " level at ", DoubleToString(strongestLevel.price, _Digits));
                }
            }
        }
    }
    
    if(InpLogDetailedInfo)
        Print("=====================================");
}

//+------------------------------------------------------------------+
//| Clean up chart objects                                           |
//+------------------------------------------------------------------+
void CleanupChartObjects()
{
    ObjectDelete(g_chartID, REGIME_BACKGROUND_NAME);
    ObjectDelete(g_chartID, REGIME_INFO_PANEL_NAME);
    ObjectDelete(g_chartID, SYSTEM_STATUS_PANEL_NAME);
    ObjectDelete(g_chartID, REGIME_TREND_ARROW_NAME);
    ObjectDelete(g_chartID, ADX_STRENGTH_METER_NAME);
    ObjectDelete(g_chartID, REGIME_ALERT_NAME);
    
    // Clean up key level lines
    if(g_keyLevelDetector != NULL)
    {
        g_keyLevelDetector.ClearAllChartObjects();
    }
    
    ChartRedraw(g_chartID);
    if(InpLogDetailedInfo)
        Print("[Grande] Chart objects cleaned up");
}

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
    // Handle chart events if needed
    if(id == CHARTEVENT_CHART_CHANGE)
    {
        // Refresh display when chart changes
        UpdateDisplayElements();
    }
    else if(id == CHARTEVENT_KEYDOWN)
    {
        // Handle keyboard shortcuts
        if(lparam == 'R' || lparam == 'r') // Press 'R' to force regime update
        {
            if(g_regimeDetector != NULL)
            {
                RegimeSnapshot newSnapshot = g_regimeDetector.DetectCurrentRegime();
                Print("[Grande] Manual regime update - Current: ", 
                      g_regimeDetector.RegimeToString(newSnapshot.regime));
                UpdateDisplayElements();
            }
        }
        else if(lparam == 'L' || lparam == 'l') // Press 'L' to force key level update
        {
            if(g_keyLevelDetector != NULL)
            {
                if(g_keyLevelDetector.DetectKeyLevels())
                {
                    g_keyLevelDetector.UpdateChartDisplay();
                    g_keyLevelDetector.PrintKeyLevelsReport();
                }
                UpdateDisplayElements();
            }
        }
        else if(lparam == 'I' || lparam == 'i') // Press 'I' to generate immediate intelligence report
        {
            if(g_reporter != NULL)
            {
                Print("[Grande] 📊 Generating immediate intelligence report...");
                g_reporter.GenerateHourlyReport();
                g_reporter.GenerateFinBERTDataset();
                Print("[Grande] ✅ Report generated - Check Experts tab and Files folder");
            }
            else
            {
                Print("[Grande] Reporter not available");
            }
        }
        else if(lparam == 'T' || lparam == 't') // Press 'T' to test visuals
        {
            if(InpLogDebugInfo)
                Print("[Grande] TESTING VISUALS - Creating test elements");
            CreateTestVisuals();
        }
        else if(lparam == 'C' || lparam == 'c') // Press 'C' to clear all objects
        {
            if(InpLogDebugInfo)
                Print("[Grande] CLEARING ALL OBJECTS");
            CleanupChartObjects();
        }
        else if(lparam == 'E' || lparam == 'e') // Press 'E' to enable/disable trading
        {
            if(InpEnableTrading && g_riskManager != NULL)
            {
                bool currentState = g_riskManager.IsTradingEnabled();
                g_riskManager.EnableTrading(!currentState);
                Print("[Grande] Trading ", !currentState ? "ENABLED" : "DISABLED");
                UpdateDisplayElements();
            }
            else
            {
                Print("[Grande] Trading not enabled in settings");
            }
        }
        else if(lparam == 'X' || lparam == 'x') // Press 'X' to close all positions
        {
            if(InpEnableTrading && g_riskManager != NULL)
            {
                Print("[Grande] CLOSING ALL POSITIONS");
                g_riskManager.CloseAllPositions();
            }
        }
        else if(lparam == 'F' || lparam == 'f') // Press 'F' to toggle trend follower panel
        {
            if(g_trendFollower != NULL && InpEnableTrendFollower)
            {
                static bool panelVisible = InpShowTrendFollowerPanel;
                panelVisible = !panelVisible;
                g_trendFollower.ShowDiagnosticPanel(panelVisible);
                if(InpLogDebugInfo)
                    Print("[Grande] Trend Follower panel ", panelVisible ? "SHOWN" : "HIDDEN");
            }
            else
            {
                if(InpLogDebugInfo)
                    Print("[Grande] Trend Follower is not enabled");
            }
        }
        else if(lparam == 'S' || lparam == 's') // Press 'S' to show trend follower status
        {
            if(g_trendFollower != NULL && InpEnableTrendFollower)
            {
                bool isBull = g_trendFollower.IsBullish();
                bool isBear = g_trendFollower.IsBearish();
                double strength = g_trendFollower.TrendStrength();
                double pullback = g_trendFollower.EntryPricePullback();
                
                Print("═══ TREND FOLLOWER STATUS ═══");
                Print("Bullish Signal: ", isBull ? "YES ✅" : "NO ❌");
                Print("Bearish Signal: ", isBear ? "YES ✅" : "NO ❌");
                Print("ADX Strength: ", DoubleToString(strength, 2));
                Print("Pullback Price (EMA20): ", DoubleToString(pullback, _Digits));
                Print("═══════════════════════════");
            }
            else
            {
                if(InpLogDebugInfo)
                    Print("[Grande] Trend Follower is not enabled");
            }
        }
        else if(lparam == 'R' || lparam == 'r') // Press 'R' to show risk manager status
        {
            if(g_riskManager != NULL)
            {
                g_riskManager.LogStatus();
            }
            else
            {
                Print("[Grande] Risk Manager is not available");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update regime trend arrows                                       |
//+------------------------------------------------------------------+
void UpdateRegimeTrendArrows(const RegimeSnapshot &snapshot)
{
    // Remove existing arrows
    ObjectDelete(g_chartID, REGIME_TREND_ARROW_NAME);
    
    if(snapshot.regime == REGIME_RANGING || snapshot.regime == REGIME_HIGH_VOLATILITY)
        return; // No arrows for ranging/high volatility
    
    // Get current price and time
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    datetime currentTime = TimeCurrent();
    
    // Determine arrow properties
    int arrowCode = 0;
    color arrowColor = clrNONE;
    string arrowName = REGIME_TREND_ARROW_NAME;
    
    switch(snapshot.regime)
    {
        case REGIME_TREND_BULL:
            arrowCode = 233; // Up arrow
            arrowColor = clrLime;
            break;
        case REGIME_TREND_BEAR:
            arrowCode = 234; // Down arrow  
            arrowColor = clrRed;
            break;
        case REGIME_BREAKOUT_SETUP:
            arrowCode = 159; // Diamond
            arrowColor = clrYellow;
            break;
    }
    
    if(arrowCode > 0)
    {
        ObjectCreate(g_chartID, arrowName, OBJ_ARROW, 0, currentTime, currentPrice);
        ObjectSetInteger(g_chartID, arrowName, OBJPROP_ARROWCODE, arrowCode);
        ObjectSetInteger(g_chartID, arrowName, OBJPROP_COLOR, arrowColor);
        ObjectSetInteger(g_chartID, arrowName, OBJPROP_WIDTH, 3);
        ObjectSetInteger(g_chartID, arrowName, OBJPROP_SELECTABLE, false);
        // Validate confidence value before display
        double displayConfidence = (snapshot.confidence >= 0.0 && snapshot.confidence <= 1.0) ? 
                                  snapshot.confidence : 0.0;
        
        string tooltipText = StringFormat("Regime: %s (Confidence: %.2f)", 
                                        g_regimeDetector.RegimeToString(snapshot.regime),
                                        displayConfidence);
        
        // Debug logging for confidence display issues
        if(InpLogDetailedInfo && (displayConfidence != snapshot.confidence || displayConfidence == 0.0))
        {
            Print(StringFormat("⚠️ Confidence Display Issue: Original=%.6f, Display=%.6f, Text='%s'", 
                  snapshot.confidence, displayConfidence, tooltipText));
        }
        
        ObjectSetString(g_chartID, arrowName, OBJPROP_TOOLTIP, tooltipText);
    }
}

//+------------------------------------------------------------------+
//| Update ADX strength meter                                        |
//+------------------------------------------------------------------+
void UpdateADXStrengthMeter(const RegimeSnapshot &snapshot)
{
    // Remove existing meter
    ObjectDelete(g_chartID, ADX_STRENGTH_METER_NAME);
    
    // Create ADX strength visualization
    double tfStrength = (g_trendFollower != NULL) ? g_trendFollower.TrendStrength() : 0.0;
    string meterText = StringFormat(
        "\n\nADX STRENGTH METER\n" +
        "══════════════════\n" +
        "Current TF: %.1f %s\n" +
        "H1 ADX: %.1f %s\n" +
        "H4 ADX: %.1f %s\n" +
        "D1 ADX: %.1f %s\n" +
        "══════════════════\n" +
        "Trend Strength:\n" +
        "%s",
        tfStrength, GetADXStrengthBar(tfStrength),
        snapshot.adx_h1, GetADXStrengthBar(snapshot.adx_h1),
        snapshot.adx_h4, GetADXStrengthBar(snapshot.adx_h4),
        snapshot.adx_d1, GetADXStrengthBar(snapshot.adx_d1),
        GetTrendStrengthDescription(tfStrength)
    );
    
    // Create meter label
    ObjectCreate(g_chartID, ADX_STRENGTH_METER_NAME, OBJ_LABEL, 0, 0, 0);
    ObjectSetString(g_chartID, ADX_STRENGTH_METER_NAME, OBJPROP_TEXT, meterText);
    ObjectSetInteger(g_chartID, ADX_STRENGTH_METER_NAME, OBJPROP_CORNER, CORNER_LEFT_LOWER);
    ObjectSetInteger(g_chartID, ADX_STRENGTH_METER_NAME, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(g_chartID, ADX_STRENGTH_METER_NAME, OBJPROP_YDISTANCE, 200);
    ObjectSetInteger(g_chartID, ADX_STRENGTH_METER_NAME, OBJPROP_COLOR, clrCyan);
    ObjectSetInteger(g_chartID, ADX_STRENGTH_METER_NAME, OBJPROP_FONTSIZE, 8);
    ObjectSetString(g_chartID, ADX_STRENGTH_METER_NAME, OBJPROP_FONT, "Consolas");
    ObjectSetInteger(g_chartID, ADX_STRENGTH_METER_NAME, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Show regime change alert                                         |
//+------------------------------------------------------------------+
void ShowRegimeChangeAlert(const RegimeSnapshot &snapshot)
{
    if(!InpShowRegimeAlerts) return;
    
    // Remove existing alert
    ObjectDelete(g_chartID, REGIME_ALERT_NAME);
    
    // Create alert text
    string alertText = StringFormat(
        "🚨 REGIME CHANGE ALERT 🚨\n" +
        "NEW: %s\n" +
        "Confidence: %.2f\n" +
        "Time: %s",
        g_regimeDetector.RegimeToString(snapshot.regime),
        snapshot.confidence,
        TimeToString(snapshot.timestamp, TIME_MINUTES)
    );
    
    // Create alert label (center of chart)
    ObjectCreate(g_chartID, REGIME_ALERT_NAME, OBJ_LABEL, 0, 0, 0);
    ObjectSetString(g_chartID, REGIME_ALERT_NAME, OBJPROP_TEXT, alertText);
    ObjectSetInteger(g_chartID, REGIME_ALERT_NAME, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(g_chartID, REGIME_ALERT_NAME, OBJPROP_XDISTANCE, 300);
    ObjectSetInteger(g_chartID, REGIME_ALERT_NAME, OBJPROP_YDISTANCE, 100);
    ObjectSetInteger(g_chartID, REGIME_ALERT_NAME, OBJPROP_COLOR, clrOrange);
    ObjectSetInteger(g_chartID, REGIME_ALERT_NAME, OBJPROP_FONTSIZE, 12);
    ObjectSetString(g_chartID, REGIME_ALERT_NAME, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(g_chartID, REGIME_ALERT_NAME, OBJPROP_SELECTABLE, false);
    
    // Auto-remove alert after 10 seconds
    EventSetTimer(10);
}

//+------------------------------------------------------------------+
//| Helper functions for visual indicators                           |
//+------------------------------------------------------------------+
string GetADXStrengthBar(double adxValue)
{
    if(adxValue >= 40) return "████████ VERY STRONG";
    if(adxValue >= 30) return "██████   STRONG";
    if(adxValue >= 25) return "████     TRENDING";
    if(adxValue >= 20) return "██       WEAK";
    return "         NO TREND";
}

string GetTrendStrengthDescription(double adxValue)
{
    if(adxValue >= 40) return "💪 VERY STRONG TREND";
    if(adxValue >= 30) return "🔥 STRONG TREND";
    if(adxValue >= 25) return "📈 TRENDING MARKET";
    if(adxValue >= 20) return "⚡ WEAK TREND";
    return "🌊 RANGING MARKET";
} 

//+------------------------------------------------------------------+
//| Test visual elements function                                    |
//+------------------------------------------------------------------+
void CreateTestVisuals()
{
    // Create a simple test label to verify chart objects work
    string testName = "GrandeTestLabel";
    ObjectDelete(g_chartID, testName);
    
    bool created = ObjectCreate(g_chartID, testName, OBJ_LABEL, 0, 0, 0);
    
    if(created)
    {
        ObjectSetString(g_chartID, testName, OBJPROP_TEXT, "GRANDE VISUAL TEST\nIf you see this, chart objects work!");
        ObjectSetInteger(g_chartID, testName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
        ObjectSetInteger(g_chartID, testName, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(g_chartID, testName, OBJPROP_YDISTANCE, 50);
        ObjectSetInteger(g_chartID, testName, OBJPROP_COLOR, clrYellow);
        ObjectSetInteger(g_chartID, testName, OBJPROP_FONTSIZE, 12);
        ObjectSetString(g_chartID, testName, OBJPROP_FONT, "Arial Bold");
        ObjectSetInteger(g_chartID, testName, OBJPROP_SELECTABLE, false);
        
        if(InpLogDebugInfo)
            Print("[Grande] Visual test label created successfully");
    }
    else
    {
        if(InpLogDebugInfo)
            Print("[Grande] Failed to create test label. Error: ", GetLastError());
    }
    
    // Force display update
    UpdateDisplayElements();
    ChartRedraw(g_chartID);
} 

//+------------------------------------------------------------------+
//| Core trade dispatcher                                            |
//+------------------------------------------------------------------+
// PURPOSE:
//   Analyzes current market regime and executes appropriate trading
//   strategy (trend, breakout, or range trading) based on market conditions.
//
// BEHAVIOR:
//   1. Validates trading conditions (risk checks, position limits, cool-off periods)
//   2. Determines appropriate strategy based on regime type
//   3. Generates trading signals using regime-specific signal functions
//   4. Executes trades if signals are valid and all checks pass
//   5. Records trade decisions in State Manager
//   6. Publishes events for all trading decisions and outcomes
//
// PARAMETERS:
//   rs (RegimeSnapshot) - Current market regime snapshot containing:
//                        - regime: Current market regime type (TRENDING_BULL, TRENDING_BEAR, RANGING, BREAKOUT)
//                        - confidence: Regime confidence level (0.0-1.0)
//                        - atr_current: Current ATR value in price units
//                        - adx_h1, adx_h4, adx_d1: ADX values for H1, H4, and D1 timeframes
//                        - timestamp: When regime was detected
//
// RETURNS:
//   (void) - No return value. Check Event Bus for trade execution results and decisions.
//
// SIDE EFFECTS:
//   - May place market or pending orders through TrendTrade(), BreakoutTrade(), or RangeTrade()
//   - Updates State Manager with trade decision data (STradeDecision structure)
//   - Publishes EVENT_SIGNAL_GENERATED, EVENT_SIGNAL_REJECTED, EVENT_ORDER_PLACED events
//   - Logs trading decisions to database (if InpEnableDatabase is true)
//   - Updates display with trade status
//   - Updates g_lastSignalAnalysisTime in State Manager for throttling
//
// ERROR CONDITIONS:
//   - Trading disabled (InpEnableTrading=false): Function returns early, no trades placed
//   - Risk check fails: EVENT_SIGNAL_REJECTED published with rejection reason
//   - Position limit reached: Signal rejected, no new trades placed
//   - Cool-off period active: Signal rejected, no new trades placed
//   - Order placement fails: EVENT_ORDER_FAILED published with error code
//   - Insufficient margin: EVENT_MARGIN_WARNING published
//   - Signal throttling active: Function returns early if called too frequently
//
// PRECONDITIONS:
//   - EA must be initialized (OnInit() completed successfully)
//   - State Manager must be initialized and accessible
//   - Event Bus must be initialized and accessible
//   - Valid symbol and timeframe must be set
//   - Regime detector must have valid regime data
//
// POSTCONDITIONS:
//   - Trade decision recorded in State Manager (if signal generated)
//   - Events published to Event Bus for all decisions
//   - Database updated with decision data (if database enabled)
//   - g_lastSignalAnalysisTime updated in State Manager
//
// USAGE EXAMPLE:
//   RegimeSnapshot regime = g_regimeDetector.GetCurrentRegime();
//   ExecuteTradeLogic(regime);
//   // Check Event Bus for results:
//   // SystemEvent events[];
//   // g_eventBus.GetRecentEvents(events, 10);
//
// NOTES:
//   - Called from OnTick() on each price update
//   - Throttled to prevent excessive analysis (see g_lastSignalAnalysisTime and g_signalAnalysisThrottleSeconds)
//   - Respects InpEnableTrading flag - no trades if disabled
//   - All trades use InpMagicNumber for identification
//   - Integrates FinBERT sentiment analysis if available
//   - Performs comprehensive risk validation before any trade execution
//
// RELATED:
//   - See Also: TrendTrade(), BreakoutTrade(), RangeTrade()
//   - Called By: OnTick()
//   - Calls: Signal_TREND(), Signal_BREAKOUT(), Signal_RANGE(), IsTradeAllowed()
//+------------------------------------------------------------------+
void ExecuteTradeLogic(const RegimeSnapshot &rs)
{
    string logPrefix = "[TRADE DECISION] ";
    
    // Check position status first
    bool hasPosition = HasOpenPositionForSymbolAndMagic(_Symbol, InpMagicNumber);
    
    // Enhanced logging - show analysis periodically even with positions
    static datetime lastAnalysisLog = 0;
    bool shouldLogAnalysis = (TimeCurrent() - lastAnalysisLog >= 600); // Log every 10 minutes (reduced from 5)
    
    if(InpLogDetailedInfo && shouldLogAnalysis)
    {
        string posStatus = hasPosition ? " (position open)" : " (no position)";
        Print(logPrefix + "🔍 ANALYZING TRADE OPPORTUNITY", posStatus);
        Print(logPrefix + "Price: ", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits), 
              " | Spread: ", SymbolInfoInteger(_Symbol, SYMBOL_SPREAD), " pts | Regime: ", g_regimeDetector.RegimeToString(rs.regime));
        lastAnalysisLog = TimeCurrent();
    }
    else if(InpLogImportantOnly && !hasPosition) // Only log when no position (potential trading opportunity)
    {
        Print(logPrefix + "🔍 Checking for trading opportunity - No position");
    }
    else if(InpLogVerbose) // Smart verbose mode - only show important changes
    {
        static datetime lastVerboseLog = 0;
        static bool lastPositionStatus = false;
        static double lastPrice = 0.0;
        static int lastSpread = -1;
        
        bool positionChanged = (hasPosition != lastPositionStatus);
        bool priceChanged = (MathAbs(SymbolInfoDouble(_Symbol, SYMBOL_BID) - lastPrice) > 0.0001);
        bool spreadChanged = (SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) != lastSpread);
        bool timeForSummary = (TimeCurrent() - lastVerboseLog >= 300); // Every 5 minutes
        
        if(positionChanged || priceChanged || spreadChanged || timeForSummary)
        {
            Print(logPrefix + "=== MARKET UPDATE ===");
            if(positionChanged) Print(logPrefix + "Position Status: ", hasPosition ? "OPEN" : "CLOSED");
            if(priceChanged) Print(logPrefix + "Price: ", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits));
            if(spreadChanged) Print(logPrefix + "Spread: ", SymbolInfoInteger(_Symbol, SYMBOL_SPREAD), " points");
            if(timeForSummary) Print(logPrefix + "Periodic check - ", hasPosition ? "Position open" : "No position");
            
            lastVerboseLog = TimeCurrent();
            lastPositionStatus = hasPosition;
            lastPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            lastSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
        }
    }
    
    // Prepare decision tracking data
    STradeDecision decision;
    decision.timestamp = TimeCurrent();
    decision.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    decision.atr = rs.atr_current;
    decision.adx_h1 = rs.adx_h1;
    decision.adx_h4 = rs.adx_h4;
    decision.adx_d1 = rs.adx_d1;
    decision.regime = g_regimeDetector.RegimeToString(rs.regime);
    decision.regime_confidence = rs.confidence;
    decision.account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    decision.open_positions = PositionsTotal();
    
    // FIX: Initialize all fields to prevent uninitialized memory values
    decision.signal_type = "";
    decision.decision = "";
    decision.rejection_reason = "";
    decision.volume_ratio = 0.0;
    decision.risk_percent = 0.0;
    decision.calculated_lot = 0.0;
    decision.risk_check_passed = false;
    decision.drawdown_check_passed = false;
    decision.nearest_resistance = 0.0;
    decision.nearest_support = 0.0;
    decision.rsi_current = 0.0;
    decision.rsi_h4 = 0.0;
    decision.rsi_d1 = 0.0;
    decision.calendar_signal = "";
    decision.calendar_confidence = 0.0;
    decision.additional_notes = "";
    
    if(g_keyLevelDetector != NULL)
        decision.key_levels_count = g_keyLevelDetector.GetKeyLevelCount();
    else
        decision.key_levels_count = 0;
    
    // Initialize RSI values - always populate them even if not used for rejection
    decision.rsi_current = GetRSIValue(_Symbol, PERIOD_CURRENT, InpRSIPeriod, 0);
    if(decision.rsi_current < 0) decision.rsi_current = 0.0;
    
    decision.rsi_h4 = GetRSIValue(_Symbol, PERIOD_H4, InpTFRsiPeriod, 0);
    if(decision.rsi_h4 < 0) decision.rsi_h4 = 0.0;
    
    decision.rsi_d1 = GetRSIValue(_Symbol, PERIOD_D1, InpTFRsiPeriod, 0);
    if(decision.rsi_d1 < 0) decision.rsi_d1 = 0.0;
    
    // Check risk management first
    if(g_riskManager != NULL)
    {
        if(!g_riskManager.CheckDrawdown())
        {
            if(InpLogDetailedInfo)
                Print(logPrefix + "❌ BLOCKED: Maximum drawdown limit reached (", 
                      DoubleToString(InpMaxDrawdownPct, 1), "%)");
            
            // Track rejection
            if(g_reporter != NULL)
            {
                decision.signal_type = "PRE_SIGNAL_CHECK";
                decision.decision = "BLOCKED";
                decision.rejection_reason = "Maximum drawdown limit reached";
                g_reporter.RecordDecision(decision);
            }
            return;
        }
            
        if(!g_riskManager.CheckMaxPositions())
        {
            if(InpLogDetailedInfo)
                Print(logPrefix + "❌ BLOCKED: Maximum positions limit reached (", 
                      InpMaxPositions, " positions)");
            
            // Track rejection
            if(g_reporter != NULL)
            {
                decision.signal_type = "PRE_SIGNAL_CHECK";
                decision.decision = "BLOCKED";
                decision.rejection_reason = "Maximum positions limit reached";
                g_reporter.RecordDecision(decision);
            }
            return;
        }
    }
    
    // Check if we already have position for this symbol & magic
    // MODIFIED: Allow signal evaluation even with position open (for scaling/grid strategies)
    
    if(hasPosition)
    {
        // Log periodically but don't block signal analysis
        static datetime lastPositionLog = 0;
        if(InpLogDetailedInfo && (TimeCurrent() - lastPositionLog >= 600)) // Every 10 minutes
        {
            Print(logPrefix + "ℹ️ Position open - continuing signal analysis for potential scaling");
            lastPositionLog = TimeCurrent();
        }
        
        // Track that we're analyzing with position open
        if(g_reporter != NULL)
        {
            static datetime lastReportTime = 0;
            if((TimeCurrent() - lastReportTime) >= 300) // Report every 5 minutes
            {
                decision.signal_type = "PRE_SIGNAL_CHECK";
                decision.decision = "ANALYZING_WITH_POSITION";
                decision.rejection_reason = "Position open but continuing analysis";
                g_reporter.RecordDecision(decision);
                lastReportTime = TimeCurrent();
            }
        }
        // Don't return - continue with signal analysis
    }
    else
    {
        // Reset warning flag when no position exists
        static bool hasWarnedAboutOpenPosition = false;
        hasWarnedAboutOpenPosition = false;
    }
    
    // THROTTLING FIX: Prevent repeated signal analysis when previous analysis was rejected
    datetime currentTime = TimeCurrent();
    bool shouldThrottle = false;
    
    // Check if we should throttle signal analysis
    datetime lastSignalAnalysisTime = (g_stateManager != NULL) ? g_stateManager.GetLastSignalAnalysisTime() : 0;
    MARKET_REGIME lastAnalysisRegime = (g_stateManager != NULL) ? g_stateManager.GetLastAnalysisRegime() : REGIME_RANGING;
    string lastRejectionReason = (g_stateManager != NULL) ? g_stateManager.GetLastRejectionReason() : "";
    
    if(lastSignalAnalysisTime > 0 && 
       (currentTime - lastSignalAnalysisTime) < g_signalAnalysisThrottleSeconds &&
       lastAnalysisRegime == rs.regime &&
       !HasOpenPositionForSymbolAndMagic(_Symbol, InpMagicNumber))
    {
        // Only throttle if we're in the same regime and no position exists
        shouldThrottle = true;
        
        if(InpLogDetailedInfo)
        {
            int remainingSeconds = g_signalAnalysisThrottleSeconds - (int)(currentTime - lastSignalAnalysisTime);
            Print(logPrefix + "⏸️ THROTTLED: Signal analysis throttled for ", 
                  remainingSeconds, 
                  " more seconds (last rejection: ", lastRejectionReason, ")");
        }
    }
    
    // THROTTLING FIX: Skip signal analysis if throttled
    if(shouldThrottle)
    {
        return;
    }
    
    // Update throttling variables before analysis
    if(g_stateManager != NULL)
    {
        g_stateManager.SetLastSignalAnalysisTime(currentTime);
        g_stateManager.SetLastAnalysisRegime(rs.regime);
    }
    
    // Smart logging - only once per session or verbose mode
    static bool hasLoggedAnalysisStart = false;
    if(InpLogDetailedInfo && !hasLoggedAnalysisStart)
    {
        Print(logPrefix + "✅ Risk checks passed - proceeding with signal analysis");
        Print(logPrefix + "Market Regime: ", g_regimeDetector.RegimeToString(rs.regime), " (", DoubleToString(rs.confidence, 2), ")");
        Print(logPrefix + "ADX: H1=", DoubleToString(rs.adx_h1, 0), " H4=", DoubleToString(rs.adx_h4, 0), " | ATR=", DoubleToString(rs.atr_current/_Point, 0), "pts");
        hasLoggedAnalysisStart = true;
    }
    else if(InpLogVerbose) // Full details only in ultra-verbose mode
    {
        Print(logPrefix + "✅ Risk checks passed - proceeding with signal analysis");
        Print(logPrefix + "Market Regime: ", g_regimeDetector.RegimeToString(rs.regime));
        Print(logPrefix + "Regime Confidence: ", DoubleToString(rs.confidence, 3));
        Print(logPrefix + "ADX H1: ", DoubleToString(rs.adx_h1, 2));
        Print(logPrefix + "ADX H4: ", DoubleToString(rs.adx_h4, 2));
        Print(logPrefix + "ATR Current: ", DoubleToString(rs.atr_current, _Digits));
        Print(logPrefix + "ATR Average: ", DoubleToString(rs.atr_avg, _Digits));
    }
    
    // Enhanced FinBERT analysis integration
    static datetime s_lastFinBERTRun = 0;
    bool finbertAnalysisAvailable = false;
    string finbertSignal = "NEUTRAL";
    double finbertConfidence = 0.0;
    double finbertScore = 0.0;
    string finbertReasoning = "";
    
    // Run enhanced FinBERT analysis if enabled and time has passed
    if(InpEnableCalendarAI && (TimeCurrent() - s_lastFinBERTRun > 300))
    {
        if(g_newsSentiment.RunCalendarAnalysis())
        {
            finbertAnalysisAvailable = true;
            finbertSignal = g_newsSentiment.GetCalendarSignal();
            finbertConfidence = g_newsSentiment.GetCalendarConfidence();
            finbertScore = g_newsSentiment.GetCalendarScore();
            finbertReasoning = g_newsSentiment.GetCalendarReasoning();
            
            if(InpLogDetailedInfo)
            {
                Print(logPrefix + "Enhanced FinBERT Analysis: ", finbertSignal, 
                      " (Confidence: ", DoubleToString(finbertConfidence, 2), 
                      ", Score: ", DoubleToString(finbertScore, 2), ")");
                Print(logPrefix + "FinBERT Reasoning: ", finbertReasoning);
            }
        }
        s_lastFinBERTRun = TimeCurrent();
    }
    
    // Store FinBERT data in decision tracking
    decision.calendar_signal = finbertSignal;
    decision.calendar_confidence = finbertConfidence;

    // Execute trading strategy with comprehensive error handling
    ResetLastError();
    
    switch(rs.regime)
    {
        case REGIME_TREND_BULL:   
            if(InpLogVerbose) Print(logPrefix + "→ Analyzing BULLISH TREND opportunity...");
            TrendTrade(true, rs, finbertSignal, finbertConfidence, finbertScore);   
            break;
        case REGIME_TREND_BEAR:   
            if(InpLogVerbose) Print(logPrefix + "→ Analyzing BEARISH TREND opportunity...");
            TrendTrade(false, rs, finbertSignal, finbertConfidence, finbertScore);  
            break;
        case REGIME_BREAKOUT_SETUP: 
            if(InpLogVerbose) Print(logPrefix + "→ Analyzing BREAKOUT opportunity...");
            BreakoutTrade(rs, finbertSignal, finbertConfidence, finbertScore);    
            break;
        case REGIME_RANGING:      
            if(InpLogVerbose) Print(logPrefix + "→ Analyzing RANGE TRADING opportunity...");
            RangeTrade(rs, finbertSignal, finbertConfidence, finbertScore);         
            break;
        default: 
            if(InpLogDetailedInfo) Print(logPrefix + "❌ BLOCKED: High volatility regime - no trading");
            return;
    }
    
    // Check for non-trade errors after analysis (avoid mislabeling indicator/data errors as trade failures)
    int lastErr = GetLastError();
    if(lastErr != 0)
    {
        // Indicator/market data readiness errors are common right after init or TF change
        bool isIndicatorDataError = (lastErr >= 4801 && lastErr <= 4812); // ERR_INDICATOR_*
        bool isMarketDataError    = (lastErr >= 4301 && lastErr <= 4307); // ERR_MARKET_*
        if(isIndicatorDataError || isMarketDataError)
        {
            // Specifically handle ERR_INDICATOR_DATA_NOT_FOUND (4806) as expected during startup
            if(lastErr == 4806)
            {
                // This is expected when indicators are still calculating - suppress logging
                if(InpLogVerbose)
                    Print("[Grande] DEBUG: Indicator data still calculating (err=4806) — normal during startup");
            }
            else
            {
                if(InpLogDetailedInfo)
                    Print("[Grande] INFO: Data not ready (err=", lastErr, ") — monitoring continues");
            }
        }
        else
        {
            Print("[Grande] WARN: Non-trade error after analysis. Err=", lastErr);
        }
        ResetLastError();
    }
    
    if(InpLogVerbose) // Only in ultra-verbose mode
        Print(logPrefix + "=== TRADE ANALYSIS COMPLETE ===\n");
}

//+------------------------------------------------------------------+
//| Trend trading logic                                              |
//+------------------------------------------------------------------+
// PURPOSE:
//   Executes trend-following trades in bullish or bearish trending markets.
//   Places market or limit orders based on trend direction and technical analysis.
//
// BEHAVIOR:
//   1. Validates trend signal using Signal_TREND()
//   2. Integrates FinBERT sentiment analysis if available
//   3. Calculates position size based on risk percentage and ATR
//   4. Calculates stop loss and take profit levels
//   5. Applies intelligent position scaling if enabled
//   6. Caps take profit at nearest strong key level if appropriate
//   7. Places market or limit order based on configuration
//   8. Records trade execution in database
//
// PARAMETERS:
//   bullish (bool) - Trade direction: true for buy, false for sell
//   rs (RegimeSnapshot) - Current market regime snapshot with ATR, ADX values
//   finbertSignal (string) - FinBERT sentiment signal: "BUY", "SELL", "NEUTRAL", etc.
//   finbertConfidence (double) - FinBERT confidence level (0.0-1.0)
//   finbertScore (double) - FinBERT sentiment score
//
// RETURNS:
//   (void) - No return value. Check Event Bus for order placement results.
//
// SIDE EFFECTS:
//   - May place market or limit order through CTrade object
//   - Updates State Manager with rejection reason if signal fails
//   - Publishes EVENT_ORDER_PLACED or EVENT_ORDER_FAILED events
//   - Records trade decision in database via IntelligentReporter
//   - Logs detailed trade information if InpLogDetailedInfo is enabled
//
// ERROR CONDITIONS:
//   - Signal validation fails: Returns early, updates g_lastRejectionReason
//   - FinBERT opposes trade with high confidence: Trade rejected
//   - Invalid lot size: Trade blocked, decision recorded
//   - Margin validation fails: Trade rejected, EVENT_MARGIN_WARNING published
//   - Order placement fails: EVENT_ORDER_FAILED published with error details
//   - Cool-off period active: Trade skipped
//   - Position scaling limit reached: Trade blocked
//
// PRECONDITIONS:
//   - Signal_TREND() must return true for the given direction
//   - Risk Manager must be initialized (if using risk manager)
//   - State Manager must be accessible
//   - Event Bus must be initialized
//
// POSTCONDITIONS:
//   - Order placed or rejected with reason recorded
//   - Events published to Event Bus
//   - Trade decision recorded in database
//
// USAGE EXAMPLE:
//   RegimeSnapshot regime = g_regimeDetector.GetCurrentRegime();
//   TrendTrade(true, regime, "BUY", 0.85, 0.75);
//
// NOTES:
//   - Uses InpRiskPctTrend for position sizing
//   - Applies FinBERT sentiment multiplier to position size (up to 50% boost)
//   - Supports limit orders if InpUseLimitOrders is enabled
//   - Caps TP at strong key levels while maintaining minimum 1.5:1 R:R
//   - Respects intelligent position scaling limits
//   - All trades use InpMagicNumber for identification
//
// RELATED:
//   - See Also: Signal_TREND(), BreakoutTrade(), RangeTrade()
//   - Called By: ExecuteTradeLogic()
//   - Calls: Signal_TREND(), CalcLot(), NormalizeVolumeToStep(), NormalizeStops()
//+------------------------------------------------------------------+
void TrendTrade(bool bullish, const RegimeSnapshot &rs, string finbertSignal = "NEUTRAL", double finbertConfidence = 0.0, double finbertScore = 0.0)
{
    string logPrefix = "[TREND SIGNAL] ";
    string direction = bullish ? "BULLISH" : "BEARISH";
    
    // Prepare tracking for trade execution
    STradeDecision execution;
    execution.timestamp = TimeCurrent();
    execution.signal_type = bullish ? "TREND_BULL" : "TREND_BEAR";
    execution.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    execution.atr = rs.atr_current;
    execution.adx_h1 = rs.adx_h1;
    execution.adx_h4 = rs.adx_h4;
    execution.adx_d1 = rs.adx_d1;
    execution.regime = g_regimeDetector.RegimeToString(rs.regime);
    execution.regime_confidence = rs.confidence;
    execution.account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    execution.open_positions = PositionsTotal();
    
    // Initialize RSI values for tracking
    execution.rsi_current = GetRSIValue(_Symbol, PERIOD_CURRENT, InpRSIPeriod, 0);
    if(execution.rsi_current < 0) execution.rsi_current = 0.0;
    
    execution.rsi_h4 = GetRSIValue(_Symbol, PERIOD_H4, InpTFRsiPeriod, 0);
    if(execution.rsi_h4 < 0) execution.rsi_h4 = 0.0;
    
    execution.rsi_d1 = GetRSIValue(_Symbol, PERIOD_D1, InpTFRsiPeriod, 0);
    if(execution.rsi_d1 < 0) execution.rsi_d1 = 0.0;
    
    // FIX: Initialize calendar data (will be updated if calendar AI is enabled)
    execution.calendar_signal = "";
    execution.calendar_confidence = 0.0;
    execution.additional_notes = "";
    execution.volume_ratio = 0.0;
    execution.risk_percent = 0.0;
    execution.calculated_lot = 0.0;
    execution.nearest_resistance = 0.0;
    execution.nearest_support = 0.0;
    execution.key_levels_count = g_keyLevelDetector != NULL ? g_keyLevelDetector.GetKeyLevelCount() : 0;
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "Analyzing ", direction, " trend signal...");
        Print(logPrefix + "Required Risk %: ", DoubleToString(InpRiskPctTrend, 1), "%");
    }
    
    if(!Signal_TREND(bullish, rs)) 
    {
        // Update throttling variables for rejection
        if(g_stateManager != NULL)
            g_stateManager.SetLastRejectionReason("Signal criteria not met - " + direction + " trend signal");
        
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ ", direction, " trend signal REJECTED - signal criteria not met");
        return;
    }
    
    // Score signal quality before execution
    if(g_signalQualityAnalyzer != NULL)
    {
        int confluenceScore = 0;
        if(g_confluenceDetector != NULL)
        {
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            ConfluenceZone zone = g_confluenceDetector.GetBestConfluenceZone(bullish, currentPrice, 50.0);
            confluenceScore = zone.score;
        }
        double rsi = execution.rsi_current;
        double adx = rs.adx_h1;
        string signalType = execution.signal_type;
        
        SignalQualityScore qualityScore = g_signalQualityAnalyzer.ScoreSignalQuality(
            signalType, rs.confidence, confluenceScore, rsi, adx, finbertConfidence);
        
        // Filter low-quality signals
        if(g_signalQualityAnalyzer.FilterLowQualitySignals(qualityScore.overallScore))
        {
            string rejectionReason = "Signal quality too low: " + 
                                    DoubleToString(qualityScore.overallScore, 2) + 
                                    " (threshold: " + 
                                    DoubleToString(g_signalQualityAnalyzer.GetMinQualityThreshold(), 2) + ")";
            
            if(g_stateManager != NULL)
                g_stateManager.SetLastRejectionReason(rejectionReason);
            
            execution.decision = "REJECTED";
            execution.rejection_reason = rejectionReason;
            if(g_reporter != NULL) g_reporter.RecordDecision(execution);
            
            if(InpLogDetailedInfo)
                Print(logPrefix + "❌ Signal REJECTED - Quality score too low: ", 
                      DoubleToString(qualityScore.overallScore, 2));
            return;
        }
        
        if(InpLogDetailedInfo)
            Print(logPrefix + "✅ Signal quality score: ", DoubleToString(qualityScore.overallScore, 2),
                  " (", g_signalQualityAnalyzer.GetQualityDescription(qualityScore.overallScore), ")");
    }
    
    if(InpLogDetailedInfo)
        Print(logPrefix + "✅ ", direction, " trend signal CONFIRMED - proceeding with trade execution");
    
    // *** ENHANCED FINBERT SENTIMENT INTEGRATION ***
    // Use enhanced FinBERT analysis data passed from ExecuteTradeLogic
    string finbert_signal = finbertSignal;
    double finbert_score = finbertScore;
    double finbert_confidence = finbertConfidence;
    double sentiment_multiplier = 1.0;
    
    // Store FinBERT data in execution tracking
    execution.calendar_signal = finbert_signal;
    execution.calendar_confidence = finbert_confidence;
    
    if(InpEnableCalendarAI && finbert_confidence > 0.0)
    {
        // Enhanced FinBERT analysis is available
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "Enhanced FinBERT Analysis: ", finbert_signal, 
                  " (Confidence: ", DoubleToString(finbert_confidence, 2), 
                  ", Score: ", DoubleToString(finbert_score, 2), ")");
        }
        
        // Apply FinBERT sentiment filter
        bool finbertSupportsTrade = false;
        if(bullish && (finbert_signal == "BUY" || finbert_signal == "STRONG_BUY"))
        {
            finbertSupportsTrade = true;
            sentiment_multiplier = 1.0 + (finbert_confidence * 0.5); // Up to 50% boost
        }
        else if(!bullish && (finbert_signal == "SELL" || finbert_signal == "STRONG_SELL"))
        {
            finbertSupportsTrade = true;
            sentiment_multiplier = 1.0 + (finbert_confidence * 0.5); // Up to 50% boost
        }
        else if(finbert_signal == "NEUTRAL")
        {
            finbertSupportsTrade = true;
            sentiment_multiplier = 1.0; // No boost, no penalty
        }
        else
        {
            // FinBERT opposes the trade direction
            finbertSupportsTrade = false;
            sentiment_multiplier = 0.3; // Significant penalty
        }
        
        if(!finbertSupportsTrade && finbert_confidence > 0.7)
        {
            // High confidence FinBERT signal opposes trade - reject
            execution.decision = "REJECTED";
            execution.rejection_reason = "FinBERT sentiment opposes trade direction with high confidence";
            
            if(InpLogDetailedInfo)
            {
                Print(logPrefix + "❌ ", direction, " trend signal REJECTED - FinBERT opposes with high confidence");
                Print(logPrefix + "FinBERT Signal: ", finbert_signal, " (Confidence: ", DoubleToString(finbert_confidence, 2), ")");
            }
            
            if(g_reporter != NULL)
                g_reporter.RecordDecision(execution);
            return;
        }
        
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "FinBERT Sentiment Multiplier: ", DoubleToString(sentiment_multiplier, 2));
        }
    }
    else
    {
        // No enhanced FinBERT analysis available
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "No enhanced FinBERT analysis available - proceeding with technical analysis only");
        }
    }
    
    // Apply sentiment multiplier to position sizing
    if(sentiment_multiplier != 1.0)
    {
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "Applying FinBERT sentiment multiplier to position sizing: ", DoubleToString(sentiment_multiplier, 2));
        }
    }
    
    // Calculate position size using risk manager
    double stopDistancePips = rs.atr_current * 1.2 / _Point;
    double lot = 0.0;
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "Risk Calculation:");
        Print(logPrefix + "  Stop Distance: ", DoubleToString(stopDistancePips, 1), " pips (1.2 × ATR)");
        Print(logPrefix + "  ATR: ", DoubleToString(rs.atr_current, _Digits));
    }
    
    if(g_riskManager != NULL)
    {
        lot = g_riskManager.CalculateLotSize(stopDistancePips, rs.regime);
        if(InpLogDetailedInfo)
            Print(logPrefix + "  Base Lot Size (Risk Manager): ", DoubleToString(lot, 2));
    }
    else
    {
        lot = CalcLot(rs.regime); // Fallback to old method
        if(InpLogDetailedInfo)
            Print(logPrefix + "  Base Lot Size (Fallback): ", DoubleToString(lot, 2));
    }
    
    // Apply FinBERT sentiment multiplier
    if(sentiment_multiplier != 1.0)
    {
        double original_lot = lot;
        lot = lot * sentiment_multiplier;
        if(InpLogDetailedInfo)
            Print(logPrefix + "  FinBERT Adjustment: ", DoubleToString(original_lot, 2), " × ", DoubleToString(sentiment_multiplier, 2), " = ", DoubleToString(lot, 2));
    }

    // Normalize lot to symbol volume step and bounds
    lot = NormalizeVolumeToStep(_Symbol, lot);
    
    if(lot <= 0) 
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ TRADE BLOCKED: Invalid lot size (", DoubleToString(lot, 2), ")");
        
        execution.decision = "BLOCKED";
        execution.rejection_reason = StringFormat("Invalid lot size: %.2f", lot);
        execution.calculated_lot = lot;
        if(g_reporter != NULL) g_reporter.RecordDecision(execution);
        return;
    }
    
    double price = bullish ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = 0.0, tp = 0.0;
    
    // Check if this is a momentum trade (large candle)
    double currentCandle = MathAbs(SymbolInfoDouble(_Symbol, SYMBOL_BID) - iOpen(_Symbol, PERIOD_CURRENT, 0));
    double momentumStrength = currentCandle / rs.atr_current;
    bool isMomentumTrade = (momentumStrength > 1.5); // Momentum if > 1.5x ATR
    
    if(isMomentumTrade && InpLogDetailedInfo)
    {
        Print(logPrefix + "💥 MOMENTUM TRADE DETECTED - ", DoubleToString(momentumStrength, 2), "x ATR");
    }
    
    // Calculate SL/TP using risk manager
    if(g_riskManager != NULL)
    {
        sl = g_riskManager.CalculateStopLoss(bullish, price, rs.atr_current);
        // For momentum trades, use our adaptive TP instead of risk manager's fixed ratio
        if(isMomentumTrade)
        {
            tp = TakeProfit_TREND(bullish, rs, true, momentumStrength);
        }
        else
        {
            tp = g_riskManager.CalculateTakeProfit(bullish, price, sl);
        }
    }
    else
    {
        sl = StopLoss_TREND(bullish, rs); // Fallback to old method
        tp = TakeProfit_TREND(bullish, rs, isMomentumTrade, momentumStrength);
    }

    if(InpLogDetailedInfo)
    {
        double slPips = MathAbs(price - sl) / GetPipSize();
        double tpPips = MathAbs(tp - price) / GetPipSize();
        double rrRatio = (tpPips > 0) ? (tpPips / slPips) : 0;
        Print(logPrefix + "SL/TP BEFORE NORMALIZE: Entry=", DoubleToString(price, _Digits), 
              " SL=", DoubleToString(sl, _Digits), " (", DoubleToString(slPips, 1), " pips)",
              " TP=", DoubleToString(tp, _Digits), " (", DoubleToString(tpPips, 1), " pips)",
              " R:R=", DoubleToString(rrRatio, 2));
    }

    // Ensure SL/TP respect broker min stop distance and correct side
    NormalizeStops(bullish, price, sl, tp);

    if(InpLogDetailedInfo)
    {
        double slPips = MathAbs(price - sl) / GetPipSize();
        double tpPips = MathAbs(tp - price) / GetPipSize();
        double rrRatio = (tpPips > 0) ? (tpPips / slPips) : 0;
        Print(logPrefix + "SL/TP AFTER NORMALIZE: Entry=", DoubleToString(price, _Digits), 
              " SL=", DoubleToString(sl, _Digits), " (", DoubleToString(slPips, 1), " pips)",
              " TP=", DoubleToString(tp, _Digits), " (", DoubleToString(tpPips, 1), " pips)",
              " R:R=", DoubleToString(rrRatio, 2));
    }
    
    // Cap TP at nearest STRONG key level (leave a buffer) and mark TP lock in comment
    string tpLockTag = "";
    {
        int levelCount = (g_keyLevelDetector != NULL ? g_keyLevelDetector.GetKeyLevelCount() : 0);
        if(levelCount > 0)
        {
            int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
            double buffer = MathMax(5 * _Point, 0.2 * rs.atr_current);
            double minStrength = InpMinStrength;
            
            // Find nearest strong resistance above price and nearest strong support below price
            bool haveStrongRes = false, haveStrongSup = false;
            SKeyLevel strongRes; ZeroMemory(strongRes);
            SKeyLevel strongSup; ZeroMemory(strongSup);
            double bestResDelta = DBL_MAX, bestSupDelta = DBL_MAX;
            
            for(int i = 0; i < levelCount; i++)
            {
                SKeyLevel lvl;
                if(!g_keyLevelDetector.GetKeyLevel(i, lvl))
                    continue;
                if(lvl.strength < minStrength)
                    continue; // skip weak levels
                
                if(lvl.isResistance && lvl.price > price)
                {
                    double d = lvl.price - price;
                    if(d < bestResDelta)
                    {
                        bestResDelta = d;
                        strongRes = lvl;
                        haveStrongRes = true;
                    }
                }
                else if(!lvl.isResistance && lvl.price < price)
                {
                    double d = price - lvl.price;
                    if(d < bestSupDelta)
                    {
                        bestSupDelta = d;
                        strongSup = lvl;
                        haveStrongSup = true;
                    }
                }
            }
            
            if(bullish && haveStrongRes)
            {
                double cappedTp = NormalizeDouble(strongRes.price - buffer, digits);
                double originalTpPips = MathAbs(tp - price) / GetPipSize();
                double cappedTpPips = MathAbs(cappedTp - price) / GetPipSize();
                double minAcceptableTP = price + (MathAbs(price - sl) * 1.5); // At least 1.5:1 R:R
                
                if(InpLogDetailedInfo)
                {
                    Print(logPrefix + "RESISTANCE CAPPING CHECK:");
                    Print(logPrefix + "  Original TP: ", DoubleToString(tp, digits), " (", DoubleToString(originalTpPips, 1), " pips)");
                    Print(logPrefix + "  Resistance: ", DoubleToString(strongRes.price, digits), " (strength: ", DoubleToString(strongRes.strength, 2), ")");
                    Print(logPrefix + "  Would cap to: ", DoubleToString(cappedTp, digits), " (", DoubleToString(cappedTpPips, 1), " pips)");
                    Print(logPrefix + "  Min acceptable TP: ", DoubleToString(minAcceptableTP, digits));
                }
                
                // Only cap TP if the capped level still gives at least 1.5:1 R:R
                if(cappedTp < tp && cappedTp >= minAcceptableTP)
                {
                    tp = cappedTp;
                    tpLockTag = StringFormat("|TP_LOCK@%s|R=%s|SCORE=%.2f", DoubleToString(tp, digits), DoubleToString(strongRes.price, digits), strongRes.strength);
                    if(InpLogDetailedInfo)
                        Print(logPrefix + "✅ TP CAPPED at resistance (maintains decent R:R)");
                }
                else if(InpLogDetailedInfo)
                {
                    Print(logPrefix + "❌ TP CAPPING REJECTED (would destroy R:R ratio)");
                }
            }
            else if(!bullish && haveStrongSup)
            {
                double cappedTp = NormalizeDouble(strongSup.price + buffer, digits);
                double originalTpPips = MathAbs(price - tp) / GetPipSize();
                double cappedTpPips = MathAbs(price - cappedTp) / GetPipSize();
                double minAcceptableTP = price - (MathAbs(sl - price) * 1.5); // At least 1.5:1 R:R
                
                if(InpLogDetailedInfo)
                {
                    Print(logPrefix + "SUPPORT CAPPING CHECK:");
                    Print(logPrefix + "  Original TP: ", DoubleToString(tp, digits), " (", DoubleToString(originalTpPips, 1), " pips)");
                    Print(logPrefix + "  Support: ", DoubleToString(strongSup.price, digits), " (strength: ", DoubleToString(strongSup.strength, 2), ")");
                    Print(logPrefix + "  Would cap to: ", DoubleToString(cappedTp, digits), " (", DoubleToString(cappedTpPips, 1), " pips)");
                    Print(logPrefix + "  Min acceptable TP: ", DoubleToString(minAcceptableTP, digits));
                }
                
                // Only cap TP if the capped level still gives at least 1.5:1 R:R
                if(cappedTp > tp && cappedTp <= minAcceptableTP)
                {
                    tp = cappedTp;
                    tpLockTag = StringFormat("|TP_LOCK@%s|S=%s|SCORE=%.2f", DoubleToString(tp, digits), DoubleToString(strongSup.price, digits), strongSup.strength);
                    if(InpLogDetailedInfo)
                        Print(logPrefix + "✅ TP CAPPED at support (maintains decent R:R)");
                }
                else if(InpLogDetailedInfo)
                {
                    Print(logPrefix + "❌ TP CAPPING REJECTED (would destroy R:R ratio)");
                }
            }
        }
    }
    
    if(InpLogDetailedInfo)
    {
        double finalSlPips = MathAbs(price - sl) / GetPipSize();
        double finalTpPips = MathAbs(tp - price) / GetPipSize();
        double finalRrRatio = (finalSlPips > 0) ? (finalTpPips / finalSlPips) : 0;
        Print(logPrefix + "FINAL SL/TP: Entry=", DoubleToString(price, _Digits), 
              " SL=", DoubleToString(sl, _Digits), " (", DoubleToString(finalSlPips, 1), " pips)",
              " TP=", DoubleToString(tp, _Digits), " (", DoubleToString(finalTpPips, 1), " pips)",
              " R:R=", DoubleToString(finalRrRatio, 2));
    }
    
    string comment = StringFormat("%s Trend-%s", InpOrderTag, bullish ? "BULL" : "BEAR");
    if(tpLockTag != "")
        comment += tpLockTag;
    
    // DISABLED: News sentiment support (commented out - only using free economic calendar data)
    bool sentimentSupports = false; // Always false since news sentiment is disabled
    /*
    // Append concise sentiment tag if sentiment agrees with direction
    // Keep order comment short due to broker limits (~31-63 chars typical)
    if(g_newsSentiment.GetCurrentSignal() != "")
    {
        if(bullish)
            sentimentSupports = g_newsSentiment.ShouldEnterLong();
        else
            sentimentSupports = g_newsSentiment.ShouldEnterShort();
        if(sentimentSupports)
        {
            comment += "|SENTI";
        }
    }
    */
    
    // CHECK COOL-OFF PERIOD
    if(IsInCooloffPeriod(bullish))
    {
        return; // Cool-off active, skip trade
    }
    
    // Check intelligent position scaling
    int existingPositions = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
            existingPositions++;
        }
    }
    
    // Apply intelligent scaling logic
    if(!ShouldAllowIntelligentScaling(existingPositions, bullish))
    {
        if(InpLogScalingDecisions)
        {
            Print(StringFormat("[SCALING] Trend trade BLOCKED - Positions: %d, Buy: %s, Range valid: %s",
                  existingPositions, bullish ? "true" : "false", 
                  (g_stateManager != NULL && g_stateManager.GetCurrentRange().isValid) ? "true" : "false"));
        }
        return;
    }
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "Trade Parameters:");
        Print(logPrefix + "  Direction: ", direction);
        Print(logPrefix + "  Entry Price: ", DoubleToString(price, _Digits));
        Print(logPrefix + "  Stop Loss: ", DoubleToString(sl, _Digits), " (", DoubleToString(MathAbs(price - sl) / _Point, 1), " pips)");
        Print(logPrefix + "  Take Profit: ", DoubleToString(tp, _Digits), " (", DoubleToString(MathAbs(tp - price) / _Point, 1), " pips)");
        Print(logPrefix + "  Risk/Reward: 1:", DoubleToString(MathAbs(tp - price) / MathAbs(price - sl), 2));
        Print(logPrefix + "  Position Size: ", DoubleToString(lot, 2), " lots");
        Print(logPrefix + "  Comment: ", comment);
        Print(logPrefix + "→ EXECUTING ", direction, " TREND TRADE...");
    }
    
    // CRITICAL: Validate margin before executing trade
    ENUM_ORDER_TYPE orderType = bullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    if(!ValidateMarginBeforeTrade(orderType, lot, price, "TREND"))
    {
        execution.decision = "REJECTED";
        execution.rejection_reason = "Insufficient margin";
        if(g_reporter != NULL) g_reporter.RecordDecision(execution);
        return;
    }
    
    bool tradeResult = false;
    double limitPrice = price; // Default to current price
    string orderTypeStr = "MARKET";
    
    // Use limit orders if enabled
    if(InpUseLimitOrders && g_limitOrderManager != NULL)
    {
        // Prepare limit order request
        LimitOrderRequest request;
        request.isBuy = bullish;
        request.lotSize = lot;
        request.basePrice = price;
        request.stopLoss = sl;
        request.takeProfit = tp;
        request.comment = comment;
        request.tradeContext = "TREND";
        request.logPrefix = logPrefix;
        
        // Place limit order using manager
        LimitOrderResult result = g_limitOrderManager.PlaceLimitOrder(request);
        
        if(result.success)
        {
            // Limit order placed successfully
            tradeResult = true;
            orderTypeStr = result.orderType;
            limitPrice = result.limitPrice;
            sl = result.adjustedSL;
            tp = result.adjustedTP;
            
            // Note: Stops are already normalized in the manager's PlaceLimitOrder method
            // The manager uses NormalizeStops internally before placing the order
        }
        else
        {
            // Limit order placement failed or rejected
            if(result.errorCode == "NO_CONFLUENCE" || result.errorCode == "TOO_FAR" || result.errorCode == "DUPLICATE")
            {
                // Rejected due to validation - skip trade
                execution.decision = "REJECTED";
                execution.rejection_reason = result.errorMessage;
                if(g_reporter != NULL) g_reporter.RecordDecision(execution);
                return;
            }
            else
            {
                // Other error - fall through to market order or fail
                if(InpLogDetailedInfo)
                    Print(logPrefix + "Limit order failed: ", result.errorMessage);
                // Continue to market order fallback if limit orders not strictly required
                // For now, we'll skip the trade if limit order fails
                execution.decision = "REJECTED";
                execution.rejection_reason = result.errorMessage;
                if(g_reporter != NULL) g_reporter.RecordDecision(execution);
                return;
            }
        }
    }
    else
    {
        // Limit orders disabled - use market orders
        if(bullish)
            tradeResult = g_trade.Buy(lot, _Symbol, price, sl, tp, comment);
        else
            tradeResult = g_trade.Sell(lot, _Symbol, price, sl, tp, comment);
    }
    
    // Always-on concise summary for monitoring
    Print(StringFormat("[TREND] %s %s %s @%s SL=%s TP=%s lot=%.2f rr=%.2f%s",
                       orderTypeStr,
                       (tradeResult?"PLACED":"FAILED"),
                       bullish?"BUY":"SELL",
                       DoubleToString(limitPrice, _Digits),
                       DoubleToString(sl, _Digits),
                       DoubleToString(tp, _Digits),
                       lot,
                       (MathAbs(tp-limitPrice)/MathMax(1e-10, MathAbs(limitPrice-sl))),
                       (sentimentSupports?" senti=YES":"")));
    
    // Log scaling decision for successful trades
    if(tradeResult)
    {
        LogScalingDecision(existingPositions + 1, price, bullish);
    }

    // Track execution result
    execution.calculated_lot = lot;
    execution.risk_percent = InpRiskPctTrend;
    
    if(tradeResult)
    {
        ulong orderTicket = g_trade.ResultOrder();
        double executionPrice = g_trade.ResultPrice();
        
        execution.decision = "EXECUTED";
        execution.rejection_reason = "";
        execution.additional_notes = StringFormat("Order #%lld filled at %.5f", orderTicket, executionPrice);
        if(g_reporter != NULL) g_reporter.RecordDecision(execution);
        
        // Publish order placed event
        string orderDetails = StringFormat("%s %s | Lot: %.2f | Entry: %s | SL: %s | TP: %s",
                                         orderTypeStr, bullish ? "BUY" : "SELL", lot,
                                         DoubleToString(limitPrice, _Digits),
                                         DoubleToString(sl, _Digits),
                                         DoubleToString(tp, _Digits));
        PublishOrderEvent(EVENT_ORDER_PLACED, orderTicket, orderDetails);
        
        // Publish position opened event if order was filled immediately
        if(orderTicket > 0)
        {
            string positionDetails = StringFormat("Trend %s | Entry: %s | SL: %s | TP: %s | Lot: %.2f",
                                                bullish ? "BULL" : "BEAR",
                                                DoubleToString(executionPrice, _Digits),
                                                DoubleToString(sl, _Digits),
                                                DoubleToString(tp, _Digits),
                                                lot);
            PublishPositionEvent(EVENT_POSITION_OPENED, orderTicket, positionDetails);
        }
        
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "🎯 TRADE EXECUTED SUCCESSFULLY!");
            Print(logPrefix + "  Ticket: ", orderTicket);
            Print(logPrefix + "  Execution Price: ", DoubleToString(executionPrice, _Digits));
            Print(logPrefix + "  Slippage: ", DoubleToString(MathAbs(executionPrice - price) / _Point, 1), " pips");
        }
    }
    else
    {
        execution.decision = "FAILED";
        string errorMsg = StringFormat("Execution failed - Error %d: %s",
                                      g_trade.ResultRetcode(),
                                      g_trade.ResultRetcodeDescription());
        execution.rejection_reason = errorMsg;
        if(g_reporter != NULL) g_reporter.RecordDecision(execution);
        
        // Publish order failed event
        string failureDetails = StringFormat("%s %s | Lot: %.2f | Error: %s",
                                           orderTypeStr, bullish ? "BUY" : "SELL", lot, errorMsg);
        PublishOrderEvent(EVENT_ORDER_FAILED, 0, failureDetails);
        
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "❌ TRADE EXECUTION FAILED!");
            Print(logPrefix + "  Error Code: ", g_trade.ResultRetcode());
            Print(logPrefix + "  Error Description: ", g_trade.ResultRetcodeDescription());
        }
    }
}

//+------------------------------------------------------------------+
//| Breakout trading logic                                           |
//+------------------------------------------------------------------+
void BreakoutTrade(const RegimeSnapshot &rs, string finbertSignal = "NEUTRAL", double finbertConfidence = 0.0, double finbertScore = 0.0)
{
    string logPrefix = "[BREAKOUT SIGNAL] ";
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "Analyzing breakout opportunity...");
        Print(logPrefix + "Required Risk %: ", DoubleToString(InpRiskPctBreakout, 1), "%");
    }
    
    if(!Signal_BREAKOUT(rs)) 
    {
        // Update throttling variables for rejection
        if(g_stateManager != NULL)
            g_stateManager.SetLastRejectionReason("Signal criteria not met - BREAKOUT signal");
        
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ Breakout signal REJECTED - signal criteria not met");
        return;
    }
    
    // Score signal quality before execution
    if(g_signalQualityAnalyzer != NULL)
    {
        int confluenceScore = 0;
        if(g_confluenceDetector != NULL)
        {
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            // Get confluence for both directions and use the maximum score
            ConfluenceZone zoneBuy = g_confluenceDetector.GetBestConfluenceZone(true, currentPrice, 50.0);
            ConfluenceZone zoneSell = g_confluenceDetector.GetBestConfluenceZone(false, currentPrice, 50.0);
            confluenceScore = MathMax(zoneBuy.score, zoneSell.score);
        }
        double rsi = GetRSIValue(_Symbol, PERIOD_CURRENT, InpRSIPeriod, 0);
        if(rsi < 0) rsi = 0.0;
        double adx = rs.adx_h1;
        
        SignalQualityScore qualityScore = g_signalQualityAnalyzer.ScoreSignalQuality(
            "BREAKOUT", rs.confidence, confluenceScore, rsi, adx, finbertConfidence);
        
        if(g_signalQualityAnalyzer.FilterLowQualitySignals(qualityScore.overallScore))
        {
            if(g_stateManager != NULL)
                g_stateManager.SetLastRejectionReason("Signal quality too low: " + 
                                                      DoubleToString(qualityScore.overallScore, 2));
            if(InpLogDetailedInfo)
                Print(logPrefix + "❌ Signal REJECTED - Quality score too low: ", 
                      DoubleToString(qualityScore.overallScore, 2));
            return;
        }
    }
    
    if(InpLogDetailedInfo)
        Print(logPrefix + "✅ Breakout signal CONFIRMED - proceeding with trade setup");
    
    // Check if this is a momentum surge trade
    double currentCandle = MathAbs(SymbolInfoDouble(_Symbol, SYMBOL_BID) - iOpen(_Symbol, PERIOD_CURRENT, 0));
    double momentumStrength = currentCandle / rs.atr_current;
    bool strongMomentumSurge = (momentumStrength > 3.0);
    bool moderateMomentumSurge = (momentumStrength > 1.5);
    
    // Get strongest key level for breakout (unless momentum surge)
    SKeyLevel strongestLevel;
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double breakoutLevel = currentPrice;  // Default to current price for momentum trades
    
    if(!strongMomentumSurge)
    {
        if(!g_keyLevelDetector.GetStrongestLevel(strongestLevel))
        {
            if(InpLogDetailedInfo)
                Print(logPrefix + "❌ TRADE BLOCKED: No strong key levels found");
            Print("[BREAKOUT] BLOCK: no strong key levels");
            return;
        }
        breakoutLevel = strongestLevel.price;
    }
    else
    {
        // For momentum surge, trade at market price
        Print(logPrefix + "💥 MOMENTUM SURGE TRADE - Trading at market price!");
        // Determine direction based on candle direction
        double openPrice = iOpen(_Symbol, PERIOD_CURRENT, 0);
        strongestLevel.isResistance = (currentPrice > openPrice);  // Buy if price above open
        strongestLevel.price = currentPrice;
        strongestLevel.strength = 1.0;
    }
    
    double stopDistancePips = rs.atr_current * 1.2 / _Point;
    double lot = 0.0;
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "Key Level Analysis:");
        Print(logPrefix + "  Strongest Level: ", DoubleToString(strongestLevel.price, _Digits));
        Print(logPrefix + "  Level Type: ", strongestLevel.isResistance ? "RESISTANCE" : "SUPPORT");
        Print(logPrefix + "  Level Strength: ", DoubleToString(strongestLevel.strength, 3));
        Print(logPrefix + "  Level Touches: ", strongestLevel.touchCount);
        Print(logPrefix + "  Current Price: ", DoubleToString(currentPrice, _Digits));
        Print(logPrefix + "  Distance to Level: ", DoubleToString(MathAbs(currentPrice - breakoutLevel), _Digits), " (", DoubleToString(MathAbs(currentPrice - breakoutLevel) / _Point, 1), " pips)");
    }
    
    // Calculate position size using risk manager
    if(g_riskManager != NULL)
    {
        lot = g_riskManager.CalculateLotSize(stopDistancePips, rs.regime);
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "Risk Calculation:");
            Print(logPrefix + "  Stop Distance: ", DoubleToString(stopDistancePips, 1), " pips (1.2 × ATR)");
            Print(logPrefix + "  Lot Size (Risk Manager): ", DoubleToString(lot, 2));
        }
    }
    else
    {
        lot = CalcLot(rs.regime); // Fallback to old method
        if(InpLogDetailedInfo)
            Print(logPrefix + "  Lot Size (Fallback): ", DoubleToString(lot, 2));
    }
    
    if(lot <= 0) 
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ TRADE BLOCKED: Invalid lot size (", DoubleToString(lot, 2), ")");
        Print(StringFormat("[BREAKOUT] BLOCK: invalid lot size (%.2f)", lot));
        return;
    }
    
    // Calculate SL/TP using risk manager
    double breakoutSL = 0.0, breakoutTP = 0.0;
    
    if(g_riskManager != NULL)
    {
        bool isBuy = strongestLevel.isResistance;
        breakoutSL = g_riskManager.CalculateStopLoss(isBuy, breakoutLevel, rs.atr_current);
        
        // For momentum trades, use adaptive TP
        if(moderateMomentumSurge)
        {
            breakoutTP = TakeProfit_TREND(isBuy, rs, true, momentumStrength);
            if(InpLogDetailedInfo)
                Print(logPrefix + "Using momentum-adaptive TP for ", DoubleToString(momentumStrength, 2), "x ATR surge");
        }
        else
        {
            breakoutTP = g_riskManager.CalculateTakeProfit(isBuy, breakoutLevel, breakoutSL);
        }
    }
    else
    {
        // Fallback to old method
        breakoutSL = strongestLevel.isResistance ? 
                    breakoutLevel + rs.atr_current * 1.2 : 
                    breakoutLevel - rs.atr_current * 1.2;
        
        // Use momentum-aware TP for momentum trades
        if(moderateMomentumSurge)
        {
            breakoutTP = TakeProfit_TREND(strongestLevel.isResistance, rs, true, momentumStrength);
        }
        else
        {
            breakoutTP = strongestLevel.isResistance ? 
                        breakoutLevel - rs.atr_current * 3.0 : 
                        breakoutLevel + rs.atr_current * 3.0;
        }
    }
    
    // Add momentum indicator to comment for tracking
    string comment = StringFormat("%s BO-%s%s", InpOrderTag, 
                                 strongestLevel.isResistance ? "RESISTANCE" : "SUPPORT",
                                 moderateMomentumSurge ? "-MOMENTUM" : "");
    // Always-on concise order summary for monitoring
    Print(StringFormat("[BREAKOUT] ORDER %s @%s SL=%s TP=%s lot=%.2f",
                       strongestLevel.isResistance ? "BUYSTOP" : "SELLSTOP",
                       DoubleToString(breakoutLevel, _Digits),
                       DoubleToString(breakoutSL, _Digits),
                       DoubleToString(breakoutTP, _Digits),
                       lot));
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "Trade Parameters:");
        Print(logPrefix + "  Direction: ", strongestLevel.isResistance ? "BUY (breakout above resistance)" : "SELL (breakout below support)");
        Print(logPrefix + "  Entry Level: ", DoubleToString(breakoutLevel, _Digits));
        Print(logPrefix + "  Stop Loss: ", DoubleToString(breakoutSL, _Digits), " (", DoubleToString(MathAbs(breakoutLevel - breakoutSL) / _Point, 1), " pips)");
        Print(logPrefix + "  Take Profit: ", DoubleToString(breakoutTP, _Digits), " (", DoubleToString(MathAbs(breakoutTP - breakoutLevel) / _Point, 1), " pips)");
        Print(logPrefix + "  Risk/Reward: 1:", DoubleToString(MathAbs(breakoutTP - breakoutLevel) / MathAbs(breakoutLevel - breakoutSL), 2));
        Print(logPrefix + "  Position Size: ", DoubleToString(lot, 2), " lots");
        Print(logPrefix + "  Comment: ", comment);
        Print(logPrefix + "→ PLACING STOP ORDER...");
    }
    
    // Validate and prepare order (skip validation for momentum surge)
    bool isBuyStop = strongestLevel.isResistance;
    
    if(!strongMomentumSurge)
    {
        // Normal breakout - validate pending order
        if(!IsPendingPriceValid(isBuyStop, breakoutLevel))
        {
            Print(StringFormat("[BREAKOUT] BLOCK: invalid trigger vs price/min distance (level=%s)", DoubleToString(breakoutLevel, _Digits)));
            return;
        }
        
        // Skip if a similar pending already exists (within 3 points)
        if(HasSimilarPendingOrderForBreakout(isBuyStop, breakoutLevel, 3))
        {
            if(InpLogDetailedInfo)
                Print("[BREAKOUT] Skip: similar pending already exists near level");
            return;
        }
    }
    
    // Normalize lot and stops
    lot = NormalizeVolumeToStep(_Symbol, lot);
    NormalizeStops(isBuyStop, breakoutLevel, breakoutSL, breakoutTP);

    // Check intelligent position scaling for breakout trades
    int existingPositions = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
            existingPositions++;
        }
    }
    
    // Apply intelligent scaling logic
    bool isBuyBreakout = strongestLevel.isResistance;
    if(!ShouldAllowIntelligentScaling(existingPositions, isBuyBreakout))
    {
        if(InpLogScalingDecisions)
        {
            Print(StringFormat("[SCALING] Breakout trade BLOCKED - Positions: %d, Buy: %s, Range valid: %s",
                  existingPositions, isBuyBreakout ? "true" : "false", 
                  (g_stateManager != NULL && g_stateManager.GetCurrentRange().isValid) ? "true" : "false"));
        }
        return;
    }
    
    // CRITICAL: Validate margin before placing order
    ENUM_ORDER_TYPE orderType = strongestLevel.isResistance ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    double checkPrice = strongMomentumSurge ? (strongestLevel.isResistance ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID)) : breakoutLevel;
    if(!ValidateMarginBeforeTrade(orderType, lot, checkPrice, "BREAKOUT"))
    {
        return;
    }
    
    // Place order - use limit orders if enabled, otherwise use stop/market orders
    bool tradeResult = false;
    double limitPrice = breakoutLevel;
    string orderTypeStr = strongMomentumSurge ? "MARKET" : "STOP";
    bool isBuyDirection = strongestLevel.isResistance;
    currentPrice = isBuyDirection ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Use limit orders if enabled and not a strong momentum surge
    if(InpUseLimitOrders && g_limitOrderManager != NULL && !strongMomentumSurge)
    {
        // Prepare limit order request
        LimitOrderRequest request;
        request.isBuy = isBuyDirection;
        request.lotSize = lot;
        request.basePrice = currentPrice;
        request.stopLoss = breakoutSL;
        request.takeProfit = breakoutTP;
        request.comment = comment;
        request.tradeContext = "BREAKOUT";
        request.logPrefix = "[BREAKOUT]";
        
        // Place limit order using manager
        LimitOrderResult result = g_limitOrderManager.PlaceLimitOrder(request);
        
        if(result.success)
        {
            // Limit order placed successfully
            tradeResult = true;
            orderTypeStr = result.orderType;
            limitPrice = result.limitPrice;
            breakoutSL = result.adjustedSL;
            breakoutTP = result.adjustedTP;
            
            // Publish order placed event
            ulong orderTicket = result.ticket;
            string orderDetails = StringFormat("LIMIT %s | Lot: %.2f | Price: %s | SL: %s | TP: %s",
                                             isBuyDirection ? "BUYLIMIT" : "SELLLIMIT", lot,
                                             DoubleToString(limitPrice, _Digits),
                                             DoubleToString(breakoutSL, _Digits),
                                             DoubleToString(breakoutTP, _Digits));
            PublishOrderEvent(EVENT_ORDER_PLACED, orderTicket, orderDetails);
        }
        else
        {
            // Limit order placement failed or rejected
            if(result.errorCode == "NO_CONFLUENCE" || result.errorCode == "TOO_FAR" || result.errorCode == "DUPLICATE")
            {
                // Rejected due to validation - skip trade
                if(InpLogConfluenceAnalysis)
                    Print("[BREAKOUT] ⚠️ ", result.errorMessage);
                return;
            }
            else
            {
                // Other error - publish failure event
                string errorMsg = result.errorMessage;
                Print(StringFormat("[BREAKOUT] LIMIT ORDER FAILED %s", errorMsg));
                string failureDetails = StringFormat("LIMIT %s | Lot: %.2f | Error: %s",
                                                   isBuyDirection ? "BUYLIMIT" : "SELLLIMIT", lot, errorMsg);
                PublishOrderEvent(EVENT_ORDER_FAILED, 0, failureDetails);
                return;
            }
        }
    }
    else if(strongMomentumSurge)
    {
        // Strong momentum surge - skip trade when limit orders are required
        if(InpLogConfluenceAnalysis)
            Print("[BREAKOUT] ⚠️ Strong momentum surge detected - skipping trade (limit orders required)");
        return; // Skip trade instead of using market order
    }
    else
    {
        // Limit orders disabled - use traditional stop orders
        orderTypeStr = "STOP";
        if(isBuyDirection)
            tradeResult = g_trade.BuyStop(NormalizeDouble(lot, 2), NormalizeDouble(breakoutLevel, _Digits), _Symbol, NormalizeDouble(breakoutSL, _Digits), NormalizeDouble(breakoutTP, _Digits), ORDER_TIME_GTC, 0, comment);
        else
            tradeResult = g_trade.SellStop(NormalizeDouble(lot, 2), NormalizeDouble(breakoutLevel, _Digits), _Symbol, NormalizeDouble(breakoutSL, _Digits), NormalizeDouble(breakoutTP, _Digits), ORDER_TIME_GTC, 0, comment);
        
        if(tradeResult)
            Print(StringFormat("[BREAKOUT] STOP ORDER PLACED OK ticket=%I64u", g_trade.ResultOrder()));
        else
            Print(StringFormat("[BREAKOUT] STOP ORDER FAILED retcode=%d desc=%s", g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
    }
    
    if(InpLogDetailedInfo)
    {
        if(tradeResult)
        {
            Print(logPrefix + "🎯 STOP ORDER PLACED SUCCESSFULLY!");
            Print(logPrefix + "  Ticket: ", g_trade.ResultOrder());
            Print(logPrefix + "  Order Type: ", strongestLevel.isResistance ? "BUY STOP" : "SELL STOP");
            Print(logPrefix + "  Trigger Price: ", DoubleToString(breakoutLevel, _Digits));
        }
        else
        {
            Print(logPrefix + "❌ STOP ORDER PLACEMENT FAILED!");
            Print(logPrefix + "  Error Code: ", g_trade.ResultRetcode());
            Print(logPrefix + "  Error Description: ", g_trade.ResultRetcodeDescription());
        }
    }
}

//+------------------------------------------------------------------+
//| Range trading logic                                              |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Range trading logic                                              |
//+------------------------------------------------------------------+
// PURPOSE:
//   Executes range-bound trades by fading touches of range boundaries.
//   Buys near support, sells near resistance, targeting mid-range.
//
// BEHAVIOR:
//   1. Validates range signal using Signal_RANGE()
//   2. Identifies current range boundaries (support and resistance)
//   3. Determines if price is near support (buy) or resistance (sell)
//   4. Calculates position size based on risk percentage
//   5. Places market order with stop loss and take profit targeting mid-range
//   6. Records trade execution in database
//
// PARAMETERS:
//   rs (RegimeSnapshot) - Current market regime snapshot with ATR, ADX values
//   finbertSignal (string) - FinBERT sentiment signal (default: "NEUTRAL")
//   finbertConfidence (double) - FinBERT confidence level (0.0-1.0)
//   finbertScore (double) - FinBERT sentiment score
//
// RETURNS:
//   (void) - No return value. Check Event Bus for order placement results.
//
// SIDE EFFECTS:
//   - May place market order through CTrade object
//   - Publishes EVENT_ORDER_PLACED or EVENT_ORDER_FAILED events
//   - Records trade decision in database via IntelligentReporter
//   - Logs detailed trade information if InpLogDetailedInfo is enabled
//
// ERROR CONDITIONS:
//   - Signal validation fails: Returns early
//   - No valid range boundaries found: Trade rejected
//   - Price not near range boundaries: Trade skipped
//   - Invalid lot size: Trade blocked
//   - Margin validation fails: Trade rejected
//   - Order placement fails: EVENT_ORDER_FAILED published
//
// PRECONDITIONS:
//   - Signal_RANGE() must return true
//   - Valid range boundaries must exist (support and resistance)
//   - Price must be near range boundary (within 0.2% of support/resistance)
//
// POSTCONDITIONS:
//   - Market order placed or rejected with reason recorded
//   - Events published to Event Bus
//   - Trade decision recorded in database
//
// NOTES:
//   - Uses InpRiskPctRange for position sizing
//   - Fades resistance (sells) when price >= 99.8% of resistance
//   - Fades support (buys) when price <= 100.2% of support
//   - Take profit targets mid-range between support and resistance
//   - Stop loss uses 0.5x ATR for tighter risk in ranging markets
//   - All trades use InpMagicNumber for identification
//
// RELATED:
//   - See Also: Signal_RANGE(), TrendTrade(), BreakoutTrade()
//   - Called By: ExecuteTradeLogic()
//   - Calls: Signal_RANGE(), GetRangeBoundaries(), CalcLot(), NormalizeVolumeToStep()
//+------------------------------------------------------------------+
void RangeTrade(const RegimeSnapshot &rs, string finbertSignal = "NEUTRAL", double finbertConfidence = 0.0, double finbertScore = 0.0)
{
    string logPrefix = "[RANGE SIGNAL] ";
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "Analyzing range trading opportunity...");
        Print(logPrefix + "Required Risk %: ", DoubleToString(InpRiskPctRange, 1), "%");
    }
    
    if(!Signal_RANGE(rs)) 
    {
        // Update throttling variables for rejection
        if(g_stateManager != NULL)
            g_stateManager.SetLastRejectionReason("Signal criteria not met - RANGE signal");
        
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ Range signal REJECTED - signal criteria not met");
        return;
    }
    
    // Score signal quality before execution
    if(g_signalQualityAnalyzer != NULL)
    {
        int confluenceScore = 0;
        if(g_confluenceDetector != NULL)
        {
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            // Get confluence for both directions and use the maximum score
            ConfluenceZone zoneBuy = g_confluenceDetector.GetBestConfluenceZone(true, currentPrice, 50.0);
            ConfluenceZone zoneSell = g_confluenceDetector.GetBestConfluenceZone(false, currentPrice, 50.0);
            confluenceScore = MathMax(zoneBuy.score, zoneSell.score);
        }
        double rsi = GetRSIValue(_Symbol, PERIOD_CURRENT, InpRSIPeriod, 0);
        if(rsi < 0) rsi = 0.0;
        double adx = rs.adx_h1;
        
        SignalQualityScore qualityScore = g_signalQualityAnalyzer.ScoreSignalQuality(
            "RANGE", rs.confidence, confluenceScore, rsi, adx, finbertConfidence);
        
        if(g_signalQualityAnalyzer.FilterLowQualitySignals(qualityScore.overallScore))
        {
            if(g_stateManager != NULL)
                g_stateManager.SetLastRejectionReason("Signal quality too low: " + 
                                                      DoubleToString(qualityScore.overallScore, 2));
            if(InpLogDetailedInfo)
                Print(logPrefix + "❌ Signal REJECTED - Quality score too low: ", 
                      DoubleToString(qualityScore.overallScore, 2));
            return;
        }
    }
    
    if(InpLogDetailedInfo)
        Print(logPrefix + "✅ Range signal CONFIRMED - proceeding with trade setup");
    
    // Get range boundaries from key levels
    SKeyLevel resistanceLevel, supportLevel;
    if(!GetRangeBoundaries(resistanceLevel, supportLevel))
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ TRADE BLOCKED: Unable to identify range boundaries");
        return;
    }
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double midRange = (resistanceLevel.price + supportLevel.price) / 2.0;
    double rangeWidth = resistanceLevel.price - supportLevel.price;
    double stopDistancePips = rs.atr_current * 0.5 / _Point;
    double lot = 0.0;
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "Range Analysis:");
        Print(logPrefix + "  Resistance Level: ", DoubleToString(resistanceLevel.price, _Digits));
        Print(logPrefix + "  Support Level: ", DoubleToString(supportLevel.price, _Digits));
        Print(logPrefix + "  Range Width: ", DoubleToString(rangeWidth, _Digits), " (", DoubleToString(rangeWidth / _Point, 1), " pips)");
        Print(logPrefix + "  Mid Range: ", DoubleToString(midRange, _Digits));
        Print(logPrefix + "  Current Price: ", DoubleToString(currentPrice, _Digits));
        Print(logPrefix + "  Position in Range: ", DoubleToString((currentPrice - supportLevel.price) / rangeWidth * 100, 1), "%");
    }
    
    // Calculate position size using risk manager
    if(g_riskManager != NULL)
    {
        lot = g_riskManager.CalculateLotSize(stopDistancePips, rs.regime);
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "Risk Calculation:");
            Print(logPrefix + "  Stop Distance: ", DoubleToString(stopDistancePips, 1), " pips (0.5 × ATR)");
            Print(logPrefix + "  Lot Size (Risk Manager): ", DoubleToString(lot, 2));
        }
    }
    else
    {
        lot = CalcLot(rs.regime); // Fallback to old method
        if(InpLogDetailedInfo)
            Print(logPrefix + "  Lot Size (Fallback): ", DoubleToString(lot, 2));
    }
    
    if(lot <= 0) 
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ TRADE BLOCKED: Invalid lot size (", DoubleToString(lot, 2), ")");
        return;
    }
    
    // Fade touches of top/bottom 80% of range
    if(currentPrice >= resistanceLevel.price * 0.998) // Near resistance
    {
        double sl = 0.0, tp = 0.0;
        
        if(g_riskManager != NULL)
        {
            sl = g_riskManager.CalculateStopLoss(false, currentPrice, rs.atr_current * 0.5);
            tp = midRange;
        }
        else
        {
            sl = resistanceLevel.price + rs.atr_current * 0.5;
            tp = midRange;
        }
        
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "🔻 FADE RESISTANCE SETUP:");
            Print(logPrefix + "  Trade Type: SELL at resistance");
            Print(logPrefix + "  Entry Price: ", DoubleToString(currentPrice, _Digits));
            Print(logPrefix + "  Stop Loss: ", DoubleToString(sl, _Digits), " (", DoubleToString(MathAbs(currentPrice - sl) / _Point, 1), " pips)");
            Print(logPrefix + "  Take Profit: ", DoubleToString(tp, _Digits), " (", DoubleToString(MathAbs(tp - currentPrice) / _Point, 1), " pips)");
            Print(logPrefix + "  Target: Mid-range (", DoubleToString(midRange, _Digits), ")");
            Print(logPrefix + "  Position Size: ", DoubleToString(lot, 2), " lots");
            Print(logPrefix + "→ EXECUTING RANGE SELL...");
        }
        
        // CRITICAL: Validate margin before executing trade
        if(!ValidateMarginBeforeTrade(ORDER_TYPE_SELL, lot, SymbolInfoDouble(_Symbol, SYMBOL_BID), "RANGE-SELL"))
        {
            // Publish risk warning event
            PublishRiskEvent(EVENT_MARGIN_WARNING, "Insufficient margin for RANGE-SELL trade", lot);
            return;
        }
        
        bool tradeResult = g_trade.Sell(lot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), sl, tp, StringFormat("%s Range-Sell", InpOrderTag));
        // Always-on concise outcome
        Print(StringFormat("[RANGE] %s SELL @%s SL=%s TP=%s lot=%.2f rr=%.2f",
                           (tradeResult?"FILLED":"FAILED"),
                           DoubleToString(currentPrice, _Digits),
                           DoubleToString(sl, _Digits),
                           DoubleToString(tp, _Digits),
                           lot,
                           (MathAbs(tp-currentPrice)/MathMax(1e-10, MathAbs(currentPrice-sl)))));
        
        if(InpLogDetailedInfo)
        {
            if(tradeResult)
            {
                Print(logPrefix + "🎯 RANGE SELL EXECUTED SUCCESSFULLY!");
                Print(logPrefix + "  Ticket: ", g_trade.ResultOrder());
                Print(logPrefix + "  Execution Price: ", DoubleToString(g_trade.ResultPrice(), _Digits));
            }
            else
            {
                Print(logPrefix + "❌ RANGE SELL EXECUTION FAILED!");
                Print(logPrefix + "  Error Code: ", g_trade.ResultRetcode());
                Print(logPrefix + "  Error Description: ", g_trade.ResultRetcodeDescription());
            }
        }
    }
    else if(currentPrice <= supportLevel.price * 1.002) // Near support
    {
        double sl = 0.0, tp = 0.0;
        
        if(g_riskManager != NULL)
        {
            sl = g_riskManager.CalculateStopLoss(true, currentPrice, rs.atr_current * 0.5);
            tp = midRange;
        }
        else
        {
            sl = supportLevel.price - rs.atr_current * 0.5;
            tp = midRange;
        }
        
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "🔺 FADE SUPPORT SETUP:");
            Print(logPrefix + "  Trade Type: BUY at support");
            Print(logPrefix + "  Entry Price: ", DoubleToString(currentPrice, _Digits));
            Print(logPrefix + "  Stop Loss: ", DoubleToString(sl, _Digits), " (", DoubleToString(MathAbs(currentPrice - sl) / _Point, 1), " pips)");
            Print(logPrefix + "  Take Profit: ", DoubleToString(tp, _Digits), " (", DoubleToString(MathAbs(tp - currentPrice) / _Point, 1), " pips)");
            Print(logPrefix + "  Target: Mid-range (", DoubleToString(midRange, _Digits), ")");
            Print(logPrefix + "  Position Size: ", DoubleToString(lot, 2), " lots");
            Print(logPrefix + "→ EXECUTING RANGE BUY...");
        }
        
        // CRITICAL: Validate margin before executing trade
        if(!ValidateMarginBeforeTrade(ORDER_TYPE_BUY, lot, SymbolInfoDouble(_Symbol, SYMBOL_ASK), "RANGE-BUY"))
        {
            // Publish risk warning event
            PublishRiskEvent(EVENT_MARGIN_WARNING, "Insufficient margin for RANGE-BUY trade", lot);
            return;
        }
        
        bool tradeResult = g_trade.Buy(lot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), sl, tp, StringFormat("%s Range-Buy", InpOrderTag));
        // Always-on concise outcome
        Print(StringFormat("[RANGE] %s BUY @%s SL=%s TP=%s lot=%.2f rr=%.2f",
                           (tradeResult?"FILLED":"FAILED"),
                           DoubleToString(currentPrice, _Digits),
                           DoubleToString(sl, _Digits),
                           DoubleToString(tp, _Digits),
                           lot,
                           (MathAbs(tp-currentPrice)/MathMax(1e-10, MathAbs(currentPrice-sl)))));
        
        if(tradeResult)
        {
            ulong orderTicket = g_trade.ResultOrder();
            double executionPrice = g_trade.ResultPrice();
            
            // Publish order and position events
            string orderDetails = StringFormat("MARKET BUY | Lot: %.2f | Entry: %s | SL: %s | TP: %s",
                                             lot, DoubleToString(currentPrice, _Digits),
                                             DoubleToString(sl, _Digits), DoubleToString(tp, _Digits));
            PublishOrderEvent(EVENT_ORDER_PLACED, orderTicket, orderDetails);
            PublishPositionEvent(EVENT_POSITION_OPENED, orderTicket, 
                               StringFormat("Range BUY | Entry: %s | SL: %s | TP: %s | Lot: %.2f",
                                          DoubleToString(executionPrice, _Digits),
                                          DoubleToString(sl, _Digits), DoubleToString(tp, _Digits), lot));
            
            if(InpLogDetailedInfo)
            {
                Print(logPrefix + "🎯 RANGE BUY EXECUTED SUCCESSFULLY!");
                Print(logPrefix + "  Ticket: ", orderTicket);
                Print(logPrefix + "  Execution Price: ", DoubleToString(executionPrice, _Digits));
            }
        }
        else
        {
            // Publish order failed event
            string errorMsg = StringFormat("Execution failed - Error %d: %s",
                                          g_trade.ResultRetcode(),
                                          g_trade.ResultRetcodeDescription());
            PublishOrderEvent(EVENT_ORDER_FAILED, 0, 
                            StringFormat("MARKET BUY | Lot: %.2f | Error: %s", lot, errorMsg));
            
            if(InpLogDetailedInfo)
            {
                Print(logPrefix + "❌ RANGE BUY EXECUTION FAILED!");
                Print(logPrefix + "  Error Code: ", g_trade.ResultRetcode());
                Print(logPrefix + "  Error Description: ", g_trade.ResultRetcodeDescription());
            }
        }
    }
    else
    {
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "ℹ️ Price not at range boundaries - waiting for better entry");
            Print(logPrefix + "  Current price is ", DoubleToString((currentPrice - supportLevel.price) / rangeWidth * 100, 1), "% through the range");
            Print(logPrefix + "  Need price near resistance (>99.8%) or support (<0.2%) for entry");
        }
    }
}

//+------------------------------------------------------------------+
//| Signal functions - Pure logic only                              |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Validate Trend Trading Signal                                    |
//+------------------------------------------------------------------+
// PURPOSE:
//   Validates whether a trend trading signal meets all technical criteria
//   for entry. Performs comprehensive multi-timeframe analysis.
//
// BEHAVIOR:
//   1. Checks Trend Follower confirmation (if enabled)
//   2. Validates EMA alignment across H1 and H4 (if required)
//   3. Checks RSI conditions on current, H4, and D1 timeframes
//   4. Validates candle structure and price position
//   5. Performs technical entry validation
//   6. Records decision in database
//
// PARAMETERS:
//   bullish (bool) - Signal direction: true for buy, false for sell
//   rs (RegimeSnapshot) - Current market regime snapshot with ADX, ATR values
//
// RETURNS:
//   (bool) - true if signal passes all validation criteria, false otherwise
//
// SIDE EFFECTS:
//   - Records trade decision in database via IntelligentReporter
//   - Updates g_lastRejectionReason in State Manager if signal rejected
//   - Logs detailed validation steps if InpLogDetailedInfo is enabled
//
// ERROR CONDITIONS:
//   - Trend Follower rejects signal: Returns false, records rejection reason
//   - EMA alignment fails: Returns false (if InpRequireEmaAlignment is true)
//   - RSI overbought/oversold: Returns false (if InpEnableMTFRSI is true)
//   - Candle structure invalid: Returns false
//   - Price position invalid: Returns false
//   - Technical validation fails: Returns false
//
// PRECONDITIONS:
//   - Regime must be REGIME_TREND_BULL or REGIME_TREND_BEAR
//   - Indicators must be initialized and data available
//   - State Manager must be accessible
//
// POSTCONDITIONS:
//   - Decision recorded in database (if reporter available)
//   - Rejection reason stored in State Manager (if rejected)
//
// NOTES:
//   - Pure signal validation logic - does not place orders
//   - Respects InpEnableTrendFollower, InpRequireEmaAlignment, InpEnableMTFRSI flags
//   - Uses multi-timeframe RSI filtering to avoid extreme conditions
//   - Validates candle structure to avoid poor entry conditions
//
// RELATED:
//   - See Also: Signal_BREAKOUT(), Signal_RANGE()
//   - Called By: TrendTrade()
//   - Calls: ValidateCandleStructure(), ValidatePricePosition(), ValidateTechnicalEntry()
//+------------------------------------------------------------------+
bool Signal_TREND(bool bullish, const RegimeSnapshot &rs)
{
    string logPrefix = "[SIGNAL ANALYSIS] ";
    string direction = bullish ? "BULLISH" : "BEARISH";
    string signal_type = bullish ? "TREND_BULL" : "TREND_BEAR";
    string rejection_reason = "";
    
    // Prepare tracking data
    STradeDecision decision;
    decision.timestamp = TimeCurrent();
    decision.signal_type = signal_type;
    decision.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    decision.atr = rs.atr_current;
    decision.adx_h1 = rs.adx_h1;
    decision.adx_h4 = rs.adx_h4;
    decision.adx_d1 = rs.adx_d1;
    decision.regime = g_regimeDetector.RegimeToString(rs.regime);
    decision.regime_confidence = rs.confidence;
    decision.account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    decision.open_positions = PositionsTotal();
    
    // FIX: Initialize remaining fields to prevent uninitialized memory values
    decision.decision = "";
    decision.rejection_reason = "";
    decision.volume_ratio = 0.0;
    decision.risk_percent = 0.0;
    decision.calculated_lot = 0.0;
    decision.risk_check_passed = false;
    decision.drawdown_check_passed = false;
    decision.nearest_resistance = 0.0;
    decision.nearest_support = 0.0;
    decision.key_levels_count = g_keyLevelDetector != NULL ? g_keyLevelDetector.GetKeyLevelCount() : 0;
    decision.calendar_signal = "";
    decision.calendar_confidence = 0.0;
    decision.additional_notes = "";
    
    // Initialize RSI values - always populate them even if not used for rejection
    decision.rsi_current = GetRSIValue(_Symbol, PERIOD_CURRENT, InpRSIPeriod, 0);
    if(decision.rsi_current < 0) decision.rsi_current = 0.0;
    
    decision.rsi_h4 = GetRSIValue(_Symbol, PERIOD_H4, InpTFRsiPeriod, 0);
    if(decision.rsi_h4 < 0) decision.rsi_h4 = 0.0;
    
    decision.rsi_d1 = GetRSIValue(_Symbol, PERIOD_D1, InpTFRsiPeriod, 0);
    if(decision.rsi_d1 < 0) decision.rsi_d1 = 0.0;
    
    if(InpLogDetailedInfo)
        Print(logPrefix + "Evaluating ", direction, " trend signal criteria...");
    
    // === ADVANCED TREND FOLLOWER CONFIRMATION ===
    // Modified: Allow trades when trend is strong even if Trend Follower disagrees
    bool trendFollowerPass = true;
    if(g_trendFollower != NULL && InpEnableTrendFollower)
    {
        bool trendFollowerSignal = bullish ? g_trendFollower.IsBullish() : g_trendFollower.IsBearish();
        double tfStrength = g_trendFollower.TrendStrength();
        
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "1. Trend Follower Analysis:");
            Print(logPrefix + "  Multi-timeframe signal: ", trendFollowerSignal ? "✅ CONFIRMED" : "⚠️ NOT ALIGNED");
            Print(logPrefix + "  TF Strength: ", DoubleToString(tfStrength, 2));
            Print(logPrefix + "  TF Pullback Price (EMA20): ", DoubleToString(g_trendFollower.EntryPricePullback(), _Digits));
        }
        
        // NEW LOGIC: Only reject if Trend Follower strongly disagrees AND local ADX is weak
        if(!trendFollowerSignal)
        {
            // Allow override if current timeframe shows strong trend (ADX > 35)
            if(rs.adx_h4 > 35.0 || rs.adx_h1 > 40.0)
            {
                if(InpLogDetailedInfo)
                    Print(logPrefix + "⚠️ Trend Follower disagrees but local ADX is strong (H4: ", 
                          DoubleToString(rs.adx_h4, 1), " H1: ", DoubleToString(rs.adx_h1, 1), 
                          ") - ALLOWING SIGNAL");
                trendFollowerPass = true; // Override rejection
            }
            else
            {
                if(InpLogDetailedInfo)
                    Print(logPrefix + "❌ SIGNAL BLOCKED: Trend Follower rejected ", direction, 
                          " signal and local ADX is weak");
                
                rejection_reason = "Trend Follower multi-timeframe analysis rejected signal (weak local trend)";
                decision.decision = "REJECTED";
                decision.rejection_reason = rejection_reason;
                if(g_reporter != NULL) g_reporter.RecordDecision(decision);
                return false;
            }
        }
    }
    else if(InpLogDetailedInfo)
    {
        Print(logPrefix + "1. Trend Follower: DISABLED (proceeding with original logic)");
    }
    
    // === MULTI-TIMEFRAME CONSENSUS CHECK ===
    // Temporarily disabled for immediate RSI fix
    // TODO: Re-enable after fixing compilation errors
    
    // === ORIGINAL GRANDE EMA ALIGNMENT LOGIC ===
    // 50 & 200 EMA alignment across H1 + H4 (NOW OPTIONAL - controlled by InpRequireEmaAlignment)
    if(InpRequireEmaAlignment)
    {
        int ema50_h1_handle = iMA(_Symbol, PERIOD_H1, InpEMA50Period, 0, MODE_EMA, PRICE_CLOSE);
        int ema200_h1_handle = iMA(_Symbol, PERIOD_H1, InpEMA200Period, 0, MODE_EMA, PRICE_CLOSE);
        int ema50_h4_handle = iMA(_Symbol, PERIOD_H4, InpEMA50Period, 0, MODE_EMA, PRICE_CLOSE);
        int ema200_h4_handle = iMA(_Symbol, PERIOD_H4, InpEMA200Period, 0, MODE_EMA, PRICE_CLOSE);
        
        double ema50_h1 = 0, ema200_h1 = 0, ema50_h4 = 0, ema200_h4 = 0;
    
    if(ema50_h1_handle != INVALID_HANDLE)
    {
        double ema50_h1_buffer[];
        ArraySetAsSeries(ema50_h1_buffer, true);
        int copied = CopyBuffer(ema50_h1_handle, 0, 0, 1, ema50_h1_buffer);
        if(copied > 0)
        {
            ema50_h1 = ema50_h1_buffer[0];
        }
        else
        {
            Print("[Grande] WARNING: Failed to copy EMA50-H1 data. Error: ", GetLastError());
            IndicatorRelease(ema50_h1_handle);
            return false; // Exit early if critical data fails
        }
        IndicatorRelease(ema50_h1_handle);
    }
    else
    {
        Print("[Grande] ERROR: Invalid EMA50-H1 handle");
        return false;
    }
    
    if(ema200_h1_handle != INVALID_HANDLE)
    {
        double ema200_h1_buffer[];
        ArraySetAsSeries(ema200_h1_buffer, true);
        int copied = CopyBuffer(ema200_h1_handle, 0, 0, 1, ema200_h1_buffer);
        if(copied > 0)
        {
            ema200_h1 = ema200_h1_buffer[0];
        }
        else
        {
            Print("[Grande] WARNING: Failed to copy EMA200-H1 data. Error: ", GetLastError());
            IndicatorRelease(ema200_h1_handle);
            return false; // Exit early if critical data fails
        }
        IndicatorRelease(ema200_h1_handle);
    }
    else
    {
        Print("[Grande] ERROR: Invalid EMA200-H1 handle");
        return false;
    }
    
    if(ema50_h4_handle != INVALID_HANDLE)
    {
        double ema50_h4_buffer[];
        ArraySetAsSeries(ema50_h4_buffer, true);
        int copied = CopyBuffer(ema50_h4_handle, 0, 0, 1, ema50_h4_buffer);
        if(copied > 0)
        {
            ema50_h4 = ema50_h4_buffer[0];
        }
        else
        {
            Print("[Grande] WARNING: Failed to copy EMA50-H4 data. Error: ", GetLastError());
            IndicatorRelease(ema50_h4_handle);
            return false; // Exit early if critical data fails
        }
        IndicatorRelease(ema50_h4_handle);
    }
    else
    {
        Print("[Grande] ERROR: Invalid EMA50-H4 handle");
        return false;
    }
    
    if(ema200_h4_handle != INVALID_HANDLE)
    {
        double ema200_h4_buffer[];
        ArraySetAsSeries(ema200_h4_buffer, true);
        int copied = CopyBuffer(ema200_h4_handle, 0, 0, 1, ema200_h4_buffer);
        if(copied > 0)
        {
            ema200_h4 = ema200_h4_buffer[0];
        }
        else
        {
            Print("[Grande] WARNING: Failed to copy EMA200-H4 data. Error: ", GetLastError());
            IndicatorRelease(ema200_h4_handle);
            return false; // Exit early if critical data fails
        }
        IndicatorRelease(ema200_h4_handle);
    }
    else
    {
        Print("[Grande] ERROR: Invalid EMA200-H4 handle");
        return false;
    }
    
    bool emaAlignment = bullish ? 
                       (ema50_h1 > ema200_h1 && ema50_h4 > ema200_h4) :
                       (ema50_h1 < ema200_h1 && ema50_h4 < ema200_h4);
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "2. EMA Alignment Analysis:");
        Print(logPrefix + "  H1 EMA50: ", DoubleToString(ema50_h1, _Digits));
        Print(logPrefix + "  H1 EMA200: ", DoubleToString(ema200_h1, _Digits));
        Print(logPrefix + "  H4 EMA50: ", DoubleToString(ema50_h4, _Digits));
        Print(logPrefix + "  H4 EMA200: ", DoubleToString(ema200_h4, _Digits));
        Print(logPrefix + "  H1 Alignment: ", (bullish ? ema50_h1 > ema200_h1 : ema50_h1 < ema200_h1) ? "✅" : "❌");
        Print(logPrefix + "  H4 Alignment: ", (bullish ? ema50_h4 > ema200_h4 : ema50_h4 < ema200_h4) ? "✅" : "❌");
        Print(logPrefix + "  Overall EMA Alignment: ", emaAlignment ? "✅ CONFIRMED" : "❌ REJECTED");
    }
    
    if(!emaAlignment) 
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ SIGNAL BLOCKED: EMA alignment not suitable for ", direction, " trend");
        
        rejection_reason = StringFormat("EMA alignment failed - H1: EMA50 %s EMA200, H4: EMA50 %s EMA200",
                                       (ema50_h1 > ema200_h1 ? ">" : "<"),
                                       (ema50_h4 > ema200_h4 ? ">" : "<"));
        decision.decision = "REJECTED";
        decision.rejection_reason = rejection_reason;
        if(g_reporter != NULL) g_reporter.RecordDecision(decision);
        return false;
    }
    }  // End of InpRequireEmaAlignment check
    else if(InpLogDetailedInfo)
    {
        Print(logPrefix + "2. EMA Alignment Check: SKIPPED (disabled by InpRequireEmaAlignment=false)");
    }
    
    // Price pull-back ≤ 1 × ATR(14) to 20 EMA
    int ema20_handle = iMA(_Symbol, PERIOD_CURRENT, InpEMA20Period, 0, MODE_EMA, PRICE_CLOSE);
    double ema20 = 0;
    
    if(ema20_handle != INVALID_HANDLE)
    {
        double ema20_buffer[];
        ArraySetAsSeries(ema20_buffer, true);
        int copied = CopyBuffer(ema20_handle, 0, 0, 1, ema20_buffer);
        if(copied > 0)
        {
            ema20 = ema20_buffer[0];
        }
        else
        {
            Print("[Grande] WARNING: Failed to copy EMA20 data. Error: ", GetLastError());
            IndicatorRelease(ema20_handle);
            return false; // Exit early if critical data fails
        }
        IndicatorRelease(ema20_handle);
    }
    else
    {
        Print("[Grande] ERROR: Invalid EMA20 handle");
        return false;
    }
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double pullbackDistance = MathAbs(currentPrice - ema20);
    
    // *** FINBERT-BASED DYNAMIC PULLBACK ADJUSTMENT ***
    double pullbackMultiplier = 3.5; // Increased from 2.0 to 3.5 for better market adaptation (was too strict)
    string finbert_signal = "";
    double finbert_confidence = 0.0;
    
    if(InpEnableCalendarAI)
    {
        finbert_signal = g_newsSentiment.GetCalendarSignal();
        finbert_confidence = g_newsSentiment.GetCalendarConfidence();
        
        if(StringLen(finbert_signal) > 0 && finbert_confidence >= 0.4)
        {
            bool sentiment_bullish = (finbert_signal == "STRONG_BUY" || finbert_signal == "BUY");
            bool sentiment_bearish = (finbert_signal == "STRONG_SELL" || finbert_signal == "SELL");
            
            // If FinBERT sentiment supports the trade direction, allow more pullback
            if((bullish && sentiment_bullish) || (!bullish && sentiment_bearish))
            {
                if(finbert_confidence >= 0.7)
                    pullbackMultiplier = 4.5; // Allow 4.5x ATR for high confidence supporting sentiment (increased from 3.0)
                else if(finbert_confidence >= 0.5)
                    pullbackMultiplier = 4.0; // Allow 4.0x ATR for medium confidence (increased from 2.5)
                
                if(InpLogDetailedInfo)
                    Print(logPrefix + "📊 FinBERT supports trade direction - pullback tolerance increased to ", DoubleToString(pullbackMultiplier, 1), "x ATR");
            }
            // If sentiment opposes but with low confidence, slightly relax
            else if(finbert_confidence < 0.6)
            {
                pullbackMultiplier = 3.0; // Slight relaxation for low confidence opposition (increased from 2.2)
                if(InpLogDetailedInfo)
                    Print(logPrefix + "📊 FinBERT low confidence - slight pullback tolerance increase to ", DoubleToString(pullbackMultiplier, 1), "x ATR");
            }
        }
    }
    
    double adjustedATRLimit = rs.atr_current * pullbackMultiplier;
    bool pullbackValid = (pullbackDistance <= adjustedATRLimit);
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "3. Pullback Analysis:");
        Print(logPrefix + "  Current Price: ", DoubleToString(currentPrice, _Digits));
        Print(logPrefix + "  EMA20: ", DoubleToString(ema20, _Digits));
        Print(logPrefix + "  Distance to EMA20: ", DoubleToString(pullbackDistance, _Digits), " (", DoubleToString(pullbackDistance / _Point, 1), " pips)");
        Print(logPrefix + "  Base ATR Limit: ", DoubleToString(rs.atr_current, _Digits), " (", DoubleToString(rs.atr_current / _Point, 1), " pips)");
        Print(logPrefix + "  Adjusted ATR Limit: ", DoubleToString(adjustedATRLimit, _Digits), " (", DoubleToString(adjustedATRLimit / _Point, 1), " pips)");
        Print(logPrefix + "  FinBERT Multiplier: ", DoubleToString(pullbackMultiplier, 1), "x");
        Print(logPrefix + "  Pullback Valid: ", pullbackValid ? "✅ WITHIN LIMIT" : "❌ TOO FAR");
    }
    
    if(!pullbackValid)
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ SIGNAL BLOCKED: Price too far from EMA20 (pullback > ", DoubleToString(pullbackMultiplier, 1), "×ATR)");
        
        rejection_reason = StringFormat("Pullback too far - Distance: %.1f pips, Limit: %.1f pips (%.1fx ATR%s)",
                                       pullbackDistance / _Point,
                                       adjustedATRLimit / _Point,
                                       pullbackMultiplier,
                                       (pullbackMultiplier > 1.0 ? " FinBERT-adjusted" : ""));
        decision.decision = "REJECTED";
        decision.rejection_reason = rejection_reason;
        if(g_reporter != NULL) g_reporter.RecordDecision(decision);
        return false;
    }
    
    // Higher-timeframe RSI exhaustion gate - ENHANCED with regime awareness
    // Declare RSI thresholds at function scope for logging
    double rsi_overbought_threshold = InpH4RSIOverbought;  // Default 68.0
    double rsi_oversold_threshold = InpH4RSIOversold;      // Default 32.0
    
    if(InpEnableMTFRSI)
    {
        // Use cached values if available
        double cachedRsiH4 = (g_stateManager != NULL) ? g_stateManager.GetCachedRsiH4() : EMPTY_VALUE;
        double rsi_h4 = (cachedRsiH4 != EMPTY_VALUE ? cachedRsiH4 : GetRSIValue(_Symbol, PERIOD_H4, InpTFRsiPeriod, 0));
        if(rsi_h4 < 0) return false;

        // === REGIME-AWARE RSI THRESHOLDS ===
        // In strong trends (ADX > 30), allow higher RSI extremes
        
        // Adjust thresholds based on trend strength and regime
        if(rs.adx_h4 > 30.0)  // Strong trend
        {
            rsi_overbought_threshold = 80.0;  // Allow up to 80 in strong trends
            rsi_oversold_threshold = 20.0;    // Allow down to 20 in strong trends
            
            if(InpLogDetailedInfo)
                Print(logPrefix + "🔧 RSI thresholds adjusted for strong trend (ADX: ", DoubleToString(rs.adx_h4, 1), ")");
        }
        else if(rs.regime == REGIME_BREAKOUT_SETUP)  // Breakout setup
        {
            rsi_overbought_threshold = 75.0;  // Slightly higher for breakouts
            rsi_oversold_threshold = 25.0;
            
            if(InpLogDetailedInfo)
                Print(logPrefix + "🔧 RSI thresholds adjusted for breakout setup");
        }
        else if(rs.regime == REGIME_RANGING)  // Ranging market
        {
            rsi_overbought_threshold = 65.0;  // Stricter for ranging
            rsi_oversold_threshold = 35.0;
            
            if(InpLogDetailedInfo)
                Print(logPrefix + "🔧 RSI thresholds adjusted for ranging market");
        }

        if(bullish && rsi_h4 >= rsi_overbought_threshold)
        {
            if(InpLogDetailedInfo) 
                Print(logPrefix + "❌ SIGNAL BLOCKED: H4 RSI overbought (", DoubleToString(rsi_h4, 2), " > ", DoubleToString(rsi_overbought_threshold, 1), ")");
            
            rejection_reason = StringFormat("H4 RSI overbought - %.1f (threshold %.1f, regime: %s)", rsi_h4, rsi_overbought_threshold, g_regimeDetector.RegimeToString(rs.regime));
            decision.decision = "REJECTED";
            decision.rejection_reason = rejection_reason;
            decision.rsi_h4 = rsi_h4;
            if(g_reporter != NULL) g_reporter.RecordDecision(decision);
            return false;
        }
        if(!bullish && rsi_h4 <= rsi_oversold_threshold)
        {
            if(InpLogDetailedInfo) 
                Print(logPrefix + "❌ SIGNAL BLOCKED: H4 RSI oversold (", DoubleToString(rsi_h4, 2), " < ", DoubleToString(rsi_oversold_threshold, 1), ")");
            
            rejection_reason = StringFormat("H4 RSI oversold - %.1f (threshold %.1f, regime: %s)", rsi_h4, rsi_oversold_threshold, g_regimeDetector.RegimeToString(rs.regime));
            decision.decision = "REJECTED";
            decision.rejection_reason = rejection_reason;
            decision.rsi_h4 = rsi_h4;
            if(g_reporter != NULL) g_reporter.RecordDecision(decision);
            return false;
        }

        // Declare D1 RSI thresholds at function scope for logging
        double d1_rsi_overbought_threshold = InpD1RSIOverbought;  // Default 70.0
        double d1_rsi_oversold_threshold = InpD1RSIOversold;      // Default 30.0
        
        if(InpUseD1RSI)
        {
            double rsi_d1 = EMPTY_VALUE;
            if(g_stateManager != NULL)
                rsi_d1 = g_stateManager.GetCachedRsiD1();
            if(rsi_d1 == EMPTY_VALUE)
                rsi_d1 = GetRSIValue(_Symbol, PERIOD_D1, InpTFRsiPeriod, 0);
            if(rsi_d1 < 0) return false;

            // Apply same regime-aware logic to D1 RSI
            if(rs.adx_d1 > 25.0)  // Strong daily trend
            {
                d1_rsi_overbought_threshold = 85.0;  // Allow higher extremes on D1
                d1_rsi_oversold_threshold = 15.0;
            }

            if(bullish && rsi_d1 >= d1_rsi_overbought_threshold)
            {
                if(InpLogDetailedInfo) 
                    Print(logPrefix + "❌ SIGNAL BLOCKED: D1 RSI overbought (", DoubleToString(rsi_d1, 2), " > ", DoubleToString(d1_rsi_overbought_threshold, 1), ")");
                return false;
            }
            if(!bullish && rsi_d1 <= d1_rsi_oversold_threshold)
            {
                if(InpLogDetailedInfo) 
                    Print(logPrefix + "❌ SIGNAL BLOCKED: D1 RSI oversold (", DoubleToString(rsi_d1, 2), " < ", DoubleToString(d1_rsi_oversold_threshold, 1), ")");
                return false;
            }
        }
        
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "5. Multi-Timeframe RSI Analysis (Regime-Aware):");
            Print(logPrefix + "  H4 RSI: ", DoubleToString(rsi_h4, 2), " (", 
                  (bullish ? (rsi_h4 < rsi_overbought_threshold ? "✅ NOT OVERBOUGHT" : "❌ OVERBOUGHT") :
                            (rsi_h4 > rsi_oversold_threshold ? "✅ NOT OVERSOLD" : "❌ OVERSOLD")), ")");
            Print(logPrefix + "  H4 Thresholds: OB=", DoubleToString(rsi_overbought_threshold, 1), " OS=", DoubleToString(rsi_oversold_threshold, 1));
            if(InpUseD1RSI)
            {
                double rsi_d1 = EMPTY_VALUE;
            if(g_stateManager != NULL)
                rsi_d1 = g_stateManager.GetCachedRsiD1();
            if(rsi_d1 == EMPTY_VALUE)
                rsi_d1 = GetRSIValue(_Symbol, PERIOD_D1, InpTFRsiPeriod, 0);
                Print(logPrefix + "  D1 RSI: ", DoubleToString(rsi_d1, 2), " (", 
                      (bullish ? (rsi_d1 < d1_rsi_overbought_threshold ? "✅ NOT OVERBOUGHT" : "❌ OVERBOUGHT") :
                                (rsi_d1 > d1_rsi_oversold_threshold ? "✅ NOT OVERSOLD" : "❌ OVERSOLD")), ")");
                Print(logPrefix + "  D1 Thresholds: OB=", DoubleToString(d1_rsi_overbought_threshold, 1), " OS=", DoubleToString(d1_rsi_oversold_threshold, 1));
            }
        }
    }
    
    // RSI momentum validation - adjusted for trend trading
    int rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
    double rsi = 0, rsi_prev = 0;
    
    if(rsi_handle != INVALID_HANDLE)
    {
        double rsi_buffer[];
        ArraySetAsSeries(rsi_buffer, true);
        int copied = CopyBuffer(rsi_handle, 0, 0, 2, rsi_buffer);
        if(copied > 1)
        {
            rsi = rsi_buffer[0];
            rsi_prev = rsi_buffer[1];
        }
        else
        {
            Print("[Grande] WARNING: Failed to copy RSI data. Error: ", GetLastError());
            IndicatorRelease(rsi_handle);
            return false; // Exit early if critical data fails
        }
        IndicatorRelease(rsi_handle);
    }
    else
    {
        Print("[Grande] ERROR: Invalid RSI handle");
        return false;
    }
    
    // FIX: Improved RSI logic for trend trading - more flexible for trending markets
    // For BULLISH (long): Avoid extreme overbought (RSI > 80) 
    // For BEARISH (short): Avoid extreme oversold (RSI < 20)
    // Allow trading in trending conditions where RSI can be rising or falling
    bool rsiCondition = false;
    if(bullish)
    {
        // For longs: RSI not extreme overbought (allow both rising and falling)
        rsiCondition = (rsi < 80);
        // Optional: Also avoid extreme oversold for longs
        if(rsi < 25) rsiCondition = false; // Don't catch falling knives
    }
    else // bearish
    {
        // For shorts: RSI not extreme oversold (allow both rising and falling)
        rsiCondition = (rsi > 20);
        // Optional: Also avoid extreme overbought for shorts
        if(rsi > 75) rsiCondition = false; // Don't short at exhaustion tops
    }
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "4. RSI Momentum Analysis:");
        Print(logPrefix + "  RSI Current: ", DoubleToString(rsi, 2));
        Print(logPrefix + "  RSI Previous: ", DoubleToString(rsi_prev, 2));
        
        // Show appropriate range based on direction
        if(bullish)
        {
            Print(logPrefix + "  RSI Valid Range: < 80 (not extreme overbought)");
            Print(logPrefix + "  RSI in Valid Range: ", (rsi < 80 && rsi > 25) ? "✅" : "❌");
        }
        else // bearish
        {
            Print(logPrefix + "  RSI Valid Range: > 20 (not extreme oversold)");
            Print(logPrefix + "  RSI in Valid Range: ", (rsi > 20 && rsi < 75) ? "✅" : "❌");
        }
        
        Print(logPrefix + "  RSI Direction: ", bullish ? (rsi > rsi_prev ? "✅ RISING" : "❌ FALLING") : 
                                                        (rsi < rsi_prev ? "✅ FALLING" : "❌ RISING"));
        Print(logPrefix + "  RSI Condition: ", rsiCondition ? "✅ CONFIRMED" : "❌ REJECTED");
    }
    
    if(!rsiCondition)
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ SIGNAL BLOCKED: RSI momentum not aligned with ", direction, " trend");
        
        // Updated rejection message to reflect new logic
        string rsiRejectionDetail = "";
        if(bullish)
        {
            if(rsi >= 80) rsiRejectionDetail = "RSI too high (>=80)";
            else if(rsi < 25) rsiRejectionDetail = "RSI too low (<25)";
            else rsiRejectionDetail = "RSI not rising";
        }
        else // bearish
        {
            if(rsi <= 20) rsiRejectionDetail = "RSI too low (<=20)";
            else if(rsi > 75) rsiRejectionDetail = "RSI too high (>75)";
            else rsiRejectionDetail = "RSI not falling";
        }
        
        rejection_reason = StringFormat("RSI conditions failed - Current: %.1f (%s)",
                                       rsi, rsiRejectionDetail);
        decision.decision = "REJECTED";
        decision.rejection_reason = rejection_reason;
        decision.rsi_current = rsi;
        if(g_reporter != NULL) g_reporter.RecordDecision(decision);
        return false;
    }
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "🎯 ALL CRITERIA PASSED - ", direction, " TREND SIGNAL CONFIRMED!");
        Print(logPrefix + "  ✅ Trend Follower (if enabled)");
        Print(logPrefix + "  ✅ EMA Alignment (H1 & H4)");
        Print(logPrefix + "  ✅ Price Pullback (≤ 2×ATR from EMA20)");
        if(InpEnableMTFRSI)
            Print(logPrefix + "  ✅ Multi-TF RSI (H4/D1 not exhausted)");
        
        // Updated success message with new RSI logic
        if(bullish)
            Print(logPrefix + "  ✅ RSI Momentum (not overbought & rising)");
        else
            Print(logPrefix + "  ✅ RSI Momentum (not oversold & falling)");
    }
    
    // Track successful signal
    decision.decision = "PASSED";
    decision.rejection_reason = "";
    decision.rsi_current = rsi;
    if(g_reporter != NULL) g_reporter.RecordDecision(decision);
    
    return true;
}

//+------------------------------------------------------------------+
//| Breakout signal function                                         |
//+------------------------------------------------------------------+
bool Signal_BREAKOUT(const RegimeSnapshot &rs)
{
    string logPrefix = "[BREAKOUT CRITERIA] ";
    
    // Prepare tracking data
    STradeDecision decision;
    decision.timestamp = TimeCurrent();
    decision.signal_type = "BREAKOUT";
    decision.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    decision.atr = rs.atr_current;
    decision.adx_h1 = rs.adx_h1;
    decision.adx_h4 = rs.adx_h4;
    decision.adx_d1 = rs.adx_d1;
    decision.regime = g_regimeDetector.RegimeToString(rs.regime);
    decision.regime_confidence = rs.confidence;
    decision.account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    decision.open_positions = PositionsTotal();
    
    // FIX: Initialize remaining fields to prevent uninitialized memory values
    decision.decision = "";
    decision.rejection_reason = "";
    decision.volume_ratio = 0.0;
    decision.risk_percent = 0.0;
    decision.calculated_lot = 0.0;
    decision.risk_check_passed = false;
    decision.drawdown_check_passed = false;
    decision.nearest_resistance = 0.0;
    decision.nearest_support = 0.0;
    decision.key_levels_count = g_keyLevelDetector != NULL ? g_keyLevelDetector.GetKeyLevelCount() : 0;
    decision.calendar_signal = "";
    decision.calendar_confidence = 0.0;
    decision.additional_notes = "";
    
    // Initialize RSI values - always populate them even if not used for rejection
    decision.rsi_current = GetRSIValue(_Symbol, PERIOD_CURRENT, InpRSIPeriod, 0);
    if(decision.rsi_current < 0) decision.rsi_current = 0.0;
    
    decision.rsi_h4 = GetRSIValue(_Symbol, PERIOD_H4, InpTFRsiPeriod, 0);
    if(decision.rsi_h4 < 0) decision.rsi_h4 = 0.0;
    
    decision.rsi_d1 = GetRSIValue(_Symbol, PERIOD_D1, InpTFRsiPeriod, 0);
    if(decision.rsi_d1 < 0) decision.rsi_d1 = 0.0;
    
    if(InpLogDetailedInfo)
        Print(logPrefix + "Evaluating breakout signal criteria...");
    
    // Inside-bar or NR7 formation at strong key level
    double high1 = SafeGetHigh(_Symbol, PERIOD_CURRENT, 1);
    double low1 = SafeGetLow(_Symbol, PERIOD_CURRENT, 1);
    double high2 = SafeGetHigh(_Symbol, PERIOD_CURRENT, 2);
    double low2 = SafeGetLow(_Symbol, PERIOD_CURRENT, 2);
    
    // Validate market data before proceeding
    if(high1 <= 0 || low1 <= 0 || high2 <= 0 || low2 <= 0)
    {
        Print("[Grande] ERROR: Invalid market data in breakout analysis");
        return false;
    }
    
    bool insideBar = (high1 <= high2 && low1 >= low2);
    bool nr7 = IsNR7();
    bool atrExpanding = IsATRExpanding(); // New momentum detection
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "1. Pattern Analysis:");
        Print(logPrefix + "  Previous Bar: H=", DoubleToString(high2, _Digits), " L=", DoubleToString(low2, _Digits), " Range=", DoubleToString((high2-low2)/_Point, 1), " pips");
        Print(logPrefix + "  Current Bar: H=", DoubleToString(high1, _Digits), " L=", DoubleToString(low1, _Digits), " Range=", DoubleToString((high1-low1)/_Point, 1), " pips");
        Print(logPrefix + "  Inside Bar: ", insideBar ? "✅ CONFIRMED" : "❌ NOT PRESENT");
        Print(logPrefix + "  NR7 Pattern: ", nr7 ? "✅ CONFIRMED" : "❌ NOT PRESENT");
        Print(logPrefix + "  ATR Expansion: ", atrExpanding ? "✅ MOMENTUM BUILDING" : "❌ NO MOMENTUM");
    }
    
    // Check for momentum surge (big candle detection)
    double currentCandle = MathAbs(SymbolInfoDouble(_Symbol, SYMBOL_BID) - iOpen(_Symbol, PERIOD_CURRENT, 0));
    double averageRange = rs.atr_current;
    bool momentumSurge = (currentCandle > averageRange * 1.5);  // Current candle is 1.5x ATR
    
    // Accept breakout if ANY of these conditions are met: Inside Bar, NR7, ATR Expansion, or Momentum Surge
    if(!insideBar && !nr7 && !atrExpanding && !momentumSurge) 
    {
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "❌ CRITERIA FAILED: No valid pattern detected");
            Print(StringFormat("[BREAKOUT] FAIL pattern (IB:%s NR7:%s ATRexp:%s Surge:%s)",
                               insideBar ? "Y" : "N",
                               nr7 ? "Y" : "N",
                               atrExpanding ? "Y" : "N",
                               momentumSurge ? "Y" : "N"));
        }
        
        decision.decision = "REJECTED";
        decision.rejection_reason = "No valid pattern (no inside bar, NR7, ATR expansion, or momentum surge)";
        if(g_reporter != NULL) g_reporter.RecordDecision(decision);
        return false;
    }
    
    // Log if momentum surge detected
    bool strongMomentumSurge = (currentCandle > averageRange * 3.0);  // Strong surge > 3x ATR
    if(momentumSurge)
    {
        Print(logPrefix + "🚀 MOMENTUM SURGE DETECTED! Current candle: ", 
              DoubleToString(currentCandle/_Point, 1), " pips (", 
              DoubleToString(currentCandle/averageRange, 2), "x ATR)");
        if(strongMomentumSurge)
            Print(logPrefix + "💥 STRONG SURGE (>3x ATR) - Will bypass some criteria!");
    }
    
    // Check if near strong key level (unless strong momentum surge)
    SKeyLevel strongestLevel;
    if(!strongMomentumSurge && !g_keyLevelDetector.GetStrongestLevel(strongestLevel))
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ CRITERIA FAILED: No strong key levels available");
        Print("[BREAKOUT] FAIL: no strong key levels");
        
        decision.decision = "REJECTED";
        decision.rejection_reason = "No strong key levels detected";
        if(g_reporter != NULL) g_reporter.RecordDecision(decision);
        return false;
    }
    else if(strongMomentumSurge && !g_keyLevelDetector.GetStrongestLevel(strongestLevel))
    {
        // For strong momentum surge, create a dummy level to continue processing
        strongestLevel.price = currentCandle > 0 ? 
            SymbolInfoDouble(_Symbol, SYMBOL_BID) + rs.atr_current : 
            SymbolInfoDouble(_Symbol, SYMBOL_BID) - rs.atr_current;
        strongestLevel.isResistance = currentCandle > 0;
        strongestLevel.strength = 1.0;
        if(InpLogDetailedInfo)
            Print(logPrefix + "💥 Strong momentum surge - bypassing key level requirement");
    }
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double distanceToLevel = MathAbs(currentPrice - strongestLevel.price);
    
    // Adaptive distance based on timeframe - longer timeframes need more room
    double atrMultiplier = 0.5;  // Default for lower timeframes
    if(Period() >= PERIOD_H1)
        atrMultiplier = 1.0;  // H1 needs more room (was causing 290+ pip rejections)
    if(Period() >= PERIOD_H4)
        atrMultiplier = 1.5;  // H4 needs even more room
    
    double maxDistance = rs.atr_current * atrMultiplier;
    bool nearKeyLevel = (distanceToLevel <= maxDistance);
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "2. Key Level Proximity:");
        Print(logPrefix + "  Strongest Level: ", DoubleToString(strongestLevel.price, _Digits), " (", strongestLevel.isResistance ? "RESISTANCE" : "SUPPORT", ")");
        Print(logPrefix + "  Level Strength: ", DoubleToString(strongestLevel.strength, 3));
        Print(logPrefix + "  Current Price: ", DoubleToString(currentPrice, _Digits));
        Print(logPrefix + "  Distance: ", DoubleToString(distanceToLevel, _Digits), " (", DoubleToString(distanceToLevel / _Point, 1), " pips)");
        Print(logPrefix + "  Max Allowed: ", DoubleToString(maxDistance, _Digits), " (", DoubleToString(maxDistance / _Point, 1), " pips)");
        Print(logPrefix + "  Near Key Level: ", nearKeyLevel ? "✅ WITHIN RANGE" : "❌ TOO FAR");
    }
    
    // Strong momentum surge bypasses key level proximity requirement
    if(!nearKeyLevel && !strongMomentumSurge)
    {
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "❌ CRITERIA FAILED: Price not close enough to key level (>0.5×ATR)");
            Print(StringFormat("[BREAKOUT] FAIL proximity dist=%sp max=%sp",
                               DoubleToString(distanceToLevel / _Point, 1),
                               DoubleToString(maxDistance / _Point, 1)));
        }
        
        decision.decision = "REJECTED";
        decision.rejection_reason = StringFormat("Price too far from key level - %.1f pips (max: %.1f pips)",
                                                distanceToLevel / _Point, maxDistance / _Point);
        decision.nearest_resistance = strongestLevel.isResistance ? strongestLevel.price : 0;
        decision.nearest_support = !strongestLevel.isResistance ? strongestLevel.price : 0;
        if(g_reporter != NULL) g_reporter.RecordDecision(decision);
        return false;
    }
    else if(!nearKeyLevel && strongMomentumSurge)
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "💥 Strong momentum surge - bypassing key level proximity check!");
    }
    
    // Volume spike ≥ 1.2 × 20-bar MA (relaxed for more opportunities)
    long volume = iTickVolume(_Symbol, PERIOD_CURRENT, 0);
    long avgVolume = GetAverageVolume(20);
    
    // FIX: Prevent division by negative or zero when volume data is unavailable
    if(avgVolume <= 0) 
    {
        avgVolume = 1; // Default to 1 to prevent division errors
        if(InpLogDetailedInfo)
            Print(logPrefix + "⚠️ Volume data unavailable, using default");
    }
    
    double volumeRatio = (double)volume / avgVolume;
    bool volumeSpike = (volume >= avgVolume * 1.2);  // Reduced from 1.5x to 1.2x
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "3. Volume Analysis:");
        Print(logPrefix + "  Current Volume: ", volume);
        Print(logPrefix + "  20-Bar Average: ", avgVolume);
        Print(logPrefix + "  Volume Ratio: ", DoubleToString(volumeRatio, 2), "x");
        Print(logPrefix + "  Volume Spike (≥1.2x): ", volumeSpike ? "✅ CONFIRMED" : "❌ INSUFFICIENT");
    }
    
    // Strong momentum surge can bypass volume requirement
    if(!volumeSpike && !strongMomentumSurge)
    {
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "❌ CRITERIA FAILED: Insufficient volume spike (need ≥1.2x average)");
            Print(StringFormat("[BREAKOUT] FAIL volume ratio=%sx need>=1.20x",
                               DoubleToString(volumeRatio, 2)));
        }
        
        decision.decision = "REJECTED";
        decision.rejection_reason = StringFormat("Insufficient volume - %.2fx (need >= 1.2x)", volumeRatio);
        decision.volume_ratio = volumeRatio;
        if(g_reporter != NULL) g_reporter.RecordDecision(decision);
        return false;
    }
    else if(!volumeSpike && strongMomentumSurge)
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "💥 Strong momentum surge - bypassing volume requirement!");
    }
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "🎯 ALL BREAKOUT CRITERIA PASSED!");
        Print(logPrefix + "  ✅ Pattern confirmed (Inside Bar, NR7, or ATR expansion)");
        Print(logPrefix + "  ✅ Near strong key level (≤0.5×ATR)");
        Print(logPrefix + "  ✅ Volume spike (≥1.2x average)");
    }
    // Always-on concise PASS summary
    Print(StringFormat("[BREAKOUT] PASS pattern(IB:%s NR7:%s ATR:%s) dist=%sp/%sp vol=%sx",
                       insideBar ? "Y" : "N",
                       nr7 ? "Y" : "N",
                       atrExpanding ? "Y" : "N",
                       DoubleToString(distanceToLevel / _Point, 1),
                       DoubleToString(maxDistance / _Point, 1),
                       DoubleToString(volumeRatio, 2)));
    
    // Track successful signal
    decision.decision = "PASSED";
    decision.rejection_reason = "";
    decision.volume_ratio = volumeRatio;
    decision.nearest_resistance = strongestLevel.isResistance ? strongestLevel.price : 0;
    decision.nearest_support = !strongestLevel.isResistance ? strongestLevel.price : 0;
    if(g_reporter != NULL) g_reporter.RecordDecision(decision);
    
    return true;
}

//+------------------------------------------------------------------+
//| Range signal function                                            |
//+------------------------------------------------------------------+
bool Signal_RANGE(const RegimeSnapshot &rs)
{
    string logPrefix = "[RANGE CRITERIA] ";
    
    // Prepare tracking data
    STradeDecision decision;
    decision.timestamp = TimeCurrent();
    decision.signal_type = "RANGE";
    decision.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    decision.atr = rs.atr_current;
    decision.adx_h1 = rs.adx_h1;
    decision.adx_h4 = rs.adx_h4;
    decision.adx_d1 = rs.adx_d1;
    decision.regime = g_regimeDetector.RegimeToString(rs.regime);
    decision.regime_confidence = rs.confidence;
    decision.account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    decision.open_positions = PositionsTotal();
    
    // FIX: Initialize remaining fields to prevent uninitialized memory values
    decision.decision = "";
    decision.rejection_reason = "";
    decision.volume_ratio = 0.0;
    decision.risk_percent = 0.0;
    decision.calculated_lot = 0.0;
    decision.risk_check_passed = false;
    decision.drawdown_check_passed = false;
    decision.nearest_resistance = 0.0;
    decision.nearest_support = 0.0;
    decision.key_levels_count = g_keyLevelDetector != NULL ? g_keyLevelDetector.GetKeyLevelCount() : 0;
    decision.calendar_signal = "";
    decision.calendar_confidence = 0.0;
    decision.additional_notes = "";
    
    // Initialize RSI values - always populate them even if not used for rejection
    decision.rsi_current = GetRSIValue(_Symbol, PERIOD_CURRENT, InpRSIPeriod, 0);
    if(decision.rsi_current < 0) decision.rsi_current = 0.0;
    
    decision.rsi_h4 = GetRSIValue(_Symbol, PERIOD_H4, InpTFRsiPeriod, 0);
    if(decision.rsi_h4 < 0) decision.rsi_h4 = 0.0;
    
    decision.rsi_d1 = GetRSIValue(_Symbol, PERIOD_D1, InpTFRsiPeriod, 0);
    if(decision.rsi_d1 < 0) decision.rsi_d1 = 0.0;
    
    if(InpLogDetailedInfo)
        Print(logPrefix + "Evaluating range signal criteria...");
    
    // Range width ≥ 1.5 × spread
    SKeyLevel resistanceLevel, supportLevel;
    if(!GetRangeBoundaries(resistanceLevel, supportLevel))
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ CRITERIA FAILED: Cannot identify range boundaries");
        
        decision.decision = "REJECTED";
        decision.rejection_reason = "Cannot identify clear range boundaries";
        if(g_reporter != NULL) g_reporter.RecordDecision(decision);
        return false;
    }
    
    double rangeWidth = resistanceLevel.price - supportLevel.price;
    double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
    double minRangeWidth = spread * 1.5;
    bool rangeWidthOK = (rangeWidth >= minRangeWidth);
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "1. Range Width Analysis:");
        Print(logPrefix + "  Resistance: ", DoubleToString(resistanceLevel.price, _Digits));
        Print(logPrefix + "  Support: ", DoubleToString(supportLevel.price, _Digits));
        Print(logPrefix + "  Range Width: ", DoubleToString(rangeWidth, _Digits), " (", DoubleToString(rangeWidth / _Point, 1), " pips)");
        Print(logPrefix + "  Current Spread: ", SymbolInfoInteger(_Symbol, SYMBOL_SPREAD), " points (", DoubleToString(spread / _Point, 1), " pips)");
        Print(logPrefix + "  Min Required: ", DoubleToString(minRangeWidth, _Digits), " (", DoubleToString(minRangeWidth / _Point, 1), " pips)");
        Print(logPrefix + "  Range Width OK: ", rangeWidthOK ? "✅ SUFFICIENT" : "❌ TOO NARROW");
    }
    
    if(!rangeWidthOK)
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ CRITERIA FAILED: Range too narrow (need ≥1.5×spread)");
        
        decision.decision = "REJECTED";
        decision.rejection_reason = StringFormat("Range too narrow - %.1f pips (need >= %.1f pips)",
                                                rangeWidth / _Point, minRangeWidth / _Point);
        decision.nearest_resistance = resistanceLevel.price;
        decision.nearest_support = supportLevel.price;
        if(g_reporter != NULL) g_reporter.RecordDecision(decision);
        return false;
    }
    
    // ADX < 20
    bool adxOK = (rs.adx_h1 < 20);
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "2. Trend Strength Analysis:");
        Print(logPrefix + "  ADX H1: ", DoubleToString(rs.adx_h1, 2));
        Print(logPrefix + "  ADX Threshold: 20.0");
        Print(logPrefix + "  Low Trend Strength: ", adxOK ? "✅ CONFIRMED (ADX < 20)" : "❌ TOO STRONG (ADX ≥ 20)");
    }
    
    if(!adxOK)
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ CRITERIA FAILED: Market trending too strongly (ADX ≥ 20)");
        
        decision.decision = "REJECTED";
        decision.rejection_reason = StringFormat("Market trending - ADX: %.1f (need < 20)", rs.adx_h1);
        if(g_reporter != NULL) g_reporter.RecordDecision(decision);
        return false;
    }
    
    // Confirm with Stoch(14,3,3) crossing 80/20
    int stoch_handle = iStochastic(_Symbol, PERIOD_CURRENT, InpStochPeriod, InpStochK, InpStochD, MODE_SMA, STO_LOWHIGH);
    double stochK = 0, stochK_prev = 0;
    
    if(stoch_handle != INVALID_HANDLE)
    {
        double stoch_buffer[];
        ArraySetAsSeries(stoch_buffer, true);
        int copied = CopyBuffer(stoch_handle, 0, 0, 2, stoch_buffer);
        if(copied > 1)
        {
            stochK = stoch_buffer[0];
            stochK_prev = stoch_buffer[1];
        }
        else
        {
            Print("[Grande] WARNING: Failed to copy Stochastic data. Error: ", GetLastError());
            IndicatorRelease(stoch_handle);
            return false; // Exit early if critical data fails
        }
        IndicatorRelease(stoch_handle);
    }
    else
    {
        Print("[Grande] ERROR: Invalid Stochastic handle");
        return false;
    }
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double midRange = (resistanceLevel.price + supportLevel.price) / 2.0;
    
    // Fade touches of top/bottom 80% of range
    bool nearResistance = (currentPrice >= resistanceLevel.price * 0.998);
    bool nearSupport = (currentPrice <= supportLevel.price * 1.002);
    bool stochOverbought = (stochK > 80 && stochK < stochK_prev);
    bool stochOversold = (stochK < 20 && stochK > stochK_prev);
    
    bool validRangeEntry = false;
    string entryReason = "";
    
    if(nearResistance && stochOverbought)
    {
        validRangeEntry = true;
        entryReason = "SELL at resistance (Stoch overbought & turning down)";
    }
    else if(nearSupport && stochOversold)
    {
        validRangeEntry = true;
        entryReason = "BUY at support (Stoch oversold & turning up)";
    }
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "3. Entry Opportunity Analysis:");
        Print(logPrefix + "  Current Price: ", DoubleToString(currentPrice, _Digits));
        Print(logPrefix + "  Position in Range: ", DoubleToString((currentPrice - supportLevel.price) / rangeWidth * 100, 1), "%");
        Print(logPrefix + "  Near Resistance (>99.8%): ", nearResistance ? "✅" : "❌");
        Print(logPrefix + "  Near Support (<0.2%): ", nearSupport ? "✅" : "❌");
        Print(logPrefix + "  Stochastic Current: ", DoubleToString(stochK, 2));
        Print(logPrefix + "  Stochastic Previous: ", DoubleToString(stochK_prev, 2));
        Print(logPrefix + "  Stoch Overbought (>80 & turning down): ", stochOverbought ? "✅" : "❌");
        Print(logPrefix + "  Stoch Oversold (<20 & turning up): ", stochOversold ? "✅" : "❌");
        Print(logPrefix + "  Valid Entry: ", validRangeEntry ? "✅ " + entryReason : "❌ NO ENTRY SIGNAL");
    }
    
    if(!validRangeEntry)
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ CRITERIA FAILED: No valid range entry signal");
        
        decision.decision = "REJECTED";
        decision.rejection_reason = "Price not at range boundaries with stochastic confirmation";
        decision.nearest_resistance = resistanceLevel.price;
        decision.nearest_support = supportLevel.price;
        if(g_reporter != NULL) g_reporter.RecordDecision(decision);
        return false;
    }
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "🎯 ALL RANGE CRITERIA PASSED!");
        Print(logPrefix + "  ✅ Range width sufficient (≥1.5×spread)");
        Print(logPrefix + "  ✅ Low trend strength (ADX < 20)");
        Print(logPrefix + "  ✅ Valid entry signal: ", entryReason);
    }
    
    // Track successful signal
    decision.decision = "PASSED";
    decision.rejection_reason = "";
    decision.nearest_resistance = resistanceLevel.price;
    decision.nearest_support = supportLevel.price;
    decision.additional_notes = entryReason;
    if(g_reporter != NULL) g_reporter.RecordDecision(decision);
    
    return true;
}

//+------------------------------------------------------------------+
//| Legacy Risk Management Functions (Fallback)                     |
//+------------------------------------------------------------------+
double CalcLot(MARKET_REGIME regime)
{
    // Fallback method when risk manager is not available
    double riskPct = (regime == REGIME_BREAKOUT_SETUP) ? InpRiskPctBreakout :
                     (regime == REGIME_RANGING)        ? InpRiskPctRange :
                                                         InpRiskPctTrend;
    
    double slPips = CurrentSLDistancePips(regime);
    if(slPips <= 0) return 0;
    
    double riskUSD = AccountInfoDouble(ACCOUNT_EQUITY) * riskPct / 100.0;
    double lot = NormalizeDouble(riskUSD / (slPips * PointValueUSD()), 2);
    
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lot = MathMin(lot, maxLot);
    lot = MathMax(lot, minLot);
    lot = NormalizeDouble(lot / lotStep, 0) * lotStep;
    
    return lot;
}

//+------------------------------------------------------------------+
//| Helper functions                                                 |
//+------------------------------------------------------------------+
double CurrentSLDistancePips(MARKET_REGIME regime)
{
    RegimeSnapshot rs = g_regimeDetector.GetLastSnapshot();
    return rs.atr_current * 1.2 / _Point; // 1.2 × ATR as default SL distance
}

double PointValueUSD()
{
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    return tickValue / tickSize * _Point;
}

double GetPipSize()
{
    // For most FX: if 5-digit pricing then pip is 10 * _Point, else use _Point
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    // Handle JPY pairs (2 or 3 digits) and metals/CFDs generically via tick size
    if(digits >= 5)
        return _Point * 10.0;
    if(digits == 3)
        return _Point * 10.0;
    // Fallback to tick size to be safe across symbols
    double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    return (ts > 0 ? ts : _Point);
}

string GetTFShortName(ENUM_TIMEFRAMES tf)
{
    switch(tf)
    {
        case PERIOD_M1:  return "M1";
        case PERIOD_M5:  return "M5";
        case PERIOD_M15: return "M15";
        case PERIOD_M30: return "M30";
        case PERIOD_H1:  return "H1";
        case PERIOD_H2:  return "H2";
        case PERIOD_H4:  return "H4";
        case PERIOD_D1:  return "D1";
        case PERIOD_W1:  return "W1";
        case PERIOD_MN1: return "MN1";
        default:         return EnumToString(tf);
    }
}

double StopLoss_TREND(bool bullish, const RegimeSnapshot &rs)
{
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    return bullish ? currentPrice - rs.atr_current * 1.2 : currentPrice + rs.atr_current * 1.2;
}

double TakeProfit_TREND(bool bullish, const RegimeSnapshot &rs, bool isMomentumTrade = false, double momentumStrength = 0.0)
{
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    if(isMomentumTrade && momentumStrength > 0)
    {
        // For momentum trades, use adaptive targets based on momentum strength
        double tpMultiplier = 3.0; // Default
        
        if(momentumStrength > 3.0)
        {
            // Very strong momentum (>3x ATR) - take quick profit as momentum may exhaust
            tpMultiplier = 1.5;
            if(InpLogDetailedInfo)
                Print("[MOMENTUM TP] Strong surge detected (", DoubleToString(momentumStrength, 2), 
                      "x ATR) - Using quick TP at ", DoubleToString(tpMultiplier, 1), "x ATR");
        }
        else if(momentumStrength > 2.0)
        {
            // Strong momentum (2-3x ATR) - moderate target
            tpMultiplier = 2.0;
            if(InpLogDetailedInfo)
                Print("[MOMENTUM TP] Moderate surge (", DoubleToString(momentumStrength, 2), 
                      "x ATR) - Using TP at ", DoubleToString(tpMultiplier, 1), "x ATR");
        }
        else if(momentumStrength > 1.5)
        {
            // Regular momentum (1.5-2x ATR) - standard target
            tpMultiplier = 2.5;
        }
        
        // Check for nearby key levels that could act as resistance/support
        if(g_keyLevelDetector != NULL)
        {
            double proposedTP = bullish ? 
                currentPrice + rs.atr_current * tpMultiplier : 
                currentPrice - rs.atr_current * tpMultiplier;
                
            // Try to find a key level between current price and proposed TP
            int levelCount = g_keyLevelDetector.GetKeyLevelCount();
            double bestLevelPrice = 0;
            double bestLevelStrength = 0;
            
            for(int i = 0; i < levelCount; i++)
            {
                SKeyLevel level;
                if(g_keyLevelDetector.GetKeyLevel(i, level))
                {
                    // Check if level is in our target direction
                    bool levelInDirection = bullish ? 
                        (level.price > currentPrice && level.price < proposedTP) :
                        (level.price < currentPrice && level.price > proposedTP);
                    
                    if(levelInDirection && level.strength > bestLevelStrength)
                    {
                        bestLevelPrice = level.price;
                        bestLevelStrength = level.strength;
                    }
                }
            }
            
            // If we found a strong key level, use it as target (with small buffer)
            if(bestLevelPrice != 0 && bestLevelStrength >= InpMinStrength)
            {
                double buffer = 0.1 * rs.atr_current; // 10% ATR buffer before key level
                double keyLevelTP = bullish ? bestLevelPrice - buffer : bestLevelPrice + buffer;
                
                // Only use key level if it gives us at least 1x ATR profit
                double minDistance = rs.atr_current * 1.0;
                if(MathAbs(keyLevelTP - currentPrice) >= minDistance)
                {
                    if(InpLogDetailedInfo)
                        Print("[MOMENTUM TP] Using key level at ", DoubleToString(bestLevelPrice, _Digits),
                              " (strength: ", DoubleToString(bestLevelStrength, 2), ") as TP target");
                    return keyLevelTP;
                }
            }
        }
        
        return bullish ? 
            currentPrice + rs.atr_current * tpMultiplier : 
            currentPrice - rs.atr_current * tpMultiplier;
    }
    
    // Standard non-momentum target
    return bullish ? currentPrice + rs.atr_current * 3.0 : currentPrice - rs.atr_current * 3.0;
}

bool GetRangeBoundaries(SKeyLevel &resistance, SKeyLevel &support)
{
    if(g_keyLevelDetector == NULL) return false;
    
    // Get all key levels and find highest resistance and lowest support
    int levelCount = g_keyLevelDetector.GetKeyLevelCount();
    if(levelCount < 2) return false;
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double highestResistance = 0;
    double lowestSupport = 999999;
    
    for(int i = 0; i < levelCount; i++)
    {
        SKeyLevel level;
        if(g_keyLevelDetector.GetKeyLevel(i, level))
        {
            if(level.isResistance && level.price > currentPrice && level.price > highestResistance)
                highestResistance = level.price;
            else if(!level.isResistance && level.price < currentPrice && level.price < lowestSupport)
                lowestSupport = level.price;
        }
    }
    
    if(highestResistance == 0 || lowestSupport == 999999) return false;
    
    resistance.price = highestResistance;
    resistance.isResistance = true;
    support.price = lowestSupport;
    support.isResistance = false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Startup snapshot helpers                                          |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Find Nearest Key Levels                                          |
//+------------------------------------------------------------------+
// PURPOSE:
//   Finds the nearest support and resistance levels to the current price
//   from the key level detector.
//
// PARAMETERS:
//   currentPrice (double) - Current market price to find levels relative to
//   outSupport (SKeyLevel&) - Output parameter: nearest support level below price
//   outResistance (SKeyLevel&) - Output parameter: nearest resistance level above price
//
// RETURNS:
//   (bool) - true if at least one level (support or resistance) was found, false otherwise
//
// SIDE EFFECTS:
//   - Modifies outSupport and outResistance output parameters
//   - None (read-only operation on key level detector)
//
// ERROR CONDITIONS:
//   - Returns false if key level detector is NULL
//   - Returns false if no key levels are available
//   - Returns false if no levels found on either side of price
//
// NOTES:
//   - Searches all key levels to find closest support (below price) and resistance (above price)
//   - Support levels are those with price < currentPrice
//   - Resistance levels are those with price > currentPrice
//   - Output parameters are only valid if function returns true
//
// RELATED:
//   - See Also: GetRangeBoundaries()
//   - Called By: ExecuteTradeLogic(), BuildGoldenNugget()
//+------------------------------------------------------------------+
bool FindNearestKeyLevels(const double currentPrice, SKeyLevel &outSupport, SKeyLevel &outResistance)
{
    if(g_keyLevelDetector == NULL)
        return false;

    int levelCount = g_keyLevelDetector.GetKeyLevelCount();
    if(levelCount <= 0)
        return false;

    bool haveSupport = false;
    bool haveResistance = false;
    double bestSupportDelta = DBL_MAX;
    double bestResistanceDelta = DBL_MAX;

    for(int i = 0; i < levelCount; i++)
    {
        SKeyLevel level;
        if(!g_keyLevelDetector.GetKeyLevel(i, level))
            continue;

        double delta = level.price - currentPrice;
        if(delta < 0)
        {
            double d = -delta;
            if(d < bestSupportDelta)
            {
                bestSupportDelta = d;
                outSupport = level;
                outSupport.isResistance = false;
                haveSupport = true;
            }
        }
        else if(delta > 0)
        {
            if(delta < bestResistanceDelta)
            {
                bestResistanceDelta = delta;
                outResistance = level;
                outResistance.isResistance = true;
                haveResistance = true;
            }
        }
    }

    return (haveSupport || haveResistance);
}

string BuildGoldenNugget(const RegimeSnapshot &rs, const SKeyLevel &support, const SKeyLevel &resistance)
{
    double atr = rs.atr_current;
    double roomUp = (resistance.price > 0 ? (resistance.price - SymbolInfoDouble(_Symbol, SYMBOL_BID)) : 0.0);
    double roomDown = (support.price > 0 ? (SymbolInfoDouble(_Symbol, SYMBOL_BID) - support.price) : 0.0);

    switch(rs.regime)
    {
        case REGIME_TREND_BULL:
            if(resistance.price > 0 && roomUp < 0.8 * atr)
                return "Bull trend but close to resistance — favor pullbacks or wait for breakout.";
            return "Bull trend with room — buy pullbacks in direction of strength.";
        case REGIME_TREND_BEAR:
            if(support.price > 0 && roomDown < 0.8 * atr)
                return "Bear trend but near support — favor rallies to sell or wait for break.";
            return "Bear trend with room — sell rallies in direction of weakness.";
        case REGIME_BREAKOUT_SETUP:
            return "Volatility building — watch for break of nearest level for momentum entry.";
        case REGIME_RANGING:
            return "Range conditions — fade moves toward boundaries; avoid chasing.";
        case REGIME_HIGH_VOLATILITY:
            return "High volatility — reduce size and widen stops; be selective.";
    }
    return "Stay disciplined — confirm with levels and risk plan.";
}

void ShowStartupSnapshot()
{
    if(g_regimeDetector == NULL)
        return;

    RegimeSnapshot rs = g_regimeDetector.GetLastSnapshot();
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    SKeyLevel support; ZeroMemory(support);
    SKeyLevel resistance; ZeroMemory(resistance);
    FindNearestKeyLevels(price, support, resistance);

    double atr = rs.atr_current;
    double atrAvg = rs.atr_avg;
    double volRatio = (atrAvg > 0 ? atr / atrAvg : 0.0);
    double pipSize = GetPipSize();

    // Risk preview
    string tradingStatus = (g_riskManager != NULL && g_riskManager.IsTradingEnabled()) ? "ACTIVE" : "DISABLED";
    double slPoints = (atr > 0 ? (atr * InpSLATRMultiplier) / _Point : 0.0); // used for calculation
    double slPipsDisp = (atr > 0 ? (atr * InpSLATRMultiplier) / pipSize : 0.0); // used for display
    double previewLot = 0.0;
    if(g_riskManager != NULL && slPoints > 0)
        previewLot = g_riskManager.CalculateLotSize(slPoints, rs.regime);

    // Distances to levels in pips
    double toResPips = (resistance.price > 0 ? (resistance.price - price) / _Point : 0.0);
    double toSupPips = (support.price > 0 ? (price - support.price) / _Point : 0.0);

    string nugget = BuildGoldenNugget(rs, support, resistance);

    string tfName = GetTFShortName((ENUM_TIMEFRAMES)Period());
    string header = StringFormat("=== Grande Snapshot %s %s ===", _Symbol, tfName);
    // Label ADX with current timeframe correctly in first slot
    string regimeLine = StringFormat("Regime: %s  Conf: %.2f  ADX(%s/H4/D1): %.1f/%.1f/%.1f",
        g_regimeDetector.RegimeToString(rs.regime), rs.confidence, tfName, rs.adx_h1, rs.adx_h4, rs.adx_d1);
    string volLine = StringFormat("Volatility: ATR %.5f (avg %.5f, x%.2f)", atr, atrAvg, volRatio);

    // Use pip size for distances and show N/A if missing
    double toRes = (resistance.price > 0 ? (resistance.price - price) : 0.0);
    double toSup = (support.price > 0 ? (price - support.price) : 0.0);
    string resStr = (resistance.price > 0 ? DoubleToString(resistance.price, _Digits) : "N/A");
    string supStr = (support.price > 0 ? DoubleToString(support.price, _Digits) : "N/A");
    string levelLine = StringFormat("Nearest: R %s (+%d pips) | S %s (+%d pips)",
        resStr, (int)MathMax(0.0, toRes / pipSize),
        supStr, (int)MathMax(0.0, toSup / pipSize));
    string riskLine = StringFormat("Risk: MaxPerTrade %.1f%%, MaxPos %d, Status %s, PreviewLot %.2f (SL≈%.0f pips)",
        InpMaxRiskPerTrade, InpMaxPositions, tradingStatus, previewLot, slPipsDisp);

    string golden = StringFormat("Golden Nugget: %s", nugget);

    string snapshot = header + "\n" + regimeLine + "\n" + volLine + "\n" + levelLine + "\n" + riskLine + "\n" + golden;

    // Create compact panel in top-right to avoid overlaps
    const string STARTUP_PANEL_NAME = "GrandeStartupSnapshotPanel";
    ObjectDelete(g_chartID, STARTUP_PANEL_NAME);

    bool ok = ObjectCreate(g_chartID, STARTUP_PANEL_NAME, OBJ_LABEL, 0, 0, 0);
    if(ok)
    {
        // Adaptive font size based on chart width
        int chartWidth = (int)ChartGetInteger(g_chartID, CHART_WIDTH_IN_PIXELS, 0);
        int fontSize = 8;
        if(chartWidth >= 1900) fontSize = 11;
        else if(chartWidth >= 1400) fontSize = 10;
        else if(chartWidth >= 1000) fontSize = 9;
        else fontSize = 8;

        ObjectSetString(g_chartID, STARTUP_PANEL_NAME, OBJPROP_TEXT, snapshot);
        ObjectSetInteger(g_chartID, STARTUP_PANEL_NAME, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(g_chartID, STARTUP_PANEL_NAME, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(g_chartID, STARTUP_PANEL_NAME, OBJPROP_YDISTANCE, 10);
        ObjectSetInteger(g_chartID, STARTUP_PANEL_NAME, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(g_chartID, STARTUP_PANEL_NAME, OBJPROP_FONTSIZE, fontSize);
        ObjectSetString(g_chartID, STARTUP_PANEL_NAME, OBJPROP_FONT, "Consolas");
        ObjectSetInteger(g_chartID, STARTUP_PANEL_NAME, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(g_chartID, STARTUP_PANEL_NAME, OBJPROP_BACK, true);
        ObjectSetInteger(g_chartID, STARTUP_PANEL_NAME, OBJPROP_BGCOLOR, C'0,0,0');
        ObjectSetInteger(g_chartID, STARTUP_PANEL_NAME, OBJPROP_BORDER_COLOR, clrDimGray);
        ObjectSetInteger(g_chartID, STARTUP_PANEL_NAME, OBJPROP_HIDDEN, false);

        // Store removal time in object description
        string expire = IntegerToString((long)(TimeCurrent() + 30));
        ObjectSetString(g_chartID, STARTUP_PANEL_NAME, OBJPROP_TOOLTIP, expire); // reuse tooltip to stash expiry
    }

    Print(snapshot);
    ChartRedraw(g_chartID);
}

//+------------------------------------------------------------------+
//| Safe market data access helper functions                         |
//+------------------------------------------------------------------+
double SafeGetHigh(string symbol, ENUM_TIMEFRAMES timeframe, int index)
{
    double value = iHigh(symbol, timeframe, index);
    if(value <= 0 || value == EMPTY_VALUE)
    {
        Print("[Grande] ERROR: Failed to get High price for bar ", index, ". Error: ", GetLastError());
        return -1; // Invalid value indicator
    }
    return value;
}

double SafeGetLow(string symbol, ENUM_TIMEFRAMES timeframe, int index)
{
    double value = iLow(symbol, timeframe, index);
    if(value <= 0 || value == EMPTY_VALUE)
    {
        Print("[Grande] ERROR: Failed to get Low price for bar ", index, ". Error: ", GetLastError());
        return -1; // Invalid value indicator
    }
    return value;
}

long SafeGetTickVolume(string symbol, ENUM_TIMEFRAMES timeframe, int index)
{
    long value = iTickVolume(symbol, timeframe, index);
    if(value <= 0)
    {
        Print("[Grande] ERROR: Failed to get Tick Volume for bar ", index, ". Error: ", GetLastError());
        return -1; // Invalid value indicator
    }
    return value;
}

long GetAverageVolume(int period)
{
    long totalVolume = 0;
    int validBars = 0;
    
    for(int i = 1; i <= period; i++)
    {
        long volume = SafeGetTickVolume(_Symbol, PERIOD_CURRENT, i);
        if(volume > 0) // Only count valid volumes
        {
            totalVolume += volume;
            validBars++;
        }
    }
    
    if(validBars == 0)
    {
        Print("[Grande] ERROR: No valid volume data found for average calculation");
        return -1;
    }
    
    return totalVolume / validBars;
}

//+------------------------------------------------------------------+
//| Get RSI value for any timeframe                                  |
//+------------------------------------------------------------------+
double GetRSIValue(string symbol, ENUM_TIMEFRAMES tf, int period, int shift=0)
{
    ResetLastError();
    SymbolSelect(symbol, true);

    int handle = iRSI(symbol, tf, period, PRICE_CLOSE);
    if(handle == INVALID_HANDLE)
    {
        Print("[Grande] ERROR: Invalid RSI handle for tf=", (int)tf, " Err=", GetLastError());
        return -1;
    }

    // Wait briefly for history/indicator to be ready (first run on new tf can lag)
    int attempts = 10;
    for(int a = 0; a < attempts; ++a)
    {
        if(SeriesInfoInteger(symbol, tf, SERIES_SYNCHRONIZED) && BarsCalculated(handle) > 0)
            break;
        Sleep(25);
    }

    double buf[];
    ArraySetAsSeries(buf, true);

    int copied = -1;
    int tryCount = 5;
    for(int t = 0; t < tryCount; ++t)
    {
        copied = CopyBuffer(handle, 0, shift, 1, buf);
        if(copied >= 1)
            break;
        // Try nudging history load for the timeframe
        MqlRates rates[];
        CopyRates(symbol, tf, 0, 2, rates);
        Sleep(25);
    }

    int lastErr = GetLastError();
    IndicatorRelease(handle);
    if(copied < 1)
    {
        Print("[Grande] WARNING: Failed to copy RSI data for tf=", (int)tf, " Err=", lastErr);
        return -1;
    }

    return buf[0];
}

//+------------------------------------------------------------------+
//| Get error description                                           |
//+------------------------------------------------------------------+
string ErrorDescription(int errorCode)
{
    switch(errorCode)
    {
        case 0:     return "No error";
        case 1:     return "No error, but result unknown";
        case 2:     return "Common error";
        case 3:     return "Invalid trade parameters";
        case 4:     return "Trade server is busy";
        case 5:     return "Old version of client terminal";
        case 6:     return "No connection with trade server";
        case 7:     return "Not enough rights";
        case 8:     return "Too frequent requests";
        case 9:     return "Malfunctional trade operation";
        case 64:    return "Account disabled";
        case 65:    return "Invalid account";
        case 128:   return "Trade timeout";
        case 129:   return "Invalid price";
        case 130:   return "Invalid stops";
        case 131:   return "Invalid trade volume";
        case 132:   return "Market is closed";
        case 133:   return "Trade is disabled";
        case 134:   return "Not enough money";
        case 135:   return "Price changed";
        case 136:   return "Off quotes";
        case 137:   return "Broker is busy";
        case 138:   return "Requote";
        case 139:   return "Order is locked";
        case 140:   return "Long positions only allowed";
        case 141:   return "Too many requests";
        case 145:   return "Modification denied because order too close to market";
        case 146:   return "Trade context is busy";
        case 147:   return "Expirations are denied by broker";
        case 148:   return "Amount of open and pending orders has reached the limit";
        case 10004:  return "Requote";
        case 10006:  return "Request rejected";
        case 10007:  return "Request canceled by trader";
        case 10008:  return "Order placed";
        case 10009:  return "Request completed";
        case 10010:  return "Only part of request completed";
        case 10011:  return "Request processing error";
        case 10012:  return "Request canceled by timeout";
        case 10013:  return "Invalid request";
        case 10014:  return "Invalid volume";
        case 10015:  return "Invalid price";
        case 10016:  return "Invalid stops";
        case 10017:  return "Trade disabled";
        case 10018:  return "Market closed";
        case 10019:  return "Not enough money";
        case 10020:  return "Prices changed";
        case 10021:  return "No quotes";
        case 10022:  return "Invalid expiration date";
        case 10023:  return "Order state changed";
        case 10024:  return "Too frequent requests";
        case 10025:  return "No changes";
        case 10026:  return "Autotrading disabled by server";
        case 10027:  return "Autotrading disabled by client";
        case 10028:  return "Request locked for processing";
        case 10029:  return "Order or position frozen";
        case 10030:  return "Invalid order filling type";
        case 10031:  return "No connection with trade server";
        case 10032:  return "Operation allowed for live accounts only";
        case 10033:  return "Pending orders limit exceeded";
        case 10034:  return "Orders and positions limit exceeded";
        case 10045:  return "Position with specified ID already closed or doesn't exist";
        default:    return StringFormat("Unknown error %d", errorCode);
    }
}

//+------------------------------------------------------------------+
//| Check if trade context is available                             |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
{
    // Check if trading is enabled
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
        return false;
        
    // Check if autotrading is enabled
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
        return false;
        
    // Check if symbol trading is allowed
    if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE))
        return false;
        
    // Check if we're connected to trade server
    if(!TerminalInfoInteger(TERMINAL_CONNECTED))
        return false;
        
    return true;
}

//+------------------------------------------------------------------+
//| Add SL/TP to manual positions                                   |
//+------------------------------------------------------------------+
void AddSLTPToManualPositions()
{
    static bool hasLoggedPositionCheck = false;
    int totalPositions = PositionsTotal();
    int processedPositions = 0;
    int positionsNeedingSLTP = 0;
    
    if(!hasLoggedPositionCheck && InpLogDetailedInfo && totalPositions > 0)
    {
        Print(StringFormat("[Grande] Checking %d total positions for missing SL/TP...", totalPositions));
        hasLoggedPositionCheck = true;
    }
    
    for(int i = 0; i < totalPositions; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket))
            continue;
            
        // Only process positions for our symbol
        if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
            
        processedPositions++;
        
        // Check if position has no SL/TP
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentTP = PositionGetDouble(POSITION_TP);
        
        if(InpLogVerbose) // Only ultra-verbose logging for position details
        {
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            string typeStr = (type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
            Print(StringFormat("[Grande] Position #%I64u %s @%.5f: SL=%.5f, TP=%.5f", 
                  ticket, typeStr, openPrice, currentSL, currentTP));
        }
        
        // If position already has both SL and TP, skip it
        if(currentSL != 0 && currentTP != 0)
        {
            if(InpLogVerbose) // Only ultra-verbose
                Print(StringFormat("[Grande] Position #%I64u already has SL/TP, skipping", ticket));
            continue;
        }
        
        positionsNeedingSLTP++;
            
        // Get position details
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        bool isBuy = (type == POSITION_TYPE_BUY);
        
        // Calculate SL/TP based on current settings
        double atr = 0.0;
        int atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
        if(atrHandle != INVALID_HANDLE)
        {
            double atrBuf[];
            ArraySetAsSeries(atrBuf, true);
            if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) > 0)
                atr = atrBuf[0];
            IndicatorRelease(atrHandle);
        }
        
        if(atr == 0)
            atr = 100 * _Point; // Fallback to 100 points if ATR fails
        
        double sl = 0.0, tp = 0.0;
        
        if(currentSL == 0) // Only set SL if not already set
        {
            if(g_riskManager != NULL)
            {
                sl = g_riskManager.CalculateStopLoss(isBuy, openPrice, atr);
            }
            else
            {
                // Fallback calculation using default ATR multiplier
                double slDistance = atr * 1.5; // Default 1.5x ATR for stop loss
                sl = isBuy ? openPrice - slDistance : openPrice + slDistance;
            }
        }
        else
        {
            sl = currentSL; // Keep existing SL
        }
        
        if(currentTP == 0) // Only set TP if not already set
        {
            if(g_riskManager != NULL)
            {
                tp = g_riskManager.CalculateTakeProfit(isBuy, openPrice, sl);
            }
            else
            {
                // Fallback calculation using configured risk-reward ratio
                double slDistance = MathAbs(openPrice - sl);
                double tpDistance = slDistance * InpTPRewardRatio; // Use configured R:R ratio
                tp = isBuy ? openPrice + tpDistance : openPrice - tpDistance;
                
                if(InpLogDetailedInfo)
                {
                    double tpPips = tpDistance / GetPipSize();
                    double slPips = slDistance / GetPipSize();
                    Print(StringFormat("[Grande] Manual Position #%I64u SL/TP calculation:", ticket));
                    Print(StringFormat("[Grande]   Open: %.5f, SL: %.5f (%.1f pips), TP: %.5f (%.1f pips)", 
                          openPrice, sl, slPips, tp, tpPips));
                    Print(StringFormat("[Grande]   R:R Ratio: %.2f:1", InpTPRewardRatio));
                }
            }
        }
        else
        {
            tp = currentTP; // Keep existing TP
        }
        
        // Normalize stops
        NormalizeStops(isBuy, openPrice, sl, tp);
        
        // Modify position to add SL/TP
        if((currentSL == 0 || currentTP == 0) && (sl != 0 || tp != 0))
        {
            // ERROR 5035 & 4203 FIX: Check trade context and implement retry mechanism
            bool modifySuccess = false;
            int maxRetries = 3;
            int retryDelay = 100; // 100ms delay between retries

            for(int retry = 0; retry < maxRetries && !modifySuccess; retry++)
            {
                // Reset error before attempt
                ResetLastError();

                // Check if trade context is available
                if(!IsTradeAllowed())
                {
                    if(InpLogDetailedInfo)
                        Print(StringFormat("[Grande] ⏸️ Trade context not available for position #%I64u (attempt %d/%d)",
                              ticket, retry + 1, maxRetries));
                    Sleep(retryDelay);
                    continue;
                }

                // Attempt to modify position
                modifySuccess = g_trade.PositionModify(ticket, sl, tp);

                if(modifySuccess)
                {
                    Print(StringFormat("[Grande] ✅ Added SL/TP to manual position #%I64u - SL: %.5f, TP: %.5f",
                          ticket, sl, tp));
                    break;
                }
                else
                {
                    int error = GetLastError();

                    // Handle specific errors
                    if(error == 5035) // Trade context is busy
                    {
                        if(InpLogDetailedInfo)
                            Print(StringFormat("[Grande] ⏸️ Trade context busy for position #%I64u (attempt %d/%d) - retrying in %dms",
                                  ticket, retry + 1, maxRetries, retryDelay));
                        Sleep(retryDelay);
                        continue;
                    }
                    else if(error == 10045) // Position already closed
                    {
                        if(InpLogDetailedInfo)
                            Print(StringFormat("[Grande] ⚠️ Position #%I64u already closed - skipping", ticket));
                        break; // Don't retry for closed positions
                    }
                    else if(error == 4203) // Invalid request - position already has SL/TP or being processed
                    {
                        // Position likely already has proper SL/TP set or is being processed
                        // This is normal for positions created by the system itself
                        if(InpLogDetailedInfo)
                            Print(StringFormat("[Grande] ℹ️ Position #%I64u already processed (error 4203) - skipping", ticket));
                        break; // Don't retry for 4203 errors
                    }
                    else
                    {
                        // Other errors - log and don't retry
                        Print(StringFormat("[Grande] ❌ FAILED to add SL/TP to position #%I64u", ticket));
                        Print(StringFormat("[Grande] ❌ Error Code: %d - %s", error, ErrorDescription(error)));
                        Print(StringFormat("[Grande] ❌ Attempted SL: %.5f, TP: %.5f", sl, tp));
                        Print(StringFormat("[Grande] ❌ Trade Result: %d", g_trade.ResultRetcode()));
                        break; // Don't retry for other errors
                    }
                }
            }

            if(!modifySuccess)
            {
                Print(StringFormat("[Grande] ❌ FINAL FAILURE: Could not add SL/TP to position #%I64u after %d attempts",
                      ticket, maxRetries));
            }
        }
    }
    
    // Summary log (only if changes were made)
    if(InpLogDetailedInfo && positionsNeedingSLTP > 0)
    {
        Print(StringFormat("[Grande] SL/TP Updates: %d positions needed updates (of %d checked)", 
              positionsNeedingSLTP, processedPositions));
    }
}

//+------------------------------------------------------------------+
//| RSI-based exit management with partial closes                    |
//+------------------------------------------------------------------+
void ApplyRSIExitRules()
{
    for(int i = PositionsTotal() - 1; i >= 0; --i)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        if(!PositionSelectByTicket(ticket)) continue;
        if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        long   type   = PositionGetInteger(POSITION_TYPE);
        double vol    = PositionGetDouble(POSITION_VOLUME);
        double open   = PositionGetDouble(POSITION_PRICE_OPEN);
        double price  = (type == POSITION_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK));

        // Check if this position has previously failed partial close (error 10045)
        string failKey = "PARTIAL_FAIL_" + IntegerToString(ticket);
        if(ObjectFind(g_chartID, failKey) >= 0)
        {
            // Skip this position as it previously failed with unrecoverable error
            continue;
        }
        
        // Cooldown check using chart objects
        string cooldownKey = StringFormat("RSIExitCooldown_%I64u", ticket);
        datetime lastTime = 0;
        string lastStr = ObjectGetString(g_chartID, cooldownKey, OBJPROP_TOOLTIP);
        if(lastStr != NULL && StringLen(lastStr) > 0)
            lastTime = (datetime)StringToInteger(lastStr);
        if(InpRSIExitCooldownSec > 0 && (TimeCurrent() - lastTime) < InpRSIExitCooldownSec)
            continue;

        // Use profit calculator for consistent profit calculation
        double profitPips = 0.0;
        if(g_profitCalculator != NULL)
            profitPips = g_profitCalculator.CalculatePositionProfitPips(ticket);
        else
        {
            double pip = GetPipSize();
            if(pip <= 0) pip = _Point;
            profitPips = (type == POSITION_TYPE_BUY ? (price - open) : (open - price)) / pip;
        }
        if(profitPips < InpRSIExitMinProfitPips) continue;

        // Use cached RSI values from current cycle
        double rsi_ctf = EMPTY_VALUE;
        double rsi_h4 = EMPTY_VALUE;
        if(g_stateManager != NULL)
        {
            rsi_ctf = g_stateManager.GetCachedRsiCTF();
            rsi_h4 = g_stateManager.GetCachedRsiH4();
        }
        if(rsi_ctf == EMPTY_VALUE)
            rsi_ctf = GetRSIValue(_Symbol, (ENUM_TIMEFRAMES)Period(), InpRSIPeriod, 0);
        if(rsi_h4 == EMPTY_VALUE)
            rsi_h4 = GetRSIValue(_Symbol, PERIOD_H4, InpTFRsiPeriod, 0);
        if(rsi_ctf < 0 || rsi_h4 < 0) continue;

        // Optional ATR guard (avoid exits when ATR collapsed)
        if(InpExitRequireATROK)
        {
            int atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
            if(atrHandle != INVALID_HANDLE)
            {
                double buf[];
                ArraySetAsSeries(buf, true);
                int copied = CopyBuffer(atrHandle, 0, 0, 11, buf);
                IndicatorRelease(atrHandle);
                if(copied >= 11)
                {
                    double currentATR = buf[0];
                    double avgATR = 0.0;
                    for(int k = 1; k < 11; ++k) avgATR += buf[k];
                    avgATR /= 10.0;
                    if(avgATR > 0 && currentATR / avgATR < InpExitMinATRRat)
                        continue;
                }
            }
        }

        // Optional structure/R-multiple guard: require >=1R in favor
        if(InpExitStructureGuard)
        {
            double sl = PositionGetDouble(POSITION_SL);
            if(sl > 0)
            {
                double pip = GetPipSize();
                if(pip <= 0) pip = _Point;
                double riskPips = MathAbs(open - sl) / pip;
                if(riskPips > 0 && profitPips < riskPips)
                    continue;
            }
        }

        // Check for momentum exhaustion first (for momentum trades)
        bool isMomentumTrade = (StringFind(PositionGetString(POSITION_COMMENT), "MOMENTUM") != -1);
        bool momentumExhausted = false;
        
        if(isMomentumTrade)
        {
            momentumExhausted = IsMomentumExhausting(ticket);
            if(momentumExhausted && InpLogDetailedInfo)
            {
                Print("[MOMENTUM EXIT] Position #", ticket, " showing exhaustion signals");
            }
        }
        
        // Check for RSI exit signals or momentum exhaustion
        bool exitSignal = false;
        if(type == POSITION_TYPE_BUY)
            exitSignal = (rsi_ctf >= InpRSIExitOB) || (rsi_h4 >= InpH4RSIOverbought);
        else
            exitSignal = (rsi_ctf <= InpRSIExitOS) || (rsi_h4 <= InpH4RSIOversold);
        
        // For momentum trades, also exit on exhaustion
        if(!exitSignal && momentumExhausted)
            exitSignal = true;

        if(!exitSignal) continue;

        double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
        double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        
        // For momentum trades on exhaustion, close more aggressively (66% instead of normal %)
        double partialClosePercent = InpRSIPartialClose;
        if(isMomentumTrade && momentumExhausted)
        {
            partialClosePercent = 0.66; // Close 66% on momentum exhaustion
            if(InpLogDetailedInfo)
                Print("[MOMENTUM EXIT] Using aggressive partial close (66%) for exhausted momentum trade");
        }
        
        double closeVol = MathFloor(MathMax(vmin, vol * partialClosePercent) / step) * step;
        if(closeVol < vmin || closeVol >= vol) continue;
        // Ensure minimum remaining volume
        if((vol - closeVol) < MathMax(vmin, InpMinRemainingVolume))
            continue;

        bool ok = g_trade.PositionClosePartial(ticket, closeVol);
        
        // ALWAYS LOG PARTIAL CLOSE ATTEMPTS
        if(!ok)
        {
            int errorCode = g_trade.ResultRetcode();
            // ALWAYS LOG THE ERROR
            Print(StringFormat("[RSI EXIT] ❌ PARTIAL CLOSE FAILED for position #%I64u", ticket));
            Print(StringFormat("[RSI EXIT] ❌ Error Code: %d - %s", errorCode, ErrorDescription(errorCode)));
            Print(StringFormat("[RSI EXIT] ❌ Attempted volume: %.2f of %.2f total", closeVol, vol));
            Print(StringFormat("[RSI EXIT] ❌ RSI Values - Current: %.1f, H4: %.1f", rsi_ctf, rsi_h4));
            
            // If error 10045 or similar, mark this position to skip future attempts
            if(errorCode == 10045 || errorCode == 10006) // Position doesn't exist or invalid request
            {
                string failKey = "PARTIAL_FAIL_" + IntegerToString(ticket);
                ObjectDelete(g_chartID, failKey);
                ObjectCreate(g_chartID, failKey, OBJ_LABEL, 0, 0, 0);
                ObjectSetString(g_chartID, failKey, OBJPROP_TOOLTIP, IntegerToString(errorCode));
                ObjectSetInteger(g_chartID, failKey, OBJPROP_HIDDEN, true);
                Print(StringFormat("[RSI EXIT] ⚠️ BLOCKING future attempts on position %I64u due to error %d", ticket, errorCode));
            }
        }
        else
        {
            Print(StringFormat("[RSI EXIT] ✅ PARTIAL CLOSE SUCCESS - Position #%I64u, Volume: %.2f", ticket, closeVol));
        }
        
        if(InpLogDetailedInfo)
            Print(StringFormat("[RSI EXIT] %s ticket=%I64u vol=%.2f rsi_ctf=%.1f rsi_h4=%.1f pips=%.1f",
                               ok ? "PARTIAL-CLOSE" : "FAILED",
                               ticket, closeVol, rsi_ctf, rsi_h4, profitPips));
        // Set cooldown timestamp
        if(ok)
        {
            ObjectDelete(g_chartID, cooldownKey);
            ObjectCreate(g_chartID, cooldownKey, OBJ_LABEL, 0, 0, 0);
            ObjectSetString(g_chartID, cooldownKey, OBJPROP_TOOLTIP, IntegerToString((long)TimeCurrent()));
            ObjectSetInteger(g_chartID, cooldownKey, OBJPROP_HIDDEN, true);
        }
    }
}

//+------------------------------------------------------------------+
//| ATR Momentum Detection - Catches expanding volatility            |
//+------------------------------------------------------------------+
bool IsATRExpanding()
{
    // Check if current ATR is significantly higher than recent average
    // This catches momentum moves as they accelerate
    
    int atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
    if(atrHandle == INVALID_HANDLE)
    {
        Print("[Grande] ERROR: Failed to create ATR handle for momentum detection");
        return false;
    }
    
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    
    // Get current ATR and 10-period average
    int copied = CopyBuffer(atrHandle, 0, 0, 11, atrBuffer);
    IndicatorRelease(atrHandle);
    
    if(copied < 11)
    {
        Print("[Grande] WARNING: Insufficient ATR data for momentum detection");
        return false;
    }
    
    double currentATR = atrBuffer[0];
    double averageATR = 0.0;
    
    // Calculate 10-period ATR average (excluding current)
    for(int i = 1; i < 11; i++)
    {
        averageATR += atrBuffer[i];
    }
    averageATR /= 10.0;
    
    // Check if current ATR is higher than average (momentum building)
    // Adaptive threshold based on timeframe - lower timeframes need less expansion
    double requiredExpansion = 1.5;  // Default 50% expansion
    if(Period() <= PERIOD_M15)
        requiredExpansion = 1.2;  // M15 only needs 20% expansion
    else if(Period() <= PERIOD_M30)
        requiredExpansion = 1.3;  // M30 needs 30% expansion
    
    double expansionRatio = currentATR / averageATR;
    bool isExpanding = (expansionRatio >= requiredExpansion);
    
    if(InpLogDetailedInfo)
    {
        Print("[ATR MOMENTUM] Current ATR: ", DoubleToString(currentATR, _Digits));
        Print("[ATR MOMENTUM] 10-Period Avg: ", DoubleToString(averageATR, _Digits));
        Print("[ATR MOMENTUM] Expansion Ratio: ", DoubleToString(expansionRatio, 2), "x");
        Print("[ATR MOMENTUM] Momentum Building: ", isExpanding ? "✅ YES (≥1.5x)" : "❌ NO (<1.5x)");
    }
    
    return isExpanding;
}

//+------------------------------------------------------------------+
//| Check if momentum is exhausting for an open position            |
//+------------------------------------------------------------------+
bool IsMomentumExhausting(ulong positionTicket)
{
    if(!PositionSelectByTicket(positionTicket))
        return false;
    
    // Check if this is a momentum trade (has MOMENTUM in comment)
    string comment = PositionGetString(POSITION_COMMENT);
    if(StringFind(comment, "MOMENTUM") == -1)
        return false; // Not a momentum trade
    
    // Get position details
    datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    
    // Calculate bars since entry
    int barsSinceEntry = Bars(_Symbol, PERIOD_CURRENT, openTime, TimeCurrent());
    
    // Get current ATR for reference
    int atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
    if(atrHandle == INVALID_HANDLE)
        return false;
    
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
    {
        IndicatorRelease(atrHandle);
        return false;
    }
    double currentATR = atrBuffer[0];
    IndicatorRelease(atrHandle);
    
    // Check multiple exhaustion signals
    int exhaustionSignals = 0;
    
    // 1. Check if recent candles are small (momentum dying)
    if(barsSinceEntry >= 2)
    {
        double lastCandle = MathAbs(iClose(_Symbol, PERIOD_CURRENT, 1) - iOpen(_Symbol, PERIOD_CURRENT, 1));
        double prevCandle = MathAbs(iClose(_Symbol, PERIOD_CURRENT, 2) - iOpen(_Symbol, PERIOD_CURRENT, 2));
        
        if(lastCandle < 0.5 * currentATR && prevCandle < 0.5 * currentATR)
        {
            exhaustionSignals++;
            if(InpLogDetailedInfo)
                Print("[MOMENTUM EXHAUST] Small candles detected - momentum dying");
        }
    }
    
    // 2. Check for reversal wicks (rejection)
    if(barsSinceEntry >= 1)
    {
        double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
        double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
        double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
        double open1 = iOpen(_Symbol, PERIOD_CURRENT, 1);
        double body = MathAbs(close1 - open1);
        double range = high1 - low1;
        
        // Check for wick rejection (small body, large wick)
        if(range > 0 && body / range < 0.3) // Body is less than 30% of range
        {
            bool upperWick = (posType == POSITION_TYPE_BUY && high1 - MathMax(open1, close1) > body * 2);
            bool lowerWick = (posType == POSITION_TYPE_SELL && MathMin(open1, close1) - low1 > body * 2);
            
            if(upperWick || lowerWick)
            {
                exhaustionSignals++;
                if(InpLogDetailedInfo)
                    Print("[MOMENTUM EXHAUST] Rejection wick detected");
            }
        }
    }
    
    // 3. Check RSI divergence (if enabled)
    if(InpEnableMTFRSI)
    {
        double rsi = GetRSIValue(_Symbol, PERIOD_CURRENT, InpRSIPeriod, 0);
        if(rsi > 0)
        {
            // For longs: price higher but RSI not making new high
            if(posType == POSITION_TYPE_BUY && currentPrice > openPrice && rsi < 65)
            {
                exhaustionSignals++;
                if(InpLogDetailedInfo)
                    Print("[MOMENTUM EXHAUST] RSI divergence detected (price up, RSI weak)");
            }
            // For shorts: price lower but RSI not making new low
            else if(posType == POSITION_TYPE_SELL && currentPrice < openPrice && rsi > 35)
            {
                exhaustionSignals++;
                if(InpLogDetailedInfo)
                    Print("[MOMENTUM EXHAUST] RSI divergence detected (price down, RSI strong)");
            }
        }
    }
    
    // 4. Time-based exhaustion for strong momentum trades
    if(StringFind(comment, "3x ATR") != -1 && barsSinceEntry > 5)
    {
        exhaustionSignals++;
        if(InpLogDetailedInfo)
            Print("[MOMENTUM EXHAUST] Strong momentum trade exceeded time limit (", barsSinceEntry, " bars)");
    }
    
    // Return true if 2 or more exhaustion signals detected
    return (exhaustionSignals >= 2);
}

//+------------------------------------------------------------------+
//| Update trailing stop for momentum trades                         |
//+------------------------------------------------------------------+
void UpdateMomentumTrailingStop(ulong positionTicket)
{
    if(!PositionSelectByTicket(positionTicket))
        return;
    
    // Check if this is a momentum trade
    string comment = PositionGetString(POSITION_COMMENT);
    if(StringFind(comment, "MOMENTUM") == -1)
        return; // Not a momentum trade
    
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    
    // Only trail if position is in profit
    bool inProfit = (posType == POSITION_TYPE_BUY) ? 
                    (currentPrice > openPrice) : 
                    (currentPrice < openPrice);
    
    if(!inProfit) return;
    
    // Get current ATR
    int atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
    if(atrHandle == INVALID_HANDLE) return;
    
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
    {
        IndicatorRelease(atrHandle);
        return;
    }
    double currentATR = atrBuffer[0];
    IndicatorRelease(atrHandle);
    
    // Use aggressive trailing for momentum trades (0.5x ATR instead of standard 0.6-0.8x)
    double trailDistance = currentATR * 0.5;
    
    // Check for very strong momentum (>3x ATR) - use even tighter trailing
    if(StringFind(comment, "3x ATR") != -1 || StringFind(comment, "STRONG") != -1)
    {
        trailDistance = currentATR * 0.4; // Ultra-tight trailing for strong momentum
        if(InpLogDetailedInfo)
            Print("[MOMENTUM TRAIL] Using ultra-tight trailing (0.4x ATR) for strong momentum trade");
    }
    
    double newSL = 0.0;
    if(posType == POSITION_TYPE_BUY)
    {
        newSL = currentPrice - trailDistance;
        // Only update if new SL is better than current
        if(newSL > currentSL && newSL < currentPrice)
        {
            // Ensure minimum stop distance
            double minDistance = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
            if(currentPrice - newSL < minDistance)
                newSL = currentPrice - minDistance;
            
            newSL = NormalizeDouble(newSL, _Digits);
            
            if(g_trade.PositionModify(positionTicket, newSL, currentTP))
            {
                if(InpLogDetailedInfo)
                    Print("[MOMENTUM TRAIL] Updated trailing stop for #", positionTicket, 
                          " from ", DoubleToString(currentSL, _Digits), 
                          " to ", DoubleToString(newSL, _Digits));
            }
        }
    }
    else // SELL position
    {
        newSL = currentPrice + trailDistance;
        // Only update if new SL is better than current
        if(newSL < currentSL && newSL > currentPrice)
        {
            // Ensure minimum stop distance
            double minDistance = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
            if(newSL - currentPrice < minDistance)
                newSL = currentPrice + minDistance;
            
            newSL = NormalizeDouble(newSL, _Digits);
            
            if(g_trade.PositionModify(positionTicket, newSL, currentTP))
            {
                if(InpLogDetailedInfo)
                    Print("[MOMENTUM TRAIL] Updated trailing stop for #", positionTicket, 
                          " from ", DoubleToString(currentSL, _Digits), 
                          " to ", DoubleToString(newSL, _Digits));
            }
        }
    }
}

bool IsNR7()
{
    // Simplified NR7 check - narrowest range in last 7 bars
    double currentHigh = SafeGetHigh(_Symbol, PERIOD_CURRENT, 0);
    double currentLow = SafeGetLow(_Symbol, PERIOD_CURRENT, 0);
    
    // Validate current bar data
    if(currentHigh <= 0 || currentLow <= 0)
    {
        Print("[Grande] ERROR: Invalid current bar data in NR7 calculation");
        return false;
    }
    
    double currentRange = currentHigh - currentLow;
    
    for(int i = 1; i < 7; i++)
    {
        double barHigh = SafeGetHigh(_Symbol, PERIOD_CURRENT, i);
        double barLow = SafeGetLow(_Symbol, PERIOD_CURRENT, i);
        
        // Validate bar data
        if(barHigh <= 0 || barLow <= 0)
        {
            Print("[Grande] WARNING: Invalid bar data at index ", i, " in NR7 calculation, skipping");
            continue; // Skip invalid bars rather than failing completely
        }
        
        double barRange = barHigh - barLow;
        if(barRange < currentRange) return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate input parameters                                         |
//+------------------------------------------------------------------+
// Cache RSI values for the current management cycle
void CacheRsiForCycle()
{
    datetime now = TimeCurrent();
    // Refresh cache at most once per second to keep values coherent
    datetime lastRsiCacheTime = (g_stateManager != NULL) ? g_stateManager.GetLastRsiCacheTime() : 0;
    if(now == lastRsiCacheTime) return;

    double rsiCTF = GetRSIValue(_Symbol, (ENUM_TIMEFRAMES)Period(), InpRSIPeriod, 0);
    double rsiH4  = GetRSIValue(_Symbol, PERIOD_H4, InpTFRsiPeriod, 0);
    // Only cache D1 if enabled to save cycles
    double rsiD1  = InpUseD1RSI ? GetRSIValue(_Symbol, PERIOD_D1, InpTFRsiPeriod, 0) : EMPTY_VALUE;
    // Store RSI cache in State Manager
    if(g_stateManager != NULL)
        g_stateManager.SetRsiCache(rsiCTF, rsiH4, rsiD1);
}

//+------------------------------------------------------------------+
//| Validate candle structure for entry                              |
//+------------------------------------------------------------------+
bool ValidateCandleStructure(bool isBuy, RegimeSnapshot &rs, string &reason)
{
    if(!InpEnableTechnicalValidation)
        return true; // Technical validation disabled
    
    if(g_candleAnalyzer == NULL)
    {
        reason = "Candle analyzer not initialized";
        return false;
    }
    
    // Validate current candle structure
    if(!g_candleAnalyzer.ValidateWickStructure(isBuy, 0, reason))
    {
        return false;
    }
    
    // Check for excessive wicks if enabled
    if(InpRejectExcessiveWicks)
    {
        CandleStructure candle = g_candleAnalyzer.AnalyzeCandleStructure(0);
        if(candle.wickToBodyRatio > InpMaxWickToBodyRatio)
        {
            reason = StringFormat("Wick-to-body ratio too high: %.2f (max: %.2f)", 
                                 candle.wickToBodyRatio, InpMaxWickToBodyRatio);
            return false;
        }
    }
    
    // Check for doji candles if enabled
    if(InpRejectDojiCandles)
    {
        CandleStructure candle = g_candleAnalyzer.AnalyzeCandleStructure(0);
        if(candle.isDoji)
        {
            reason = "Doji candle indicates indecision";
            return false;
        }
    }
    
    // Validate multi-candle setup
    if(!g_candleAnalyzer.ValidateMultiCandleSetup(isBuy, 0, reason))
    {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate price position relative to key levels                   |
//+------------------------------------------------------------------+
bool ValidatePricePosition(bool isBuy, double price, RegimeSnapshot &rs, string &reason)
{
    if(!InpEnableTechnicalValidation)
        return true;
    
    if(g_keyLevelDetector == NULL)
    {
        reason = "Key level detector not initialized";
        return false;
    }
    
    // Get nearby key levels
    double nearestResistance = 0;
    double nearestSupport = 0;
    double proximityPips = 20.0; // Check within 20 pips
    
    // Find nearest key levels
    int levelCount = g_keyLevelDetector.GetKeyLevelCount();
    for(int i = 0; i < levelCount; i++)
    {
        SKeyLevel level;
        if(g_keyLevelDetector.GetKeyLevel(i, level))
        {
            double distance = MathAbs(price - level.price) / GetPipSize();
            
            if(distance > proximityPips)
                continue;
            
            if(level.isResistance)
            {
                if(nearestResistance == 0 || MathAbs(price - level.price) < MathAbs(price - nearestResistance))
                    nearestResistance = level.price;
            }
            else
            {
                if(nearestSupport == 0 || MathAbs(price - level.price) < MathAbs(price - nearestSupport))
                    nearestSupport = level.price;
            }
        }
    }
    
    // For buy orders, don't enter at resistance
    if(isBuy && nearestResistance > 0 && price >= nearestResistance * 0.995)
    {
        reason = StringFormat("Price at resistance level: %.5f", nearestResistance);
        return false;
    }
    
    // For sell orders, don't enter at support
    if(!isBuy && nearestSupport > 0 && price <= nearestSupport * 1.005)
    {
        reason = StringFormat("Price at support level: %.5f", nearestSupport);
        return false;
    }
    
    // Check EMA alignment
    double ema20 = GetEMAValue(InpEMA20Period);
    double ema50 = GetEMAValue(InpEMA50Period);
    double ema200 = GetEMAValue(InpEMA200Period);
    
    if(ema20 > 0 && ema50 > 0 && ema200 > 0)
    {
        // For buy orders in uptrend, prefer price near or above EMA support
        if(isBuy && ema20 > ema50 && ema50 > ema200)
        {
            if(price < ema200)
            {
                reason = "Price too far below EMA support in uptrend";
                return false;
            }
        }
        
        // For sell orders in downtrend, prefer price near or below EMA resistance
        if(!isBuy && ema20 < ema50 && ema50 < ema200)
        {
            if(price > ema200)
            {
                reason = "Price too far above EMA resistance in downtrend";
                return false;
            }
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Main technical validation function                               |
//+------------------------------------------------------------------+
bool ValidateTechnicalEntry(bool isBuy, RegimeSnapshot &rs, string &rejectionReason)
{
    if(!InpEnableTechnicalValidation)
        return true; // Technical validation disabled
    
    double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Step 1: Validate candle structure
    string candleReason = "";
    if(!ValidateCandleStructure(isBuy, rs, candleReason))
    {
        rejectionReason = "Candle: " + candleReason;
        return false;
    }
    
    // Step 2: Validate price position
    string positionReason = "";
    if(!ValidatePricePosition(isBuy, currentPrice, rs, positionReason))
    {
        rejectionReason = "Position: " + positionReason;
        return false;
    }
    
    // Step 3: Check for Fibonacci confluence if required
    if(InpRequireFibConfluence && g_fibCalculator != NULL)
    {
        FibLevels fib = g_fibCalculator.CalculateAutoFibonacci();
        if(fib.isValid)
        {
            string fibLevel;
            if(!g_fibCalculator.IsPriceNearFibLevel(currentPrice, fib, InpFibProximityPips, fibLevel))
            {
                rejectionReason = "No Fibonacci confluence nearby";
                return false;
            }
        }
    }
    
    // Step 4: Check for key level confluence if required
    if(InpRequireKeyLevelConfluence && g_keyLevelDetector != NULL)
    {
        bool nearKeyLevel = false;
        double proximityPips = InpConfluenceProximityPips;
        
        int levelCount = g_keyLevelDetector.GetKeyLevelCount();
        for(int i = 0; i < levelCount; i++)
        {
            SKeyLevel level;
            if(g_keyLevelDetector.GetKeyLevel(i, level))
            {
                double distance = MathAbs(currentPrice - level.price) / GetPipSize();
                
                if(distance <= proximityPips)
                {
                    // Check if it's the right type of level
                    if(isBuy && !level.isResistance) // Buy at support
                    {
                        nearKeyLevel = true;
                        break;
                    }
                    else if(!isBuy && level.isResistance) // Sell at resistance
                    {
                        nearKeyLevel = true;
                        break;
                    }
                }
            }
        }
        
        if(!nearKeyLevel)
        {
            rejectionReason = "No key level confluence nearby";
            return false;
        }
    }
    
    // All checks passed
    return true;
}

bool ValidateInputParameters()
{
    bool isValid = true;
    
    // Symbol validation and compatibility check
    string symbol = _Symbol;
    
    // First, ensure the symbol is selected in Market Watch and available
    if(!SymbolInfoInteger(symbol, SYMBOL_SELECT))
    {
        Print("INFO: Symbol ", symbol, " not in Market Watch, attempting to add...");
        if(!SymbolSelect(symbol, true))
        {
            Print("ERROR: Failed to add ", symbol, " to Market Watch");
            Print("ERROR: This symbol may not be available from your broker");
            Print("HINT: Check that the symbol name is correct for your broker");
            Print("HINT: Some brokers use suffixes like .m, .pro, -m, or ! for different account types");
            isValid = false;
            return isValid; // Exit early if symbol cannot be selected
        }
        else
        {
            Print("INFO: Successfully added ", symbol, " to Market Watch");
            Sleep(500); // Give MT5 time to load symbol properties
        }
    }
    
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    // Validate symbol is a Forex pair
    if(StringLen(symbol) < 6)
    {
        Print("WARNING: Symbol name too short. Expected format: EURUSD, GBPJPY, etc.");
    }
    
    // Extract base pair name (remove broker suffixes like !, .m, etc.)
    string basePairName = symbol;
    StringReplace(basePairName, "!", "");
    StringReplace(basePairName, ".m", "");
    StringReplace(basePairName, ".pro", "");
    StringReplace(basePairName, "-m", "");
    
    // Check if this is a known major pair
    bool isKnownMajor = (
        basePairName == "EURUSD" || basePairName == "GBPUSD" || basePairName == "USDJPY" || 
        basePairName == "USDCHF" || basePairName == "USDCAD" || basePairName == "AUDUSD" || 
        basePairName == "NZDUSD" || basePairName == "EURJPY" || basePairName == "GBPJPY" || 
        basePairName == "AUDJPY" || basePairName == "EURGBP" || basePairName == "EURAUD" ||
        basePairName == "EURCHF" || basePairName == "GBPAUD" || basePairName == "GBPCAD" ||
        basePairName == "AUDCAD" || basePairName == "AUDNZD"
    );
    
    if(!isKnownMajor)
    {
        Print("INFO: Trading on ", symbol, " - Not in standard tested major pairs list");
        Print("INFO: EA should work but requires thorough backtesting for this pair");
    }
    else
    {
        Print("INFO: Trading on ", symbol, " (", basePairName, ") - Recognized major currency pair");
    }
    
    // Validate digit count
    if(digits != 2 && digits != 3 && digits != 4 && digits != 5)
    {
        Print("WARNING: Unusual digit count (", digits, ") for ", symbol);
        Print("WARNING: Expected 2-3 digits (JPY pairs) or 4-5 digits (other pairs)");
    }
    else
    {
        if(digits == 2 || digits == 3)
            Print("INFO: JPY pair detected (", digits, " digits) - pip calculations adjusted");
        else
            Print("INFO: Standard pair detected (", digits, " digits)");
    }
    
    // Validate minimum lot size is reasonable
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    if(minLot <= 0 || maxLot <= 0)
    {
        Print("ERROR: Invalid lot sizes for ", symbol, " (Min: ", minLot, ", Max: ", maxLot, ")");
        isValid = false;
    }
    
    // Check if trading is allowed for this symbol
    long tradeMode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
    if(tradeMode == SYMBOL_TRADE_MODE_DISABLED)
    {
        Print("ERROR: Trading is disabled for ", symbol, " (SYMBOL_TRADE_MODE = ", tradeMode, ")");
        Print("ERROR: This symbol cannot be traded on your account/broker");
        Print("HINT: Check if this is a valid trading symbol or if you need a different account type");
        isValid = false;
    }
    else if(tradeMode == SYMBOL_TRADE_MODE_LONGONLY)
    {
        Print("INFO: Only LONG positions allowed for ", symbol);
    }
    else if(tradeMode == SYMBOL_TRADE_MODE_SHORTONLY)
    {
        Print("INFO: Only SHORT positions allowed for ", symbol);
    }
    else if(tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY)
    {
        Print("WARNING: Only position closing allowed for ", symbol);
    }
    else if(tradeMode == SYMBOL_TRADE_MODE_FULL)
    {
        Print("INFO: Full trading enabled for ", symbol);
    }
    else
    {
        Print("WARNING: Unknown trade mode (", tradeMode, ") for ", symbol);
    }
    
    // Market Regime Settings
    if(InpADXTrendThreshold < 15.0 || InpADXTrendThreshold > 40.0)
    {
        Print("ERROR: InpADXTrendThreshold must be between 15.0 and 40.0. Current: ", InpADXTrendThreshold);
        isValid = false;
    }
    
    if(InpADXBreakoutMin < 10.0 || InpADXBreakoutMin > 35.0)
    {
        Print("ERROR: InpADXBreakoutMin must be between 10.0 and 35.0. Current: ", InpADXBreakoutMin);
        isValid = false;
    }
    
    if(InpATRPeriod < 5 || InpATRPeriod > 30)
    {
        Print("ERROR: InpATRPeriod must be between 5 and 30. Current: ", InpATRPeriod);
        isValid = false;
    }
    
    if(InpATRAvgPeriod < 30 || InpATRAvgPeriod > 200)
    {
        Print("ERROR: InpATRAvgPeriod must be between 30 and 200. Current: ", InpATRAvgPeriod);
        isValid = false;
    }
    
    if(InpHighVolMultiplier < 1.0 || InpHighVolMultiplier > 5.0)
    {
        Print("ERROR: InpHighVolMultiplier must be between 1.0 and 5.0. Current: ", InpHighVolMultiplier);
        isValid = false;
    }
    
    // Key Level Detection Settings
    if(InpLookbackPeriod < 100 || InpLookbackPeriod > 1000)
    {
        Print("ERROR: InpLookbackPeriod must be between 100 and 1000. Current: ", InpLookbackPeriod);
        isValid = false;
    }
    
    if(InpMinStrength < 0.20 || InpMinStrength > 0.80)
    {
        Print("ERROR: InpMinStrength must be between 0.20 and 0.80. Current: ", InpMinStrength);
        isValid = false;
    }
    
    if(InpTouchZone != 0.0 && (InpTouchZone < 0.00005 || InpTouchZone > 0.0100))
    {
        Print("ERROR: InpTouchZone must be 0 (auto ATR-based) or between 0.00005 and 0.0100. Current: ", InpTouchZone);
        Print("INFO: For most major pairs, use 0 for automatic ATR-based touch zones");
        isValid = false;
    }
    
    if(InpMinTouches < 1 || InpMinTouches > 5)
    {
        Print("ERROR: InpMinTouches must be between 1 and 5. Current: ", InpMinTouches);
        isValid = false;
    }
    
    // Trading Settings - CRITICAL VALIDATION
    if(InpRiskPctTrend < 0.5 || InpRiskPctTrend > 5.0)
    {
        Print("ERROR: InpRiskPctTrend must be between 0.5 and 5.0. Current: ", InpRiskPctTrend);
        Print("WARNING: High risk percentages can lead to account blowup!");
        isValid = false;
    }
    
    if(InpRiskPctRange < 0.25 || InpRiskPctRange > 3.0)
    {
        Print("ERROR: InpRiskPctRange must be between 0.25 and 3.0. Current: ", InpRiskPctRange);
        isValid = false;
    }
    
    if(InpRiskPctBreakout < 0.5 || InpRiskPctBreakout > 6.0)
    {
        Print("ERROR: InpRiskPctBreakout must be between 0.5 and 6.0. Current: ", InpRiskPctBreakout);
        isValid = false;
    }
    
    if(InpMaxDrawdownPct < 10.0 || InpMaxDrawdownPct > 40.0)
    {
        Print("ERROR: InpMaxDrawdownPct must be between 10.0 and 40.0. Current: ", InpMaxDrawdownPct);
        Print("WARNING: High drawdown limits are dangerous!");
        isValid = false;
    }
    
    if(InpSlippage < 10 || InpSlippage > 100)
    {
        Print("ERROR: InpSlippage must be between 10 and 100. Current: ", InpSlippage);
        isValid = false;
    }
    
    // Signal Settings
    if(InpEMA50Period < 20 || InpEMA50Period > 100)
    {
        Print("ERROR: InpEMA50Period must be between 20 and 100. Current: ", InpEMA50Period);
        isValid = false;
    }
    
    if(InpEMA200Period < 100 || InpEMA200Period > 300)
    {
        Print("ERROR: InpEMA200Period must be between 100 and 300. Current: ", InpEMA200Period);
        isValid = false;
    }
    
    if(InpEMA20Period < 10 || InpEMA20Period > 40)
    {
        Print("ERROR: InpEMA20Period must be between 10 and 40. Current: ", InpEMA20Period);
        isValid = false;
    }
    
    if(InpRSIPeriod < 8 || InpRSIPeriod > 25)
    {
        Print("ERROR: InpRSIPeriod must be between 8 and 25. Current: ", InpRSIPeriod);
        isValid = false;
    }
    
    if(InpStochPeriod < 8 || InpStochPeriod > 25)
    {
        Print("ERROR: InpStochPeriod must be between 8 and 25. Current: ", InpStochPeriod);
        isValid = false;
    }
    
    if(InpStochK < 1 || InpStochK > 8)
    {
        Print("ERROR: InpStochK must be between 1 and 8. Current: ", InpStochK);
        isValid = false;
    }
    
    if(InpStochD < 1 || InpStochD > 8)
    {
        Print("ERROR: InpStochD must be between 1 and 8. Current: ", InpStochD);
        isValid = false;
    }
    
    // Advanced Trend Follower Settings
    if(InpEnableTrendFollower)
    {
        if(InpTFEmaFastPeriod < 20 || InpTFEmaFastPeriod > 100)
        {
            Print("ERROR: InpTFEmaFastPeriod must be between 20 and 100. Current: ", InpTFEmaFastPeriod);
            isValid = false;
        }
        
        if(InpTFEmaSlowPeriod < 100 || InpTFEmaSlowPeriod > 300)
        {
            Print("ERROR: InpTFEmaSlowPeriod must be between 100 and 300. Current: ", InpTFEmaSlowPeriod);
            isValid = false;
        }
        
        if(InpTFEmaFastPeriod >= InpTFEmaSlowPeriod)
        {
            Print("ERROR: InpTFEmaFastPeriod must be less than InpTFEmaSlowPeriod");
            isValid = false;
        }
        
        if(InpTFEmaPullbackPeriod < 10 || InpTFEmaPullbackPeriod > 40)
        {
            Print("ERROR: InpTFEmaPullbackPeriod must be between 10 and 40. Current: ", InpTFEmaPullbackPeriod);
            isValid = false;
        }
        
        if(InpTFRsiThreshold < 30.0 || InpTFRsiThreshold > 70.0)
        {
            Print("ERROR: InpTFRsiThreshold must be between 30.0 and 70.0. Current: ", InpTFRsiThreshold);
            isValid = false;
        }
        
        // Validate ADX period for Trend Follower
        if(InpTFAdxPeriod < 5 || InpTFAdxPeriod > 50)
        {
            Print("ERROR: InpTFAdxPeriod must be between 5 and 50. Current: ", InpTFAdxPeriod);
            isValid = false;
        }
        
        if(InpTFAdxThreshold < 15.0 || InpTFAdxThreshold > 40.0)
        {
            Print("ERROR: InpTFAdxThreshold must be between 15.0 and 40.0. Current: ", InpTFAdxThreshold);
            isValid = false;
        }
    }
    
    // RSI Risk Management Settings
    if(InpEnableMTFRSI)
    {
        if(InpH4RSIOverbought < 60.0 || InpH4RSIOverbought > 85.0)
        {
            Print("ERROR: InpH4RSIOverbought must be between 60.0 and 85.0. Current: ", InpH4RSIOverbought);
            isValid = false;
        }
        
        if(InpH4RSIOversold < 15.0 || InpH4RSIOversold > 40.0)
        {
            Print("ERROR: InpH4RSIOversold must be between 15.0 and 40.0. Current: ", InpH4RSIOversold);
            isValid = false;
        }
        
        if(InpUseD1RSI)
        {
            if(InpD1RSIOverbought < 65.0 || InpD1RSIOverbought > 85.0)
            {
                Print("ERROR: InpD1RSIOverbought must be between 65.0 and 85.0. Current: ", InpD1RSIOverbought);
                isValid = false;
            }
            
            if(InpD1RSIOversold < 15.0 || InpD1RSIOversold > 35.0)
            {
                Print("ERROR: InpD1RSIOversold must be between 15.0 and 35.0. Current: ", InpD1RSIOversold);
                isValid = false;
            }
        }
    }
    
    if(InpEnableRSIExits)
    {
        if(InpRSIExitOB < 60.0 || InpRSIExitOB > 85.0)
        {
            Print("ERROR: InpRSIExitOB must be between 60.0 and 85.0. Current: ", InpRSIExitOB);
            isValid = false;
        }
        
        if(InpRSIExitOS < 15.0 || InpRSIExitOS > 40.0)
        {
            Print("ERROR: InpRSIExitOS must be between 15.0 and 40.0. Current: ", InpRSIExitOS);
            isValid = false;
        }
        
        if(InpRSIPartialClose < 0.1 || InpRSIPartialClose > 0.9)
        {
            Print("ERROR: InpRSIPartialClose must be between 0.1 and 0.9. Current: ", InpRSIPartialClose);
            isValid = false;
        }
        
        if(InpRSIExitMinProfitPips < 0 || InpRSIExitMinProfitPips > 100)
        {
            Print("ERROR: InpRSIExitMinProfitPips must be between 0 and 100. Current: ", InpRSIExitMinProfitPips);
            isValid = false;
        }
    }
    
    // Update Settings
    if(InpRegimeUpdateSeconds < 1 || InpRegimeUpdateSeconds > 30)
    {
        Print("ERROR: InpRegimeUpdateSeconds must be between 1 and 30. Current: ", InpRegimeUpdateSeconds);
        isValid = false;
    }
    
    if(InpKeyLevelUpdateSeconds < 60 || InpKeyLevelUpdateSeconds > 1800)
    {
        Print("ERROR: InpKeyLevelUpdateSeconds must be between 60 and 1800. Current: ", InpKeyLevelUpdateSeconds);
        isValid = false;
    }
    
    // Database Settings
    if(InpDataCollectionInterval < 30 || InpDataCollectionInterval > 3600)
    {
        Print("ERROR: InpDataCollectionInterval must be between 30 and 3600. Current: ", InpDataCollectionInterval);
        isValid = false;
    }
    
    if(InpFinBERTAnalysisInterval < 60 || InpFinBERTAnalysisInterval > 1800)
    {
        Print("ERROR: InpFinBERTAnalysisInterval must be between 60 and 1800. Current: ", InpFinBERTAnalysisInterval);
        isValid = false;
    }
    
    if(isValid && InpLogDebugInfo)
    {
        Print("✅ All input parameters validated successfully");
    }
    else if(!isValid)
    {
        Print("❌ Parameter validation failed. Please correct the errors above.");
    }
    
    return isValid;
}

//+------------------------------------------------------------------+
//| Close All Positions FIFO (oldest first)                          |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    // Fallback method when risk manager is not available
    int totalPositions = PositionsTotal();
    int closedCount = 0;

    // Collect matching tickets and times
    ulong tickets[];
    long  times[];
    ArrayResize(tickets, 0);
    ArrayResize(times, 0);

    for(int i = 0; i < totalPositions; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket))
            continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
        ArrayResize(tickets, ArraySize(tickets) + 1);
        ArrayResize(times, ArraySize(times) + 1);
        tickets[ArraySize(tickets) - 1] = ticket;
        times[ArraySize(times) - 1] = (long)PositionGetInteger(POSITION_TIME);
    }

    // Sort by open time ascending (oldest first)
    int n = ArraySize(tickets);
    for(int a = 0; a < n - 1; a++)
    {
        for(int b = a + 1; b < n; b++)
        {
            if(times[a] > times[b])
            {
                long  tTime = times[a];
                times[a] = times[b];
                times[b] = tTime;
                ulong tTicket = tickets[a];
                tickets[a] = tickets[b];
                tickets[b] = tTicket;
            }
        }
    }

    // Close in FIFO order
    for(int i = 0; i < n; i++)
    {
        ulong ticket = tickets[i];
        if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == _Symbol)
        {
            // Always-on concise rationale for closing
            double po = PositionGetDouble(POSITION_PRICE_OPEN);
            double pc = PositionGetDouble(POSITION_PRICE_CURRENT);
            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);
            ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            Print(StringFormat("[CLOSE] ATTEMPT ticket=%I64u %s open=%s curr=%s sl=%s tp=%s reason=manual_close_all",
                               ticket,
                               (ptype==POSITION_TYPE_BUY?"BUY":"SELL"),
                               DoubleToString(po, _Digits),
                               DoubleToString(pc, _Digits),
                               DoubleToString(sl, _Digits),
                               DoubleToString(tp, _Digits)));
            if(g_trade.PositionClose(ticket))
            {
                closedCount++;
                Print(StringFormat("[CLOSE] ✅ SUCCESS ticket=%I64u (%d of %d)", ticket, closedCount, n));
            }
            else
            {
                int error = GetLastError();
                Print(StringFormat("[CLOSE] ❌ FAIL ticket=%I64u", ticket));
                Print(StringFormat("[CLOSE] ❌ Error: %d - %s", error, ErrorDescription(error)));
                Print(StringFormat("[CLOSE] ❌ Trade Result: %d", g_trade.ResultRetcode()));
                Print("[CLOSE] ❌ Continuing with next position...");
            }
        }
    }

    Print(StringFormat("[CLOSE] SUMMARY closed=%d symbol=%s", closedCount, _Symbol));
} 

//+------------------------------------------------------------------+
//| Close a specific ticket FIFO-safe                                 |
//+------------------------------------------------------------------+
bool ClosePositionFifoSafe(const ulong requestedTicket)
{
    if(!PositionSelectByTicket(requestedTicket))
        return false;

    string symbol = PositionGetString(POSITION_SYMBOL);
    ENUM_POSITION_TYPE side = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double vol = PositionGetDouble(POSITION_VOLUME);

    double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    if(step <= 0.0)
        step = 0.01;

    ulong oldestTicket = 0;
    long oldestTime = LONG_MAX;

    int total = PositionsTotal();
    for(int i = 0; i < total; i++)
    {
        ulong t = PositionGetTicket(i);
        if(!PositionSelectByTicket(t))
            continue;
        if(PositionGetString(POSITION_SYMBOL) != symbol)
            continue;
        if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side)
            continue;
        double v = PositionGetDouble(POSITION_VOLUME);
        if(MathAbs(v - vol) > step / 2.0)
            continue;
        long timeOpen = (long)PositionGetInteger(POSITION_TIME);
        if(timeOpen < oldestTime)
        {
            oldestTime = timeOpen;
            oldestTicket = t;
        }
    }

    if(oldestTicket == 0)
        return false;

    if(requestedTicket != oldestTicket && InpLogDetailedInfo)
        Print("[Grande] FIFO guard rerouted close from #", requestedTicket, " to oldest #", oldestTicket);

    return g_trade.PositionClose(oldestTicket);
}

//+------------------------------------------------------------------+
//| Close volume FIFO-safe for symbol and side                        |
//+------------------------------------------------------------------+
double CloseSymbolFifoVolume(const string symbol,
                             const ENUM_POSITION_TYPE side,
                             double volumeToClose)
{
    if(volumeToClose <= 0.0)
        return 0.0;

    double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    double volMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double volMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    if(step <= 0.0) step = 0.01;
    if(volMin <= 0.0) volMin = step;

    // helper to normalize to volume step
    double normalizeVol;
    normalizeVol = 0.0; // placeholder to appease compiler before first use

    double remaining = volumeToClose;
    double closed = 0.0;

    while(remaining > 0.0)
    {
        ulong oldestTicket = 0;
        long oldestTime = LONG_MAX;
        double oldestVolume = 0.0;

        int total = PositionsTotal();
        for(int i = 0; i < total; i++)
        {
            ulong t = PositionGetTicket(i);
            if(!PositionSelectByTicket(t))
                continue;
            if(PositionGetString(POSITION_SYMBOL) != symbol)
                continue;
            if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side)
                continue;
            long timeOpen = (long)PositionGetInteger(POSITION_TIME);
            if(timeOpen < oldestTime)
            {
                oldestTime = timeOpen;
                oldestTicket = t;
                oldestVolume = PositionGetDouble(POSITION_VOLUME);
            }
        }

        if(oldestTicket == 0)
            break;

        double allowable = MathMin(remaining, oldestVolume);
        double n = MathFloor(allowable / step + 1e-8) * step;
        if(n < 0.0) n = 0.0;
        allowable = n;
        if(allowable < volMin - 1e-12)
            break;

        bool ok;
        if(allowable + step/2.0 < oldestVolume)
            ok = g_trade.PositionClosePartial(oldestTicket, allowable);
        else
            ok = g_trade.PositionClose(oldestTicket);

        if(!ok)
        {
            // ALWAYS LOG FIFO FAILURES - CRITICAL
            int error = GetLastError();
            Print(StringFormat("[Grande] ⚠️ FIFO CLOSE FAILED for position #%I64u", oldestTicket));
            Print(StringFormat("[Grande] ⚠️ Error: %d - %s", error, ErrorDescription(error)));
            Print(StringFormat("[Grande] ⚠️ Attempted volume: %.2f, Position volume: %.2f", allowable, oldestVolume));
            Print(StringFormat("[Grande] ⚠️ Trade Result Code: %d", g_trade.ResultRetcode()));
            Print("[Grande] ⚠️ FIFO closing sequence ABORTED due to error");
            break;
        }
        else
        {
            Print(StringFormat("[Grande] ✅ FIFO closed %.2f lots of position #%I64u successfully", 
                  allowable, oldestTicket));
        }

        closed += allowable;
        remaining -= allowable;
    }

    return closed;
}


//+------------------------------------------------------------------+
//| Check for Conflicting Positions                                 |
//+------------------------------------------------------------------+
bool HasConflictingPosition(ENUM_ORDER_TYPE orderType)
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetTicket(i) > 0)
        {
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            // Check for opposite direction conflicts
            if((orderType == ORDER_TYPE_BUY && posType == POSITION_TYPE_SELL) ||
               (orderType == ORDER_TYPE_SELL && posType == POSITION_TYPE_BUY))
            {
                return true;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Calculate Current Account Risk Percentage                       |
//+------------------------------------------------------------------+
double CalculateCurrentAccountRisk()
{
    double totalRisk = 0.0;
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetTicket(i) > 0)
        {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double stopLoss = PositionGetDouble(POSITION_SL);
            double volume = PositionGetDouble(POSITION_VOLUME);
            
            if(stopLoss > 0)
            {
                double riskAmount = MathAbs(openPrice - stopLoss) * volume;
                totalRisk += (riskAmount / accountBalance) * 100;
            }
        }
    }
    
    return totalRisk;
}

//+------------------------------------------------------------------+
//| Validate Margin Before Trade                                     |
//| Returns true if sufficient margin available, false otherwise     |
//+------------------------------------------------------------------+
bool ValidateMarginBeforeTrade(ENUM_ORDER_TYPE orderType, double lotSize, double entryPrice, string tradeContext = "")
{
    string logPrefix = StringFormat("[MARGIN CHECK%s] ", (tradeContext != "" ? " " + tradeContext : ""));
    
    // Get account information
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double accountFreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    double accountMargin = AccountInfoDouble(ACCOUNT_MARGIN);
    
    // Calculate current margin level FIRST - block all trades if current margin is too low
    double currentMarginLevel = (accountMargin > 0) ? (accountEquity / accountMargin * 100.0) : 0.0;
    
    // CRITICAL: Don't open new positions if current margin level is already below minimum threshold
    if(accountMargin > 0 && currentMarginLevel < InpMinMarginLevelToTrade)
    {
        Print(logPrefix + "BLOCKED: Current margin level too low to open new positions");
        Print(logPrefix + "  Current margin level: ", DoubleToString(currentMarginLevel, 2), "%");
        Print(logPrefix + "  Minimum required to trade: ", DoubleToString(InpMinMarginLevelToTrade, 2), "%");
        Print(logPrefix + "  Balance: $", DoubleToString(accountBalance, 2));
        Print(logPrefix + "  Equity: $", DoubleToString(accountEquity, 2));
        Print(logPrefix + "  Margin: $", DoubleToString(accountMargin, 2));
        Print(logPrefix + "Trade BLOCKED - Wait for margin level to recover");
        // Publish margin warning event
        PublishRiskEvent(EVENT_MARGIN_WARNING, 
                        StringFormat("Margin level too low: %.2f%% (min: %.2f%%)", currentMarginLevel, InpMinMarginLevelToTrade),
                        currentMarginLevel);
        return false;
    }
    
    // Calculate required margin for the trade
    double requiredMargin = 0.0;
    if(!OrderCalcMargin(orderType, _Symbol, lotSize, entryPrice, requiredMargin))
    {
        Print(logPrefix + "CRITICAL: Failed to calculate required margin");
        return false;
    }
    
    // Check if we have sufficient free margin
    if(requiredMargin > accountFreeMargin)
    {
        Print(logPrefix + "CRITICAL: Insufficient margin");
        Print(logPrefix + "  Required: $", DoubleToString(requiredMargin, 2));
        Print(logPrefix + "  Available: $", DoubleToString(accountFreeMargin, 2));
        Print(logPrefix + "  Balance: $", DoubleToString(accountBalance, 2));
        Print(logPrefix + "  Equity: $", DoubleToString(accountEquity, 2));
        Print(logPrefix + "Trade BLOCKED to prevent 'No money' error");
        // Publish margin warning event
        PublishRiskEvent(EVENT_MARGIN_WARNING,
                        StringFormat("Insufficient margin: Required $%.2f, Available $%.2f", requiredMargin, accountFreeMargin),
                        accountFreeMargin);
        return false;
    }
    
    // Calculate margin level after this trade
    double marginLevelAfterTrade = ((accountMargin + requiredMargin) > 0) ? 
                                   (accountEquity / (accountMargin + requiredMargin) * 100.0) : 0.0;
    
    // Don't trade if margin level would drop below 200%
    if(accountMargin > 0 && marginLevelAfterTrade < 200.0)
    {
        Print(logPrefix + "CRITICAL: Margin level too low after trade");
        Print(logPrefix + "  Current margin level: ", DoubleToString(currentMarginLevel, 1), "%");
        Print(logPrefix + "  After trade would be: ", DoubleToString(marginLevelAfterTrade, 1), "%");
        Print(logPrefix + "  Minimum required: 200.0%");
        Print(logPrefix + "Trade BLOCKED for account safety");
        // Publish margin warning event
        PublishRiskEvent(EVENT_MARGIN_WARNING,
                        StringFormat("Margin level would drop to %.1f%% after trade (min: 200%%)", marginLevelAfterTrade),
                        marginLevelAfterTrade);
        return false;
    }
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "Margin validation PASSED");
        Print(logPrefix + "  Required margin: $", DoubleToString(requiredMargin, 2));
        Print(logPrefix + "  Free margin: $", DoubleToString(accountFreeMargin, 2));
        Print(logPrefix + "  Margin level after: ", DoubleToString(marginLevelAfterTrade, 1), "%");
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Emergency Margin Protection                                      |
//| Monitors margin level and takes protective action when critical  |
//+------------------------------------------------------------------+
void CheckEmergencyMarginProtection()
{
    if(!InpEnableMarginProtection)
        return;
    
    // Get current margin information
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double accountFreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    double accountMargin = AccountInfoDouble(ACCOUNT_MARGIN);
    
    if(accountMargin <= 0)
        return; // No positions open, no margin risk
    
    // Calculate current margin level
    double marginLevel = (accountEquity / accountMargin) * 100.0;
    
    // Track last margin level for state changes
    static double lastMarginLevel = 0.0;
    static bool warningShown = false;
    static bool criticalShown = false;
    static bool emergencyShown = false;
    
    // Reset flags if margin recovers
    if(marginLevel > InpMarginWarningLevel)
    {
        warningShown = false;
        criticalShown = false;
        emergencyShown = false;
        lastMarginLevel = marginLevel;
        return;
    }
    
    // EMERGENCY LEVEL: Close positions immediately
    if(marginLevel <= InpMarginEmergencyLevel)
    {
        if(!emergencyShown || marginLevel != lastMarginLevel)
        {
            Print("========================================");
            Print("[MARGIN PROTECTION] EMERGENCY: Margin level at ", DoubleToString(marginLevel, 2), "%");
            Print("[MARGIN PROTECTION] Balance: $", DoubleToString(accountBalance, 2));
            Print("[MARGIN PROTECTION] Equity: $", DoubleToString(accountEquity, 2));
            Print("[MARGIN PROTECTION] Margin: $", DoubleToString(accountMargin, 2));
            Print("[MARGIN PROTECTION] Free Margin: $", DoubleToString(accountFreeMargin, 2));
            Print("[MARGIN PROTECTION] Closing positions to prevent liquidation!");
            Print("========================================");
            emergencyShown = true;
            
            // Publish critical margin event
            PublishRiskEvent(EVENT_MARGIN_CRITICAL,
                            StringFormat("EMERGENCY: Margin level at %.2f%% - Closing positions to prevent liquidation", marginLevel),
                            marginLevel);
        }
        
        // Cancel all pending orders immediately
        CancelPendingOrdersForMarginProtection();
        
        // Close worst-performing positions
        int positionsClosed = CloseWorstPositionsForMargin(InpMaxPositionsToClose);
        
        if(positionsClosed > 0)
        {
            Print("[MARGIN PROTECTION] Closed ", positionsClosed, " position(s) in emergency response");
        }
    }
    // CRITICAL LEVEL: Close some positions and cancel pending orders
    else if(marginLevel <= InpMarginCriticalLevel)
    {
        if(!criticalShown || marginLevel != lastMarginLevel)
        {
            Print("========================================");
            Print("[MARGIN PROTECTION] CRITICAL: Margin level at ", DoubleToString(marginLevel, 2), "%");
            Print("[MARGIN PROTECTION] Balance: $", DoubleToString(accountBalance, 2));
            Print("[MARGIN PROTECTION] Equity: $", DoubleToString(accountEquity, 2));
            Print("[MARGIN PROTECTION] Taking protective action...");
            Print("========================================");
            criticalShown = true;
        }
        
        // Cancel pending orders to prevent further margin usage
        CancelPendingOrdersForMarginProtection();
        
        // Close worst-performing positions (fewer than emergency)
        int positionsToClose = MathMax(1, InpMaxPositionsToClose / 2);
        int positionsClosed = CloseWorstPositionsForMargin(positionsToClose);
        
        if(positionsClosed > 0)
        {
            Print("[MARGIN PROTECTION] Closed ", positionsClosed, " position(s) in critical response");
        }
    }
    // WARNING LEVEL: Log warning and cancel pending orders
    else if(marginLevel <= InpMarginWarningLevel)
    {
        if(!warningShown || marginLevel != lastMarginLevel)
        {
            Print("[MARGIN PROTECTION] WARNING: Margin level at ", DoubleToString(marginLevel, 2), "%");
            Print("[MARGIN PROTECTION] Balance: $", DoubleToString(accountBalance, 2));
            Print("[MARGIN PROTECTION] Equity: $", DoubleToString(accountEquity, 2));
            Print("[MARGIN PROTECTION] Free Margin: $", DoubleToString(accountFreeMargin, 2));
            Print("[MARGIN PROTECTION] Cancelling pending orders to preserve margin");
            warningShown = true;
        }
        
        // Cancel pending orders to prevent further margin usage
        CancelPendingOrdersForMarginProtection();
    }
    
    lastMarginLevel = marginLevel;
}

//+------------------------------------------------------------------+
//| Cancel Pending Orders for Margin Protection                      |
//| Cancels all pending orders to free up margin                    |
//+------------------------------------------------------------------+
void CancelPendingOrdersForMarginProtection()
{
    int ordersCancelled = 0;
    
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        
        // Check if order is ours
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        if((int)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
        
        // Cancel the order
        if(g_trade.OrderDelete(ticket))
        {
            ordersCancelled++;
            Print("[MARGIN PROTECTION] Cancelled pending order #", ticket, " to preserve margin");
        }
        else
        {
            Print("[MARGIN PROTECTION] Failed to cancel order #", ticket, " (error: ", GetLastError(), ")");
        }
    }
    
    if(ordersCancelled > 0)
    {
        Print("[MARGIN PROTECTION] Cancelled ", ordersCancelled, " pending order(s)");
    }
}

//+------------------------------------------------------------------+
//| Close Worst Positions for Margin                                 |
//| Closes worst-performing positions to free up margin             |
//+------------------------------------------------------------------+
int CloseWorstPositionsForMargin(int maxPositionsToClose)
{
    if(maxPositionsToClose <= 0)
        return 0;
    
    // Collect all positions with their profit/loss
    struct PositionInfo
    {
        ulong ticket;
        double profit;
        double margin;
        string symbol;
    };
    
    PositionInfo positions[];
    ArrayResize(positions, 0);
    
    // Collect position information
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        if(!PositionSelectByTicket(ticket)) continue;
        
        // Check if position is ours
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        
        PositionInfo pos;
        pos.ticket = ticket;
        // Use profit calculator for consistent profit calculation
        if(g_profitCalculator != NULL)
            pos.profit = g_profitCalculator.CalculatePositionProfitCurrency(ticket);
        else
            pos.profit = PositionGetDouble(POSITION_PROFIT);
        pos.symbol = PositionGetString(POSITION_SYMBOL);
        
        // Calculate margin used by this position
        double volume = PositionGetDouble(POSITION_VOLUME);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
        ENUM_ORDER_TYPE calcType = (orderType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
        
        if(OrderCalcMargin(calcType, pos.symbol, volume, openPrice, pos.margin))
        {
            int size = ArraySize(positions);
            ArrayResize(positions, size + 1);
            positions[size] = pos;
        }
    }
    
    if(ArraySize(positions) == 0)
        return 0;
    
    // Sort positions by profit (worst first if InpCloseWorstPositionsFirst, otherwise by margin)
    if(InpCloseWorstPositionsFirst)
    {
        // Sort by profit ascending (worst losses first)
        for(int i = 0; i < ArraySize(positions) - 1; i++)
        {
            for(int j = i + 1; j < ArraySize(positions); j++)
            {
                if(positions[i].profit > positions[j].profit)
                {
                    PositionInfo temp = positions[i];
                    positions[i] = positions[j];
                    positions[j] = temp;
                }
            }
        }
    }
    else
    {
        // Sort by margin descending (largest margin first)
        for(int i = 0; i < ArraySize(positions) - 1; i++)
        {
            for(int j = i + 1; j < ArraySize(positions); j++)
            {
                if(positions[i].margin < positions[j].margin)
                {
                    PositionInfo temp = positions[i];
                    positions[i] = positions[j];
                    positions[j] = temp;
                }
            }
        }
    }
    
    // Close the worst positions
    int positionsClosed = 0;
    int toClose = MathMin(maxPositionsToClose, ArraySize(positions));
    
    for(int i = 0; i < toClose; i++)
    {
        ulong ticket = positions[i].ticket;
        double profit = positions[i].profit;
        double margin = positions[i].margin;
        
        if(g_trade.PositionClose(ticket))
        {
            positionsClosed++;
            Print("[MARGIN PROTECTION] Closed position #", ticket, 
                  " (Profit: $", DoubleToString(profit, 2), 
                  ", Margin: $", DoubleToString(margin, 2), ")");
        }
        else
        {
            Print("[MARGIN PROTECTION] Failed to close position #", ticket, 
                  " (error: ", GetLastError(), ")");
        }
    }
    
    return positionsClosed;
}

//+------------------------------------------------------------------+
//| Get Regime String for Display                                   |
//+------------------------------------------------------------------+
string GetRegimeString(MARKET_REGIME regime)
{
    switch(regime)
    {
        case REGIME_TREND_BULL:      return "TREND-BULL";
        case REGIME_TREND_BEAR:      return "TREND-BEAR";
        case REGIME_BREAKOUT_SETUP:  return "BREAKOUT";
        case REGIME_RANGING:         return "RANGING";
        case REGIME_HIGH_VOLATILITY: return "HIGH-VOL";
        default:                     return "UNKNOWN";
    }
}


//+------------------------------------------------------------------+
//| New helpers: symbol/magic checks, normalization, stops, pending  |
//+------------------------------------------------------------------+
bool HasOpenPositionForSymbolAndMagic(const string symbol, const int magic)
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        if(!PositionSelectByTicket(ticket)) continue;
        if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Database Market Data Collection                                  |
//+------------------------------------------------------------------+
void CollectMarketDataForDatabase()
{
    if(g_databaseManager == NULL || !g_databaseManager.IsConnected())
        return;
    
    datetime currentTime = TimeCurrent();
    
    // Check if we should collect data (based on interval)
    datetime lastDataCollectionTime = (g_stateManager != NULL) ? g_stateManager.GetLastDataCollectionTime() : 0;
    if((currentTime - lastDataCollectionTime) < InpDataCollectionInterval)
        return;
    
    // Check if we have a new bar
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    datetime lastBarTime = (g_stateManager != NULL) ? g_stateManager.GetLastBarTime() : 0;
    if(currentBarTime == lastBarTime)
        return;
    
    if(g_stateManager != NULL)
    {
        g_stateManager.SetLastBarTime(currentBarTime);
        g_stateManager.SetLastDataCollectionTime(currentTime);
    }
    
    // Get current bar data
    double open = iOpen(_Symbol, PERIOD_CURRENT, 0);
    double high = iHigh(_Symbol, PERIOD_CURRENT, 0);
    double low = iLow(_Symbol, PERIOD_CURRENT, 0);
    double close = iClose(_Symbol, PERIOD_CURRENT, 0);
    double volume = iRealVolume(_Symbol, PERIOD_CURRENT, 0);
    
    // Validate data
    if(open <= 0 || high <= 0 || low <= 0 || close <= 0)
        return;
    
    // Get indicator values
    double atr = 0, adx_h1 = 0, adx_h4 = 0, adx_d1 = 0;
    double rsi_current = 0, rsi_h4 = 0, rsi_d1 = 0;
    double ema_20 = 0, ema_50 = 0, ema_200 = 0;
    double stoch_k = 0, stoch_d = 0;
    
    // ATR
    int atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
    if(atrHandle != INVALID_HANDLE)
    {
        double atrBuffer[];
        if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0)
            atr = atrBuffer[0];
        IndicatorRelease(atrHandle);
    }
    
    // ADX values
    if(g_regimeDetector != NULL)
    {
        RegimeSnapshot rs = g_regimeDetector.DetectCurrentRegime();
        adx_h1 = rs.adx_h1;
        adx_h4 = rs.adx_h4;
        adx_d1 = rs.adx_d1;
    }
    
    // RSI values
    rsi_current = GetRSIValue(_Symbol, PERIOD_CURRENT, InpRSIPeriod, 0);
    rsi_h4 = GetRSIValue(_Symbol, PERIOD_H4, InpTFRsiPeriod, 0);
    rsi_d1 = InpUseD1RSI ? GetRSIValue(_Symbol, PERIOD_D1, InpTFRsiPeriod, 0) : 0;
    
    // EMA values
    int ema20Handle = iMA(_Symbol, PERIOD_CURRENT, InpEMA20Period, 0, MODE_EMA, PRICE_CLOSE);
    int ema50Handle = iMA(_Symbol, PERIOD_CURRENT, InpEMA50Period, 0, MODE_EMA, PRICE_CLOSE);
    int ema200Handle = iMA(_Symbol, PERIOD_CURRENT, InpEMA200Period, 0, MODE_EMA, PRICE_CLOSE);
    
    if(ema20Handle != INVALID_HANDLE)
    {
        double emaBuffer[];
        if(CopyBuffer(ema20Handle, 0, 0, 1, emaBuffer) > 0)
            ema_20 = emaBuffer[0];
        IndicatorRelease(ema20Handle);
    }
    
    if(ema50Handle != INVALID_HANDLE)
    {
        double emaBuffer[];
        if(CopyBuffer(ema50Handle, 0, 0, 1, emaBuffer) > 0)
            ema_50 = emaBuffer[0];
        IndicatorRelease(ema50Handle);
    }
    
    if(ema200Handle != INVALID_HANDLE)
    {
        double emaBuffer[];
        if(CopyBuffer(ema200Handle, 0, 0, 1, emaBuffer) > 0)
            ema_200 = emaBuffer[0];
        IndicatorRelease(ema200Handle);
    }
    
    // Stochastic values
    int stochHandle = iStochastic(_Symbol, PERIOD_CURRENT, InpStochPeriod, InpStochK, InpStochD, MODE_SMA, STO_LOWHIGH);
    if(stochHandle != INVALID_HANDLE)
    {
        double stochKBuffer[], stochDBuffer[];
        if(CopyBuffer(stochHandle, 0, 0, 1, stochKBuffer) > 0 && CopyBuffer(stochHandle, 1, 0, 1, stochDBuffer) > 0)
        {
            stoch_k = stochKBuffer[0];
            stoch_d = stochDBuffer[0];
        }
        IndicatorRelease(stochHandle);
    }
    
    // Insert market data into database
    bool success = g_databaseManager.InsertMarketData(
        _Symbol, 
        Period(), 
        currentBarTime, 
        open, high, low, close, volume,
        atr, adx_h1, adx_h4, adx_d1,
        rsi_current, rsi_h4, rsi_d1,
        ema_20, ema_50, ema_200,
        stoch_k, stoch_d
    );
    
    if(!success && InpDatabaseDebug)
    {
        Print("[GrandeDB] Failed to insert market data for bar: ", TimeToString(currentBarTime));
    }
    
    // Also insert regime data if available
    if(g_regimeDetector != NULL)
    {
        RegimeSnapshot rs = g_regimeDetector.DetectCurrentRegime();
        string regimeStr = g_regimeDetector.RegimeToString(rs.regime);
        string volatilityLevel = "NORMAL";
        
        if(rs.atr_current > 0 && atr > 0)
        {
            double atrRatio = rs.atr_current / atr;
            if(atrRatio > InpHighVolMultiplier)
                volatilityLevel = "HIGH";
            else if(atrRatio < 0.5)
                volatilityLevel = "LOW";
        }
        
        g_databaseManager.InsertRegimeData(
            _Symbol,
            currentBarTime,
            regimeStr,
            rs.confidence,
            rs.adx_h1, rs.adx_h4, rs.adx_d1,
            rs.atr_current,
            volatilityLevel
        );
    }
    
    // Publish data collection event
    if(g_eventBus != NULL)
    {
        g_eventBus.PublishEvent(EVENT_DATA_COLLECTED, "DataCollector", 
                               "Market data collected and saved to database", 0.0, 0);
    }
}

//+------------------------------------------------------------------+
//| Enhanced Market Data Collection for FinBERT Analysis            |
//+------------------------------------------------------------------+
void CollectEnhancedMarketDataForFinBERT()
{
    datetime currentTime = TimeCurrent();
    
    // Check if we should collect data (based on FinBERT analysis interval)
    datetime lastFinBERTAnalysisTime = (g_stateManager != NULL) ? g_stateManager.GetLastFinBERTAnalysisTime() : 0;
    if((currentTime - lastFinBERTAnalysisTime) < InpFinBERTAnalysisInterval)
        return;
    
    // TEMPORARY: Skip bar check for immediate testing
    // Check if we have a new bar
    // datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    // datetime lastBarTime = (g_stateManager != NULL) ? g_stateManager.GetLastBarTime() : 0;
    // if(currentBarTime == lastBarTime)
    //     return;
    
    if(g_stateManager != NULL)
        g_stateManager.SetLastFinBERTAnalysisTime(currentTime);
    
    // Create comprehensive market context JSON
    string marketContextJson = CreateComprehensiveMarketContext();
    
    // Save to file for FinBERT analysis
    SaveMarketContextToFile(marketContextJson);
    
    // Publish data collection event
    if(g_eventBus != NULL)
    {
        g_eventBus.PublishEvent(EVENT_DATA_COLLECTED, "DataCollector", 
                               "Enhanced FinBERT market data collected and saved", 0.0, 0);
    }
    
    if(InpLogDetailedInfo)
    {
        Print("[GrandeFinBERT] Enhanced market data collected and saved for analysis");
    }
}

//+------------------------------------------------------------------+
//| Create Comprehensive Market Context JSON                         |
//+------------------------------------------------------------------+
string CreateComprehensiveMarketContext()
{
    datetime currentTime = TimeCurrent();
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double open = iOpen(_Symbol, PERIOD_CURRENT, 0);
    double high = iHigh(_Symbol, PERIOD_CURRENT, 0);
    double low = iLow(_Symbol, PERIOD_CURRENT, 0);
    double close = iClose(_Symbol, PERIOD_CURRENT, 0);
    double volume = iRealVolume(_Symbol, PERIOD_CURRENT, 0);
    
    // Calculate price change
    double changePips = (close - open) / _Point;
    double changePercent = ((close - open) / open) * 100.0;
    
    // Get volume average
    double volumeAverage = GetVolumeAverage(20);
    double volumeRatio = volumeAverage > 0 ? volume / volumeAverage : 1.0;
    
    // Get technical indicators
    double atr = GetATRValue();
    double atrAverage = GetATRAverage(90);
    double rsiCurrent = GetRSIValue(_Symbol, PERIOD_CURRENT, InpRSIPeriod, 0);
    double rsiH4 = GetRSIValue(_Symbol, PERIOD_H4, InpTFRsiPeriod, 0);
    double rsiD1 = InpUseD1RSI ? GetRSIValue(_Symbol, PERIOD_D1, InpTFRsiPeriod, 0) : 0;
    
    // Get EMA values
    double ema20 = GetEMAValue(InpEMA20Period);
    double ema50 = GetEMAValue(InpEMA50Period);
    double ema200 = GetEMAValue(InpEMA200Period);
    
    // Determine trend direction and strength
    string trendDirection = "NEUTRAL";
    double trendStrength = 0.0;
    if(ema20 > ema50 && ema50 > ema200)
    {
        trendDirection = "BULLISH";
        trendStrength = MathMin(1.0, (ema20 - ema200) / (ema200 * 0.01));
    }
    else if(ema20 < ema50 && ema50 < ema200)
    {
        trendDirection = "BEARISH";
        trendStrength = MathMin(1.0, (ema200 - ema20) / (ema200 * 0.01));
    }
    
    // Get RSI status
    string rsiStatus = "NEUTRAL";
    if(rsiCurrent > 70) rsiStatus = "OVERBOUGHT";
    else if(rsiCurrent < 30) rsiStatus = "OVERSOLD";
    else if(rsiCurrent > 60) rsiStatus = "NEUTRAL_TO_BULLISH";
    else if(rsiCurrent < 40) rsiStatus = "NEUTRAL_TO_BEARISH";
    
    // Get stochastic values
    double stochK = 0, stochD = 0;
    int stochHandle = iStochastic(_Symbol, PERIOD_CURRENT, InpStochPeriod, InpStochK, InpStochD, MODE_SMA, STO_LOWHIGH);
    if(stochHandle != INVALID_HANDLE)
    {
        double stochKBuffer[], stochDBuffer[];
        if(CopyBuffer(stochHandle, 0, 0, 1, stochKBuffer) > 0 && CopyBuffer(stochHandle, 1, 0, 1, stochDBuffer) > 0)
        {
            stochK = stochKBuffer[0];
            stochD = stochDBuffer[0];
        }
        IndicatorRelease(stochHandle);
    }
    
    string stochSignal = "NEUTRAL";
    if(stochK > 80) stochSignal = "OVERBOUGHT_WARNING";
    else if(stochK < 20) stochSignal = "OVERSOLD_WARNING";
    
    // Get volatility level
    string volatilityLevel = "NORMAL";
    if(atrAverage > 0)
    {
        double atrRatio = atr / atrAverage;
        if(atrRatio > InpHighVolMultiplier)
            volatilityLevel = "ABOVE_AVERAGE";
        else if(atrRatio < 0.5)
            volatilityLevel = "BELOW_AVERAGE";
    }
    
    // Get market regime
    string currentRegime = "RANGING";
    double regimeConfidence = 0.0;
    double adxH1 = 0, adxH4 = 0, adxD1 = 0;
    double plusDI = 0, minusDI = 0;
    
    if(g_regimeDetector != NULL)
    {
        RegimeSnapshot rs = g_regimeDetector.DetectCurrentRegime();
        currentRegime = g_regimeDetector.RegimeToString(rs.regime);
        regimeConfidence = rs.confidence;
        adxH1 = rs.adx_h1;
        adxH4 = rs.adx_h4;
        adxD1 = rs.adx_d1;
        plusDI = rs.plus_di;
        minusDI = rs.minus_di;
    }
    
    // Get key levels
    string keyLevelsJson = GetKeyLevelsJson();
    
    // Get economic calendar data
    string economicCalendarJson = GetEconomicCalendarJson();
    
    // Build comprehensive JSON
    string json = "{";
    json += "\"timestamp\":\"" + TimeToString(currentTime, TIME_DATE|TIME_SECONDS) + "\",";
    json += "\"symbol\":\"" + _Symbol + "\",";
    json += "\"timeframe\":\"" + EnumToString(Period()) + "\",";
    json += "\"market_data\":{";
    json += "\"price\":{";
    json += "\"current\":" + DoubleToString(currentPrice, _Digits) + ",";
    json += "\"open\":" + DoubleToString(open, _Digits) + ",";
    json += "\"high\":" + DoubleToString(high, _Digits) + ",";
    json += "\"low\":" + DoubleToString(low, _Digits) + ",";
    json += "\"change_pips\":" + DoubleToString(changePips, 1) + ",";
    json += "\"change_percent\":" + DoubleToString(changePercent, 3);
    json += "},";
    json += "\"volume\":{";
    json += "\"current\":" + DoubleToString(volume, 0) + ",";
    json += "\"average_20\":" + DoubleToString(volumeAverage, 0) + ",";
    json += "\"ratio\":" + DoubleToString(volumeRatio, 2);
    json += "}";
    json += "},";
    
    // Calculate enhanced technical indicators
    double currentSpread = GetCurrentSpreadPips();
    double avgSpread = GetAverageSpread();
    string spreadStatus = GetSpreadStatus(currentSpread, avgSpread);
    
    double priceToEma20 = (currentPrice - ema20) / _Point;
    double priceToEma50 = (currentPrice - ema50) / _Point;
    double priceToEma200 = (currentPrice - ema200) / _Point;
    string emaAlignment = GetEMAAlignment(ema20, ema50, ema200);
    
    string rsiSlope = GetRSISlope();
    double priceMomentum3bar = GetPriceMomentum3Bar();
    string atrSlope = GetATRSlope();
    
    string candlePattern = GetCandlePattern();
    double candleBodyRatio = GetCandleBodyRatio();
    string rejectionSignal = GetRejectionSignal();
    
    string tradingSession = GetTradingSession();
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int hourOfDay = dt.hour;
    
    json += "\"technical_indicators\":{";
    json += "\"trend_direction\":\"" + trendDirection + "\",";
    json += "\"trend_strength\":" + DoubleToString(trendStrength, 2) + ",";
    json += "\"rsi_current\":" + DoubleToString(rsiCurrent, 1) + ",";
    json += "\"rsi_h4\":" + DoubleToString(rsiH4, 1) + ",";
    json += "\"rsi_d1\":" + DoubleToString(rsiD1, 1) + ",";
    json += "\"rsi_status\":\"" + rsiStatus + "\",";
    json += "\"stoch_k\":" + DoubleToString(stochK, 1) + ",";
    json += "\"stoch_d\":" + DoubleToString(stochD, 1) + ",";
    json += "\"stoch_signal\":\"" + stochSignal + "\",";
    json += "\"atr_current\":" + DoubleToString(atr, _Digits) + ",";
    json += "\"atr_average\":" + DoubleToString(atrAverage, _Digits) + ",";
    json += "\"volatility_level\":\"" + volatilityLevel + "\",";
    json += "\"ema_20\":" + DoubleToString(ema20, _Digits) + ",";
    json += "\"ema_50\":" + DoubleToString(ema50, _Digits) + ",";
    json += "\"ema_200\":" + DoubleToString(ema200, _Digits) + ",";
    json += "\"price_to_ema20_pips\":" + DoubleToString(priceToEma20, 1) + ",";
    json += "\"price_to_ema50_pips\":" + DoubleToString(priceToEma50, 1) + ",";
    json += "\"price_to_ema200_pips\":" + DoubleToString(priceToEma200, 1) + ",";
    json += "\"ema_alignment\":\"" + emaAlignment + "\",";
    json += "\"spread_current\":" + DoubleToString(currentSpread, 1) + ",";
    json += "\"spread_average\":" + DoubleToString(avgSpread, 1) + ",";
    json += "\"spread_status\":\"" + spreadStatus + "\",";
    json += "\"rsi_slope\":\"" + rsiSlope + "\",";
    json += "\"price_momentum_3bar\":" + DoubleToString(priceMomentum3bar, 3) + ",";
    json += "\"atr_slope\":\"" + atrSlope + "\",";
    json += "\"candle_pattern\":\"" + candlePattern + "\",";
    json += "\"candle_body_ratio\":" + DoubleToString(candleBodyRatio, 2) + ",";
    json += "\"rejection_signal\":\"" + rejectionSignal + "\",";
    json += "\"trading_session\":\"" + tradingSession + "\",";
    json += "\"hour_of_day\":" + IntegerToString(hourOfDay);
    json += "},";
    json += "\"market_regime\":{";
    json += "\"current_regime\":\"" + currentRegime + "\",";
    json += "\"confidence\":" + DoubleToString(regimeConfidence, 2) + ",";
    json += "\"adx_h1\":" + DoubleToString(adxH1, 1) + ",";
    json += "\"adx_h4\":" + DoubleToString(adxH4, 1) + ",";
    json += "\"adx_d1\":" + DoubleToString(adxD1, 1) + ",";
    json += "\"plus_di\":" + DoubleToString(plusDI, 1) + ",";
    json += "\"minus_di\":" + DoubleToString(minusDI, 1);
    json += "},";
    json += "\"key_levels\":" + keyLevelsJson + ",";
    json += "\"economic_calendar\":" + economicCalendarJson;
    json += "}";
    
    return json;
}

//+------------------------------------------------------------------+
//| Helper Functions for Market Context Creation                    |
//+------------------------------------------------------------------+
double GetVolumeAverage(int periods)
{
    double totalVolume = 0;
    int validBars = 0;
    
    for(int i = 1; i <= periods; i++)
    {
        double volume = iRealVolume(_Symbol, PERIOD_CURRENT, i);
        if(volume > 0)
        {
            totalVolume += volume;
            validBars++;
        }
    }
    
    return validBars > 0 ? totalVolume / validBars : 0;
}

//+------------------------------------------------------------------+
//| Get Current ATR Value                                            |
//+------------------------------------------------------------------+
// PURPOSE:
//   Returns the current ATR (Average True Range) value for the symbol
//   on the current timeframe.
//
// RETURNS:
//   (double) - Current ATR value in price units, or 0.0 if indicator
//              handle is invalid or data not available.
//
// SIDE EFFECTS:
//   - Creates and releases ATR indicator handle (temporary)
//   - None (read-only operation)
//
// ERROR CONDITIONS:
//   - Returns 0.0 if ATR indicator handle creation fails
//   - Returns 0.0 if insufficient bars available for calculation
//   - Returns 0.0 if buffer copy fails
//
// NOTES:
//   - Uses InpATRPeriod for ATR calculation period
//   - Indicator handle is created and released on each call
//   - For better performance, consider caching ATR value
//   - ATR value is in price units (not pips)
//
// RELATED:
//   - See Also: GetATRAverage(), GetCurrentATR() in State Manager
//   - Called By: ExecuteTradeLogic(), CreateComprehensiveMarketContext()
//+------------------------------------------------------------------+
double GetATRValue()
{
    int atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
    if(atrHandle == INVALID_HANDLE)
        return 0;
    
    double atrBuffer[];
    double atr = 0;
    if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0)
        atr = atrBuffer[0];
    
    IndicatorRelease(atrHandle);
    return atr;
}

double GetATRAverage(int periods)
{
    double totalATR = 0;
    int validBars = 0;
    
    for(int i = 1; i <= periods; i++)
    {
        int atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
        if(atrHandle != INVALID_HANDLE)
        {
            double atrBuffer[];
            if(CopyBuffer(atrHandle, 0, i, 1, atrBuffer) > 0)
            {
                totalATR += atrBuffer[0];
                validBars++;
            }
            IndicatorRelease(atrHandle);
        }
    }
    
    return validBars > 0 ? totalATR / validBars : 0;
}

//+------------------------------------------------------------------+
//| Get EMA Value                                                    |
//+------------------------------------------------------------------+
// PURPOSE:
//   Returns the current EMA (Exponential Moving Average) value for the symbol
//   on the current timeframe with the specified period.
//
// PARAMETERS:
//   period (int) - EMA period (e.g., 20, 50, 200)
//
// RETURNS:
//   (double) - Current EMA value in price units, or 0.0 if indicator
//              handle is invalid or data not available.
//
// SIDE EFFECTS:
//   - Creates and releases EMA indicator handle (temporary)
//   - None (read-only operation)
//
// ERROR CONDITIONS:
//   - Returns 0.0 if EMA indicator handle creation fails
//   - Returns 0.0 if insufficient bars available for calculation
//   - Returns 0.0 if buffer copy fails
//
// NOTES:
//   - Uses PRICE_CLOSE for EMA calculation
//   - Indicator handle is created and released on each call
//   - For better performance, consider caching EMA values
//   - EMA value is in price units
//
// RELATED:
//   - See Also: Signal_TREND() for EMA alignment checks
//   - Called By: CreateComprehensiveMarketContext(), Signal_TREND()
//+------------------------------------------------------------------+
double GetEMAValue(int period)
{
    int emaHandle = iMA(_Symbol, PERIOD_CURRENT, period, 0, MODE_EMA, PRICE_CLOSE);
    if(emaHandle == INVALID_HANDLE)
        return 0;
    
    double emaBuffer[];
    double ema = 0;
    if(CopyBuffer(emaHandle, 0, 0, 1, emaBuffer) > 0)
        ema = emaBuffer[0];
    
    IndicatorRelease(emaHandle);
    return ema;
}

string GetKeyLevelsJson()
{
    string json = "{";
    json += "\"support_levels\":[";
    
    // Get support levels from key level detector
    if(g_keyLevelDetector != NULL)
    {
        int levelCount = g_keyLevelDetector.GetKeyLevelCount();
        bool firstSupport = true;
        
        for(int i = 0; i < levelCount; i++)
        {
            SKeyLevel level;
            if(g_keyLevelDetector.GetKeyLevel(i, level) && !level.isResistance)
            {
                if(!firstSupport) json += ",";
                json += "{";
                json += "\"price\":" + DoubleToString(level.price, _Digits) + ",";
                json += "\"strength\":" + DoubleToString(level.strength, 2) + ",";
                json += "\"touches\":" + IntegerToString(level.touchCount);
                json += "}";
                firstSupport = false;
            }
        }
    }
    
    json += "],";
    json += "\"resistance_levels\":[";
    
    // Get resistance levels from key level detector
    if(g_keyLevelDetector != NULL)
    {
        int levelCount = g_keyLevelDetector.GetKeyLevelCount();
        bool firstResistance = true;
        
        for(int i = 0; i < levelCount; i++)
        {
            SKeyLevel level;
            if(g_keyLevelDetector.GetKeyLevel(i, level) && level.isResistance)
            {
                if(!firstResistance) json += ",";
                json += "{";
                json += "\"price\":" + DoubleToString(level.price, _Digits) + ",";
                json += "\"strength\":" + DoubleToString(level.strength, 2) + ",";
                json += "\"touches\":" + IntegerToString(level.touchCount);
                json += "}";
                firstResistance = false;
            }
        }
    }
    
    json += "],";
    
    // Find nearest support and resistance
    double nearestSupportPrice = 0.0;
    double nearestSupportDist = 0.0;
    double nearestResistancePrice = 0.0;
    double nearestResistanceDist = 0.0;
    
    if(g_keyLevelDetector != NULL)
    {
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double pipSize = GetPipSize();
        int levelCount = g_keyLevelDetector.GetKeyLevelCount();
        
        double minSupportDist = 999999.0;
        double minResistanceDist = 999999.0;
        
        for(int i = 0; i < levelCount; i++)
        {
            SKeyLevel level;
            if(g_keyLevelDetector.GetKeyLevel(i, level))
            {
                double distance = MathAbs(level.price - currentPrice);
                double distancePips = distance / pipSize;
                
                if(level.isResistance && level.price > currentPrice)
                {
                    if(distance < minResistanceDist)
                    {
                        minResistanceDist = distance;
                        nearestResistancePrice = level.price;
                        nearestResistanceDist = distancePips;
                    }
                }
                else if(!level.isResistance && level.price < currentPrice)
                {
                    if(distance < minSupportDist)
                    {
                        minSupportDist = distance;
                        nearestSupportPrice = level.price;
                        nearestSupportDist = distancePips;
                    }
                }
            }
        }
    }
    
    json += "\"nearest_support\":{";
    json += "\"price\":" + DoubleToString(nearestSupportPrice, _Digits) + ",";
    json += "\"distance_pips\":" + DoubleToString(nearestSupportDist, 1);
    json += "},";
    json += "\"nearest_resistance\":{";
    json += "\"price\":" + DoubleToString(nearestResistancePrice, _Digits) + ",";
    json += "\"distance_pips\":" + DoubleToString(nearestResistanceDist, 1);
    json += "}";
    json += "}";
    
    return json;
}

string GetEconomicCalendarJson()
{
    int eventsToday = 0;
    int highImpactEvents = 0;
    string nextEventTime = "";
    string nextEventCurrency = "";
    string nextEventName = "";
    string nextEventImpact = "";
    
    // Get calendar data from calendar reader
    if(g_calendarReader.IsCalendarAvailable())
    {
        eventsToday = g_calendarReader.GetEventCount();
        
        // Count high impact events and find next upcoming event
        datetime currentTime = TimeCurrent();
        datetime nextEventDateTime = D'2099.12.31 23:59:59';
        
        for(int i = 0; i < eventsToday; i++)
        {
            NewsEvent evt = g_calendarReader.GetEvent(i);
            
            // Count high impact events
            if(evt.impact >= NEWS_IMPACT_HIGH)
            {
                highImpactEvents++;
            }
            
            // Find next upcoming event (future event closest to now)
            if(evt.time > currentTime && evt.time < nextEventDateTime)
            {
                nextEventDateTime = evt.time;
                nextEventTime = TimeToString(evt.time, TIME_DATE|TIME_SECONDS);
                nextEventCurrency = evt.currency;
                nextEventName = evt.event;
                nextEventImpact = g_calendarReader.GetImpactString(evt.impact);
            }
        }
    }
    
    // Build JSON
    string json = "{";
    json += "\"events_today\":" + IntegerToString(eventsToday) + ",";
    json += "\"high_impact_events\":" + IntegerToString(highImpactEvents) + ",";
    json += "\"finbert_signal\":\"NEUTRAL\",";
    json += "\"finbert_confidence\":0.0,";
    json += "\"next_event\":{";
    json += "\"time\":\"" + nextEventTime + "\",";
    json += "\"currency\":\"" + nextEventCurrency + "\",";
    json += "\"name\":\"" + nextEventName + "\",";
    json += "\"impact\":\"" + nextEventImpact + "\"";
    json += "}";
    json += "}";
    
    return json;
}

void SaveMarketContextToFile(string jsonData)
{
    string filename = "market_context_" + _Symbol + "_" + TimeToString(TimeCurrent(), TIME_DATE) + ".json";
    int fileHandle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_COMMON);
    
    if(fileHandle != INVALID_HANDLE)
    {
        FileWriteString(fileHandle, jsonData);
        FileClose(fileHandle);
        
        if(InpLogDetailedInfo)
        {
            Print("[GrandeFinBERT] Market context saved to: ", filename);
        }
    }
    else
    {
        Print("[GrandeFinBERT] ERROR: Failed to save market context to file");
    }
}

//+------------------------------------------------------------------+
//| Enhanced FinBERT Helper Functions                               |
//+------------------------------------------------------------------+

// Get current spread in pips
double GetCurrentSpreadPips()
{
    return (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
}

// Get average spread over last 20 bars (simplified - using current spread as proxy)
double GetAverageSpread()
{
    // Note: Real implementation would track spread history
    // For now, returning current spread as reasonable estimate
    return GetCurrentSpreadPips();
}

// Determine spread status
string GetSpreadStatus(double currentSpread, double avgSpread)
{
    if(avgSpread <= 0) return "NORMAL";
    
    double ratio = currentSpread / avgSpread;
    if(ratio > 1.5) return "WIDE";
    if(ratio < 0.7) return "TIGHT";
    return "NORMAL";
}

// Get RSI slope (rising/falling/flat)
string GetRSISlope()
{
    double rsi0 = GetRSIValue(_Symbol, PERIOD_CURRENT, InpRSIPeriod, 0);
    double rsi1 = GetRSIValue(_Symbol, PERIOD_CURRENT, InpRSIPeriod, 1);
    double rsi2 = GetRSIValue(_Symbol, PERIOD_CURRENT, InpRSIPeriod, 2);
    
    double slope = (rsi0 - rsi2) / 2.0;
    
    if(slope > 2.0) return "RISING";
    if(slope < -2.0) return "FALLING";
    return "FLAT";
}

// Get price momentum over last 3 bars
double GetPriceMomentum3Bar()
{
    double close0 = iClose(_Symbol, PERIOD_CURRENT, 0);
    double close3 = iClose(_Symbol, PERIOD_CURRENT, 3);
    
    if(close3 == 0) return 0;
    return ((close0 - close3) / close3) * 100.0;
}

// Get ATR slope (increasing/decreasing/stable)
string GetATRSlope()
{
    double atr0 = GetATRValue();
    
    // Calculate ATR from 5 bars ago
    double atrSum5 = 0;
    for(int i = 1; i <= 5; i++)
    {
        double high = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low = iLow(_Symbol, PERIOD_CURRENT, i);
        atrSum5 += (high - low) / _Point;
    }
    double atr5 = atrSum5 / 5.0;
    
    // Calculate ATR from 10 bars ago
    double atrSum10 = 0;
    for(int i = 6; i <= 10; i++)
    {
        double high = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low = iLow(_Symbol, PERIOD_CURRENT, i);
        atrSum10 += (high - low) / _Point;
    }
    double atr10 = atrSum10 / 5.0;
    
    double atrCurrent = atr0 / _Point;
    
    if(atrCurrent > atr5 && atr5 > atr10) return "INCREASING";
    if(atrCurrent < atr5 && atr5 < atr10) return "DECREASING";
    return "STABLE";
}

// Simple candlestick pattern detection
string GetCandlePattern()
{
    double open = iOpen(_Symbol, PERIOD_CURRENT, 0);
    double high = iHigh(_Symbol, PERIOD_CURRENT, 0);
    double low = iLow(_Symbol, PERIOD_CURRENT, 0);
    double close = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    double body = MathAbs(close - open);
    double totalRange = high - low;
    double upperWick = high - MathMax(open, close);
    double lowerWick = MathMin(open, close) - low;
    
    if(totalRange == 0) return "NORMAL";
    
    double bodyRatio = body / totalRange;
    
    // Doji: very small body
    if(bodyRatio < 0.1) return "DOJI";
    
    // Hammer: long lower wick, small body at top
    if(lowerWick > body * 2 && upperWick < body && close > open)
        return "HAMMER";
    
    // Shooting Star: long upper wick, small body at bottom
    if(upperWick > body * 2 && lowerWick < body && close < open)
        return "SHOOTING_STAR";
    
    // Engulfing check (simplified)
    double prevBody = MathAbs(iClose(_Symbol, PERIOD_CURRENT, 1) - iOpen(_Symbol, PERIOD_CURRENT, 1));
    if(body > prevBody * 1.5)
        return "ENGULFING";
    
    return "NORMAL";
}

// Get candle body ratio
double GetCandleBodyRatio()
{
    double open = iOpen(_Symbol, PERIOD_CURRENT, 0);
    double high = iHigh(_Symbol, PERIOD_CURRENT, 0);
    double low = iLow(_Symbol, PERIOD_CURRENT, 0);
    double close = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    double body = MathAbs(close - open);
    double totalRange = high - low;
    
    return totalRange > 0 ? body / totalRange : 0;
}

// Get rejection signal from wicks
string GetRejectionSignal()
{
    double open = iOpen(_Symbol, PERIOD_CURRENT, 0);
    double high = iHigh(_Symbol, PERIOD_CURRENT, 0);
    double low = iLow(_Symbol, PERIOD_CURRENT, 0);
    double close = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    double body = MathAbs(close - open);
    double upperWick = high - MathMax(open, close);
    double lowerWick = MathMin(open, close) - low;
    
    // Strong upper wick rejection
    if(upperWick > body * 2 && upperWick > lowerWick * 2)
        return "BEARISH_REJECTION";
    
    // Strong lower wick rejection
    if(lowerWick > body * 2 && lowerWick > upperWick * 2)
        return "BULLISH_REJECTION";
    
    return "NONE";
}

// Get current trading session
string GetTradingSession()
{
    datetime currentTime = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(currentTime, dt);
    int hour = dt.hour;
    
    // Asian: 0-8 GMT
    if(hour >= 0 && hour < 8) return "ASIAN";
    
    // London: 8-16 GMT
    if(hour >= 8 && hour < 16) return "LONDON";
    
    // NY: 13-21 GMT (overlaps with London 13-16)
    if(hour >= 13 && hour < 21)
    {
        if(hour >= 13 && hour < 16)
            return "LONDON_NY_OVERLAP";
        return "NEW_YORK";
    }
    
    // After hours
    return "AFTER_HOURS";
}

// Get EMA alignment status
string GetEMAAlignment(double ema20, double ema50, double ema200)
{
    // Perfect bullish stack
    if(ema20 > ema50 && ema50 > ema200)
        return "BULLISH_STACK";
    
    // Perfect bearish stack
    if(ema20 < ema50 && ema50 < ema200)
        return "BEARISH_STACK";
    
    // Mixed/transitioning
    return "MIXED";
}

//+------------------------------------------------------------------+
//| Normalize Volume to Symbol Step                                  |
//+------------------------------------------------------------------+
// PURPOSE:
//   Normalizes a volume value to match the symbol's volume step requirements
//   and ensures it is within the symbol's min/max volume limits.
//
// PARAMETERS:
//   symbol (string) - Symbol name to get volume constraints from
//   volume (double) - Volume to normalize (in lots)
//
// RETURNS:
//   (double) - Normalized volume value rounded to symbol's volume step,
//              clamped to min/max limits, or minimum volume if input is too small.
//
// SIDE EFFECTS:
//   - None (read-only symbol property queries)
//
// ERROR CONDITIONS:
//   - Returns minimum volume if input volume is below minimum
//   - Returns maximum volume if input volume exceeds maximum
//   - Uses default step of 0.01 if symbol step is invalid
//
// NOTES:
//   - Volume is rounded down to nearest step using MathFloor()
//   - Ensures volume is never zero (returns minimum if normalized value is zero)
//   - Result is normalized to 2 decimal places
//   - Critical for order placement as brokers reject invalid lot sizes
//
// USAGE EXAMPLE:
//   double lot = 0.12345;
//   lot = NormalizeVolumeToStep(_Symbol, lot); // Returns 0.12 if step is 0.01
//
// RELATED:
//   - See Also: NormalizeStops()
//   - Called By: TrendTrade(), BreakoutTrade(), RangeTrade()
//+------------------------------------------------------------------+
double NormalizeVolumeToStep(const string symbol, double volume)
{
    double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    double vmin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double vmax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    if(step <= 0.0) step = 0.01;
    if(vmin <= 0.0) vmin = step;
    if(vmax <= 0.0) vmax = volume;
    if(volume < vmin) volume = vmin;
    if(volume > vmax) volume = vmax;
    double normalized = MathFloor((volume + 1e-12) / step) * step;
    // make sure we don't round to zero
    if(normalized < vmin) normalized = vmin;
    return NormalizeDouble(normalized, 2);
}

//+------------------------------------------------------------------+
//| Normalize Stop Loss and Take Profit Levels                       |
//+------------------------------------------------------------------+
// PURPOSE:
//   Normalizes stop loss and take profit levels to ensure they are on the
//   correct side of entry price and respect broker's minimum stop distance.
//
// BEHAVIOR:
//   1. Ensures SL is below entry for buys, above entry for sells
//   2. Ensures TP is above entry for buys, below entry for sells
//   3. Enforces minimum stop distance from entry price
//   4. Normalizes prices to symbol's digit precision
//
// PARAMETERS:
//   isBuy (bool) - Trade direction: true for buy, false for sell
//   entryPrice (double) - Entry price for the trade
//   sl (double&) - Stop loss level (modified in place)
//   tp (double&) - Take profit level (modified in place)
//
// RETURNS:
//   (void) - No return value. Parameters sl and tp are modified in place.
//
// SIDE EFFECTS:
//   - Modifies sl and tp parameters to valid values
//   - None (read-only symbol property queries)
//
// ERROR CONDITIONS:
//   - If SL is on wrong side, it is corrected to minimum distance from entry
//   - If TP is on wrong side, it is corrected to minimum distance from entry
//   - If distance is less than minimum, levels are adjusted to minimum distance
//
// NOTES:
//   - Critical for order placement as brokers reject invalid stop levels
//   - Uses SYMBOL_TRADE_STOPS_LEVEL to determine minimum distance
//   - Prices are normalized to symbol's digit precision
//   - Must be called before placing any order with SL/TP
//
// USAGE EXAMPLE:
//   double entry = 1.1000;
//   double sl = 1.0950;
//   double tp = 1.1100;
//   NormalizeStops(true, entry, sl, tp); // Ensures valid levels for buy order
//
// RELATED:
//   - See Also: NormalizeVolumeToStep()
//   - Called By: TrendTrade(), BreakoutTrade(), RangeTrade()
//+------------------------------------------------------------------+
void NormalizeStops(const bool isBuy, const double entryPrice, double &sl, double &tp)
{
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int stopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double minDistance = (stopLevel > 0 ? stopLevel : 0) * point;

    // Correct side sanity
    if(isBuy)
    {
        if(sl >= entryPrice) sl = entryPrice - minDistance;
        if(tp <= entryPrice) tp = entryPrice + minDistance;
    }
    else
    {
        if(sl <= entryPrice) sl = entryPrice + minDistance;
        if(tp >= entryPrice) tp = entryPrice - minDistance;
    }

    // Enforce minimum distances
    if(minDistance > 0)
    {
        if(isBuy)
        {
            if((entryPrice - sl) < minDistance) sl = entryPrice - minDistance;
            if((tp - entryPrice) < minDistance) tp = entryPrice + minDistance;
        }
        else
        {
            if((sl - entryPrice) < minDistance) sl = entryPrice + minDistance;
            if((entryPrice - tp) < minDistance) tp = entryPrice - minDistance;
        }
    }

    sl = NormalizeDouble(sl, digits);
    tp = NormalizeDouble(tp, digits);
}

bool IsPendingPriceValid(const bool isBuyStop, const double levelPrice)
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int stopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double minDistance = (stopLevel > 0 ? stopLevel : 0) * point;

    if(isBuyStop)
        return (levelPrice > ask + minDistance);
    else
        return (levelPrice < bid - minDistance);
}

bool HasSimilarPendingOrderForBreakout(const bool isBuyStop, const double levelPrice, const int tolerancePoints)
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double tol = MathMax(1, tolerancePoints) * point;
    int total = OrdersTotal();
    for(int i = 0; i < total; i++)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        if(!OrderSelect(ticket))
            continue;
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        long type = OrderGetInteger(ORDER_TYPE);
        if(isBuyStop && type != ORDER_TYPE_BUY_STOP) continue;
        if(!isBuyStop && type != ORDER_TYPE_SELL_STOP) continue;
        if((int)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
        double price = OrderGetDouble(ORDER_PRICE_OPEN);
        if(MathAbs(price - levelPrice) <= tol)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check if similar pending limit order already exists              |
//| Returns true if a similar limit order exists within tolerance    |
//+------------------------------------------------------------------+
bool HasSimilarPendingLimitOrder(const bool isBuyLimit, const double levelPrice, const int tolerancePoints)
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double tol = MathMax(1, tolerancePoints) * point;
    int total = OrdersTotal();
    for(int i = 0; i < total; i++)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        if(!OrderSelect(ticket))
            continue;
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        long type = OrderGetInteger(ORDER_TYPE);
        if(isBuyLimit && type != ORDER_TYPE_BUY_LIMIT) continue;
        if(!isBuyLimit && type != ORDER_TYPE_SELL_LIMIT) continue;
        if((int)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
        double price = OrderGetDouble(ORDER_PRICE_OPEN);
        if(MathAbs(price - levelPrice) <= tol)
            return true;
    }
    return false;
}

void ConfigureTradeFillingMode()
{
    // Prefer FOK, fall back to RETURN if required
    long filling = (long)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    // If symbol supports FOK or IOC, set accordingly. Otherwise, RETURN is safest.
    // SYMBOL_FILLING_MODE returns bitmask in some brokers; be conservative.
    g_trade.SetTypeFilling(ORDER_FILLING_FOK);
}

//+------------------------------------------------------------------+
//| Intelligent Position Scaling Functions                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update 15-minute range information                              |
//+------------------------------------------------------------------+
void UpdateRangeInfo()
{
    if (!InpEnableIntelligentScaling) return;
    
    datetime currentTime = TimeCurrent();
    datetime lastRangeUpdate = (g_stateManager != NULL) ? g_stateManager.GetLastRangeUpdate() : 0;
    if (currentTime - lastRangeUpdate < 900) return; // Update every 15 minutes
    
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    int copied = CopyHigh(_Symbol, PERIOD_M15, 0, InpScalingRangePeriods, high);
    int copiedLow = CopyLow(_Symbol, PERIOD_M15, 0, InpScalingRangePeriods, low);
    
    if (copied > 0 && copiedLow > 0) {
        // Find highest high and lowest low in the range
        double maxHigh = high[ArrayMaximum(high, 0, InpScalingRangePeriods)];
        double minLow = low[ArrayMinimum(low, 0, InpScalingRangePeriods)];
        
        RangeInfo currentRange;
        currentRange.upperBound = maxHigh;
        currentRange.lowerBound = minLow;
        currentRange.rangeSize = maxHigh - minLow;
        currentRange.rangeStartTime = currentTime;
        currentRange.isValid = (currentRange.rangeSize >= InpMinRangeSizePips * _Point);
        currentRange.touchCount = 0;
        
        if(g_stateManager != NULL)
            g_stateManager.SetCurrentRange(currentRange);
        
        if (InpLogScalingDecisions && currentRange.isValid) {
            Print(StringFormat("[SCALING] Range Updated - Upper: %s, Lower: %s, Size: %.1f pips",
                  DoubleToString(currentRange.upperBound, _Digits),
                  DoubleToString(currentRange.lowerBound, _Digits),
                  currentRange.rangeSize / _Point));
        }
    }
    
        // Range update timestamp is automatically updated by SetCurrentRange() in State Manager
}

//+------------------------------------------------------------------+
//| Check if intelligent scaling should be allowed                  |
//+------------------------------------------------------------------+
bool ShouldAllowIntelligentScaling(int existingPositions, bool isBuySignal)
{
    if (!InpEnableIntelligentScaling) return false;
    if (existingPositions >= InpMaxScalingPositions) return false;
    RangeInfo currentRange = (g_stateManager != NULL) ? g_stateManager.GetCurrentRange() : RangeInfo();
    if (!currentRange.isValid) return false;
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double rangeSize = currentRange.rangeSize;
    double buffer = rangeSize * InpScalingRangeBuffer;
    
    // First position: Allow if conditions are met
    if (existingPositions == 0) {
        return true;
    }
    
    // Second position: Wait for price to move toward range boundaries
    if (existingPositions == 1) {
        if (isBuySignal) {
            // For BUY: Second position at upper bound (price goes against you, better entry)
            bool nearUpper = (currentPrice >= currentRange.upperBound - buffer);
            if (nearUpper && InpLogScalingDecisions) {
                Print(StringFormat("[SCALING] BUY position 2 opportunity - Price: %s, Upper: %s",
                      DoubleToString(currentPrice, _Digits),
                      DoubleToString(currentRange.upperBound, _Digits)));
            }
            return nearUpper;
        } else {
            // For SELL: Second position at lower bound (price goes against you, better entry)
            bool nearLower = (currentPrice <= currentRange.lowerBound + buffer);
            if (nearLower && InpLogScalingDecisions) {
                Print(StringFormat("[SCALING] SELL position 2 opportunity - Price: %s, Lower: %s",
                      DoubleToString(currentPrice, _Digits),
                      DoubleToString(currentRange.lowerBound, _Digits)));
            }
            return nearLower;
        }
    }
    
    // Third position: Even more favorable price
    if (existingPositions == 2) {
        if (isBuySignal) {
            // For BUY: Third position at lower bound (most favorable)
            bool nearLower = (currentPrice <= currentRange.lowerBound + buffer);
            if (nearLower && InpLogScalingDecisions) {
                Print(StringFormat("[SCALING] BUY position 3 opportunity - Price: %s, Lower: %s",
                      DoubleToString(currentPrice, _Digits),
                      DoubleToString(currentRange.lowerBound, _Digits)));
            }
            return nearLower;
        } else {
            // For SELL: Third position at upper bound (most favorable)
            bool nearUpper = (currentPrice >= currentRange.upperBound - buffer);
            if (nearUpper && InpLogScalingDecisions) {
                Print(StringFormat("[SCALING] SELL position 3 opportunity - Price: %s, Upper: %s",
                      DoubleToString(currentPrice, _Digits),
                      DoubleToString(currentRange.upperBound, _Digits)));
            }
            return nearUpper;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Log scaling decision for analysis                               |
//+------------------------------------------------------------------+
void LogScalingDecision(int positionCount, double entryPrice, bool isBuySignal)
{
    if (!InpLogScalingDecisions) return;
    
    RangeInfo currentRange = (g_stateManager != NULL) ? g_stateManager.GetCurrentRange() : RangeInfo();
    string logMsg = StringFormat("[SCALING] Position %d @%s | %s | Range: %s-%s (%.1f pips) | %s",
        positionCount,
        DoubleToString(entryPrice, _Digits),
        isBuySignal ? "BUY" : "SELL",
        DoubleToString(currentRange.lowerBound, _Digits),
        DoubleToString(currentRange.upperBound, _Digits),
        currentRange.rangeSize / _Point,
        currentRange.isValid ? "VALID_RANGE" : "NO_RANGE");
    
    Print(logMsg);
}

//+------------------------------------------------------------------+
//| Cool-Off Period Helper Functions                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get cool-off key for global variable storage                     |
//+------------------------------------------------------------------+
string GetCooloffKey()
{
    return "COOLOFF_" + _Symbol + "_" + IntegerToString(InpMagicNumber);
}

//+------------------------------------------------------------------+
//| Store cool-off state to global variable (persists across restart)|
//+------------------------------------------------------------------+
void SaveCooloffState(datetime exitTime, double exitPrice, int direction, int reason)
{
    string key = GetCooloffKey();
    
    GlobalVariableSet(key + "_TIME", (double)exitTime);
    GlobalVariableSet(key + "_DIR", (double)direction);
    GlobalVariableSet(key + "_REASON", (double)reason);
    
    if(InpLogCooloffDecisions)
    {
        Print(StringFormat("[COOL-OFF] State saved - Exit: %s, Dir: %s, Reason: %s",
              TimeToString(exitTime),
              direction == 0 ? "BUY" : "SELL",
              reason == 0 ? "TP" : (reason == 1 ? "SL" : "OTHER")));
    }
}

//+------------------------------------------------------------------+
//| Load cool-off state from global variable                         |
//+------------------------------------------------------------------+
bool LoadCooloffState()
{
    string key = GetCooloffKey();
    
    if(!GlobalVariableCheck(key + "_TIME"))
        return false;
    
    CoolOffInfo coolOff;
    coolOff.lastExitTime = (datetime)GlobalVariableGet(key + "_TIME");
    coolOff.lastDirection = (int)GlobalVariableGet(key + "_DIR");
    coolOff.exitReason = (int)GlobalVariableGet(key + "_REASON");
    coolOff.lastExitPrice = GlobalVariableGet(key + "_PRICE");
    coolOff.isActive = true;
    
    if(g_stateManager != NULL)
        g_stateManager.SetCoolOffInfo(coolOff);
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if symbol is in cool-off period                            |
//+------------------------------------------------------------------+
bool IsInCooloffPeriod(bool isBuySignal)
{
    if(!InpEnableCooloffPeriod)
        return false;
    
    // Load state from global variables
    if(!LoadCooloffState())
    {
        if(g_stateManager != NULL)
        {
            CoolOffInfo coolOff;
            coolOff.isActive = false;
            g_stateManager.SetCoolOffInfo(coolOff);
        }
        return false;
    }
    
    if(g_stateManager == NULL)
        return false;
    
    CoolOffInfo coolOffState = g_stateManager.GetCoolOffInfo();
    if(!coolOffState.isActive)
        return false;
    
    datetime currentTime = TimeCurrent();
    int secondsSinceExit = (int)(currentTime - coolOffState.lastExitTime);
    
    // Determine BASE cool-off duration based on exit reason
    int baseCooloffMinutes = 0;
    if(coolOffState.exitReason == 0) // TP
        baseCooloffMinutes = InpTPCooloffMinutes;
    else if(coolOffState.exitReason == 1) // SL
        baseCooloffMinutes = InpSLCooloffMinutes;
    else
        return false; // No cool-off for manual or other exits
    
    // Apply dynamic adjustments
    double cooloffMultiplier = 1.0;
    
    // 1. ATR-based volatility adjustment
    if(InpEnableDynamicCooloff)
    {
        double volMultiplier = GetVolatilityAdjustment();
        if(volMultiplier > 0)
        {
            cooloffMultiplier *= volMultiplier;
            if(InpLogCooloffDecisions)
            {
                Print(StringFormat("[COOL-OFF] Dynamic adjustment: Volatility multiplier %.2f", volMultiplier));
            }
        }
    }
    
    // 2. Regime-aware adjustment
    if(InpEnableRegimeAwareCooloff && g_regimeDetector != NULL)
    {
        double regimeMultiplier = GetRegimeAdjustment();
        if(regimeMultiplier > 0)
        {
            cooloffMultiplier *= regimeMultiplier;
            if(InpLogCooloffDecisions)
            {
                Print(StringFormat("[COOL-OFF] Regime adjustment: multiplier %.2f", regimeMultiplier));
            }
        }
    }
    
    // Calculate final cool-off duration
    int adjustedCooloffMinutes = (int)(baseCooloffMinutes * cooloffMultiplier);
    int cooloffSeconds = adjustedCooloffMinutes * 60;
    
    // Log adjustment if significant
    if(InpLogCooloffDecisions && MathAbs(cooloffMultiplier - 1.0) > 0.1)
    {
        Print(StringFormat("[COOL-OFF] Adjusted duration: %d min (base: %d, multiplier: %.2f)",
              adjustedCooloffMinutes, baseCooloffMinutes, cooloffMultiplier));
    }
    
    // Check if cool-off period has expired
    if(secondsSinceExit >= cooloffSeconds)
    {
        CoolOffInfo expiredCoolOff = coolOffState;
        expiredCoolOff.isActive = false;
        if(g_stateManager != NULL)
            g_stateManager.SetCoolOffInfo(expiredCoolOff);
        
        // TECHNICAL VALIDATION GATE - even after cooloff expires, check technical conditions
        if(InpEnableTechnicalValidation)
        {
            string techRejectionReason = "";
            RegimeSnapshot currentRegime;
            if(g_regimeDetector != NULL)
                currentRegime = g_regimeDetector.DetectCurrentRegime();
            
            if(!ValidateTechnicalEntry(isBuySignal, currentRegime, techRejectionReason))
            {
                if(InpLogCooloffDecisions)
                {
                    Print(StringFormat("[TECH-GATE] %s blocked after cooloff expired: %s", 
                         isBuySignal ? "BUY" : "SELL", techRejectionReason));
                }
                return true; // Block entry due to technical rejection
            }
            
            if(InpLogCooloffDecisions)
            {
                Print(StringFormat("[TECH-GATE] %s passed technical validation after cooloff", 
                     isBuySignal ? "BUY" : "SELL"));
            }
        }
        
        return false;
    }
    
    // Check for direction change override
    if(InpAllowDirectionChangeOverride)
    {
        int currentDirection = isBuySignal ? 0 : 1;
        if(currentDirection != coolOffState.lastDirection)
        {
        if(InpLogCooloffDecisions)
        {
            Print(StringFormat("[COOL-OFF] OVERRIDE - Direction changed from %s to %s",
                  coolOffState.lastDirection == 0 ? "BUY" : "SELL",
                  currentDirection == 0 ? "BUY" : "SELL"));
        }
        
        // Track override statistics
        if(InpEnableCooloffStatistics && g_stateManager != NULL)
        {
            CoolOffStats stats = g_stateManager.GetCoolOffStats();
            stats.overridesUsed++;
            g_stateManager.SetCoolOffStats(stats);
        }
        
        return false; // Allow trade - direction changed
        }
    }
    
    // Still in cool-off period
    if(InpLogCooloffDecisions)
    {
        int minutesRemaining = (cooloffSeconds - secondsSinceExit) / 60;
        int secondsRemaining = (cooloffSeconds - secondsSinceExit) % 60;
        
        Print(StringFormat("[COOL-OFF] %s blocked - %dm %ds remaining (Exit: %s, Reason: %s)",
              isBuySignal ? "BUY" : "SELL",
              minutesRemaining,
              secondsRemaining,
              TimeToString(coolOffState.lastExitTime),
              coolOffState.exitReason == 0 ? "TP" : "SL"));
    }
    
    // Track blocked trade statistics
    if(InpEnableCooloffStatistics && g_stateManager != NULL)
    {
        CoolOffStats stats = g_stateManager.GetCoolOffStats();
        stats.tradesBlocked++;
        g_stateManager.SetCoolOffStats(stats);
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Get volatility-based adjustment multiplier                       |
//+------------------------------------------------------------------+
double GetVolatilityAdjustment()
{
    int atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
    if(atrHandle == INVALID_HANDLE)
        return 1.0;
    
    double atr[];
    ArraySetAsSeries(atr, true);
    
    if(CopyBuffer(atrHandle, 0, 0, 20, atr) < 20)
    {
        IndicatorRelease(atrHandle);
        return 1.0;
    }
    
    double currentATR = atr[0];
    double avgATR = 0;
    for(int i = 0; i < 20; i++)
        avgATR += atr[i];
    avgATR /= 20;
    
    IndicatorRelease(atrHandle);
    
    if(avgATR == 0)
        return 1.0;
    
    double atrRatio = currentATR / avgATR;
    
    // High volatility (>1.5x avg) - LONGER cool-off (more dangerous)
    if(atrRatio > 1.5)
        return InpATRHighVolMultiplier;
    
    // Low volatility (<0.7x avg) - SHORTER cool-off (less movement expected)
    if(atrRatio < 0.7)
        return InpATRLowVolMultiplier;
    
    // Normal volatility - standard cool-off
    return 1.0;
}

//+------------------------------------------------------------------+
//| Get regime-based adjustment multiplier                           |
//+------------------------------------------------------------------+
double GetRegimeAdjustment()
{
    if(g_regimeDetector == NULL)
        return 1.0;
    
    // Get cached regime data from last analysis
    MARKET_REGIME regime = g_lastAnalysisRegime;
    double adx = 0;
    
    // Try to get ADX from regime detector
    int atrHandle = iATR(_Symbol, PERIOD_H4, 14);
    if(atrHandle != INVALID_HANDLE)
    {
        // Get ADX from H4 timeframe
        int adxHandle = iADX(_Symbol, PERIOD_H4, 14);
        if(adxHandle != INVALID_HANDLE)
        {
            double adxBuffer[];
            ArraySetAsSeries(adxBuffer, true);
            if(CopyBuffer(adxHandle, 0, 0, 1, adxBuffer) > 0)
            {
                adx = adxBuffer[0];
            }
            IndicatorRelease(adxHandle);
        }
        IndicatorRelease(atrHandle);
    }
    
    // Strong trending market (ADX > 40) - SHORTER cool-off
    // Rationale: Strong trends continue, re-entry opportunities are good
    if((regime == REGIME_TREND_BULL || regime == REGIME_TREND_BEAR) && adx > 40)
    {
        return InpTrendingCooloffMultiplier; // 0.7 = 30 min becomes 21 min
    }
    
    // Ranging/choppy market (ADX < 25) - LONGER cool-off
    // Rationale: More likely to whipsaw, need more confirmation
    if(regime == REGIME_RANGING || adx < 25)
    {
        return InpRangingCooloffMultiplier; // 1.3 = 30 min becomes 39 min
    }
    
    // Moderate trending - standard cool-off
    return 1.0;
}

//+------------------------------------------------------------------+
//| Update cool-off statistics after trade closes                    |
//+------------------------------------------------------------------+
void UpdateCooloffStatistics(bool tradeWon)
{
    if(!InpEnableCooloffStatistics || g_stateManager == NULL)
        return;
    
    // Track allowed trades (those that executed after cool-off expired)
    CoolOffStats stats = g_stateManager.GetCoolOffStats();
    stats.tradesAllowed++;
    
    if(tradeWon)
        stats.allowedWins++;
    else
        stats.allowedLosses++;
    
    g_stateManager.SetCoolOffStats(stats);
}

//+------------------------------------------------------------------+
//| Report cool-off statistics                                       |
//+------------------------------------------------------------------+
void ReportCooloffStatistics()
{
    if(!InpEnableCooloffStatistics || g_stateManager == NULL)
        return;
    
    datetime currentTime = TimeCurrent();
    CoolOffStats stats = g_stateManager.GetCoolOffStats();
    
    // Check if it's time for a report
    if(stats.lastReportTime == 0)
    {
        stats.lastReportTime = currentTime;
        g_stateManager.SetCoolOffStats(stats);
        return;
    }
    
    int minutesSinceReport = (int)((currentTime - stats.lastReportTime) / 60);
    if(minutesSinceReport < InpStatisticsReportMinutes)
        return;
    
    // Generate report
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║           COOL-OFF PERIOD STATISTICS REPORT                  ║");
    Print("╠═══════════════════════════════════════════════════════════════╣");
    
    int totalBlocked = stats.tradesBlocked;
    int totalAllowed = stats.tradesAllowed;
    int totalOverrides = stats.overridesUsed;
    
    Print(StringFormat("║ Trades Blocked by Cool-Off: %4d                             ║", totalBlocked));
    Print(StringFormat("║ Trades Allowed After Cool-Off: %4d                          ║", totalAllowed));
    Print(StringFormat("║ Direction Change Overrides: %4d                             ║", totalOverrides));
    Print("╠═══════════════════════════════════════════════════════════════╣");
    
    if(totalAllowed > 0)
    {
        int wins = stats.allowedWins;
        int losses = stats.allowedLosses;
        double winRate = (double)wins / totalAllowed * 100;
        
        Print(StringFormat("║ Post-Cool-Off Wins: %4d (%.1f%%)                            ║", wins, winRate));
        Print(StringFormat("║ Post-Cool-Off Losses: %4d (%.1f%%)                          ║", losses, 100 - winRate));
        Print("╠═══════════════════════════════════════════════════════════════╣");
    }
    
    // Calculate effectiveness metrics
    if(totalBlocked > 0 && totalAllowed > 0)
    {
        double blockRate = (double)totalBlocked / (totalBlocked + totalAllowed) * 100;
        Print(StringFormat("║ Block Rate: %.1f%% (trades prevented from executing)       ║", blockRate));
    }
    
    Print("╚═══════════════════════════════════════════════════════════════╝");
    
    // Update last report time
    stats.lastReportTime = currentTime;
    g_stateManager.SetCoolOffStats(stats);
}

//+------------------------------------------------------------------+
//| Clear cool-off state                                             |
//+------------------------------------------------------------------+
void ClearCooloffState()
{
    string key = GetCooloffKey();
    
    GlobalVariableDel(key + "_TIME");
    GlobalVariableDel(key + "_DIR");
    GlobalVariableDel(key + "_REASON");
    
    if(g_stateManager != NULL)
    {
        CoolOffInfo coolOff;
        coolOff.isActive = false;
        g_stateManager.SetCoolOffInfo(coolOff);
    }
    
    if(InpLogCooloffDecisions)
        Print("[COOL-OFF] State cleared for ", _Symbol);
}

//+------------------------------------------------------------------+
//| Get last deal exit reason from history                           |
//+------------------------------------------------------------------+
int GetLastDealExitReason()
{
    // Request deal history
    if(!HistorySelect(TimeCurrent() - 3600, TimeCurrent())) // Last hour
        return -1;
    
    // Get the most recent deal for this symbol
    for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket == 0) continue;
        
        if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
            continue;
        
        if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber)
            continue;
        
        // Check entry type (only interested in exits)
        ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
        if(entry != DEAL_ENTRY_OUT)
            continue;
        
        // Determine exit reason
        ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(ticket, DEAL_REASON);
        
        if(reason == DEAL_REASON_TP)
            return 0; // TP
        else if(reason == DEAL_REASON_SL)
            return 1; // SL
        else
            return 2; // OTHER
    }
    
    return -1; // Not found
}

//+------------------------------------------------------------------+
//| Get last deal direction                                          |
//+------------------------------------------------------------------+
int GetLastDealDirection()
{
    if(!HistorySelect(TimeCurrent() - 3600, TimeCurrent()))
        return -1;
    
    for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket == 0) continue;
        
        if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
            continue;
        
        if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber)
            continue;
        
        ENUM_DEAL_TYPE type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
        
        if(type == DEAL_TYPE_BUY)
            return 0; // BUY
        else if(type == DEAL_TYPE_SELL)
            return 1; // SELL
    }
    
    return -1;
}

//+------------------------------------------------------------------+
//| Get last deal price                                              |
//+------------------------------------------------------------------+
double GetLastDealPrice()
{
    if(!HistorySelect(TimeCurrent() - 3600, TimeCurrent()))
        return 0;
    
    for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket == 0) continue;
        
        if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
            continue;
        
        if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber)
            continue;
        
        return HistoryDealGetDouble(ticket, DEAL_PRICE);
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Detect position closure and set cool-off if needed               |
//+------------------------------------------------------------------+
void CheckForPositionClosure()
{
    // Count current positions for this symbol and magic number
    int currentPositions = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) == _Symbol && 
           PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
            currentPositions++;
        }
    }
    
    // Position was closed
    int lastPositionCount = (g_stateManager != NULL) ? g_stateManager.GetLastPositionCount() : 0;
    if(lastPositionCount > 0 && currentPositions == 0)
    {
        // Try to determine exit reason from last deal
        int exitReason = GetLastDealExitReason();
        int lastDirection = GetLastDealDirection();
        double lastExitPrice = GetLastDealPrice();
        
        if(exitReason >= 0)
        {
            SaveCooloffState(TimeCurrent(), lastExitPrice, lastDirection, exitReason);
            
            if(InpLogCooloffDecisions)
            {
                string reasonStr = exitReason == 0 ? "TP" : (exitReason == 1 ? "SL" : "OTHER");
                int cooloffMinutes = exitReason == 0 ? InpTPCooloffMinutes : InpSLCooloffMinutes;
                
                Print(StringFormat("[COOL-OFF] Position closed via %s - Cool-off active for %d minutes",
                      reasonStr, cooloffMinutes));
            }
        }
    }
    
    if(g_stateManager != NULL)
        g_stateManager.SetLastPositionCount(currentPositions);
}

//+------------------------------------------------------------------+
//| Event Bus Helper Functions                                        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Publish Order Event                                               |
//+------------------------------------------------------------------+
// PURPOSE:
//   Publishes order-related events to the Event Bus for consistent event handling.
//
// BEHAVIOR:
//   - Validates Event Bus is available
//   - Publishes event with order ticket and details
//   - Handles NULL Event Bus gracefully (no error thrown)
//
// PARAMETERS:
//   @param eventType - The type of order event (EVENT_ORDER_PLACED, EVENT_ORDER_FILLED, EVENT_ORDER_CANCELLED, EVENT_ORDER_FAILED)
//   @param ticket - Order ticket number (0 if not applicable)
//   @param details - Human-readable details about the order event
//
// RETURNS:
//   (void) - No return value
//
// SIDE EFFECTS:
//   - Publishes event to Event Bus if available
//   - No side effects if Event Bus is NULL
//
// ERROR CONDITIONS:
//   - Event Bus is NULL: Function returns silently (no error)
//   - Invalid event type: Event may not be processed correctly by subscribers
//
// USAGE EXAMPLE:
//   PublishOrderEvent(EVENT_ORDER_PLACED, 12345, "BUY LIMIT | Lot: 0.10 | Price: 1.2000");
//
//+------------------------------------------------------------------+
void PublishOrderEvent(EVENT_TYPE eventType, ulong ticket, string details)
{
    if(g_eventBus == NULL)
        return;
    
    string source = "OrderManager";
    double value = (double)ticket;
    g_eventBus.PublishEvent(eventType, source, details, value, (long)ticket);
}

//+------------------------------------------------------------------+
//| Publish Position Event                                            |
//+------------------------------------------------------------------+
// PURPOSE:
//   Publishes position-related events to the Event Bus for consistent event handling.
//
// BEHAVIOR:
//   - Validates Event Bus is available
//   - Publishes event with position ticket and details
//   - Handles NULL Event Bus gracefully (no error thrown)
//
// PARAMETERS:
//   @param eventType - The type of position event (EVENT_POSITION_OPENED, EVENT_POSITION_MODIFIED, EVENT_POSITION_CLOSED, EVENT_PARTIAL_CLOSE)
//   @param ticket - Position ticket number (0 if not applicable)
//   @param details - Human-readable details about the position event
//
// RETURNS:
//   (void) - No return value
//
// SIDE EFFECTS:
//   - Publishes event to Event Bus if available
//   - No side effects if Event Bus is NULL
//
// ERROR CONDITIONS:
//   - Event Bus is NULL: Function returns silently (no error)
//   - Invalid event type: Event may not be processed correctly by subscribers
//
// USAGE EXAMPLE:
//   PublishPositionEvent(EVENT_POSITION_OPENED, 12345, "Trend BUY | Entry: 1.2000 | SL: 1.1950 | TP: 1.2100");
//
//+------------------------------------------------------------------+
void PublishPositionEvent(EVENT_TYPE eventType, ulong ticket, string details)
{
    if(g_eventBus == NULL)
        return;
    
    string source = "PositionManager";
    double value = (double)ticket;
    g_eventBus.PublishEvent(eventType, source, details, value, (long)ticket);
}

//+------------------------------------------------------------------+
//| Publish Risk Event                                                |
//+------------------------------------------------------------------+
// PURPOSE:
//   Publishes risk management events to the Event Bus for consistent event handling.
//
// BEHAVIOR:
//   - Validates Event Bus is available
//   - Publishes event with risk details and numeric value
//   - Handles NULL Event Bus gracefully (no error thrown)
//
// PARAMETERS:
//   @param eventType - The type of risk event (EVENT_RISK_WARNING, EVENT_MARGIN_WARNING, EVENT_MARGIN_CRITICAL, EVENT_DRAWDOWN_WARNING)
//   @param details - Human-readable details about the risk event
//   @param value - Numeric value associated with the risk event (e.g., margin level percentage, drawdown percentage)
//
// RETURNS:
//   (void) - No return value
//
// SIDE EFFECTS:
//   - Publishes event to Event Bus if available
//   - No side effects if Event Bus is NULL
//
// ERROR CONDITIONS:
//   - Event Bus is NULL: Function returns silently (no error)
//   - Invalid event type: Event may not be processed correctly by subscribers
//
// USAGE EXAMPLE:
//   PublishRiskEvent(EVENT_MARGIN_WARNING, "Margin level at 250% - Monitor closely", 250.0);
//
//+------------------------------------------------------------------+
void PublishRiskEvent(EVENT_TYPE eventType, string details, double value)
{
    if(g_eventBus == NULL)
        return;
    
    string source = "RiskManager";
    g_eventBus.PublishEvent(eventType, source, details, value, 0);
}
