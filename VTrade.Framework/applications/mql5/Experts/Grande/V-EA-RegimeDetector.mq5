//+------------------------------------------------------------------+
//| V-EA-RegimeDetector.mq5                                          |
//| Copyright 2024, Grande Tech                                      |
//| Market Regime Detection Demo EA - Module 1 Implementation       |
//+------------------------------------------------------------------+
// Pattern from: MetaTrader 5 MQL5 Documentation  
// Reference: Expert Advisor OnInit/OnTick/OnDeinit event handling patterns

#property copyright "Copyright 2024, Grande Tech"
#property link      "https://www.grandetech.com"
#property version   "1.00"
#property description "Market Regime Detection Demo EA for Grande Tech"

#include <Grande/VMarketRegimeDetector.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== Regime Detection Settings ==="
input double InpADXTrendThreshold = 25.0;    // ADX Threshold for Trending
input double InpADXBreakoutMin = 20.0;       // ADX Minimum for Breakout Setup
input int    InpATRPeriod = 14;              // ATR Period
input int    InpATRAvgPeriod = 90;           // ATR Average Period (for volatility)
input double InpHighVolMultiplier = 2.0;     // High Volatility Multiplier

input group "=== Visual Display Settings ==="
input bool   InpShowRegimeOnChart = true;    // Show Regime Background on Chart
input bool   InpShowRegimeInfo = true;       // Show Regime Info Panel
input bool   InpLogRegimeChanges = true;     // Log Regime Changes to Experts Tab

input group "=== Update Settings ==="
input int    InpUpdateIntervalSeconds = 5;   // Update Interval (seconds)

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CMarketRegimeDetector*  g_regimeDetector;
RegimeConfig           g_config;
datetime               g_lastChartUpdate;
long                   g_chartID;

// Chart object names
const string REGIME_BACKGROUND_NAME = "RegimeBackground";
const string REGIME_INFO_PANEL_NAME = "RegimeInfoPanel";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== Grande Tech Market Regime Detector EA ===");
    Print("Initializing for symbol: ", _Symbol);
    
    // Get chart ID
    g_chartID = ChartID();
    
    // Configure regime detection settings
    g_config.adx_trend_threshold = InpADXTrendThreshold;
    g_config.adx_breakout_min = InpADXBreakoutMin;
    g_config.adx_ranging_threshold = InpADXBreakoutMin;
    g_config.atr_period = InpATRPeriod;
    g_config.atr_avg_period = InpATRAvgPeriod;
    g_config.high_vol_multiplier = InpHighVolMultiplier;
    g_config.tf_primary = PERIOD_H1;
    g_config.tf_secondary = PERIOD_H4;
    g_config.tf_tertiary = PERIOD_D1;
    
    // Create regime detector
    g_regimeDetector = new CMarketRegimeDetector();
    if(g_regimeDetector == NULL)
    {
        Print("ERROR: Failed to create Market Regime Detector");
        return INIT_FAILED;
    }
    
    // Initialize detector
    if(!g_regimeDetector.Initialize(_Symbol, g_config))
    {
        Print("ERROR: Failed to initialize Market Regime Detector");
        delete g_regimeDetector;
        g_regimeDetector = NULL;
        return INIT_FAILED;
    }
    
    // Set up chart display
    if(InpShowRegimeOnChart)
        SetupChartDisplay();
    
    // Set timer for updates
    EventSetTimer(InpUpdateIntervalSeconds);
    
    Print("Market Regime Detector EA initialized successfully");
    Print("Configuration:");
    Print("  - ADX Trend Threshold: ", InpADXTrendThreshold);
    Print("  - ADX Breakout Min: ", InpADXBreakoutMin);
    Print("  - ATR Period: ", InpATRPeriod);
    Print("  - High Vol Multiplier: ", InpHighVolMultiplier);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("Deinitializing Market Regime Detector EA. Reason: ", reason);
    
    // Clean up timer
    EventKillTimer();
    
    // Clean up detector
    if(g_regimeDetector != NULL)
    {
        delete g_regimeDetector;
        g_regimeDetector = NULL;
    }
    
    // Clean up chart objects
    CleanupChartObjects();
    
    Print("Market Regime Detector EA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Main regime detection logic runs in OnTimer
    // OnTick is kept minimal for performance
    
    if(g_regimeDetector == NULL)
        return;
        
    // Update regime detection (lightweight check)
    g_regimeDetector.UpdateRegime();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
    if(g_regimeDetector == NULL)
        return;
        
    // Get current regime
    RegimeSnapshot currentSnapshot = g_regimeDetector.DetectCurrentRegime();
    
    // Update chart display
    if(InpShowRegimeOnChart)
        UpdateChartDisplay(currentSnapshot);
    
    // Log detailed info periodically (every 5 minutes)
    static datetime lastDetailLog = 0;
    if(TimeCurrent() - lastDetailLog >= 300) // 5 minutes
    {
        LogDetailedRegimeInfo(currentSnapshot);
        lastDetailLog = TimeCurrent();
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
    ChartSetInteger(g_chartID, CHART_COLOR_GRID, clrGray);
    
    Print("Chart display setup completed");
}

//+------------------------------------------------------------------+
//| Update chart display with regime information                     |
//+------------------------------------------------------------------+
void UpdateChartDisplay(const RegimeSnapshot &snapshot)
{
    // Update only if enough time has passed or regime changed
    if(TimeCurrent() - g_lastChartUpdate < 10 && 
       snapshot.timestamp == g_lastChartUpdate)
        return;
    
    // Update background color based on regime
    UpdateRegimeBackground(snapshot.regime);
    
    // Update info panel
    if(InpShowRegimeInfo)
        UpdateInfoPanel(snapshot);
    
    g_lastChartUpdate = TimeCurrent();
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
            bgColor = C'0,50,0';        // Dark green
            break;
        case REGIME_TREND_BEAR:
            bgColor = C'50,0,0';        // Dark red
            break;
        case REGIME_BREAKOUT_SETUP:
            bgColor = C'50,50,0';       // Dark yellow
            break;
        case REGIME_RANGING:
            bgColor = C'25,25,25';      // Dark gray
            break;
        case REGIME_HIGH_VOLATILITY:
            bgColor = C'50,0,50';       // Dark purple
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
        
        ObjectCreate(g_chartID, REGIME_BACKGROUND_NAME, OBJ_RECTANGLE, 0, 
                    timeStart, priceLow, timeEnd, priceHigh);
        ObjectSetInteger(g_chartID, REGIME_BACKGROUND_NAME, OBJPROP_COLOR, bgColor);
        ObjectSetInteger(g_chartID, REGIME_BACKGROUND_NAME, OBJPROP_FILL, true);
        ObjectSetInteger(g_chartID, REGIME_BACKGROUND_NAME, OBJPROP_BACK, true);
        ObjectSetInteger(g_chartID, REGIME_BACKGROUND_NAME, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(g_chartID, REGIME_BACKGROUND_NAME, OBJPROP_HIDDEN, true);
    }
}

//+------------------------------------------------------------------+
//| Update information panel                                         |
//+------------------------------------------------------------------+
void UpdateInfoPanel(const RegimeSnapshot &snapshot)
{
    // Remove existing panel
    ObjectDelete(g_chartID, REGIME_INFO_PANEL_NAME);
    
    // Create info text
    string infoText = StringFormat(
        "REGIME: %s\n" +
        "Confidence: %.2f\n" +
        "ADX H1: %.1f\n" +
        "ADX H4: %.1f\n" +
        "ADX D1: %.1f\n" +
        "ATR Ratio: %.2f\n" +
        "+DI: %.1f | -DI: %.1f\n" +
        "Updated: %s",
        g_regimeDetector.RegimeToString(snapshot.regime),
        snapshot.confidence,
        snapshot.adx_h1,
        snapshot.adx_h4,
        snapshot.adx_d1,
        (snapshot.atr_avg > 0) ? snapshot.atr_current / snapshot.atr_avg : 0.0,
        snapshot.plus_di,
        snapshot.minus_di,
        TimeToString(snapshot.timestamp, TIME_MINUTES)
    );
    
    // Create text label
    ObjectCreate(g_chartID, REGIME_INFO_PANEL_NAME, OBJ_LABEL, 0, 0, 0);
    ObjectSetString(g_chartID, REGIME_INFO_PANEL_NAME, OBJPROP_TEXT, infoText);
    ObjectSetInteger(g_chartID, REGIME_INFO_PANEL_NAME, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(g_chartID, REGIME_INFO_PANEL_NAME, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(g_chartID, REGIME_INFO_PANEL_NAME, OBJPROP_YDISTANCE, 30);
    ObjectSetInteger(g_chartID, REGIME_INFO_PANEL_NAME, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(g_chartID, REGIME_INFO_PANEL_NAME, OBJPROP_FONTSIZE, 10);
    ObjectSetString(g_chartID, REGIME_INFO_PANEL_NAME, OBJPROP_FONT, "Courier New");
    ObjectSetInteger(g_chartID, REGIME_INFO_PANEL_NAME, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Log detailed regime information                                  |
//+------------------------------------------------------------------+
void LogDetailedRegimeInfo(const RegimeSnapshot &snapshot)
{
    if(!InpLogRegimeChanges)
        return;
        
    Print("=== REGIME STATUS UPDATE ===");
    Print("Symbol: ", _Symbol);
    Print("Current Regime: ", g_regimeDetector.RegimeToString(snapshot.regime));
    Print("Confidence Level: ", DoubleToString(snapshot.confidence, 3));
    Print("Timestamp: ", TimeToString(snapshot.timestamp, TIME_DATE|TIME_MINUTES));
    Print("");
    Print("ADX Values:");
    Print("  H1: ", DoubleToString(snapshot.adx_h1, 2));
    Print("  H4: ", DoubleToString(snapshot.adx_h4, 2));
    Print("  D1: ", DoubleToString(snapshot.adx_d1, 2));
    Print("");
    Print("Directional Indicators:");
    Print("  +DI: ", DoubleToString(snapshot.plus_di, 2));
    Print("  -DI: ", DoubleToString(snapshot.minus_di, 2));
    Print("  DI Difference: ", DoubleToString(MathAbs(snapshot.plus_di - snapshot.minus_di), 2));
    Print("");
    Print("Volatility Analysis:");
    Print("  Current ATR: ", DoubleToString(snapshot.atr_current, _Digits));
    Print("  Average ATR: ", DoubleToString(snapshot.atr_avg, _Digits));
    if(snapshot.atr_avg > 0)
        Print("  ATR Ratio: ", DoubleToString(snapshot.atr_current / snapshot.atr_avg, 3));
    Print("");
    Print("Regime Conditions:");
    Print("  Is Trending: ", g_regimeDetector.IsTrending() ? "YES" : "NO");
    Print("  Is Bull Trend: ", g_regimeDetector.IsTrendingBull() ? "YES" : "NO");
    Print("  Is Bear Trend: ", g_regimeDetector.IsTrendingBear() ? "YES" : "NO");
    Print("  Is Ranging: ", g_regimeDetector.IsRanging() ? "YES" : "NO");
    Print("  Is Breakout Setup: ", g_regimeDetector.IsBreakoutSetup() ? "YES" : "NO");
    Print("  Is High Volatility: ", g_regimeDetector.IsHighVolatility() ? "YES" : "NO");
    Print("================================");
}

//+------------------------------------------------------------------+
//| Clean up chart objects                                           |
//+------------------------------------------------------------------+
void CleanupChartObjects()
{
    ObjectDelete(g_chartID, REGIME_BACKGROUND_NAME);
    ObjectDelete(g_chartID, REGIME_INFO_PANEL_NAME);
    ChartRedraw(g_chartID);
    Print("Chart objects cleaned up");
}

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
    // Handle chart events if needed
    if(id == CHARTEVENT_CHART_CHANGE)
    {
        if(InpShowRegimeOnChart && g_regimeDetector != NULL)
        {
            RegimeSnapshot currentSnapshot = g_regimeDetector.GetLastSnapshot();
            UpdateChartDisplay(currentSnapshot);
        }
    }
} 