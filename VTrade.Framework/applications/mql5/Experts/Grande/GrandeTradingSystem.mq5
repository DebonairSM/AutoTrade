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
input int    InpLookbackPeriod = 100;            // Lookback Period for Key Levels
input double InpMinStrength = 0.65;              // Minimum Level Strength
input double InpTouchZone = 0.0005;              // Touch Zone (0 = auto)
input int    InpMinTouches = 2;                  // Minimum Touches Required

input group "=== Display Settings ==="
input bool   InpShowRegimeBackground = true;     // Show Regime Background Colors
input bool   InpShowRegimeInfo = true;           // Show Regime Info Panel
input bool   InpShowKeyLevels = true;            // Show Key Level Lines
input bool   InpShowSystemStatus = true;         // Show System Status Panel
input bool   InpShowRegimeTrendArrows = true;    // Show Regime Trend Arrows
input bool   InpShowADXStrengthMeter = true;     // Show ADX Strength Meter
input bool   InpShowRegimeAlerts = true;         // Show Regime Change Alerts
input bool   InpLogDetailedInfo = true;          // Log Detailed Information

input group "=== Update Settings ==="
input int    InpRegimeUpdateSeconds = 5;         // Regime Update Interval (seconds)
input int    InpKeyLevelUpdateSeconds = 300;     // Key Level Update Interval (seconds)

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CGrandeMarketRegimeDetector*  g_regimeDetector;
CGrandeKeyLevelDetector*      g_keyLevelDetector;
RegimeConfig                  g_regimeConfig;
datetime                      g_lastRegimeUpdate;
datetime                      g_lastKeyLevelUpdate;
datetime                      g_lastDisplayUpdate;
long                          g_chartID;

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
    Print("=== Grande Tech Advanced Trading System ===");
    Print("Initializing for symbol: ", _Symbol);
    
    // Get chart ID
    g_chartID = ChartID();
    
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
    
    if(!g_regimeDetector.Initialize(_Symbol, g_regimeConfig))
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
                                      InpMinTouches, InpLogDetailedInfo))
    {
        Print("ERROR: Failed to initialize Key Level Detector");
        delete g_regimeDetector;
        delete g_keyLevelDetector;
        g_regimeDetector = NULL;
        g_keyLevelDetector = NULL;
        return INIT_FAILED;
    }
    
    // Set up chart display - always setup for any visual features
    SetupChartDisplay();
    
    // Set timer for updates
    EventSetTimer(MathMin(InpRegimeUpdateSeconds, InpKeyLevelUpdateSeconds));
    
    // Initialize update times
    g_lastRegimeUpdate = 0;
    g_lastKeyLevelUpdate = 0;
    g_lastDisplayUpdate = 0;
    
    // Initial analysis
    PerformInitialAnalysis();
    
    Print("Grande Trading System initialized successfully");
    Print("Configuration Summary:");
    Print("  - ADX Trend Threshold: ", InpADXTrendThreshold);
    Print("  - Key Level Min Strength: ", InpMinStrength);
    Print("  - Lookback Period: ", InpLookbackPeriod);
    Print("  - Display Features: Regime=", InpShowRegimeBackground ? "ON" : "OFF", 
          ", KeyLevels=", InpShowKeyLevels ? "ON" : "OFF");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
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
    
    // Clean up chart objects
    CleanupChartObjects();
    
    Print("Grande Trading System deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Lightweight tick processing
    if(g_regimeDetector != NULL)
    {
        g_regimeDetector.UpdateRegime();
    }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
    datetime currentTime = TimeCurrent();
    
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
    
    // Update display elements
    if(currentTime - g_lastDisplayUpdate >= 10) // Update display every 10 seconds
    {
        UpdateDisplayElements();
        g_lastDisplayUpdate = currentTime;
    }
}

//+------------------------------------------------------------------+
//| Setup chart display                                              |
//+------------------------------------------------------------------+
void SetupChartDisplay()
{
    Print("[Grande] DEBUG: Setting up chart display properties");
    
    // Set chart properties for better visualization
    ChartSetInteger(g_chartID, CHART_SHOW_GRID, false);
    ChartSetInteger(g_chartID, CHART_COLOR_BACKGROUND, clrBlack);
    ChartSetInteger(g_chartID, CHART_COLOR_FOREGROUND, clrWhite);
    ChartSetInteger(g_chartID, CHART_COLOR_GRID, clrDimGray);
    
    Print("[Grande] DEBUG: Chart display setup completed - Chart ID: ", g_chartID);
}

//+------------------------------------------------------------------+
//| Perform initial analysis                                         |
//+------------------------------------------------------------------+
void PerformInitialAnalysis()
{
    Print("[Grande] Performing initial market analysis...");
    
    // Get initial regime snapshot
    if(g_regimeDetector != NULL)
    {
        RegimeSnapshot initialRegime = g_regimeDetector.DetectCurrentRegime();
        Print("[Grande] Current Market Regime: ", g_regimeDetector.RegimeToString(initialRegime.regime));
        Print("[Grande] Regime Confidence: ", DoubleToString(initialRegime.confidence, 3));
    }
    
    // Detect initial key levels
    if(g_keyLevelDetector != NULL)
    {
        if(g_keyLevelDetector.DetectKeyLevels())
        {
            Print("[Grande] Found ", g_keyLevelDetector.GetKeyLevelCount(), " key levels");
            
            if(InpShowKeyLevels)
                g_keyLevelDetector.UpdateChartDisplay();
        }
        else
        {
            Print("[Grande] No significant key levels detected");
        }
    }
    
    // Force immediate visual update
    UpdateDisplayElements();
    Print("[Grande] Visual display elements updated");
    
    // Ensure chart redraws
    ChartRedraw(g_chartID);
}

//+------------------------------------------------------------------+
//| Update display elements                                          |
//+------------------------------------------------------------------+
void UpdateDisplayElements()
{
    if(g_regimeDetector == NULL) 
    {
        Print("[Grande] DEBUG: Regime detector is NULL - skipping display update");
        return;
    }
    
    RegimeSnapshot currentRegime = g_regimeDetector.GetLastSnapshot();
    Print("[Grande] DEBUG: Updating display elements for regime: ", g_regimeDetector.RegimeToString(currentRegime.regime));
    
    // Update regime background
    if(InpShowRegimeBackground)
    {
        Print("[Grande] DEBUG: Updating regime background");
        UpdateRegimeBackground(currentRegime.regime);
    }
    
    // Update info panels
    if(InpShowRegimeInfo)
    {
        Print("[Grande] DEBUG: Updating regime info panel");
        UpdateRegimeInfoPanel(currentRegime);
    }
        
    if(InpShowSystemStatus)
    {
        Print("[Grande] DEBUG: Updating system status panel");
        UpdateSystemStatusPanel();
    }
        
    // Update additional visual indicators
    if(InpShowRegimeTrendArrows)
    {
        Print("[Grande] DEBUG: Updating regime trend arrows");
        UpdateRegimeTrendArrows(currentRegime);
    }
        
    if(InpShowADXStrengthMeter)
    {
        Print("[Grande] DEBUG: Updating ADX strength meter");
        UpdateADXStrengthMeter(currentRegime);
    }
    
    Print("[Grande] DEBUG: Forcing chart redraw");
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
    
    Print("[Grande] DEBUG: Background color for regime ", regime, " = ", bgColor);
    
    // Remove existing background
    ObjectDelete(g_chartID, REGIME_BACKGROUND_NAME);
    
    // Create new background rectangle
    if(bgColor != clrNONE)
    {
        datetime timeStart = iTime(_Symbol, PERIOD_CURRENT, 500);
        datetime timeEnd = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 100;
        double priceHigh = ChartGetDouble(g_chartID, CHART_PRICE_MAX);
        double priceLow = ChartGetDouble(g_chartID, CHART_PRICE_MIN);
        
        Print("[Grande] DEBUG: Creating background rectangle from ", TimeToString(timeStart), " to ", TimeToString(timeEnd));
        Print("[Grande] DEBUG: Price range ", priceLow, " to ", priceHigh);
        
        bool created = ObjectCreate(g_chartID, REGIME_BACKGROUND_NAME, OBJ_RECTANGLE, 0, 
                    timeStart, priceLow, timeEnd, priceHigh);
        
        if(created)
        {
            ObjectSetInteger(g_chartID, REGIME_BACKGROUND_NAME, OBJPROP_COLOR, bgColor);
            ObjectSetInteger(g_chartID, REGIME_BACKGROUND_NAME, OBJPROP_FILL, true);
            ObjectSetInteger(g_chartID, REGIME_BACKGROUND_NAME, OBJPROP_BACK, true);
            ObjectSetInteger(g_chartID, REGIME_BACKGROUND_NAME, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(g_chartID, REGIME_BACKGROUND_NAME, OBJPROP_HIDDEN, true);
            Print("[Grande] DEBUG: Background rectangle created successfully");
        }
        else
        {
            Print("[Grande] DEBUG: FAILED to create background rectangle. Error: ", GetLastError());
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
        "Confidence: %.2f\n" +
        "─────────────────────────\n" +
        "ADX H1: %.1f | H4: %.1f | D1: %.1f\n" +
        "ATR Ratio: %.2f\n" +
        "+DI: %.1f | -DI: %.1f\n" +
        "─────────────────────────\n" +
        "Key Levels: %d\n" +
        "Updated: %s",
        g_regimeDetector.RegimeToString(snapshot.regime),
        snapshot.confidence,
        snapshot.adx_h1,
        snapshot.adx_h4,
        snapshot.adx_d1,
        (snapshot.atr_avg > 0) ? snapshot.atr_current / snapshot.atr_avg : 0.0,
        snapshot.plus_di,
        snapshot.minus_di,
        g_keyLevelDetector != NULL ? g_keyLevelDetector.GetKeyLevelCount() : 0,
        TimeToString(snapshot.timestamp, TIME_MINUTES)
    );
    
    Print("[Grande] DEBUG: Creating info panel with text length: ", StringLen(infoText));
    
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
        Print("[Grande] DEBUG: Info panel created successfully");
    }
    else
    {
        Print("[Grande] DEBUG: FAILED to create info panel. Error: ", GetLastError());
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
    
    // Create status text
    string statusText = StringFormat(
        "═══ SYSTEM STATUS ═══\n" +
        "Symbol: %s\n" +
        "Timeframe: %s\n" +
        "Spread: %.1f pips\n" +
        "─────────────────\n" +
        "Strongest Level:\n" +
        "%s\n" +
        "─────────────────\n" +
        "Updates:\n" +
        "Regime: %ds\n" +
        "Levels: %ds\n" +
        "─────────────────\n" +
        "Grande Tech\n" +
        "www.grandetech.com.br",
        _Symbol,
        EnumToString(Period()),
        (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) / 10.0,
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
    Print("=== GRANDE REGIME CHANGE DETECTED ===");
    Print("New Regime: ", g_regimeDetector.RegimeToString(snapshot.regime));
    Print("Confidence: ", DoubleToString(snapshot.confidence, 3));
    Print("Time: ", TimeToString(snapshot.timestamp, TIME_DATE|TIME_MINUTES));
    Print("ADX Values - H1:", DoubleToString(snapshot.adx_h1, 1), 
          " H4:", DoubleToString(snapshot.adx_h4, 1), 
          " D1:", DoubleToString(snapshot.adx_d1, 1));
    
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
            Print("[Grande] TESTING VISUALS - Creating test elements");
            CreateTestVisuals();
        }
        else if(lparam == 'C' || lparam == 'c') // Press 'C' to clear all objects
        {
            Print("[Grande] CLEARING ALL OBJECTS");
            CleanupChartObjects();
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
        ObjectSetString(g_chartID, arrowName, OBJPROP_TOOLTIP, 
                       StringFormat("Regime: %s (Confidence: %.2f)", 
                                   g_regimeDetector.RegimeToString(snapshot.regime),
                                   snapshot.confidence));
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
    string meterText = StringFormat(
        "ADX STRENGTH METER\n" +
        "══════════════════\n" +
        "Current TF: %.1f %s\n" +
        "H4: %.1f %s\n" +
        "D1: %.1f %s\n" +
        "══════════════════\n" +
        "Trend Strength:\n" +
        "%s",
        snapshot.adx_h1, GetADXStrengthBar(snapshot.adx_h1),
        snapshot.adx_h4, GetADXStrengthBar(snapshot.adx_h4),
        snapshot.adx_d1, GetADXStrengthBar(snapshot.adx_d1),
        GetTrendStrengthDescription(snapshot.adx_h1)
    );
    
    // Create meter label
    ObjectCreate(g_chartID, ADX_STRENGTH_METER_NAME, OBJ_LABEL, 0, 0, 0);
    ObjectSetString(g_chartID, ADX_STRENGTH_METER_NAME, OBJPROP_TEXT, meterText);
    ObjectSetInteger(g_chartID, ADX_STRENGTH_METER_NAME, OBJPROP_CORNER, CORNER_LEFT_LOWER);
    ObjectSetInteger(g_chartID, ADX_STRENGTH_METER_NAME, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(g_chartID, ADX_STRENGTH_METER_NAME, OBJPROP_YDISTANCE, 150);
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
    return "�� RANGING MARKET";
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
        
        Print("[Grande] TEST: Visual test label created successfully");
    }
    else
    {
        Print("[Grande] TEST: FAILED to create test label. Error: ", GetLastError());
    }
    
    // Force display update
    UpdateDisplayElements();
    ChartRedraw(g_chartID);
} 