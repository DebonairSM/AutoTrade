//+------------------------------------------------------------------+
//| GrandeTradingSystem.mq5                                          |
//| Copyright 2024, Grande Tech                                      |
//| Advanced Trading System - Regime Detection + Key Levels         |
//+------------------------------------------------------------------+
// Pattern from: MetaTrader 5 MQL5 Documentation
// Reference: Expert Advisor OnInit/OnTick/OnDeinit event handling patterns

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com.br"
#property version   "1.00"
#property description "Advanced trading system combining market regime detection with key level analysis"

#include "GrandeMarketRegimeDetector.mqh"
#include "GrandeKeyLevelDetector.mqh"
#include "GrandeTrianglePatternDetector.mqh"
#include "GrandeTriangleTradingRules.mqh"
#include "mcp/analyze_sentiment_server/GrandeNewsSentimentIntegration.mqh"
#include "GrandeMT5CalendarReader.mqh"
#include "GrandeIntelligentReporter.mqh"
#include "..\VSol\AdvancedTrendFollower.mqh"
#include "..\VSol\GrandeRiskManager.mqh"
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== Market Regime Settings ==="
input double InpADXTrendThreshold = 25.0;        // ADX Threshold for Trending
input double InpADXBreakoutMin = 18.0;           // ADX Minimum for Breakout Setup
input int    InpATRPeriod = 14;                  // ATR Period
input int    InpATRAvgPeriod = 90;               // ATR Average Period
input double InpHighVolMultiplier = 2.0;         // High Volatility Multiplier

input group "=== Key Level Detection Settings ==="
input int    InpLookbackPeriod = 300;            // Lookback Period for Key Levels
input double InpMinStrength = 0.40;              // Minimum Level Strength
input double InpTouchZone = 0.0010;              // Touch Zone (0 = auto)
input int    InpMinTouches = 1;                  // Minimum Touches Required

input group "=== Trading Settings ==="
input bool   InpEnableTrading = true;           // Enable Live Trading
input int    InpMagicNumber = 123456;            // Magic Number for Trades
input int    InpSlippage = 30;                   // Slippage in Points
input string InpOrderTag = "[GRANDE]";           // Order comment tag for identification

input group "=== Triangle Pattern Settings ==="
input bool   InpEnableTriangleTrading = true;    // Enable Triangle Pattern Trading
input double InpTriangleMinConfidence = 0.6;     // Minimum Pattern Confidence
input double InpTriangleMinBreakoutProb = 0.6;   // Minimum Breakout Probability
input bool   InpTriangleRequireVolume = true;    // Require Volume Confirmation
input double InpTriangleRiskPct = 2.0;           // Risk % for Triangle Trades
input bool   InpTriangleAllowEarlyEntry = false; // Allow Early Entry (Pre-breakout)

input group "=== Risk Management Settings ==="
input double InpRiskPctTrend = 2.5;              // Risk % for Trend Trades
input double InpRiskPctRange = 1.0;              // Risk % for Range Trades
input double InpRiskPctBreakout = 4.5;           // Risk % for Breakout Trades
input double InpMaxRiskPerTrade = 5.0;           // Maximum Risk % per Trade
input double InpMaxDrawdownPct = 30.0;           // Maximum Account Drawdown %
input double InpEquityPeakReset = 5.0;           // Reset Peak after X% Recovery
input int    InpMaxPositions = 7;                // Maximum Concurrent Positions

input group "=== Stop Loss & Take Profit ==="
input double InpSLATRMultiplier = 1.2;           // Stop Loss ATR Multiplier
input double InpTPRewardRatio = 3.0;             // Take Profit Reward Ratio (R:R)
input double InpBreakevenATR = 1.0;              // Move to Breakeven after X ATR
input double InpPartialCloseATR = 1.5;           // Partial Close after X ATR
input double InpBreakevenBuffer = 0.5;           // Breakeven Buffer (pips)

input group "=== Position Management ==="
input bool   InpEnableTrailingStop = true;       // Enable Trailing Stops
input double InpTrailingATRMultiplier = 0.6;     // Trailing Stop ATR Multiplier
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

input group "=== Signal Settings ==="
input int    InpEMA50Period = 50;                // 50 EMA Period
input int    InpEMA200Period = 200;              // 200 EMA Period
input int    InpEMA20Period = 20;                // 20 EMA Period
input int    InpRSIPeriod = 14;                  // RSI Period
input int    InpStochPeriod = 14;                // Stochastic Period
input int    InpStochK = 3;                      // Stochastic %K
input int    InpStochD = 3;                      // Stochastic %D

input group "=== Advanced Trend Follower ==="
input bool   InpEnableTrendFollower = true;      // Enable Trend Follower Confirmation
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
input double InpH4RSIOverbought = 68.0;           // H4 RSI overbought
input double InpH4RSIOversold  = 32.0;            // H4 RSI oversold
input bool   InpUseD1RSI = true;                  // Also gate by D1 extremes
input double InpD1RSIOverbought = 70.0;
input double InpD1RSIOversold  = 30.0;

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
input bool   InpLogDetailedInfo = false;         // Log Detailed Trade Information
input bool   InpLogDebugInfo = false;            // Log Debug Information (Risk Manager)

input group "=== Update Settings ==="
input int    InpRegimeUpdateSeconds = 5;         // Regime Update Interval (seconds)
input int    InpKeyLevelUpdateSeconds = 300;     // Key Level Update Interval (seconds)
input int    InpRiskUpdateSeconds   = 2;         // Risk Update Interval (seconds)

input group "=== Calendar AI Settings ==="
input bool   InpEnableCalendarAI        = true;  // Enable Calendar AI analysis
input int    InpCalendarUpdateMinutes   = 15;    // Calendar AI update interval (minutes)
input int    InpCalendarLookaheadHours  = 24;    // Lookahead window for calendar events (hours)
input double InpCalendarMinConfidence   = 0.60;  // Log highlight threshold for confidence
input bool   InpCalendarOnlyOnTimeframe = true;  // Run calendar only on a specific timeframe
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
CGrandeTrianglePatternDetector* g_triangleDetector;
CGrandeTriangleTradingRules*  g_triangleTrading;
CAdvancedTrendFollower*       g_trendFollower;
CGrandeRiskManager*           g_riskManager;
CGrandeIntelligentReporter*   g_reporter;
CNewsSentimentIntegration     g_newsSentiment;
CGrandeMT5NewsReader          g_calendarReader;
CTrade                        g_trade;
RegimeConfig                  g_regimeConfig;
RiskConfig                    g_riskConfig;
TriangleTradingConfig         g_triangleConfig;
datetime                      g_lastRegimeUpdate;
datetime                      g_lastKeyLevelUpdate;
datetime                      g_lastTriangleUpdate;
datetime                      g_lastDisplayUpdate;
long                          g_chartID;
datetime                      g_lastRiskUpdate;
datetime                      g_lastCalendarUpdate;

// Cached RSI values per management cycle
datetime                      g_lastRsiCacheTime;
double                        g_cachedRsiCTF = EMPTY_VALUE;
double                        g_cachedRsiH4  = EMPTY_VALUE;
double                        g_cachedRsiD1  = EMPTY_VALUE;

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
    
    // Configure triangle trading settings
    g_triangleConfig.minConfidence = InpTriangleMinConfidence;
    g_triangleConfig.minBreakoutProb = InpTriangleMinBreakoutProb;
    g_triangleConfig.requireVolumeConfirm = InpTriangleRequireVolume;
    g_triangleConfig.maxRiskPercent = InpTriangleRiskPct;
    g_triangleConfig.allowEarlyEntry = InpTriangleAllowEarlyEntry;
    
    // Create and initialize triangle pattern detector (if enabled)
    g_triangleDetector = NULL;
    g_triangleTrading = NULL;
    if(InpEnableTriangleTrading)
    {
        g_triangleDetector = new CGrandeTrianglePatternDetector();
        if(g_triangleDetector == NULL)
        {
            Print("ERROR: Failed to create Triangle Pattern Detector");
            delete g_regimeDetector;
            delete g_keyLevelDetector;
            g_regimeDetector = NULL;
            g_keyLevelDetector = NULL;
            return INIT_FAILED;
        }
        
        TriangleConfig triangleConfig;
        if(!g_triangleDetector.Initialize(_Symbol, triangleConfig))
        {
            Print("ERROR: Failed to initialize Triangle Pattern Detector");
            delete g_regimeDetector;
            delete g_keyLevelDetector;
            delete g_triangleDetector;
            g_regimeDetector = NULL;
            g_keyLevelDetector = NULL;
            g_triangleDetector = NULL;
            return INIT_FAILED;
        }
        
        // Create and initialize triangle trading rules
        g_triangleTrading = new CGrandeTriangleTradingRules();
        if(g_triangleTrading == NULL)
        {
            Print("ERROR: Failed to create Triangle Trading Rules");
            delete g_regimeDetector;
            delete g_keyLevelDetector;
            delete g_triangleDetector;
            g_regimeDetector = NULL;
            g_keyLevelDetector = NULL;
            g_triangleDetector = NULL;
            return INIT_FAILED;
        }
        
        if(!g_triangleTrading.Initialize(_Symbol, g_triangleConfig))
        {
            Print("ERROR: Failed to initialize Triangle Trading Rules");
            delete g_regimeDetector;
            delete g_keyLevelDetector;
            delete g_triangleDetector;
            delete g_triangleTrading;
            g_regimeDetector = NULL;
            g_keyLevelDetector = NULL;
            g_triangleDetector = NULL;
            g_triangleTrading = NULL;
            return INIT_FAILED;
        }
        
        if(InpLogDebugInfo)
            Print("[Grande] Triangle Pattern Detection and Trading initialized");
    }
    
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
        g_lastCalendarUpdate = 0;
        
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
    
    // Generate immediate startup report after short delay to collect initial data
    EventSetTimer(5); // Set 5 second timer for initial report
    
    // Set up chart display - always setup for any visual features
    SetupChartDisplay();
    
    // Set timer for updates
    EventSetTimer(MathMin(MathMin(InpRegimeUpdateSeconds, InpKeyLevelUpdateSeconds), InpRiskUpdateSeconds));
    
    // Initialize update times
    g_lastRegimeUpdate = 0;
    g_lastKeyLevelUpdate = 0;
    g_lastTriangleUpdate = 0;
    g_lastDisplayUpdate = 0;
    g_lastRiskUpdate = 0;
    
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
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(InpLogDebugInfo)
        Print("Deinitializing Grande Trading System. Reason: ", reason);
    
    // Clean up timer
    EventKillTimer();
    
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
    
    if(g_triangleDetector != NULL)
    {
        delete g_triangleDetector;
        g_triangleDetector = NULL;
    }
    
    if(g_triangleTrading != NULL)
    {
        delete g_triangleTrading;
        g_triangleTrading = NULL;
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
    // Minimize OnTick work and avoid any logging or trade/risk operations here.
    // Check if trading is allowed
    if(!MQLInfoInteger(MQL_TRADE_ALLOWED) || !InpEnableTrading)
        return;
    // All periodic updates are handled in OnTimer to prevent per-tick thrashing
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
    
    // Periodic risk manager updates (trailing stop, breakeven, etc.)
    if(g_riskManager != NULL && currentTime - g_lastRiskUpdate >= InpRiskUpdateSeconds)
    {
        // CRITICAL FIX: Only manage positions on the designated timeframe to prevent competition
        if(!InpManageOnlyOnTimeframe || Period() == InpManagementTimeframe)
        {
            ResetLastError();
            // Cache RSI once per management tick for reuse
            if(InpEnableRSIExits || InpEnableMTFRSI)
                CacheRsiForCycle();
            g_riskManager.OnTick();
            // Add RSI-based exit management (optional)
            if(InpEnableRSIExits)
                ApplyRSIExitRules();
            // Do not log on timer by default; optional debug only
            int rmError = GetLastError();
            if(rmError == 0 && !g_riskManager.IsTradingEnabled())
            {
                // Trading disabled by risk checks; simply skip further actions this cycle
            }
        }
        g_lastRiskUpdate = currentTime;
    }
    
    // Update regime detection
    if(g_regimeDetector != NULL && 
       currentTime - g_lastRegimeUpdate >= InpRegimeUpdateSeconds)
    {
        RegimeSnapshot currentRegime = g_regimeDetector.DetectCurrentRegime();
        g_lastRegimeUpdate = currentTime;
        
        // Log regime changes if requested
        if(InpLogDetailedInfo)
        {
            static MARKET_REGIME lastLoggedRegime = REGIME_RANGING;
            if(currentRegime.regime != lastLoggedRegime)
            {
                LogRegimeChange(currentRegime);
                lastLoggedRegime = currentRegime.regime;
            }
        }

        // Execute trading logic periodically based on current regime (no tick-level execution)
        ResetLastError();
        ExecuteTradeLogic(currentRegime);
        // Swallow non-critical errors silently to avoid log spam
    }
    
    // Update key level detection
    if(g_keyLevelDetector != NULL && 
       currentTime - g_lastKeyLevelUpdate >= InpKeyLevelUpdateSeconds)
    {
        if(g_keyLevelDetector.DetectKeyLevels())
        {
            if(InpShowKeyLevels)
                g_keyLevelDetector.UpdateChartDisplay();
                
            if(InpLogDetailedInfo)
                g_keyLevelDetector.PrintKeyLevelsReport();
        }
        g_lastKeyLevelUpdate = currentTime;
    }
    
    // Update triangle pattern detection and trading
    if(g_triangleDetector != NULL && g_triangleTrading != NULL && 
       InpEnableTriangleTrading && currentTime - g_lastTriangleUpdate >= InpRegimeUpdateSeconds)
    {
        // CRITICAL: Only proceed if risk manager allows trading
        if(g_riskManager != NULL && !g_riskManager.IsTradingEnabled())
        {
            // Risk manager has disabled trading - skip triangle detection
            g_lastTriangleUpdate = currentTime;
            return;
        }
        
        // Update triangle pattern detection
        if(g_triangleDetector.DetectTrianglePattern(100))
        {
            // Generate trading signals if pattern detected
            STriangleSignal signal = g_triangleTrading.GenerateSignal();
            if(signal.isValid && InpEnableTrading)
            {
                // CRITICAL: Validate regime compatibility before executing
                RegimeSnapshot currentRegime = g_regimeDetector.GetLastSnapshot();
                if(IsTriangleRegimeCompatible(currentRegime.regime))
                {
                    // Execute triangle-based trades with full validation
                    ExecuteTriangleTrade(signal, currentRegime);
                }
                else if(InpLogDetailedInfo)
                {
                    Print("[Grande] Triangle trade skipped: Incompatible regime - ", GetRegimeString(currentRegime.regime));
                }
            }
        }
        g_lastTriangleUpdate = currentTime;
    }
    
    // Update trend follower
    if(g_trendFollower != NULL && InpEnableTrendFollower)
    {
        if(!g_trendFollower.Refresh())
        {
            Print("[Grande] Warning: Trend Follower refresh failed");
        }
    }
    
    // Calendar AI analysis (periodic)
    if(InpEnableCalendarAI 
       && (!InpCalendarOnlyOnTimeframe || Period() == InpCalendarRunTimeframe)
       && currentTime - g_lastCalendarUpdate >= InpCalendarUpdateMinutes * 60)
    {
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
                Print("[CAL-AI] Calendar analysis unavailable. Ensure MCP server and Docker FinBERT are running.");
            }
        }
        g_lastCalendarUpdate = currentTime;
    }
    
    // Update display elements
    if(currentTime - g_lastDisplayUpdate >= 10) // Update display every 10 seconds
    {
        UpdateDisplayElements();
        g_lastDisplayUpdate = currentTime;
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
void ConfigureTradeFillingMode();

//+------------------------------------------------------------------+
//| Perform initial analysis                                          |
//+------------------------------------------------------------------+
void PerformInitialAnalysis()
{
    // Get initial regime snapshot
    if(g_regimeDetector != NULL)
    {
        RegimeSnapshot initialRegime = g_regimeDetector.DetectCurrentRegime();
        if(InpLogDetailedInfo)
        {
            Print("[Grande] Current Market Regime: ", g_regimeDetector.RegimeToString(initialRegime.regime));
            Print("[Grande] Regime Confidence: ", DoubleToString(initialRegime.confidence, 3));
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
void UpdateDisplayElements()
{
    if(g_regimeDetector == NULL) 
        return;
    
    RegimeSnapshot currentRegime = g_regimeDetector.GetLastSnapshot();
    
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
                bool nearStrongLevel = MathAbs(currentPrice - strongestLevel.price) <= 0.0020; // Within 20 pips
                
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
void ExecuteTradeLogic(const RegimeSnapshot &rs)
{
    string logPrefix = "[TRADE DECISION] ";
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "=== ANALYZING TRADE OPPORTUNITY ===");
        Print(logPrefix + "Timestamp: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
        Print(logPrefix + "Symbol: ", _Symbol);
        Print(logPrefix + "Current Price: ", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits));
        Print(logPrefix + "Spread: ", SymbolInfoInteger(_Symbol, SYMBOL_SPREAD), " points");
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
    
    // Check if we already have position for this symbol & magic (avoid blocking other symbols)
    if(HasOpenPositionForSymbolAndMagic(_Symbol, InpMagicNumber))
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ BLOCKED: Position already open for symbol/magic");
        
        // Track rejection
        if(g_reporter != NULL)
        {
            decision.signal_type = "PRE_SIGNAL_CHECK";
            decision.decision = "BLOCKED";
            decision.rejection_reason = "Position already open for symbol/magic";
            g_reporter.RecordDecision(decision);
        }
        return;
    }
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "✅ Risk checks passed - proceeding with signal analysis");
        Print(logPrefix + "Market Regime: ", g_regimeDetector.RegimeToString(rs.regime));
        Print(logPrefix + "Regime Confidence: ", DoubleToString(rs.confidence, 3));
        Print(logPrefix + "ADX H1: ", DoubleToString(rs.adx_h1, 2));
        Print(logPrefix + "ADX H4: ", DoubleToString(rs.adx_h4, 2));
        Print(logPrefix + "ATR Current: ", DoubleToString(rs.atr_current, _Digits));
        Print(logPrefix + "ATR Average: ", DoubleToString(rs.atr_avg, _Digits));
    }
    
    // DISABLED: News sentiment refresh (commented out - only using free economic calendar data)
    /*
    // Optionally refresh sentiment before decisions (rate-limited)
    static datetime s_lastSentimentRun = 0;
    if(TimeCurrent() - s_lastSentimentRun > 300 && !g_newsSentiment.IsAnalysisFresh())
    {
        if(g_newsSentiment.RunNewsAnalysis())
        {
            if(InpLogDetailedInfo)
            {
                Print(logPrefix + "Sentiment refreshed: ", g_newsSentiment.GetSentimentDescription());
            }
        }
        s_lastSentimentRun = TimeCurrent();
    }
    */

    // Execute trading strategy with comprehensive error handling
    ResetLastError();
    
    switch(rs.regime)
    {
        case REGIME_TREND_BULL:   
            if(InpLogDetailedInfo) Print(logPrefix + "→ Analyzing BULLISH TREND opportunity...");
            TrendTrade(true, rs);   
            break;
        case REGIME_TREND_BEAR:   
            if(InpLogDetailedInfo) Print(logPrefix + "→ Analyzing BEARISH TREND opportunity...");
            TrendTrade(false, rs);  
            break;
        case REGIME_BREAKOUT_SETUP: 
            if(InpLogDetailedInfo) Print(logPrefix + "→ Analyzing BREAKOUT opportunity...");
            BreakoutTrade(rs);    
            break;
        case REGIME_RANGING:      
            if(InpLogDetailedInfo) Print(logPrefix + "→ Analyzing RANGE TRADING opportunity...");
            RangeTrade(rs);         
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
            if(InpLogDetailedInfo)
                Print("[Grande] INFO: Data not ready (err=", lastErr, ") — monitoring continues");
        }
        else
        {
            Print("[Grande] WARN: Non-trade error after analysis. Err=", lastErr);
        }
        ResetLastError();
    }
    
    if(InpLogDetailedInfo)
        Print(logPrefix + "=== TRADE ANALYSIS COMPLETE ===\n");
}

//+------------------------------------------------------------------+
//| Trend trading logic                                              |
//+------------------------------------------------------------------+
void TrendTrade(bool bullish, const RegimeSnapshot &rs)
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
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "Analyzing ", direction, " trend signal...");
        Print(logPrefix + "Required Risk %: ", DoubleToString(InpRiskPctTrend, 1), "%");
    }
    
    if(!Signal_TREND(bullish, rs)) 
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ ", direction, " trend signal REJECTED - signal criteria not met");
        return;
    }
    
    if(InpLogDetailedInfo)
        Print(logPrefix + "✅ ", direction, " trend signal CONFIRMED - proceeding with trade execution");
    
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
            Print(logPrefix + "  Lot Size (Risk Manager): ", DoubleToString(lot, 2));
    }
    else
    {
        lot = CalcLot(rs.regime); // Fallback to old method
        if(InpLogDetailedInfo)
            Print(logPrefix + "  Lot Size (Fallback): ", DoubleToString(lot, 2));
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
    
    // Calculate SL/TP using risk manager
    if(g_riskManager != NULL)
    {
        sl = g_riskManager.CalculateStopLoss(bullish, price, rs.atr_current);
        tp = g_riskManager.CalculateTakeProfit(bullish, price, sl);
    }
    else
    {
        sl = StopLoss_TREND(bullish, rs); // Fallback to old method
        tp = TakeProfit_TREND(bullish, rs);
    }

    // Ensure SL/TP respect broker min stop distance and correct side
    NormalizeStops(bullish, price, sl, tp);
    
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
                if(cappedTp < tp)
                {
                    tp = cappedTp;
                    tpLockTag = StringFormat("|TP_LOCK@%s|R=%s|SCORE=%.2f", DoubleToString(tp, digits), DoubleToString(strongRes.price, digits), strongRes.strength);
                }
            }
            else if(!bullish && haveStrongSup)
            {
                double cappedTp = NormalizeDouble(strongSup.price + buffer, digits);
                if(cappedTp > tp)
                {
                    tp = cappedTp;
                    tpLockTag = StringFormat("|TP_LOCK@%s|S=%s|SCORE=%.2f", DoubleToString(tp, digits), DoubleToString(strongSup.price, digits), strongSup.strength);
                }
            }
        }
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
    
    bool tradeResult = false;
    if(bullish)
        tradeResult = g_trade.Buy(lot, _Symbol, price, sl, tp, comment);
    else
        tradeResult = g_trade.Sell(lot, _Symbol, price, sl, tp, comment);
    
    // Always-on concise summary for monitoring
    Print(StringFormat("[TREND] %s %s @%s SL=%s TP=%s lot=%.2f rr=%.2f%s",
                       (tradeResult?"FILLED":"FAILED"),
                       bullish?"BUY":"SELL",
                       DoubleToString(price, _Digits),
                       DoubleToString(sl, _Digits),
                       DoubleToString(tp, _Digits),
                       lot,
                       (MathAbs(tp-price)/MathMax(1e-10, MathAbs(price-sl))),
                       (sentimentSupports?" senti=YES":"")));

    // Track execution result
    execution.calculated_lot = lot;
    execution.risk_percent = InpRiskPctTrend;
    
    if(tradeResult)
    {
        execution.decision = "EXECUTED";
        execution.rejection_reason = "";
        execution.additional_notes = StringFormat("Order #%lld filled at %.5f", 
                                                 g_trade.ResultOrder(), 
                                                 g_trade.ResultPrice());
        if(g_reporter != NULL) g_reporter.RecordDecision(execution);
        
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "🎯 TRADE EXECUTED SUCCESSFULLY!");
            Print(logPrefix + "  Ticket: ", g_trade.ResultOrder());
            Print(logPrefix + "  Execution Price: ", DoubleToString(g_trade.ResultPrice(), _Digits));
            Print(logPrefix + "  Slippage: ", DoubleToString(MathAbs(g_trade.ResultPrice() - price) / _Point, 1), " pips");
        }
    }
    else
    {
        execution.decision = "FAILED";
        execution.rejection_reason = StringFormat("Execution failed - Error %d: %s",
                                                 g_trade.ResultRetcode(),
                                                 g_trade.ResultRetcodeDescription());
        if(g_reporter != NULL) g_reporter.RecordDecision(execution);
        
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
void BreakoutTrade(const RegimeSnapshot &rs)
{
    string logPrefix = "[BREAKOUT SIGNAL] ";
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "Analyzing breakout opportunity...");
        Print(logPrefix + "Required Risk %: ", DoubleToString(InpRiskPctBreakout, 1), "%");
    }
    
    if(!Signal_BREAKOUT(rs)) 
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ Breakout signal REJECTED - signal criteria not met");
        return;
    }
    
    if(InpLogDetailedInfo)
        Print(logPrefix + "✅ Breakout signal CONFIRMED - proceeding with trade setup");
    
    // Get strongest key level for breakout
    SKeyLevel strongestLevel;
    if(!g_keyLevelDetector.GetStrongestLevel(strongestLevel))
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ TRADE BLOCKED: No strong key levels found");
        Print("[BREAKOUT] BLOCK: no strong key levels");
        return;
    }
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double breakoutLevel = strongestLevel.price;
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
        breakoutTP = g_riskManager.CalculateTakeProfit(isBuy, breakoutLevel, breakoutSL);
    }
    else
    {
        // Fallback to old method
        breakoutSL = strongestLevel.isResistance ? 
                    breakoutLevel + rs.atr_current * 1.2 : 
                    breakoutLevel - rs.atr_current * 1.2;
        breakoutTP = strongestLevel.isResistance ? 
                    breakoutLevel - rs.atr_current * 3.0 : 
                    breakoutLevel + rs.atr_current * 3.0;
    }
    
    string comment = StringFormat("%s BO-%s", InpOrderTag, strongestLevel.isResistance ? "RESISTANCE" : "SUPPORT");
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
    
    // Validate pending trigger distance vs current price and deduplicate
    bool isBuyStop = strongestLevel.isResistance;
    if(!IsPendingPriceValid(isBuyStop, breakoutLevel))
    {
        Print(StringFormat("[BREAKOUT] BLOCK: invalid trigger vs price/min distance (level=%s)", DoubleToString(breakoutLevel, _Digits)));
        return;
    }

    // Normalize lot and stops for pending order
    lot = NormalizeVolumeToStep(_Symbol, lot);
    NormalizeStops(isBuyStop, breakoutLevel, breakoutSL, breakoutTP);

    // Skip if a similar pending already exists (within 3 points)
    if(HasSimilarPendingOrderForBreakout(isBuyStop, breakoutLevel, 3))
    {
        if(InpLogDetailedInfo)
            Print("[BREAKOUT] Skip: similar pending already exists near level");
        return;
    }

    // Place stop order
    bool tradeResult = false;
    if(strongestLevel.isResistance)
        tradeResult = g_trade.BuyStop(NormalizeDouble(lot, 2), NormalizeDouble(breakoutLevel, _Digits), NormalizeDouble(breakoutSL, _Digits), NormalizeDouble(breakoutTP, _Digits), comment);
    else
        tradeResult = g_trade.SellStop(NormalizeDouble(lot, 2), NormalizeDouble(breakoutLevel, _Digits), NormalizeDouble(breakoutSL, _Digits), NormalizeDouble(breakoutTP, _Digits), comment);
    // Always-on concise outcome
    if(tradeResult)
        Print(StringFormat("[BREAKOUT] ORDER PLACED OK ticket=%I64u", g_trade.ResultOrder()));
    else
        Print(StringFormat("[BREAKOUT] ORDER FAILED retcode=%d desc=%s", g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()));
    
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
void RangeTrade(const RegimeSnapshot &rs)
{
    string logPrefix = "[RANGE SIGNAL] ";
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "Analyzing range trading opportunity...");
        Print(logPrefix + "Required Risk %: ", DoubleToString(InpRiskPctRange, 1), "%");
    }
    
    if(!Signal_RANGE(rs)) 
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ Range signal REJECTED - signal criteria not met");
        return;
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
        
        bool tradeResult = g_trade.Buy(lot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), sl, tp, StringFormat("%s Range-Buy", InpOrderTag));
        // Always-on concise outcome
        Print(StringFormat("[RANGE] %s BUY @%s SL=%s TP=%s lot=%.2f rr=%.2f",
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
                Print(logPrefix + "🎯 RANGE BUY EXECUTED SUCCESSFULLY!");
                Print(logPrefix + "  Ticket: ", g_trade.ResultOrder());
                Print(logPrefix + "  Execution Price: ", DoubleToString(g_trade.ResultPrice(), _Digits));
            }
            else
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
    if(g_trendFollower != NULL && InpEnableTrendFollower)
    {
        bool trendFollowerSignal = bullish ? g_trendFollower.IsBullish() : g_trendFollower.IsBearish();
        
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "1. Trend Follower Analysis:");
            Print(logPrefix + "  Multi-timeframe signal: ", trendFollowerSignal ? "✅ CONFIRMED" : "❌ REJECTED");
            Print(logPrefix + "  TF Strength: ", DoubleToString(g_trendFollower.TrendStrength(), 2));
            Print(logPrefix + "  TF Pullback Price (EMA20): ", DoubleToString(g_trendFollower.EntryPricePullback(), _Digits));
        }
        
        if(!trendFollowerSignal)
        {
            if(InpLogDetailedInfo)
                Print(logPrefix + "❌ SIGNAL BLOCKED: Trend Follower rejected ", direction, " signal");
            
            rejection_reason = "Trend Follower multi-timeframe analysis rejected signal";
            decision.decision = "REJECTED";
            decision.rejection_reason = rejection_reason;
            if(g_reporter != NULL) g_reporter.RecordDecision(decision);
            return false;
        }
    }
    else if(InpLogDetailedInfo)
    {
        Print(logPrefix + "1. Trend Follower: DISABLED (proceeding with original logic)");
    }
    
    // === ORIGINAL GRANDE EMA ALIGNMENT LOGIC ===
    // 50 & 200 EMA alignment across H1 + H4
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
    bool pullbackValid = (pullbackDistance <= rs.atr_current);
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "3. Pullback Analysis:");
        Print(logPrefix + "  Current Price: ", DoubleToString(currentPrice, _Digits));
        Print(logPrefix + "  EMA20: ", DoubleToString(ema20, _Digits));
        Print(logPrefix + "  Distance to EMA20: ", DoubleToString(pullbackDistance, _Digits), " (", DoubleToString(pullbackDistance / _Point, 1), " pips)");
        Print(logPrefix + "  ATR Limit: ", DoubleToString(rs.atr_current, _Digits), " (", DoubleToString(rs.atr_current / _Point, 1), " pips)");
        Print(logPrefix + "  Pullback Valid: ", pullbackValid ? "✅ WITHIN LIMIT" : "❌ TOO FAR");
    }
    
    if(!pullbackValid)
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ SIGNAL BLOCKED: Price too far from EMA20 (pullback > 1×ATR)");
        
        rejection_reason = StringFormat("Pullback too far - Distance: %.1f pips, Limit: %.1f pips",
                                       pullbackDistance / _Point,
                                       rs.atr_current / _Point);
        decision.decision = "REJECTED";
        decision.rejection_reason = rejection_reason;
        if(g_reporter != NULL) g_reporter.RecordDecision(decision);
        return false;
    }
    
    // Higher-timeframe RSI exhaustion gate
    if(InpEnableMTFRSI)
    {
        // Use cached values if available
        double rsi_h4 = (g_cachedRsiH4 != EMPTY_VALUE ? g_cachedRsiH4 : GetRSIValue(_Symbol, PERIOD_H4, InpTFRsiPeriod, 0));
        if(rsi_h4 < 0) return false;

            if(bullish && rsi_h4 >= InpH4RSIOverbought)
            {
                if(InpLogDetailedInfo) 
                    Print(logPrefix + "❌ SIGNAL BLOCKED: H4 RSI overbought (", DoubleToString(rsi_h4, 2), ")");
                
                rejection_reason = StringFormat("H4 RSI overbought - %.1f (threshold %.1f)", rsi_h4, InpH4RSIOverbought);
                decision.decision = "REJECTED";
                decision.rejection_reason = rejection_reason;
                decision.rsi_h4 = rsi_h4;
                if(g_reporter != NULL) g_reporter.RecordDecision(decision);
                return false;
            }
            if(!bullish && rsi_h4 <= InpH4RSIOversold)
            {
                if(InpLogDetailedInfo) 
                    Print(logPrefix + "❌ SIGNAL BLOCKED: H4 RSI oversold (", DoubleToString(rsi_h4, 2), ")");
                
                rejection_reason = StringFormat("H4 RSI oversold - %.1f (threshold %.1f)", rsi_h4, InpH4RSIOversold);
                decision.decision = "REJECTED";
                decision.rejection_reason = rejection_reason;
                decision.rsi_h4 = rsi_h4;
                if(g_reporter != NULL) g_reporter.RecordDecision(decision);
                return false;
            }

        if(InpUseD1RSI)
        {
            double rsi_d1 = (g_cachedRsiD1 != EMPTY_VALUE ? g_cachedRsiD1 : GetRSIValue(_Symbol, PERIOD_D1, InpTFRsiPeriod, 0));
            if(rsi_d1 < 0) return false;

            if(bullish && rsi_d1 >= InpD1RSIOverbought)
            {
                if(InpLogDetailedInfo) 
                    Print(logPrefix + "❌ SIGNAL BLOCKED: D1 RSI overbought (", DoubleToString(rsi_d1, 2), ")");
                return false;
            }
            if(!bullish && rsi_d1 <= InpD1RSIOversold)
            {
                if(InpLogDetailedInfo) 
                    Print(logPrefix + "❌ SIGNAL BLOCKED: D1 RSI oversold (", DoubleToString(rsi_d1, 2), ")");
                return false;
            }
        }
        
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "5. Multi-Timeframe RSI Analysis:");
            Print(logPrefix + "  H4 RSI: ", DoubleToString(rsi_h4, 2), " (", 
                  (bullish ? (rsi_h4 < InpH4RSIOverbought ? "✅ NOT OVERBOUGHT" : "❌ OVERBOUGHT") :
                            (rsi_h4 > InpH4RSIOversold ? "✅ NOT OVERSOLD" : "❌ OVERSOLD")), ")");
            if(InpUseD1RSI)
            {
                double rsi_d1 = (g_cachedRsiD1 != EMPTY_VALUE ? g_cachedRsiD1 : GetRSIValue(_Symbol, PERIOD_D1, InpTFRsiPeriod, 0));
                Print(logPrefix + "  D1 RSI: ", DoubleToString(rsi_d1, 2), " (", 
                      (bullish ? (rsi_d1 < InpD1RSIOverbought ? "✅ NOT OVERBOUGHT" : "❌ OVERBOUGHT") :
                                (rsi_d1 > InpD1RSIOversold ? "✅ NOT OVERSOLD" : "❌ OVERSOLD")), ")");
            }
        }
    }
    
    // RSI(14) 40-60 reset, then hook with price continuation
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
    
    bool rsiCondition = bullish ? 
                       (rsi > 40 && rsi < 60 && rsi > rsi_prev) :
                       (rsi > 40 && rsi < 60 && rsi < rsi_prev);
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "4. RSI Momentum Analysis:");
        Print(logPrefix + "  RSI Current: ", DoubleToString(rsi, 2));
        Print(logPrefix + "  RSI Previous: ", DoubleToString(rsi_prev, 2));
        Print(logPrefix + "  RSI in Range (40-60): ", (rsi > 40 && rsi < 60) ? "✅" : "❌");
        Print(logPrefix + "  RSI Direction: ", bullish ? (rsi > rsi_prev ? "✅ RISING" : "❌ FALLING") : 
                                                        (rsi < rsi_prev ? "✅ FALLING" : "❌ RISING"));
        Print(logPrefix + "  RSI Condition: ", rsiCondition ? "✅ CONFIRMED" : "❌ REJECTED");
    }
    
    if(!rsiCondition)
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ SIGNAL BLOCKED: RSI momentum not aligned with ", direction, " trend");
        
        rejection_reason = StringFormat("RSI conditions failed - Current: %.1f (need 40-60 and %s)",
                                       rsi, bullish ? "rising" : "falling");
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
        Print(logPrefix + "  ✅ Price Pullback (≤ 1×ATR from EMA20)");
        if(InpEnableMTFRSI)
            Print(logPrefix + "  ✅ Multi-TF RSI (H4/D1 not exhausted)");
        Print(logPrefix + "  ✅ RSI Momentum (40-60 range with correct direction)");
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
    
    // Accept breakout if ANY of these conditions are met: Inside Bar, NR7, or ATR Expansion
    if(!insideBar && !nr7 && !atrExpanding) 
    {
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "❌ CRITERIA FAILED: No inside bar, NR7 pattern, or ATR expansion detected");
            Print(StringFormat("[BREAKOUT] FAIL pattern (IB:%s NR7:%s ATRexp:%s)",
                               insideBar ? "Y" : "N",
                               nr7 ? "Y" : "N",
                               atrExpanding ? "Y" : "N"));
        }
        
        decision.decision = "REJECTED";
        decision.rejection_reason = "No valid pattern (no inside bar, NR7, or ATR expansion)";
        if(g_reporter != NULL) g_reporter.RecordDecision(decision);
        return false;
    }
    
    // Check if near strong key level
    SKeyLevel strongestLevel;
    if(!g_keyLevelDetector.GetStrongestLevel(strongestLevel))
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ CRITERIA FAILED: No strong key levels available");
        Print("[BREAKOUT] FAIL: no strong key levels");
        
        decision.decision = "REJECTED";
        decision.rejection_reason = "No strong key levels detected";
        if(g_reporter != NULL) g_reporter.RecordDecision(decision);
        return false;
    }
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double distanceToLevel = MathAbs(currentPrice - strongestLevel.price);
    double maxDistance = rs.atr_current * 0.5;  // Expanded from 0.2 to catch more breakouts
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
    
    if(!nearKeyLevel)
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
    
    // Volume spike ≥ 1.2 × 20-bar MA (relaxed for more opportunities)
    long volume = iTickVolume(_Symbol, PERIOD_CURRENT, 0);
    long avgVolume = GetAverageVolume(20);
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
    
    if(!volumeSpike)
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

double TakeProfit_TREND(bool bullish, const RegimeSnapshot &rs)
{
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
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

        // Cooldown check using chart objects
        string cooldownKey = StringFormat("RSIExitCooldown_%I64u", ticket);
        datetime lastTime = 0;
        string lastStr = ObjectGetString(g_chartID, cooldownKey, OBJPROP_TOOLTIP);
        if(lastStr != NULL && StringLen(lastStr) > 0)
            lastTime = (datetime)StringToInteger(lastStr);
        if(InpRSIExitCooldownSec > 0 && (TimeCurrent() - lastTime) < InpRSIExitCooldownSec)
            continue;

        double pip = GetPipSize();
        if(pip <= 0) pip = _Point;
        double profitPips = (type == POSITION_TYPE_BUY ? (price - open) : (open - price)) / pip;
        if(profitPips < InpRSIExitMinProfitPips) continue;

        // Use cached RSI values from current cycle
        double rsi_ctf = (g_cachedRsiCTF != EMPTY_VALUE ? g_cachedRsiCTF : GetRSIValue(_Symbol, (ENUM_TIMEFRAMES)Period(), InpRSIPeriod, 0));
        double rsi_h4  = (g_cachedRsiH4  != EMPTY_VALUE ? g_cachedRsiH4  : GetRSIValue(_Symbol, PERIOD_H4, InpTFRsiPeriod, 0));
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
                double riskPips = MathAbs(open - sl) / pip;
                if(riskPips > 0 && profitPips < riskPips)
                    continue;
            }
        }

        bool exitSignal = false;
        if(type == POSITION_TYPE_BUY)
            exitSignal = (rsi_ctf >= InpRSIExitOB) || (rsi_h4 >= InpH4RSIOverbought);
        else
            exitSignal = (rsi_ctf <= InpRSIExitOS) || (rsi_h4 <= InpH4RSIOversold);

        if(!exitSignal) continue;

        double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
        double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double closeVol = MathFloor(MathMax(vmin, vol * InpRSIPartialClose) / step) * step;
        if(closeVol < vmin || closeVol >= vol) continue;
        // Ensure minimum remaining volume
        if((vol - closeVol) < MathMax(vmin, InpMinRemainingVolume))
            continue;

        bool ok = g_trade.PositionClosePartial(ticket, closeVol);
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
    
    // Check if current ATR is 50% higher than average (momentum building)
    double expansionRatio = currentATR / averageATR;
    bool isExpanding = (expansionRatio >= 1.5);
    
    if(InpLogDetailedInfo)
    {
        Print("[ATR MOMENTUM] Current ATR: ", DoubleToString(currentATR, _Digits));
        Print("[ATR MOMENTUM] 10-Period Avg: ", DoubleToString(averageATR, _Digits));
        Print("[ATR MOMENTUM] Expansion Ratio: ", DoubleToString(expansionRatio, 2), "x");
        Print("[ATR MOMENTUM] Momentum Building: ", isExpanding ? "✅ YES (≥1.5x)" : "❌ NO (<1.5x)");
    }
    
    return isExpanding;
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
    if(now == g_lastRsiCacheTime) return;

    g_cachedRsiCTF = GetRSIValue(_Symbol, (ENUM_TIMEFRAMES)Period(), InpRSIPeriod, 0);
    g_cachedRsiH4  = GetRSIValue(_Symbol, PERIOD_H4, InpTFRsiPeriod, 0);
    // Only cache D1 if enabled to save cycles
    g_cachedRsiD1  = InpUseD1RSI ? GetRSIValue(_Symbol, PERIOD_D1, InpTFRsiPeriod, 0) : EMPTY_VALUE;
    g_lastRsiCacheTime = now;
}

bool ValidateInputParameters()
{
    bool isValid = true;
    
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
    
    if(InpTouchZone != 0.0 && (InpTouchZone < 0.0001 || InpTouchZone > 0.0050))
    {
        Print("ERROR: InpTouchZone must be 0 (auto) or between 0.0001 and 0.0050. Current: ", InpTouchZone);
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
                Print(StringFormat("[CLOSE] SUCCESS ticket=%I64u", ticket));
            }
            else
            {
                Print(StringFormat("[CLOSE] FAIL ticket=%I64u err=%d", ticket, GetLastError()));
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
            if(InpLogDetailedInfo)
                Print("[Grande] FIFO volume close failed for #", oldestTicket, " Error: ", GetLastError());
            break;
        }

        closed += allowable;
        remaining -= allowable;
    }

    return closed;
}

//+------------------------------------------------------------------+
//| Execute Triangle Pattern Trade with Full Integration            |
//+------------------------------------------------------------------+
void ExecuteTriangleTrade(const STriangleSignal &signal, const RegimeSnapshot &currentRegime)
{
    if(!signal.isValid)
        return;
    
    string logPrefix = "[TRIANGLE TRADE] ";
    
    // CRITICAL: Check if we already have a triangle trade open
    if(HasTrianglePositionOpen())
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "Triangle trade already open, skipping new signal");
        return;
    }
    
    // CRITICAL: Check for conflicting positions
    if(HasConflictingPosition(signal.orderType))
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "Conflicting position exists, skipping triangle trade");
        return;
    }
    
    // CRITICAL: Validate trade setup with triangle trading rules
    if(!g_triangleTrading.ValidateTradeSetup())
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "Triangle trade setup validation failed");
        return;
    }
    
    // CRITICAL: Use Risk Manager for position sizing and validation
    double stopDistancePips = MathAbs(signal.stopLoss - signal.entryPrice) / _Point;
    double lotSize = 0.0;
    
    if(g_riskManager != NULL)
    {
        // Use Grande Risk Manager for position sizing
        lotSize = g_riskManager.CalculateLotSize(stopDistancePips, currentRegime.regime);
        
        // Risk manager validation is handled by CalculateLotSize returning 0 for invalid setups
        
        if(InpLogDetailedInfo)
        {
            Print(logPrefix + "Risk Manager Integration:");
            Print(logPrefix + "  Stop Distance: ", DoubleToString(stopDistancePips, 1), " pips");
            Print(logPrefix + "  Lot Size (Risk Manager): ", DoubleToString(lotSize, 2));
            Print(logPrefix + "  Regime: ", GetRegimeString(currentRegime.regime));
        }
    }
    else
    {
        // Fallback to triangle trading rules position sizing
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = g_triangleTrading.CalculateRiskAmount(accountBalance);
        lotSize = g_triangleTrading.CalculatePositionSize(accountBalance, riskAmount);
        
        if(InpLogDetailedInfo)
            Print(logPrefix + "Using fallback position sizing: ", DoubleToString(lotSize, 2));
    }
    
    if(lotSize <= 0)
    {
        Print(logPrefix + "ERROR: Invalid lot size calculated (", DoubleToString(lotSize, 2), ")");
        return;
    }
    
    // CRITICAL: Final risk validation
    double currentRisk = CalculateCurrentAccountRisk();
    double triangleRisk = (MathAbs(signal.stopLoss - signal.entryPrice) * lotSize) / AccountInfoDouble(ACCOUNT_BALANCE) * 100;
    
    if(currentRisk + triangleRisk > InpMaxRiskPerTrade)
    {
        Print(logPrefix + "Trade blocked: Risk limit exceeded (", DoubleToString(currentRisk + triangleRisk, 1), "% > ", InpMaxRiskPerTrade, "%)");
        return;
    }
    
    // Execute the trade with proper integration
    bool success = false;
    string comment = StringFormat("[GRANDE-TRIANGLE-%s] %s", 
                                 GetRegimeString(currentRegime.regime),
                                 g_triangleTrading.GetSignalTypeString());
    // DISABLED: News sentiment support for triangle trades (commented out - only using free economic calendar data)
    bool triangleSenti = false; // Always false since news sentiment is disabled
    /*
    // Append concise sentiment tag if sentiment aligns
    if(g_newsSentiment.GetCurrentSignal() != "")
    {
        if(signal.orderType == ORDER_TYPE_BUY)
            triangleSenti = g_newsSentiment.ShouldEnterLong();
        else if(signal.orderType == ORDER_TYPE_SELL)
            triangleSenti = g_newsSentiment.ShouldEnterShort();
        if(triangleSenti)
        {
            comment += "|SENTI";
        }
    }
    */
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "Trade Parameters:");
        Print(logPrefix + "  Direction: ", g_triangleTrading.GetSignalTypeString());
        Print(logPrefix + "  Entry Price: ", DoubleToString(signal.entryPrice, _Digits));
        Print(logPrefix + "  Stop Loss: ", DoubleToString(signal.stopLoss, _Digits));
        Print(logPrefix + "  Take Profit: ", DoubleToString(signal.takeProfit, _Digits));
        Print(logPrefix + "  Lot Size: ", DoubleToString(lotSize, 2));
        Print(logPrefix + "  Risk/Reward: 1:", DoubleToString(MathAbs(signal.takeProfit - signal.entryPrice) / MathAbs(signal.entryPrice - signal.stopLoss), 2));
        Print(logPrefix + "  Regime: ", GetRegimeString(currentRegime.regime));
        Print(logPrefix + "  Pattern: ", g_triangleDetector.GetPatternTypeString());
        Print(logPrefix + "→ EXECUTING TRIANGLE TRADE...");
    }
    
    if(signal.orderType == ORDER_TYPE_BUY)
    {
        success = g_trade.Buy(lotSize, _Symbol, signal.entryPrice, signal.stopLoss, 
                             signal.takeProfit, comment);
    }
    else if(signal.orderType == ORDER_TYPE_SELL)
    {
        success = g_trade.Sell(lotSize, _Symbol, signal.entryPrice, signal.stopLoss, 
                              signal.takeProfit, comment);
    }
    
    // Always-on concise summary for monitoring
    Print(StringFormat("[TRIANGLE] %s %s @%s SL=%s TP=%s lot=%.2f rr=%.2f pattern=%s%s",
                       (success ? "FILLED" : "FAILED"),
                       g_triangleTrading.GetSignalTypeString(),
                       DoubleToString(signal.entryPrice, _Digits),
                       DoubleToString(signal.stopLoss, _Digits),
                       DoubleToString(signal.takeProfit, _Digits),
                       lotSize,
                       (MathAbs(signal.takeProfit - signal.entryPrice) / MathMax(1e-10, MathAbs(signal.entryPrice - signal.stopLoss))),
                       g_triangleDetector.GetPatternTypeString(),
                       (triangleSenti?" senti=YES":"")));
    
    if(success)
    {
        if(InpLogDetailedInfo)
        {
            Print("✅ TRIANGLE TRADE EXECUTED:");
            Print("   Type: ", g_triangleTrading.GetSignalTypeString());
            Print("   Entry: ", DoubleToString(signal.entryPrice, _Digits));
            Print("   Stop Loss: ", DoubleToString(signal.stopLoss, _Digits));
            Print("   Take Profit: ", DoubleToString(signal.takeProfit, _Digits));
            Print("   Lot Size: ", DoubleToString(lotSize, 2));
            Print("   Signal Strength: ", DoubleToString(signal.signalStrength * 100, 1), "%");
            Print("   Pattern: ", g_triangleDetector.GetPatternTypeString());
            Print("   Regime: ", GetRegimeString(currentRegime.regime));
            Print("   Comment: ", comment);
            Print("   Reason: ", signal.signalReason);
        }
        
        // Register triangle trade for special management
        RegisterTriangleTrade(signal);
    }
    else
    {
        Print(logPrefix + "Trade execution failed. Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Check if Triangle Position is Already Open                      |
//+------------------------------------------------------------------+
bool HasTrianglePositionOpen()
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetTicket(i) > 0)
        {
            string comment = PositionGetString(POSITION_COMMENT);
            if(StringFind(comment, "[GRANDE-TRIANGLE]") >= 0)
                return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check if Triangle Trading is Compatible with Current Regime     |
//+------------------------------------------------------------------+
bool IsTriangleRegimeCompatible(MARKET_REGIME regime)
{
    // Triangle trading works best in breakout and ranging regimes
    switch(regime)
    {
        case REGIME_BREAKOUT_SETUP:  return true;  // Perfect for triangle breakouts
        case REGIME_RANGING:         return true;  // Good for triangle formations
        case REGIME_TREND_BULL:      return true;  // Can work with trend continuation
        case REGIME_TREND_BEAR:      return true;  // Can work with trend continuation
        case REGIME_HIGH_VOLATILITY: return false; // Too risky for precise triangle patterns
        default:                     return false;
    }
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
//| Register Triangle Trade for Special Management                  |
//+------------------------------------------------------------------+
void RegisterTriangleTrade(const STriangleSignal &signal)
{
    // This function can be expanded to track triangle trades for special management
    // For now, it's a placeholder for future triangle-specific position management
    if(InpLogDetailedInfo)
    {
        Print("[TRIANGLE] Trade registered for special management:");
        Print("  Pattern: ", g_triangleDetector.GetPatternTypeString());
        Print("  Signal Strength: ", DoubleToString(signal.signalStrength * 100, 1), "%");
        Print("  Breakout Confirmed: ", signal.breakoutConfirmed ? "YES" : "NO");
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

void ConfigureTradeFillingMode()
{
    // Prefer FOK, fall back to RETURN if required
    long filling = (long)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    // If symbol supports FOK or IOC, set accordingly. Otherwise, RETURN is safest.
    // SYMBOL_FILLING_MODE returns bitmask in some brokers; be conservative.
    g_trade.SetTypeFilling(ORDER_FILLING_FOK);
}