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
#include "..\VSol\AdvancedTrendFollower.mqh"
#include "..\VSol\GrandeRiskManager.mqh"
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== Market Regime Settings ==="
input double InpADXTrendThreshold = 25.0;        // ADX Threshold for Trending
input double InpADXBreakoutMin = 20.0;           // ADX Minimum for Breakout Setup
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

input group "=== Risk Management Settings ==="
input double InpRiskPctTrend = 2.5;              // Risk % for Trend Trades
input double InpRiskPctRange = 1.0;              // Risk % for Range Trades
input double InpRiskPctBreakout = 3.0;           // Risk % for Breakout Trades
input double InpMaxRiskPerTrade = 5.0;           // Maximum Risk % per Trade
input double InpMaxDrawdownPct = 25.0;           // Maximum Account Drawdown %
input double InpEquityPeakReset = 5.0;           // Reset Peak after X% Recovery
input int    InpMaxPositions = 3;                // Maximum Concurrent Positions

input group "=== Stop Loss & Take Profit ==="
input double InpSLATRMultiplier = 1.2;           // Stop Loss ATR Multiplier
input double InpTPRewardRatio = 3.0;             // Take Profit Reward Ratio (R:R)
input double InpBreakevenATR = 1.0;              // Move to Breakeven after X ATR
input double InpPartialCloseATR = 2.0;           // Partial Close after X ATR
input double InpBreakevenBuffer = 0.5;           // Breakeven Buffer (pips)

input group "=== Position Management ==="
input bool   InpEnableTrailingStop = true;       // Enable Trailing Stops
input double InpTrailingATRMultiplier = 0.8;     // Trailing Stop ATR Multiplier
input bool   InpEnablePartialCloses = true;      // Enable Partial Profit Taking
input double InpPartialClosePercent = 50.0;      // % of Position to Close
input bool   InpEnableBreakeven = true;          // Enable Breakeven Stops
input ENUM_TIMEFRAMES InpManagementTimeframe = PERIOD_H1; // Only manage on this TF when gated
input bool   InpManageOnlyOnTimeframe = true;    // Gate management to InpManagementTimeframe
input double InpMinModifyPips = 7.0;             // Min pips change to modify SL/TP
input double InpMinModifyATRFraction = 0.07;     // Fraction of ATR for material change
input int    InpMinModifyCooldownSec = 180;      // Cooldown between SL/TP modifies

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
input int    InpTFAdxPeriod = 14;                // TF ADX Period
input double InpTFAdxThreshold = 25.0;           // TF ADX Minimum Threshold
input bool   InpShowTrendFollowerPanel = true;   // Show TF Diagnostic Panel

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

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CGrandeMarketRegimeDetector*  g_regimeDetector;
CGrandeKeyLevelDetector*      g_keyLevelDetector;
CAdvancedTrendFollower*       g_trendFollower;
CGrandeRiskManager*           g_riskManager;
CTrade                        g_trade;
RegimeConfig                  g_regimeConfig;
RiskConfig                    g_riskConfig;
datetime                      g_lastRegimeUpdate;
datetime                      g_lastKeyLevelUpdate;
datetime                      g_lastDisplayUpdate;
long                          g_chartID;
datetime                      g_lastRiskUpdate;

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
    g_trade.SetTypeFilling(ORDER_FILLING_FOK);
    
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
    
    // Set up chart display - always setup for any visual features
    SetupChartDisplay();
    
    // Set timer for updates
    EventSetTimer(MathMin(MathMin(InpRegimeUpdateSeconds, InpKeyLevelUpdateSeconds), InpRiskUpdateSeconds));
    
    // Initialize update times
    g_lastRegimeUpdate = 0;
    g_lastKeyLevelUpdate = 0;
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
    
    // Periodic risk manager updates (trailing stop, breakeven, etc.)
    if(g_riskManager != NULL && currentTime - g_lastRiskUpdate >= InpRiskUpdateSeconds)
    {
        ResetLastError();
        g_riskManager.OnTick();
        // Do not log on timer by default; optional debug only
        int rmError = GetLastError();
        if(rmError == 0 && !g_riskManager.IsTradingEnabled())
        {
            // Trading disabled by risk checks; simply skip further actions this cycle
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
    
    // Update trend follower
    if(g_trendFollower != NULL && InpEnableTrendFollower)
    {
        if(!g_trendFollower.Refresh())
        {
            Print("[Grande] Warning: Trend Follower refresh failed");
        }
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
    
    // Check risk management first
    if(g_riskManager != NULL)
    {
        if(!g_riskManager.CheckDrawdown())
        {
            if(InpLogDetailedInfo)
                Print(logPrefix + "❌ BLOCKED: Maximum drawdown limit reached (", 
                      DoubleToString(InpMaxDrawdownPct, 1), "%)");
            return;
        }
            
        if(!g_riskManager.CheckMaxPositions())
        {
            if(InpLogDetailedInfo)
                Print(logPrefix + "❌ BLOCKED: Maximum positions limit reached (", 
                      InpMaxPositions, " positions)");
            return;
        }
    }
    
    // Check if we already have positions
    if(PositionsTotal() > 0)
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ BLOCKED: Already have ", PositionsTotal(), " open position(s)");
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
    
    // Check for errors after trade execution
    int error = GetLastError();
    if(error != 0)
    {
        Print("[Grande] ERROR: Trade execution function failed. Error: ", error);
        Print("[Grande] INFO: System will continue monitoring for next opportunity");
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
    
    if(lot <= 0) 
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ TRADE BLOCKED: Invalid lot size (", DoubleToString(lot, 2), ")");
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
    Print(StringFormat("[TREND] %s %s @%s SL=%s TP=%s lot=%.2f rr=%.2f",
                       (tradeResult?"FILLED":"FAILED"),
                       bullish?"BUY":"SELL",
                       DoubleToString(price, _Digits),
                       DoubleToString(sl, _Digits),
                       DoubleToString(tp, _Digits),
                       lot,
                       (MathAbs(tp-price)/MathMax(1e-10, MathAbs(price-sl)))));

    if(InpLogDetailedInfo)
    {
        if(tradeResult)
        {
            Print(logPrefix + "🎯 TRADE EXECUTED SUCCESSFULLY!");
            Print(logPrefix + "  Ticket: ", g_trade.ResultOrder());
            Print(logPrefix + "  Execution Price: ", DoubleToString(g_trade.ResultPrice(), _Digits));
            Print(logPrefix + "  Slippage: ", DoubleToString(MathAbs(g_trade.ResultPrice() - price) / _Point, 1), " pips");
        }
        else
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
    
    // Place stop order
    bool tradeResult = false;
    if(strongestLevel.isResistance)
        tradeResult = g_trade.BuyStop(NormalizeDouble(lot, 2), NormalizeDouble(breakoutLevel, _Digits), NormalizeDouble(breakoutSL, _Digits), NormalizeDouble(breakoutTP, _Digits), (string)comment);
    else
        tradeResult = g_trade.SellStop(NormalizeDouble(lot, 2), NormalizeDouble(breakoutLevel, _Digits), NormalizeDouble(breakoutSL, _Digits), NormalizeDouble(breakoutTP, _Digits), (string)comment);
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
        return false;
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
        return false;
    }
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "🎯 ALL CRITERIA PASSED - ", direction, " TREND SIGNAL CONFIRMED!");
        Print(logPrefix + "  ✅ Trend Follower (if enabled)");
        Print(logPrefix + "  ✅ EMA Alignment (H1 & H4)");
        Print(logPrefix + "  ✅ Price Pullback (≤ 1×ATR from EMA20)");
        Print(logPrefix + "  ✅ RSI Momentum (40-60 range with correct direction)");
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Breakout signal function                                         |
//+------------------------------------------------------------------+
bool Signal_BREAKOUT(const RegimeSnapshot &rs)
{
    string logPrefix = "[BREAKOUT CRITERIA] ";
    
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
            Print(logPrefix + "❌ CRITERIA FAILED: No inside bar, NR7 pattern, or ATR expansion detected");
        Print(StringFormat("[BREAKOUT] FAIL pattern (IB:%s NR7:%s ATRexp:%s)",
                           insideBar ? "Y" : "N",
                           nr7 ? "Y" : "N",
                           atrExpanding ? "Y" : "N"));
        return false;
    }
    
    // Check if near strong key level
    SKeyLevel strongestLevel;
    if(!g_keyLevelDetector.GetStrongestLevel(strongestLevel))
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ CRITERIA FAILED: No strong key levels available");
        Print("[BREAKOUT] FAIL: no strong key levels");
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
            Print(logPrefix + "❌ CRITERIA FAILED: Price not close enough to key level (>0.5×ATR)");
        Print(StringFormat("[BREAKOUT] FAIL proximity dist=%sp max=%sp",
                           DoubleToString(distanceToLevel / _Point, 1),
                           DoubleToString(maxDistance / _Point, 1)));
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
            Print(logPrefix + "❌ CRITERIA FAILED: Insufficient volume spike (need ≥1.2x average)");
        Print(StringFormat("[BREAKOUT] FAIL volume ratio=%sx need>=1.20x",
                           DoubleToString(volumeRatio, 2)));
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
    
    return true;
}

//+------------------------------------------------------------------+
//| Range signal function                                            |
//+------------------------------------------------------------------+
bool Signal_RANGE(const RegimeSnapshot &rs)
{
    string logPrefix = "[RANGE CRITERIA] ";
    
    if(InpLogDetailedInfo)
        Print(logPrefix + "Evaluating range signal criteria...");
    
    // Range width ≥ 1.5 × spread
    SKeyLevel resistanceLevel, supportLevel;
    if(!GetRangeBoundaries(resistanceLevel, supportLevel))
    {
        if(InpLogDetailedInfo)
            Print(logPrefix + "❌ CRITERIA FAILED: Cannot identify range boundaries");
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
        return false;
    }
    
    if(InpLogDetailedInfo)
    {
        Print(logPrefix + "🎯 ALL RANGE CRITERIA PASSED!");
        Print(logPrefix + "  ✅ Range width sufficient (≥1.5×spread)");
        Print(logPrefix + "  ✅ Low trend strength (ADX < 20)");
        Print(logPrefix + "  ✅ Valid entry signal: ", entryReason);
    }
    
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
        
        if(InpTFAdxThreshold < 15.0 || InpTFAdxThreshold > 40.0)
        {
            Print("ERROR: InpTFAdxThreshold must be between 15.0 and 40.0. Current: ", InpTFAdxThreshold);
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